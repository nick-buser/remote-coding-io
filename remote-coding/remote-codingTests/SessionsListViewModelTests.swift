import Foundation
import Testing
@testable import remote_coding

struct SessionsListViewModelTests {

    @MainActor
    private func makeLoaded() async throws -> (SessionsListViewModel, MockTmuxAgentRepository) {
        let repository = MockTmuxAgentRepository()
        let viewModel = SessionsListViewModel()
        await viewModel.load(
            fetcher: CrossProjectFeatureFetcher(repository: repository),
            repository: repository
        )
        return (viewModel, repository)
    }

    // MARK: - Loading

    @MainActor
    @Test func loadFetchesProjectsFeaturesAndSessions() async throws {
        let (viewModel, _) = try await makeLoaded()

        #expect(viewModel.bundle?.projects.isEmpty == false)
        #expect(!viewModel.allSessions.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Grouping

    @MainActor
    @Test func groupingPartitionsByState() async throws {
        let (viewModel, _) = try await makeLoaded()
        let total = viewModel.allSessions.count

        let active   = viewModel.activeSessions.count
        let awaiting = viewModel.awaitingSessions.count
        let idle     = viewModel.idleSessions.count

        #expect(active + awaiting + idle == total)
    }

    @MainActor
    @Test func heroAndSectionAvoidDoubleRendering() async throws {
        let (viewModel, _) = try await makeLoaded()

        // Either hero shows the awaiting list or the section does — never
        // both, never neither (when awaiting is non-empty).
        let awaitingTotal = viewModel.awaitingSessions.count
        if awaitingTotal == 0 {
            #expect(viewModel.heroAwaiting.isEmpty)
            #expect(viewModel.awaitingSection.isEmpty)
        } else if awaitingTotal <= 3 {
            #expect(viewModel.heroAwaiting.count == awaitingTotal)
            #expect(viewModel.awaitingSection.isEmpty)
        } else {
            #expect(viewModel.heroAwaiting.isEmpty)
            #expect(viewModel.awaitingSection.count == awaitingTotal)
        }
    }

    // MARK: - Filter

    @MainActor
    @Test func filterCountsMatchActualSessions() async throws {
        let (viewModel, _) = try await makeLoaded()

        let counts = viewModel.filterCounts()

        #expect(counts[.active]   == viewModel.activeSessions.count)
        #expect(counts[.awaiting] == viewModel.awaitingSessions.count)
        #expect(counts[.idle]     == viewModel.idleSessions.count)
        #expect(counts[.all]      == viewModel.allSessions.count)
    }

    @MainActor
    @Test func filterMatchesIgnoresEnded() async {
        // Spot check the predicate.
        #expect(SessionsListViewModel.SessionFilter.all.matches(.active))
        #expect(SessionsListViewModel.SessionFilter.all.matches(.awaitingInput))
        #expect(SessionsListViewModel.SessionFilter.all.matches(.idle))
        #expect(SessionsListViewModel.SessionFilter.all.matches(.ended) == false)

        #expect(SessionsListViewModel.SessionFilter.active.matches(.active))
        #expect(SessionsListViewModel.SessionFilter.awaiting.matches(.awaitingInput))
        #expect(SessionsListViewModel.SessionFilter.idle.matches(.idle))
    }

    // MARK: - Metadata lookup

    @MainActor
    @Test func metadataResolvesProjectAndTicketForSession() async throws {
        let (viewModel, _) = try await makeLoaded()
        // Pick the first session that has a ticketId — the seed
        // wires ticketID 200 (TMX-0042) → session-04.
        guard let session = viewModel.allSessions.first(where: { $0.ticketId != nil }) else {
            return
        }

        let metadata = viewModel.metadata(for: session)

        #expect(metadata.project != nil)
        #expect(metadata.ticket != nil)
        #expect(metadata.featurePublicLabel?.hasPrefix("FEAT-") == true)
    }

    // MARK: - Subtitle

    @MainActor
    @Test func subtitleShowsLiveCountAndProjectCount() async throws {
        let (viewModel, _) = try await makeLoaded()

        let subtitle = viewModel.subtitle()
        let projectCount = viewModel.bundle?.projects.count ?? 0

        #expect(subtitle.contains("\(projectCount) project"))
        #expect(subtitle.contains("live"))
    }
}
