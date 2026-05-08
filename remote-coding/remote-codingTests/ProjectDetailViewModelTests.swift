import Foundation
import Testing
@testable import remote_coding

struct ProjectDetailViewModelTests {

    // MARK: - Helpers

    @MainActor
    private func makeViewModel() async throws -> (ProjectDetailViewModel, MockTmuxAgentRepository) {
        let repository = MockTmuxAgentRepository()
        let project = try await repository.getProject(idOrSlug: "tmux-server-coding-app")
        let viewModel = ProjectDetailViewModel(project: project)
        return (viewModel, repository)
    }

    // MARK: - Loading

    @MainActor
    @Test func loadFetchesFeaturesAndTickets() async throws {
        let (viewModel, repository) = try await makeViewModel()

        await viewModel.load(repository: repository)

        #expect(viewModel.features.count >= 1)
        #expect(viewModel.errorMessage == nil)
        for feature in viewModel.features {
            #expect(viewModel.ticketsByFeatureID[feature.id] != nil)
        }
    }

    @MainActor
    @Test func loadPopulatesAgentSessions() async throws {
        let (viewModel, repository) = try await makeViewModel()

        await viewModel.load(repository: repository)

        // tmux-server-coding-app has seeded agent sessions
        #expect(!viewModel.agentSessions.isEmpty)
    }

    // MARK: - Stats

    @MainActor
    @Test func statsActiveCountsInProgressFeatures() async throws {
        let (viewModel, repository) = try await makeViewModel()
        await viewModel.load(repository: repository)

        let inProgress = viewModel.features.filter { $0.status == .inProgress }.count

        #expect(viewModel.stats.active == inProgress)
        #expect(viewModel.stats.total == viewModel.features.count)
    }

    @MainActor
    @Test func statsOpenSumsTicketsNotDone() async throws {
        let (viewModel, repository) = try await makeViewModel()
        await viewModel.load(repository: repository)

        let openTicketsByHand = viewModel.ticketsByFeatureID.values
            .reduce(0) { partial, tickets in partial + tickets.filter { $0.status != .done }.count }

        #expect(viewModel.stats.open == openTicketsByHand)
    }

    @MainActor
    @Test func statsLiveCountsActiveAndAwaitingSessions() async throws {
        let (viewModel, repository) = try await makeViewModel()
        await viewModel.load(repository: repository)

        let liveByHand = viewModel.agentSessions.filter {
            $0.state == .active || $0.state == .awaitingInput
        }.count

        #expect(viewModel.stats.live == liveByHand)
    }

    // MARK: - Section grouping

    @MainActor
    @Test func featuresForStatusFiltersCorrectly() async throws {
        let (viewModel, repository) = try await makeViewModel()
        await viewModel.load(repository: repository)

        let inProgress = viewModel.features(for: [.inProgress])
        for feature in inProgress {
            #expect(feature.status == .inProgress)
        }

        let shipped = viewModel.features(for: [.shipped, .merged])
        for feature in shipped {
            #expect(feature.status == .shipped || feature.status == .merged)
        }
    }

    // MARK: - Flat lists

    @MainActor
    @Test func allTicketsSpansEveryFeature() async throws {
        let (viewModel, repository) = try await makeViewModel()
        await viewModel.load(repository: repository)

        let total = viewModel.ticketsByFeatureID.values.reduce(0) { $0 + $1.count }

        #expect(viewModel.allTickets.count == total)
    }

    // MARK: - Status mapping

    @MainActor
    @Test func featureStatusStyleCoversAllCases() async {
        #expect(FeatureStatusStyle.glyphRole(for: .inProgress) == .doing)
        #expect(FeatureStatusStyle.glyphRole(for: .review) == .review)
        #expect(FeatureStatusStyle.glyphRole(for: .planned) == .planned)
        #expect(FeatureStatusStyle.glyphRole(for: .shipped) == .shipped)
        #expect(FeatureStatusStyle.glyphRole(for: .merged) == .shipped)
        #expect(FeatureStatusStyle.glyphRole(for: .abandoned) == .todo)
    }

    @MainActor
    @Test func ticketStatusStyleCoversAllCases() async {
        #expect(TicketStatusStyle.glyphRole(for: .todo) == .todo)
        #expect(TicketStatusStyle.glyphRole(for: .doing) == .doing)
        #expect(TicketStatusStyle.glyphRole(for: .review) == .review)
        #expect(TicketStatusStyle.glyphRole(for: .done) == .shipped)
    }

    // MARK: - Section enum

    @MainActor
    @Test func projectDetailSectionFromLabelRoundTrips() async {
        for section in ProjectDetailSection.allCases {
            #expect(ProjectDetailSection.from(label: section.rawValue) == section)
        }
        // Unknown labels fall back to `.features`.
        #expect(ProjectDetailSection.from(label: "garbage") == .features)
    }
}
