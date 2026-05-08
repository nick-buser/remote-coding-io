import Foundation
import Observation

/// Resolved context for a question event's `Reply` action — the agent
/// session's tmux session name + pane index. The reply sheet wraps
/// `repository.sendPaneInput` around this and the user's text.
struct ReplyContext: Equatable, Sendable {
    var eventID: Int64
    var sessionName: String
    var paneID: Int
    var ticketPublicID: String?
}

/// View model for the Inbox screen.
///
/// Owns: `selectedFilter`, the set of optimistically-removed event ids
/// (`pendingHidden`), an in-memory accent cache, and an `error` slot.
/// Does **not** own the activity poller — the workspace-scoped poller
/// on `AppModel` is the source of truth, the view passes its `events`
/// snapshot into the VM's pure derivation methods.
@Observable
@MainActor
final class InboxViewModel {
    var selectedFilter: InboxFilter = .all
    var isLoading: Bool = false
    var error: String?
    /// Event ids the VM has optimistically dropped from the row list
    /// (e.g. after an Approve action). Cleared when a fresh poller
    /// tick replaces the upstream feed.
    var pendingHidden: Set<Int64> = []

    @ObservationIgnored private var accentByProjectID: [Int64: AccentColor] = [:]
    @ObservationIgnored private var didLoadAccents = false
    /// Live (non-idle) sessions count rendered in the header subtitle.
    /// Nil until the first successful load. The cross-project fan-out
    /// helper introduced in service-0017 will replace this loader.
    var liveSessionsCount: Int?
    @ObservationIgnored private var didLoadSessions = false

    // MARK: - Derivation

    func visibleEvents(from events: [Components.Schemas.ActivityEvent]) -> [Components.Schemas.ActivityEvent] {
        guard !pendingHidden.isEmpty else { return events }
        return events.filter { !pendingHidden.contains($0.id) }
    }

    /// "Needs you" group: questions + reviews always, plus decisions
    /// newer than the recency window (1h by default).
    func needsYouEvents(
        from events: [Components.Schemas.ActivityEvent],
        now: Date = .now,
        recency: TimeInterval = 3600
    ) -> [Components.Schemas.ActivityEvent] {
        let visible = visibleEvents(from: events)
        let threshold = now.addingTimeInterval(-recency)
        return visible.filter { event in
            switch event.kind {
            case .question, .review:
                return true
            case .decision:
                return event.createdAt > threshold
            default:
                return false
            }
        }
    }

    /// "Earlier today" group: events from the current local day not
    /// already classified as needs-you.
    func earlierTodayEvents(
        from events: [Components.Schemas.ActivityEvent],
        now: Date = .now,
        recency: TimeInterval = 3600,
        calendar: Calendar = .current
    ) -> [Components.Schemas.ActivityEvent] {
        let visible = visibleEvents(from: events)
        let threshold = now.addingTimeInterval(-recency)
        let startOfDay = calendar.startOfDay(for: now)
        return visible.filter { event in
            guard event.createdAt >= startOfDay else { return false }
            switch event.kind {
            case .question, .review:
                return false
            case .decision where event.createdAt > threshold:
                return false
            default:
                return true
            }
        }
    }

    /// Apply the current filter selection to a candidate row list.
    func applyFilter(_ events: [Components.Schemas.ActivityEvent]) -> [Components.Schemas.ActivityEvent] {
        guard selectedFilter != .all else { return events }
        return events.filter { selectedFilter.matches($0) }
    }

    /// Counts shown next to each chip. Built off the visible (non-hidden)
    /// event set so optimistic-hide affects chip counts too.
    func filterCounts(from events: [Components.Schemas.ActivityEvent]) -> [InboxFilter: Int] {
        let visible = visibleEvents(from: events)
        var counts: [InboxFilter: Int] = [:]
        for filter in InboxFilter.displayed {
            counts[filter] = visible.lazy.filter(filter.matches).count
        }
        return counts
    }

    // MARK: - Header subtitle

    /// "<n> need you · <m> sessions live" — the small subtitle under
    /// the title. `liveSessionsCount` is provided by the view (it reads
    /// from project agent sessions via `AppModel`).
    func subtitle(needsYouCount: Int, liveSessionsCount: Int?) -> String {
        let needsYou = "\(needsYouCount) need you"
        if let live = liveSessionsCount {
            return "\(needsYou) · \(live) sessions live"
        } else {
            return needsYou
        }
    }

    // MARK: - Accent resolver

    /// Resolve the accent for a project, falling back to `.iris` when
    /// the project is unknown or its accent string is one of the legacy
    /// web-hub values ("indigo", "teal", "blue", ...). The mapping below
    /// keeps rows visually distinct between projects until the mock
    /// fixtures migrate to the v2 accent set in service-mock-rich-seed.
    func accent(forProjectID id: Int64?) -> AccentColor {
        guard let id, let accent = accentByProjectID[id] else { return .iris }
        return accent
    }

    func loadAccentsIfNeeded(repository: TmuxAgentRepository) async {
        guard !didLoadAccents else { return }
        didLoadAccents = true
        do {
            let projects = try await repository.listProjects()
            for project in projects {
                accentByProjectID[project.id] = Self.accentColor(forRaw: project.accent ?? "")
            }
        } catch {
            // Accent fallback is `.iris`; surface the error only when
            // a user-driven action depends on a live repository call.
            didLoadAccents = false
        }
    }

