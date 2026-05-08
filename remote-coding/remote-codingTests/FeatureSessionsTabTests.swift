import Foundation
import Testing
@testable import remote_coding

struct FeatureSessionsTabTests {

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

    // MARK: - Feature scoping

    @MainActor
    @Test func sessionsLoadedAreScopedToFeatureTickets() async throws {
        let (viewModel, _) = try await loadedViewModel(featureID: 11)
        let ticketIDs = Set(viewModel.tickets.map(\.id))

        for session in viewModel.agentSessions {
            #expect(session.ticketId.map { ticketIDs.contains($0) } ?? false)
        }
    }

    // MARK: - State group spec

    @MainActor
    @Test func stateGroupsCoverEverySessionState() async {
        let allStates: [Components.Schemas.SessionState] = [.active, .awaitingInput, .idle, .ended]
        let coveredStates = FeatureSessionsTab.stateGroups.flatMap(\.states)

        for state in allStates {
            #expect(coveredStates.contains(state), "state \(state) is not assigned to a group")
        }
    }

    // MARK: - Spawn flow

    @MainActor
    @Test func spawnReturnsNewSessionAndPrependsToList() async throws {
        let (viewModel, repository) = try await loadedViewModel(featureID: 11)
        guard let ticket = viewModel.tickets.first else {
            return
        }
        let initialCount = viewModel.agentSessions.count

        let body = Components.Schemas.CreateAgentSessionRequest(
            ticketPublicId: ticket.publicId,
            tmuxSession: nil,
            state: nil,
            pane: nil,
            cpu: nil
        )
        let created = try await repository.createAgentSession(body)
        viewModel.agentSessions.insert(created, at: 0)

        #expect(viewModel.agentSessions.count == initialCount + 1)
        #expect(viewModel.agentSessions.first?.id == created.id)
        #expect(viewModel.agentSessions.first?.ticketId == ticket.id)
    }

    @MainActor
    @Test func spawnHonoursTmuxOverride() async throws {
        let (viewModel, repository) = try await loadedViewModel()
        guard let ticket = viewModel.tickets.first else {
            return
        }

        let body = Components.Schemas.CreateAgentSessionRequest(
            ticketPublicId: ticket.publicId,
            tmuxSession: "custom_override",
            state: nil,
            pane: nil,
            cpu: nil
        )
        let created = try await repository.createAgentSession(body)

        #expect(created.tmuxSession == "custom_override")
    }

    @MainActor
    @Test func spawnHonoursStartingState() async throws {
        let (viewModel, repository) = try await loadedViewModel()
        guard let ticket = viewModel.tickets.first else {
            return
        }

        let body = Components.Schemas.CreateAgentSessionRequest(
            ticketPublicId: ticket.publicId,
            tmuxSession: nil,
            state: .active,
            pane: nil,
            cpu: nil
        )
        let created = try await repository.createAgentSession(body)

        #expect(created.state == .active)
    }
}
