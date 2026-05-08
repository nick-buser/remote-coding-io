import Foundation
import Testing
@testable import remote_coding

struct EditProjectViewModelTests {

    @MainActor
    private func makeExistingProject() async throws -> Components.Schemas.Project {
        let repository = MockTmuxAgentRepository()
        return try await repository.getProject(idOrSlug: "tmux-server-coding-app")
    }

    // MARK: - Mode + pre-fill

    @MainActor
    @Test func initWithExistingPrefillsAndMarksEditMode() async throws {
        let project = try await makeExistingProject()
        let vm = CreateProjectViewModel(existing: project)

        #expect(vm.mode == .edit)
        #expect(vm.name == project.name)
        #expect(vm.slug == project.slug)
        #expect(vm.localRepoPath == project.localRepoPath)
        #expect(vm.status == project.status)
        #expect(vm.pinned == project.pinned)
        #expect(vm.slugWasManuallyEdited)
    }

    @MainActor
    @Test func initWithoutExistingDefaultsToCreateMode() async {
        let vm = CreateProjectViewModel()

        #expect(vm.mode == .create)
        #expect(vm.existing == nil)
        #expect(vm.slugWasManuallyEdited == false)
    }

    // MARK: - Submit routes through updateProject in edit mode

    @MainActor
    @Test func submitInEditModeRoutesThroughUpdateProject() async throws {
        let repository = MockTmuxAgentRepository()
        let project = try await repository.getProject(idOrSlug: "tmux-server-coding-app")
        let vm = CreateProjectViewModel(existing: project)
        vm.tagline = "Updated tagline"

        var captured: Components.Schemas.Project?
        await vm.submit(repository: repository) { captured = $0 }

        #expect(captured != nil)
        #expect(captured?.tagline == "Updated tagline")
        // Name / slug / id stay the same because we routed through
        // updateProject, not createProject.
        #expect(captured?.id == project.id)
        #expect(captured?.slug == project.slug)
    }

    // MARK: - deleteProject mock surface

    @MainActor
    @Test func deleteProjectRemovesProjectAndCascadesChildren() async throws {
        let repository = MockTmuxAgentRepository()
        let project = try await repository.getProject(idOrSlug: "tmux-server-coding-app")
        let projectID = project.id
        let beforeFeatures = try await repository.listFeatures(projectIDOrSlug: project.slug)
        #expect(!beforeFeatures.isEmpty)

        try await repository.deleteProject(idOrSlug: project.slug)

        // Project no longer listed.
        let projects = try await repository.listProjects()
        #expect(projects.contains { $0.id == projectID } == false)

        // Listing features by the deleted slug now throws.
        await #expect(throws: Error.self) {
            _ = try await repository.listFeatures(projectIDOrSlug: project.slug)
        }
    }

    @MainActor
    @Test func deleteProjectThrowsWhenNotFound() async {
        let repository = MockTmuxAgentRepository()

        await #expect(throws: Error.self) {
            try await repository.deleteProject(idOrSlug: "ghost-project")
        }
    }

    // MARK: - Update body shape

    @MainActor
    @Test func makeUpdateRequestRoundTripsEveryField() async throws {
        let project = try await makeExistingProject()
        let vm = CreateProjectViewModel(existing: project)
        vm.pinned = !project.pinned

        let body = vm.makeUpdateRequest()

        #expect(body.name == project.name)
        #expect(body.slug == project.slug)
        #expect(body.localRepoPath == project.localRepoPath)
        #expect(body.pinned == !project.pinned)
        #expect(body.status == project.status)
    }
}