    /// Fan out across projects to total non-idle agent sessions for the
    /// header subtitle. A single fetch failure cancels the load so a
    /// later appear can retry. Replaced by the cross-project helper
    /// from service-0017 — keep the surface small here.
    func loadLiveSessionsIfNeeded(repository: TmuxAgentRepository) async {
        guard !didLoadSessions else { return }
        didLoadSessions = true
        do {
            let projects = try await repository.listProjects()
            var total = 0
            for project in projects {
                let sessions = try await repository.listProjectAgentSessions(projectIDOrSlug: project.slug)
                total += sessions.filter { $0.state == .active || $0.state == .awaitingInput }.count
            }
            liveSessionsCount = total
        } catch {
            didLoadSessions = false
        }
    }

    static func accentColor(forRaw raw: String) -> AccentColor {
        if let direct = AccentColor(rawValue: raw) { return direct }
        switch raw {
        case "indigo", "blue", "purple": return .iris
        case "teal", "green":             return .mint
        case "orange", "yellow":          return .amber
        case "red", "pink":               return .rose
        case "gray", "grey":              return .slate
        default:                          return .iris
        }
    }

    // MARK: - Tap targets / actions

    /// Resolve the public id of the ticket referenced by an event, by
    /// listing the tickets on the event's feature and matching by
    /// numeric id. Returns nil when either id is missing or the lookup
    /// finds no matching ticket. A `getTicketByID` repository method
    /// would simplify this; tracked as a follow-up.
    func resolveTicketPublicID(
        for event: Components.Schemas.ActivityEvent,
        repository: TmuxAgentRepository
    ) async -> String? {
        guard let ticketId = event.ticketId, let featureId = event.featureId else { return nil }
        do {
            let tickets = try await repository.listTickets(featureID: featureId, status: nil)
            return tickets.first { $0.id == ticketId }?.publicId
        } catch {
            return nil
        }
    }

    /// Resolve the agent session for an event's referenced ticket. Used
    /// by question / commit / test row taps to push `.agentSession`.
    func resolveAgentSession(
        for event: Components.Schemas.ActivityEvent,
        repository: TmuxAgentRepository
    ) async -> Components.Schemas.AgentSession? {
        guard let publicID = await resolveTicketPublicID(for: event, repository: repository) else { return nil }
        do {
            return try await repository.listTicketAgentSessions(ticketPublicID: publicID).first
        } catch {
            return nil
        }
    }

    /// Approve action on a review row. Optimistically hides the row,
    /// calls the repo, and on failure re-shows it and surfaces the
    /// error. The next poller tick will refresh the upstream events.
    func approve(
        event: Components.Schemas.ActivityEvent,
        repository: TmuxAgentRepository
    ) async {
        guard let publicID = await resolveTicketPublicID(for: event, repository: repository) else {
            error = "Couldn't find the ticket for this review."
            return
        }
        pendingHidden.insert(event.id)
        do {
            _ = try await repository.approveTicket(publicID: publicID)
        } catch {
            pendingHidden.remove(event.id)
            self.error = "Approve failed: \(error.localizedDescription)"
        }
    }

    /// Open-pane / open-diff / commit-row body taps. Returns the route
    /// to push (or nil to no-op). Async because session resolution is.
    func route(
        for event: Components.Schemas.ActivityEvent,
        repository: TmuxAgentRepository
    ) async -> AppRoute? {
        switch event.kind {
        case .question, .commit, .test:
            if let session = await resolveAgentSession(for: event, repository: repository) {
                return .agentSession(sessionID: session.id)
            }
            if let publicID = await resolveTicketPublicID(for: event, repository: repository) {
                return .ticketDetail(publicID: publicID)
            }
            return fallbackRoute(for: event)
        case .review, .approve, .check:
            if let publicID = await resolveTicketPublicID(for: event, repository: repository) {
                return .ticketDetail(publicID: publicID)
            }
            return fallbackRoute(for: event)
        case .decision, .doc:
            return fallbackRoute(for: event)
        }
    }

    /// Synchronous fallback used when no ticket / session lookup is
    /// possible. Pure so it's exercisable in unit tests without a repo.
    func fallbackRoute(for event: Components.Schemas.ActivityEvent) -> AppRoute? {
        if let featureID = event.featureId {
            return .featureDetail(featureID: featureID)
        }
        return nil
    }

    /// Build a `ReplyContext` for a question event by resolving its
    /// agent session and parsing the pane string (e.g. `agent:1.0` →
    /// pane index 0). Returns nil when no session is reachable.
    func replyContext(
        for event: Components.Schemas.ActivityEvent,
        repository: TmuxAgentRepository
    ) async -> ReplyContext? {
        guard let session = await resolveAgentSession(for: event, repository: repository) else { return nil }
        let paneID = Self.parsePaneID(session.pane) ?? 0
        let publicID = await resolveTicketPublicID(for: event, repository: repository)
        return ReplyContext(
            eventID: event.id,
            sessionName: session.tmuxSession,
            paneID: paneID,
            ticketPublicID: publicID
        )
    }

    /// `agent:1.0` → 0. Falls back to nil (caller defaults to 0) if
    /// the string isn't in the expected `<window>.<pane>` shape.
    static func parsePaneID(_ pane: String?) -> Int? {
        guard let pane else { return nil }
        let parts = pane.split(separator: ".")
        guard let last = parts.last, let index = Int(last) else { return nil }
        return index
    }

    // MARK: - Refresh

    func refresh(poller: ActivityPoller) async {
        isLoading = true
        defer { isLoading = false }
        _ = await poller.tick()
        // A fresh tick replaces the upstream feed; clear optimistic
        // hides so the new state isn't artificially trimmed.
        pendingHidden.removeAll()
    }
}
