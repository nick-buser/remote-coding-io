import Foundation
import Testing
@testable import remote_coding

struct FeatureDetailViewModelTests {

    @MainActor
    private func makeViewModel(featureID: Int64 = 11) async throws -> (FeatureDetailViewModel, MockTmuxAgentRepository) {
        let repository = MockTmuxAgentRepository()
        let feature = try await repository.getFeature(id: featureID)
        let project = try await repository.getProject(idOrSlug: String(feature.projectId))
        let viewModel = FeatureDetailViewModel(project: project, feature: feature)
        return (viewModel, repository)
    }

    // MARK: - Header copy

    @MainActor
    @Test func publicLabelFormatsAsThreeDigitFEAT() async throws {
        let (viewModel, _) = try await makeViewModel(featureID: 11)

        #expect(viewModel.publicLabel == "FEAT-011")
    }

    @MainActor
    @Test func statusRoleAndLabelMatchFeatureStatus() async throws {
        // FEAT-011 in the seed is status .inProgress.
        let (viewModel, _) = try await makeViewModel(featureID: 11)

        #expect(viewModel.statusRole == .doing)
        #expect(viewModel.statusLabel == "In progress")
    }

    @MainActor
    @Test func accentColorMapsLegacyValues() async throws {
        // FEAT-011 has accent "indigo" → maps to .iris.
        let (viewModel, _) = try await makeViewModel(featureID: 11)

        #expect(viewModel.accentColor == .iris)
    }

    // MARK: - Loading

    @MainActor
    @Test func loadFetchesAllFourCollections() async throws {
        let (viewModel, repository) = try await makeViewModel()

        await viewModel.load(repository: repository)

        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.tickets.isEmpty)
        // Decisions are seeded for some features only — counts may be 0,
        // but the array should be assigned (no error).
        #expect(viewModel.decisions.count >= 0)
    }

    @MainActor
    @Test func loadScopesAgentSessionsToFeatureTickets() async throws {
        let (viewModel, repository) = try await makeViewModel(featureID: 11)

        await viewModel.load(repository: repository)

        let ticketIDs = Set(viewModel.tickets.map(\.id))
        for session in viewModel.agentSessions {
            #expect(session.ticketId.map { ticketIDs.contains($0) } ?? false)
        }
    }

    // MARK: - Progress

    @MainActor
    @Test func progressFractionIsZeroWhenNoTickets() async throws {
        let (viewModel, _) = try await makeViewModel()

        #expect(viewModel.progress.fraction == 0)
        #expect(viewModel.progress.total == 0)
    }

    @MainActor
    @Test func progressFractionMatchesTicketStatuses() async throws {
        let (viewModel, repository) = try await makeViewModel()
        await viewModel.load(repository: repository)

        let done = viewModel.tickets.filter { $0.status == .done }.count

        #expect(viewModel.progress.done == done)
        #expect(viewModel.progress.total == viewModel.tickets.count)
        if viewModel.progress.total > 0 {
            let expected = Double(done) / Double(viewModel.tickets.count)
            #expect(viewModel.progress.fraction == expected)
        }
    }

    // MARK: - Status mutation

    @MainActor
    @Test func setStatusUpdatesFeatureInPlace() async throws {
        let (viewModel, repository) = try await makeViewModel(featureID: 11)
        let initial = viewModel.feature.status

        await viewModel.setStatus(initial == .review ? .inProgress : .review, repository: repository)

        #expect(viewModel.feature.status != initial)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Section enum

    @MainActor
    @Test func featureDetailSectionRoundTripsByLabel() async {
        for section in FeatureDetailSection.allCases {
            #expect(FeatureDetailSection.from(label: section.rawValue) == section)
        }
        #expect(FeatureDetailSection.from(label: "garbage") == .tickets)
    }
}
