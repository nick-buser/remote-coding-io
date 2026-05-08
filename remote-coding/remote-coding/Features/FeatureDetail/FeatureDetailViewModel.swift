import Foundation
import Observation

/// View model for the Feature detail screen.
///
/// Owns the project + feature + every collection the four sub-tabs
/// need — tickets, docs, decisions, agent sessions — plus a small
/// progress rollup. Loading is sequential at the top level (`async
/// let` for the four list endpoints, awaited in turn). The actual
/// sub-tab bodies stay stubbed in this ticket; their bodies land in
/// service-feature-{tickets,prd,decisions,sessions}-tab.
@MainActor
@Observable
final class FeatureDetailViewModel {
    var project: Components.Schemas.Project
    var feature: Components.Schemas.Feature
    var tickets: [Components.Schemas.Ticket] = []
    var docs: [Components.Schemas.Doc] = []
    var decisions: [Components.Schemas.Decision] = []
    var agentSessions: [Components.Schemas.AgentSession] = []
    var isLoading = false
    var errorMessage: String?

    init(project: Components.Schemas.Project, feature: Components.Schemas.Feature) {
        self.project = project
        self.feature = feature
    }

    // MARK: - Progress

    struct Progress: Equatable, Sendable {
        var done: Int
        var total: Int
        var fraction: Double {
            guard total > 0 else { return 0 }
            return Double(done) / Double(total)
        }
    }

    var progress: Progress {
        let done = tickets.filter { $0.status == .done }.count
        return Progress(done: done, total: tickets.count)
    }

    // MARK: - Header copy

    var publicLabel: String {
        "FEAT-\(String(format: "%03d", feature.id))"
    }

    var statusRole: StatusGlyphRole {
        FeatureStatusStyle.glyphRole(for: feature.status)
    }

    var statusLabel: String {
        FeatureStatusStyle.label(for: feature.status)
    }

    var accentColor: AccentColor {
        ProjectAccentMapper.color(for: feature.accent)
    }

    // MARK: - Load

    func load(repository: TmuxAgentRepository) async {
        isLoading = true
        errorMessage = nil
        do {
            // Refresh the feature first so a status mutation from the
            // dots menu picks up the new value on next reload.
            feature = try await repository.getFeature(id: feature.id)
            async let loadedTickets   = repository.listTickets(featureID: feature.id, status: nil)
            async let loadedDocs      = repository.listFeatureDocs(featureID: feature.id)
            async let loadedDecisions = repository.listFeatureDecisions(featureID: feature.id)
            tickets = try await loadedTickets
            docs = try await loadedDocs
            decisions = try await loadedDecisions
            // Agent sessions for this feature = sessions on any of the
            // feature's tickets. Filter from the project-scoped list
            // to avoid an N+1.
            let projectSessions = try await repository.listProjectAgentSessions(projectIDOrSlug: project.slug)
            let ticketIDs = Set(tickets.map(\.id))
            agentSessions = projectSessions.filter { session in
                guard let ticketID = session.ticketId else { return false }
                return ticketIDs.contains(ticketID)
            }
        } catch {
            errorMessage = "Couldn't load \(feature.title): \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Status mutations

    func setStatus(_ status: Components.Schemas.FeatureStatus, repository: TmuxAgentRepository) async {
        do {
            let updated = try await repository.updateFeatureStatus(
                id: feature.id,
                body: Components.Schemas.UpdateFeatureStatusRequest(status: status)
            )
            feature = updated
        } catch {
            errorMessage = "Couldn't update status: \(error.localizedDescription)"
        }
    }
}
