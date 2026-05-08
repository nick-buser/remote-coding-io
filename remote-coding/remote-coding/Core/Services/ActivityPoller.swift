import Foundation
import Observation

/// Scope a poller is bound to. The Inbox feed is workspace-scoped; the
/// Project / Feature detail screens spawn additional scoped pollers
/// alongside the workspace one.
enum ActivityPollerScope: Hashable {
    case workspace
    case project(idOrSlug: String)
    case feature(id: Int64)
}

/// Observable activity feed driven by `repository.listActivity`.
///
/// Events stream in latest-first; the cursor is the most recent
/// `createdAt` the poller has seen, and each subsequent tick fetches
/// `since: cursor`. `needsYou` flips when an unseen `kind ∈ {question,
/// review}` event arrives and resets through `markSeen()`.
///
/// The poller exposes `start / stop` so the app can pause it while the
/// terminal screen is presented (per `service-terminal-shell`) and
/// resume it on dismiss. Scene-phase wiring is the caller's
/// responsibility — the poller does not subscribe to ScenePhase
/// itself, which keeps it usable from previews and tests without
/// pulling SwiftUI in.
@Observable
@MainActor
final class ActivityPoller {
    /// Latest-first. Capped at `Self.eventsCap` to avoid unbounded
    /// growth on long-running app sessions.
    private(set) var events: [Components.Schemas.ActivityEvent] = []

    /// `true` when an unseen attention-grade event (question / review)
    /// is in the buffer. The tab-bar Inbox dot reads this directly.
    private(set) var needsYou: Bool = false

    static let eventsCap = 500

    /// Kinds that flip `needsYou` when added past the seen cursor.
    private static let attentionKinds: Set<Components.Schemas.ActivityKind> = [.question, .review]

    @ObservationIgnored private let repository: TmuxAgentRepository
    @ObservationIgnored private let interval: Duration
    @ObservationIgnored private let limit: Int
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private(set) var cursor: Date?
    @ObservationIgnored private var seenCursor: Date?
    @ObservationIgnored private(set) var scope: ActivityPollerScope = .workspace

    init(
        repository: TmuxAgentRepository,
        interval: Duration = .seconds(5),
        limit: Int = 100
    ) {
        self.repository = repository
        self.interval = interval
        self.limit = limit
    }

    /// Start polling at `interval`. Idempotent — calling `start` while
    /// already running stops the previous task and re-anchors the
    /// scope.
    func start(scope: ActivityPollerScope) {
        stop()
        self.scope = scope
        let interval = self.interval
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// Marks the latest event as seen — `needsYou` resets until a
    /// newer attention-grade event arrives.
    func markSeen() {
        seenCursor = events.first?.createdAt ?? Date()
        recomputeNeedsYou()
    }

    /// Single fetch + merge cycle, exposed for tests so the polling
    /// loop's timer doesn't have to be exercised.
    @discardableResult
    func tick() async -> [Components.Schemas.ActivityEvent] {
        let project: String?
        let feature: Int64?
        switch scope {
        case .workspace:
            project = nil
            feature = nil
        case .project(let idOrSlug):
            project = idOrSlug
            feature = nil
        case .feature(let id):
            project = nil
            feature = id
        }
        let fetched: [Components.Schemas.ActivityEvent]
        do {
            fetched = try await repository.listActivity(
                project: project,
                feature: feature,
                since: cursor,
                limit: limit
            )
        } catch {
            return []
        }
        guard !fetched.isEmpty else { return [] }
        // listActivity returns newest-first; prepend to the buffer and
        // cap. Cursor advances to the newest event in the page.
        let merged = (fetched + events).prefix(Self.eventsCap)
        events = Array(merged)
        cursor = fetched.first?.createdAt
        recomputeNeedsYou()
        return fetched
    }

    private func recomputeNeedsYou() {
        let threshold = seenCursor
        needsYou = events.contains { event in
            guard Self.attentionKinds.contains(event.kind) else { return false }
            guard let threshold else { return true }
            return event.createdAt > threshold
        }
    }
}
