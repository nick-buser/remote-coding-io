import Foundation
import Observation

@MainActor
@Observable
final class ProjectListViewModel {
    var projects: [Components.Schemas.Project] = []
    var isLoading = false
    var errorMessage: String?

    func load(repository: TmuxAgentRepository) async {
        isLoading = true
        errorMessage = nil
        do {
            projects = try await repository.listProjects()
        } catch {
            errorMessage = "Unable to load projects."
        }
        isLoading = false
    }
}

