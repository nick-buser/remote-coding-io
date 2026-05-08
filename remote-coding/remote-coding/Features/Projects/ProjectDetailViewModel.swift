import Foundation
import Observation

/// View model for the Project detail screen.
///
/// Owns the project plus its child collections (features, tickets,
/// docs, agent sessions) and a small `Stats` rollup for the 4-up
/// strip. Loading is sequential at the top level (`listFeatures` →
/// per-feature `listTickets` / `listFeatureDocs`) for the same
/// reasons documented on `ProjectListViewModel.loadFeatureCounts`.
/// `service-0017` will introduce the parallel fan-out helper that
/// replaces this loader.
@MainActor
@Observable
final class ProjectDetailViewModel {
    var project: Components.Schemas.Project
    var features: [Components.Schemas.Feature] = []
    var ticketsByFeatureID: [Int64: [Components.Schemas.Ticket]] = [:]
    var docsByFeatureID: [Int64: [Components.Schemas.Doc]] = [:]
    var agentSessions: [Components.Schemas.AgentSession] = []
    var liveSessionsByFeatureID: [Int64: Int] = [:]
    var isLoading = false
    var errorMessage: String?

    init(project: Components.Schemas.Project) {
        self.project = project
    }

    // MARK: - Stats

    struct Stats: Equatable, Sendable {
        var active: Int
        var open: Int
        var live: Int
        var total: Int
    }

    var stats: Stats {
        let active = features.filter { $0.status == .inProgress }.count
        let open = ticketsByFeatureID.values.reduce(0) { partial, tickets in
            partial + tickets.filter { $0.status != .done }.count
        }
        let live = agentSessions.filter { $0.state == .active || $0.state == .awaitingInput }.count
        return Stats(active: active, open: open, live: live, total: features.count)
    }

    // MARK: - Section grouping

    /// `(label, status[, status…])` pairs in render order. Sections
    /// with no matching features are filtered out by the view.
    static let featureSections: [(label: String, statuses: [Components.Schemas.FeatureStatus])] = [
        ("In progress", [.inProgress]),
        ("In review",   [.review]),
        ("Planned",     [.planned]),
        ("Shipped",     [.shipped, .merged])
    ]

    func features(for statuses: [Components.Schemas.FeatureStatus]) -> [Components.Schemas.Feature] {
        features.filter { statuses.contains($0.status) }
    }

    /// Flat ticket list across all features for the project's
    /// "Tickets" sub-tab. Ordered by feature, then ticket public id.
    var allTickets: [Components.Schemas.Ticket] {
        features.flatMap { feature -> [Components.Schemas.Ticket] in
            (ticketsByFeatureID[feature.id] ?? []).sorted { $0.publicId < $1.publicId }
        }
    }

    /// Flat doc list across all features. Doc rows render the parent
    /// feature title for context.
    var allDocs: [(feature: Components.Schemas.Feature, doc: Components.Schemas.Doc)] {
        features.flatMap { feature in
            (docsByFeatureID[feature.id] ?? []).map { (feature, $0) }
        }
    }

    // MARK: - Load

    func load(repository: TmuxAgentRepository) async {
        isLoading = true
        errorMessage = nil
        do {
            let loadedFeatures = try await repository.listFeatures(projectIDOrSlug: project.slug)
            let loadedSessions = try await repository.listProjectAgentSessions(projectIDOrSlug: project.slug)
            features = loadedFeatures
            agentSessions = loadedSessions
            // Fan out per-feature data sequentially. The mock seed has
            // ≤4 features per project; the live backend will benefit
            // when service-0017's parallel helper lands.
            var newTickets: [Int64: [Components.Schemas.Ticket]] = [:]
            var newDocs: [Int64: [Components.Schemas.Doc]] = [:]
            var newLive: [Int64: Int] = [:]
            for feature in loadedFeatures {
                if let tickets = try? await repository.listTickets(featureID: feature.id, status: nil) {
                    newTickets[feature.id] = tickets
                }
                if let docs = try? await repository.listFeatureDocs(featureID: feature.id) {
                    newDocs[feature.id] = docs
                }
                let liveForFeature = loadedSessions.filter { session in
                    guard let ticketID = session.ticketId,
                          let tickets = newTickets[feature.id]
                    else { return false }
                    let inFeature = tickets.contains { $0.id == ticketID }
                    let isLive = session.state == .active || session.state == .awaitingInput
                    return inFeature && isLive
                }.count
                newLive[feature.id] = liveForFeature
            }
            ticketsByFeatureID = newTickets
            docsByFeatureID = newDocs
            liveSessionsByFeatureID = newLive
        } catch {
            errorMessage = "Couldn't load \(project.name): \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Header copy

    func subtitle() -> String {
        if let tagline = project.tagline, !tagline.isEmpty {
            return tagline
        }
        return project.localRepoPath
    }
}
