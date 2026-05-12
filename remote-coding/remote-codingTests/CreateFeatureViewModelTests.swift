import Foundation
import Testing
@testable import remote_coding

struct CreateFeatureViewModelTests {

    // MARK: - Required field gating

    @MainActor
    @Test func canSubmitRequiresNonEmptyTitle() async {
        let vm = CreateFeatureViewModel(parentSlug: "tmux-server-coding-app")
        #expect(vm.canSubmit == false)

        vm.title = "  "
        #expect(vm.canSubmit == false)

        vm.title = "Inbox composer"
        #expect(vm.canSubmit)
    }

    // MARK: - Slug + branch derivation

    @MainActor
    @Test func titleAutoDerivesSlugAndBranchUntilManuallyEdited() async {
        let vm = CreateFeatureViewModel(parentSlug: "p")
        vm.title = "Inbox composer"
        vm.titleChanged(vm.title)

        #expect(vm.slug == "inbox-composer")
        #expect(vm.branchName == "feat/inbox-composer")

        vm.title = "Renamed feature"
        vm.titleChanged(vm.title)
        #expect(vm.slug == "renamed-feature")
        #expect(vm.branchName == "feat/renamed-feature")

        // Manual slug edit halts auto-derivation for slug only.
        vm.slug = "custom-slug"
        vm.slugChangedExternally(vm.slug)
        vm.title = "Different title"
        vm.titleChanged(vm.title)
        #expect(vm.slug == "custom-slug")
        // Branch keeps tracking the title until the user edits it.
        #expect(vm.branchName == "feat/different-title")
    }

    @MainActor
    @Test func deriveSlugStripsAndCollapses() async {
        #expect(CreateFeatureViewModel.deriveSlug(from: "Inbox  Composer!!") == "inbox-composer")
        #expect(CreateFeatureViewModel.deriveSlug(from: "") == "")
        #expect(CreateFeatureViewModel.deriveBranchName(from: "Inbox") == "feat/inbox")
        #expect(CreateFeatureViewModel.deriveBranchName(from: "") == "")
    }

    // MARK: - Tags parsing

    @MainActor
    @Test func parsedTagsTrimsAndDropsEmpty() async {
        let vm = CreateFeatureViewModel(parentSlug: "p")
        vm.tagsInput = "  swift, , ios , runtime  "

        let tags = vm.parsedTags()

        #expect(tags == ["swift", "ios", "runtime"])
    }

    // MARK: - Field error mapping

    @MainActor
    @Test func fieldErrorMapperHandlesContractAndCamelPaths() async {
        #expect(CreateFeatureViewModel.fieldErrorMapper(rawField: "title") == .title)
        #expect(CreateFeatureViewModel.fieldErrorMapper(rawField: "branch_name") == .branchName)
        #expect(CreateFeatureViewModel.fieldErrorMapper(rawField: "branchName") == .branchName)
        #expect(CreateFeatureViewModel.fieldErrorMapper(rawField: "target_date") == .targetDate)
        #expect(CreateFeatureViewModel.fieldErrorMapper(rawField: "tags") == .tags)
        #expect(CreateFeatureViewModel.fieldErrorMapper(rawField: "unknown") == nil)
    }

    // MARK: - Edit mode

    @MainActor
    @Test func initWithExistingPrefillsAndLocksAutoDerivation() async throws {
        let repository = MockTmuxAgentRepository()
        let feature = try await repository.getFeature(id: 11)
        let vm = CreateFeatureViewModel(parentSlug: "tmux-server-coding-app", existing: feature)

        #expect(vm.mode == .edit)
        #expect(vm.title == feature.title)
        #expect(vm.slug == feature.slug)
        #expect(vm.status == feature.status)
        #expect(vm.slugWasManuallyEdited)
        #expect(vm.branchWasManuallyEdited)
        #expect(vm.nonStatusFieldsAreEditable == false)
    }

    @MainActor
    @Test func submitInEditModeRoutesThroughUpdateFeatureStatus() async throws {
        let repository = MockTmuxAgentRepository()
        let feature = try await repository.getFeature(id: 11)
        let vm = CreateFeatureViewModel(parentSlug: "tmux-server-coding-app", existing: feature)
        vm.status = .review

        var captured: Components.Schemas.Feature?
        await vm.submit(repository: repository) { captured = $0 }

        #expect(captured?.id == feature.id)
        #expect(captured?.status == .review)
        #expect(vm.bannerError == nil)
    }

    // MARK: - Mock-backed create

    @MainActor
    @Test func createSubmitYieldsFeatureScopedToProject() async throws {
        let repository = MockTmuxAgentRepository()
        let project = try await repository.getProject(idOrSlug: "tmux-server-coding-app")
        let initialFeatureCount = try await repository.listFeatures(projectIDOrSlug: project.slug).count

        let vm = CreateFeatureViewModel(parentSlug: project.slug)
        vm.title = "Brand new feature"
        vm.tagsInput = "swift, ios"

        var captured: Components.Schemas.Feature?
        await vm.submit(repository: repository) { captured = $0 }

        #expect(captured != nil)
        #expect(captured?.title == "Brand new feature")
        #expect(captured?.projectId == project.id)
        #expect(captured?.tags == ["swift", "ios"])

        let after = try await repository.listFeatures(projectIDOrSlug: project.slug)
        #expect(after.count == initialFeatureCount + 1)
    }

    @MainActor
    @Test func createSubmitMapsSlugConflictToSlugField() async throws {
        let repository = MockTmuxAgentRepository()
        // Seed has feature id 11 with slug "session-stream-and-pane-input"
        // on tmux-server-coding-app.
        let vm = CreateFeatureViewModel(parentSlug: "tmux-server-coding-app")
        vm.title = "Duplicate"
        vm.slug = "session-stream-and-pane-input"
        vm.slugChangedExternally(vm.slug)

        var captured: Components.Schemas.Feature?
        await vm.submit(repository: repository) { captured = $0 }

        #expect(captured == nil)
        #expect(vm.fieldErrors[.slug] != nil)
    }
}
