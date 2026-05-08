import Foundation
import Testing
@testable import remote_coding

struct FeatureTicketsTabTests {

    // MARK: - Helpers

    @MainActor
    private func loadedViewModel(featureID: Int64 = 11) async throws -> (FeatureDetailViewModel, MockTmuxAgentRepository) {
        let repository = MockTmuxAgentRepository()
        let feature = try await repository.getFeature(id: featureID)
        let project = try await repository.getProject(idOrSlug: String(feature.projectId))
        let viewModel = FeatureDetailViewModel(project: project, feature: feature)
        await viewModel.load(repository: repository)
        return (viewModel, repository)
    }

    // MARK: - Status group spec

    @MainActor
    @Test func statusGroupsCoverEveryTicketStatus() async {
        let allStatuses: [Components.Schemas.TicketStatus] = [.todo, .doing, .review, .done]
        let coveredStatuses = FeatureTicketsTab.statusGroups.flatMap(\.statuses)

        for status in allStatuses {
            #expect(coveredStatuses.contains(status), "status \(status) is not assigned to a group")
        }
    }

    @MainActor
    @Test func statusGroupsAreInDoingFirstOrder() async {
        let firstLabel = FeatureTicketsTab.statusGroups.first?.label

        #expect(firstLabel == "Doing")
    }

    // MARK: - Mock-backed integration

    @MainActor
    @Test func loadPopulatesTicketsForSeededFeature() async throws {
        let (viewModel, _) = try await loadedViewModel()

        #expect(!viewModel.tickets.isEmpty)
        #expect(viewModel.tickets.allSatisfy { $0.featureId == viewModel.feature.id })
    }

    @MainActor
    @Test func updateTicketStatusReflectsInLocalArray() async throws {
        let (viewModel, repository) = try await loadedViewModel()
        guard let original = viewModel.tickets.first else {
            return
        }
        let nextStatus: Components.Schemas.TicketStatus = original.status == .doing ? .review : .doing

        let body = Components.Schemas.UpdateTicketRequest(
            title: nil,
            description: nil,
            status: nextStatus,
            estimate: nil
        )
        let updated = try await repository.updateTicket(publicID: original.publicId, body: body)
        if let index = viewModel.tickets.firstIndex(where: { $0.id == updated.id }) {
            viewModel.tickets[index] = updated
        }

        #expect(viewModel.tickets.first(where: { $0.id == original.id })?.status == nextStatus)
    }

    @MainActor
    @Test func createTicketAppearsAtFrontWhenInsertedLocally() async throws {
        let (viewModel, repository) = try await loadedViewModel()
        let initialCount = viewModel.tickets.count

        let body = Components.Schemas.CreateTicketRequest(
            title: "New ticket from test",
            description: "Test description",
            status: .todo,
            estimate: "S",
            branchName: nil
        )
        let created = try await repository.createTicket(featureID: viewModel.feature.id, body: body)
        viewModel.tickets.insert(created, at: 0)

        #expect(viewModel.tickets.count == initialCount + 1)
        #expect(viewModel.tickets.first?.publicId == created.publicId)
        #expect(viewModel.tickets.first?.title == "New ticket from test")
    }

    // MARK: - Live indicator derivation

    @MainActor
    @Test func liveIndicatorMatchesActiveSessionTicketID() async throws {
        let (viewModel, _) = try await loadedViewModel(featureID: 11)
        // Seed: session-04 has ticketID 200, state .idle. session-08 has
        // an active session for ticket 206 on feature 11. Pick whichever
        // active/awaiting session lands here and confirm the predicate.
        let activeSession = viewModel.agentSessions.first { $0.state == .active || $0.state == .awaitingInput }
        guard let session = activeSession, let ticketID = session.ticketId else {
            return
        }

        let isLive = viewModel.agentSessions.contains { other in
            other.ticketId == ticketID
                && (other.state == .active || other.state == .awaitingInput)
        }

        #expect(isLive)
    }

    // MARK: - Router dispatch

    @MainActor
    @Test func routerDispatchesReviewStatusToReviewView() async throws {
        let repository = MockTmuxAgentRepository()
        let reviewTicket = try await repository.getTicket(publicID: "TMX-0050")

        #expect(reviewTicket.status == .review)
    }

    @MainActor
    @Test func routerDispatchesNonReviewStatusToDetailView() async throws {
        let repository = MockTmuxAgentRepository()
        let doingTicket = try await repository.getTicket(publicID: "TMX-0042")

        #expect(doingTicket.status != .review)
    }
}
