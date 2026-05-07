import Foundation
import Observation

@MainActor
@Observable
final class FeatureDetailViewModel {
    var project: Components.Schemas.Project
    var feature: Components.Schemas.Feature
    var docs: [Components.Schemas.Doc] = []
    var sessions: [Components.Schemas.Session] = []
    var panes: [String: [Components.Schemas.Pane]] = [:]
    var errorMessage: String?

    init(project: Components.Schemas.Project, feature: Components.Schemas.Feature) {
        self.project = project
        self.feature = feature
    }

    func load(repository: TmuxAgentRepository) async {
        do {
            async let loadedDocs = repository.listFeatureDocs(featureID: feature.id)
            async let loadedSessions = repository.listSessions(featureID: feature.id)
            docs = try await loadedDocs
            sessions = try await loadedSessions
            for session in sessions {
                panes[session.name] = try await repository.listPanes(sessionName: session.name)
            }
        } catch {
            errorMessage = "Unable to load feature."
        }
    }
}
