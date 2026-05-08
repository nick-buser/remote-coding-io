import Foundation
import Observation

/// View model for the Sessions tab.
///
/// Aggregates agent sessions across every project in the workspace
/// via `CrossProjectFeatureFetcher.loadFeaturesAndSessions()`. Owns
/// the active filter selection plus a small `RowMetadata` cache that
/// resolves a session's parent feature / ticket / project for the
/// dense row rendering.
@MainActor
@Observable
final class SessionsListViewModel {
    var bundle: CrossProjectFeatureFetcher.Bundle?
    var ticketsByProjectID: [Int64: [Components.Schemas.Ticket]] = [:]
    var selectedFilter: SessionFilter = .all
    var isLoading = false
    var errorMessage: String?

    enum SessionFilter: String, Hashable, CaseIterable, Sendable {
        case all
        case active
        case awaiting
        case idle

        var label: String {
            switch self {
            case .all:      return "All"
            case .active:   return "Active"
            case .awaiting: return "Awaiting"
            case .idle:     return "Idle"
            }
        }

        func matches(_ state: Components.Schemas.SessionState) -> Bool {
            switch self {
            case .all:      return state != .ended
            case .active:   return state == .active
            case .awaiting: return state == .awaitingInput
            case .idle:     return state == .idle
            }
        }

        static let displayed: [SessionFilter] = [.all, .active, .awaiting, .idle]
    }

    // MARK: - Derivation

    var allSessions: [Components.Schemas.AgentSession] {
        bundle?.allAgentSessions.filter { $0.state != .ended } ?? []
    }

    var awaitingSessions: [Components.Schemas.AgentSession] {
        allSessions.filter { $0.state == .awaitingInput }
    }

    var activeSessions: [Components.Schemas.AgentSession] {
        allSessions.filter { $0.state == .active }
    }

    var idleSessions: [Components.Schemas.AgentSession] {
        allSessions.filter { $0.state == .idle }
    }

    /// Hero wins when there are 1–3 awaiting sessions. Above that the
    /// awaiting section renders with the full list and the hero is
    /// hidden (matching the ticket note).
    var heroAwaiting: [Components.Schemas.AgentSession] {
        let awaiting = awaitingSessions
        return awaiting.count <= 3 ? awaiting : []
    }

    /// Awaiting section is hidden when the hero already covers it.
    var awaitingSection: [Components.Schemas.AgentSession] {
        let awaiting = awaitingSessions
        return awaiting.count <= 3 ? [] : awaiting
    }

    /// Filter counts for the chip row. `.ended` sessions never count.
    func filterCounts() -> [SessionFilter: Int] {
        var counts: [SessionFilter: Int] = [:]
        let sessions = allSessions
        for filter in SessionFilter.displayed {
            counts[filter] = sessions.filter { filter.matches($0.state) }.count
        }
        return counts
    }

    // MARK: - Row metadata lookup

    struct RowMetadata: Equatable, Sendable {
        var project: Components.Schemas.Project?
        var ticket: Components.Schemas.Ticket?
        var featurePublicLabel: String?
        var accent: AccentColor
    }

    func metadata(for session: Components.Schemas.AgentSession) -> RowMetadata {
        let project = bundle?.projects.first { project in
            (bundle?.agentSessionsByProjectID[project.id] ?? []).contains { $0.id == session.id }
        }
        let ticket = ticketsByProjectID.values.flatMap { $0 }.first { ticket in
            session.ticketId == ticket.id
        }
        let featureLabel = ticket.map { "FEAT-\(String(format: "%03d", $0.featureId))" }
        let accent = ProjectAccentMapper.color(for: project?.accent ?? "")
        return RowMetadata(project: project, ticket: ticket, featurePublicLabel: featureLabel, accent: accent)
    }

    // MARK: - Header

    func subtitle() -> String {
        let live = activeSessions.count + awaitingSessions.count
        let projectCount = bundle?.projects.count ?? 0
        return "\(live) live · \(projectCount) project\(projectCount == 1 ? "" : "s")"
    }

    // MARK: - Load

    func load(fetcher: CrossProjectFeatureFetcher, repository: TmuxAgentRepository) async {
        isLoading = true
        errorMessage = nil
        do {
            let bundle = try await fetcher.loadFeaturesAndSessions()
            self.bundle = bundle
            // Pre-load tickets per project so row metadata can resolve
            // the session's parent ticket without a per-row fetch.
            var byProject: [Int64: [Components.Schemas.Ticket]] = [:]
            for project in bundle.projects {
                var collected: [Components.Schemas.Ticket] = []
                for feature in bundle.featuresByProjectID[project.id] ?? [] {
                    if let tickets = try? await repository.listTickets(featureID: feature.id, status: nil) {
                        collected.append(contentsOf: tickets)
                    }
                }
                byProject[project.id] = collected
            }
            ticketsByProjectID = byProject
        } catch {
            errorMessage = "Couldn't load sessions: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
