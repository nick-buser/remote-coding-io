import Foundation
import Observation

@MainActor
@Observable
final class FeatureDetailViewModel {
    var project: OpenAPI.Project
    var feature: OpenAPI.Feature
    var documents: [WorkspaceDocument] = []
    var sessions: [OpenAPI.Session] = []
    var panes: [String: [OpenAPI.Pane]] = [:]
    var errorMessage: String?

    init(project: OpenAPI.Project, feature: OpenAPI.Feature) {
        self.project = project
        self.feature = feature
    }

    func load(repository: TmuxAgentRepository) async {
        do {
            async let loadedDocuments = repository.listFeatureDocuments(featureID: feature.id)
            async let loadedSessions = repository.listSessions(featureID: feature.id)
            documents = try await loadedDocuments
            sessions = try await loadedSessions
            for session in sessions {
                panes[session.name] = try await repository.listPanes(sessionName: session.name)
            }
        } catch {
            errorMessage = "Unable to load feature."
        }
    }
}
