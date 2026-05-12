import Foundation
import Testing
@testable import remote_coding

struct CreateProjectViewModelTests {

    // MARK: - Validation gates

    @MainActor
    @Test func canSubmitRequiresNonEmptyNameAndPath() async {
        let vm = CreateProjectViewModel()
        #expect(vm.canSubmit == false)

        vm.name = "  "
        vm.localRepoPath = "/tmp"
        #expect(vm.canSubmit == false)  // whitespace-only name

        vm.name = "Project"
        vm.localRepoPath = ""
        #expect(vm.canSubmit == false)  // empty path

        vm.name = "Project"
        vm.localRepoPath = "/tmp/project"
        #expect(vm.canSubmit)
    }

    @MainActor
    @Test func canSubmitFalseWhileSubmitting() async {
        let vm = CreateProjectViewModel()
        vm.name = "Project"
        vm.localRepoPath = "/tmp"
        vm.isSubmitting = true
        #expect(vm.canSubmit == false)
    }

    // MARK: - Slug derivation

    @MainActor
    @Test func slugAutoDerivesFromNameUntilManuallyEdited() async {
        let vm = CreateProjectViewModel()

        vm.name = "Remote Coding iOS"
        vm.nameChanged(vm.name)
        #expect(vm.slug == "remote-coding-ios")

        vm.name = "Remote Coding iOS App"
        vm.nameChanged(vm.name)
        #expect(vm.slug == "remote-coding-ios-app")

        // Once the user edits the slug directly, name changes stop
        // overwriting it.
        vm.slugEdited("custom-slug")
        vm.name = "Renamed Project"
        vm.nameChanged(vm.name)
        #expect(vm.slug == "custom-slug")
    }

    @MainActor
    @Test func deriveSlugStripsLeadingTrailingDashesAndCollapsesRuns() async {
        #expect(CreateProjectViewModel.deriveSlug(from: "  __Hello   World!! ") == "hello-world")
        #expect(CreateProjectViewModel.deriveSlug(from: "ALL CAPS") == "all-caps")
        #expect(CreateProjectViewModel.deriveSlug(from: "👋 emoji 👋") == "emoji")
        #expect(CreateProjectViewModel.deriveSlug(from: "")  == "")
    }

    // MARK: - Field error mapping

    @MainActor
    @Test func fieldErrorMapperHandlesContractAndCamelPaths() async {
        #expect(CreateProjectViewModel.fieldErrorMapper(rawField: "name") == .name)
        #expect(CreateProjectViewModel.fieldErrorMapper(rawField: "slug") == .slug)
        #expect(CreateProjectViewModel.fieldErrorMapper(rawField: "local_repo_path") == .localRepoPath)
        #expect(CreateProjectViewModel.fieldErrorMapper(rawField: "localRepoPath") == .localRepoPath)
        #expect(CreateProjectViewModel.fieldErrorMapper(rawField: "git_repo_url") == .gitRepoUrl)
        // Unknown segments fall through to nil so the caller can
        // route the message to the banner.
        #expect(CreateProjectViewModel.fieldErrorMapper(rawField: "unknown_field") == nil)
    }

    @MainActor
    @Test func fieldErrorMapperUsesLeadingSegment() async {
        // Nested validators emit field paths like "slug.format" — we
        // route on the leading segment so the form's slug field still
        // catches it.
        #expect(CreateProjectViewModel.fieldErrorMapper(rawField: "slug.format") == .slug)
    }

    // MARK: - Mock-backed submit roundtrip

    @MainActor
    @Test func submitCallsRepositoryAndYieldsProject() async {
        let vm = CreateProjectViewModel()
        vm.name = "New Project"
        vm.localRepoPath = "/tmp/new-project"
        vm.gitRepoUrl = "git@github.com:nick/new.git"
        vm.tagline = "Fresh project"
        vm.icon = "✺"

        let repository = MockTmuxAgentRepository()
        var captured: Components.Schemas.Project?

        await vm.submit(repository: repository) { project in
            captured = project
        }

        #expect(captured != nil)
        #expect(captured?.name == "New Project")
        #expect(captured?.slug == "new-project")
        #expect(captured?.icon == "✺")
        #expect(vm.bannerError == nil)
        #expect(vm.fieldErrors.isEmpty)
    }

    @MainActor
    @Test func submitMapsConflictErrorToSlugField() async {
        // The mock seed already has a project with slug
        // "tmux-server-coding-app"; submitting again should hit the
        // mock's conflict path and route the error to .slug.
        let vm = CreateProjectViewModel()
        vm.name = "tmux-server-coding-app"
        vm.localRepoPath = "/tmp/dup"
        vm.slugEdited("tmux-server-coding-app")

        let repository = MockTmuxAgentRepository()
        var captured: Components.Schemas.Project?

        await vm.submit(repository: repository) { captured = $0 }

        #expect(captured == nil)
        #expect(vm.fieldErrors[.slug] != nil)
    }
}
