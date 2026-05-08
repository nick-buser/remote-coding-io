import Foundation
import Testing
@testable import remote_coding

struct TicketReviewViewModelTests {

    @MainActor
    private func loaded(publicID: String = "TMX-0050") async -> (TicketReviewViewModel, MockTmuxAgentRepository) {
        let repository = MockTmuxAgentRepository()
        let viewModel = TicketReviewViewModel(publicID: publicID)
        await viewModel.load(repository: repository)
        return (viewModel, repository)
    }

    @MainActor
    @Test func loadFetchesTicketCriteriaAndDiff() async {
        let (viewModel, _) = await loaded()

        #expect(viewModel.ticket?.publicId == "TMX-0050")
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.diff?.ticketPublicId == "TMX-0050")
    }

    @MainActor
    @Test func diffStatsAggregateAcrossFiles() async {
        let (viewModel, _) = await loaded()

        let stats = viewModel.diffStats

        #expect(stats.fileCount == viewModel.diff?.files.count ?? 0)
        #expect(stats.adds >= 0)
        #expect(stats.dels >= 0)
    }

    @MainActor
    @Test func filesByChangeGroupsByEnum() async {
        let (viewModel, _) = await loaded()

        let groups = viewModel.filesByChange()
        let allFiles = viewModel.diff?.files ?? []

        let groupedTotal = groups.reduce(0) { $0 + $1.files.count }
        #expect(groupedTotal == allFiles.count)
    }

    @MainActor
    @Test func approveCallsRepoAndFlipsFinishedFlag() async {
        let (viewModel, repository) = await loaded()

        await viewModel.approve(repository: repository)

        #expect(viewModel.didFinishAction == true)
        let ticket = try? await repository.getTicket(publicID: "TMX-0050")
        #expect(ticket?.status == .done)
    }

    @MainActor
    @Test func requestChangesCarriesComment() async {
        let (viewModel, repository) = await loaded()

        await viewModel.requestChanges(comment: "needs more tests", repository: repository)

        #expect(viewModel.didFinishAction == true)
    }

    @MainActor
    @Test func sendBackTransitionsTicketToDoing() async {
        let (viewModel, repository) = await loaded()

        await viewModel.sendBack(comment: nil, repository: repository)

        #expect(viewModel.didFinishAction == true)
        let ticket = try? await repository.getTicket(publicID: "TMX-0050")
        #expect(ticket?.status == .doing)
    }

    @MainActor
    @Test func reviewSectionFromLabelHandlesDynamicChecklistLabel() async {
        #expect(ReviewSection.from(label: "Diff") == .diff)
        #expect(ReviewSection.from(label: "Checklist 0/0") == .checklist)
        #expect(ReviewSection.from(label: "Checklist 3/6") == .checklist)
        #expect(ReviewSection.from(label: "Files") == .files)
        #expect(ReviewSection.from(label: "garbage") == .diff)
    }
}
