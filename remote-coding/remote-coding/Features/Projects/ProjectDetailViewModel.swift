import Foundation
import Observation

@MainActor
@Observable
final class ProjectDetailViewModel {
    var project: OpenAPI.Project
    var features: [OpenAPI.Feature] = []
    var documents: [WorkspaceDocument] = []
    var sessions: [OpenAPI.Session] = []
    var panes: [String: [OpenAPI.Pane]] = [:]
    var isLoading = false
    var errorMessage: String?

    init(project: OpenAPI.Project) {
        self.project = project
    }

    func load(repository: TmuxAgentRepository) async {
        isLoading = true
        errorMessage = nil
        do {
            async let loadedFeatures = repository.listFeatures(projectIDOrSlug: project.slug)
            async let loadedDocuments = repository.listProjectDocuments(projectID: project.id)
            async let loadedSessions = repository.listSessions(projectID: project.id)
            features = try await loadedFeatures
            documents = try await loadedDocuments
            sessions = try await loadedSessions
            for session in sessions {
                panes[session.name] = try await repository.listPanes(sessionName: session.name)
            }
        } catch {
            errorMessage = "Unable to load project workspace."
        }
        isLoading = false
    }

    func openProjectSession(repository: TmuxAgentRepository) async {
        do {
            project = try await repository.openProjectSession(idOrSlug: project.slug)
            sessions = try await repository.listSessions(projectID: project.id)
            for session in sessions {
                panes[session.name] = try await repository.listPanes(sessionName: session.name)
            }
        } catch {
            errorMessage = "Unable to open tmux session."
        }
    }
}
