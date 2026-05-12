import Foundation
import Testing
@testable import remote_coding

@MainActor
struct SpawnSheetViewModelTests {

    private func makeViewModel(
        entry: SpawnEntry,
        repo: MockTmuxAgentRepository = MockTmuxAgentRepository()
    ) -> (SpawnSheetViewModel, MockTmuxAgentRepository) {
        let coordinator = RootCoordinator()
        let vm = SpawnSheetViewModel(entry: entry, repository: repo, coordinator: coordinator)
        return (vm, repo)
    }

    // MARK: - Scope change clears downstream selections

    @Test func scopeChangeClearsTicketSelection() async throws {
        let repo = MockTmuxAgentRepository()
        let feature = try await repo.getFeature(id: 12)
        let project = try await repo.getProject(idOrSlug: "1")
        let (vm, _) = makeViewModel(entry: .feature(feature, project), repo: repo)
        await vm.loadInitial()
        // Select a ticket
        vm.selectedTicket = vm.tickets.first
        #expect(vm.selectedTicket != nil)

        // Change scope to feature — ticket should be cleared
        await vm.onScopeChanged(.feature)

        #expect(vm.selectedTicket == nil)
        #expect(vm.scope == .feature)
    }

    @Test func featureSelectionClearsTicketSelection() async throws {
        let repo = MockTmuxAgentRepository()
        let project = try await repo.getProject(idOrSlug: "1")
        let (vm, _) = makeViewModel(entry: .project(project), repo: repo)
        await vm.loadInitial()
        // Simulate having a feature and ticket selected
        let feature = try await repo.getFeature(id: 12)
        await vm.onFeatureSelected(feature)
        vm.selectedTicket = vm.tickets.first

        let differentFeature = try await repo.getFeature(id: 11)
        await vm.onFeatureSelected(differentFeature)

        #expect(vm.selectedTicket == nil)
    }

    // MARK: - isSpawnEnabled

    @Test func spawnDisabledForSessionsTabWithNoProject() async throws {
        let (vm, _) = makeViewModel(entry: .sessionsTab)
        #expect(!vm.isSpawnEnabled)
    }

    @Test func spawnEnabledForProjectScopeWhenProjectSelected() async throws {
        let repo = MockTmuxAgentRepository()
        let project = try await repo.getProject(idOrSlug: "1")
        let (vm, _) = makeViewModel(entry: .project(project), repo: repo)
        await vm.onScopeChanged(.project)
        #expect(vm.isSpawnEnabled)
    }

    @Test func spawnDisabledForFeatureScopeWithNoFeature() async throws {
        let repo = MockTmuxAgentRepository()
        let project = try await repo.getProject(idOrSlug: "1")
        let (vm, _) = makeViewModel(entry: .project(project), repo: repo)
        // scope defaults to .feature, selectedFeature = nil
        #expect(!vm.isSpawnEnabled)
    }

    @Test func spawnEnabledForFeatureScopeWhenFeatureSelected() async throws {
        let repo = MockTmuxAgentRepository()
        let project = try await repo.getProject(idOrSlug: "1")
        let feature = try await repo.getFeature(id: 12)
        let (vm, _) = makeViewModel(entry: .project(project), repo: repo)
        await vm.onFeatureSelected(feature)
        #expect(vm.isSpawnEnabled)
    }

    @Test func spawnDisabledForTicketScopeWithNoTicket() async throws {
        let repo = MockTmuxAgentRepository()
        let project = try await repo.getProject(idOrSlug: "1")
        let feature = try await repo.getFeature(id: 12)
        let (vm, _) = makeViewModel(entry: .feature(feature, project), repo: repo)
        // No ticket selected yet
        #expect(!vm.isSpawnEnabled)
    }

    @Test func spawnEnabledForTicketScopeWhenTicketSelected() async throws {
        let repo = MockTmuxAgentRepository()
        let project = try await repo.getProject(idOrSlug: "1")
        let feature = try await repo.getFeature(id: 12)
        let (vm, _) = makeViewModel(entry: .feature(feature, project), repo: repo)
        await vm.loadInitial()
        vm.selectedTicket = vm.tickets.first
        #expect(vm.isSpawnEnabled)
    }

    // MARK: - Successful create triggers navigation

    @Test func spawnSuccessNavigatesToSession() async throws {
        let store = UserDefaults(suiteName: "SpawnTest-\(UUID())")!
        let repo = MockTmuxAgentRepository()
        let coordinator = RootCoordinator(store: store)
        let project = try await repo.getProject(idOrSlug: "1")
        let vm = SpawnSheetViewModel(entry: .project(project), repository: repo, coordinator: coordinator)
        await vm.onScopeChanged(.project)

        #expect(vm.isSpawnEnabled)
        // push() goes to the coordinator's selectedTab (inbox by default)
        let activeTab = coordinator.selectedTab
        let before = coordinator.paths[activeTab]?.count ?? 0

        await vm.spawn()

        let after = coordinator.paths[activeTab]?.count ?? 0
        #expect(vm.errorMessage == nil)
        #expect(after == before + 1)
    }

    // MARK: - Failure shows error and does not navigate

    @Test func spawnFailureShowsErrorWithoutNavigating() async throws {
        let store = UserDefaults(suiteName: "SpawnTest-\(UUID())")!
        let goodRepo = MockTmuxAgentRepository()
        let failRepo = SpawnFailingRepository()
        let coordinator = RootCoordinator(store: store)
        // Get a real project to inject into the failing-repo VM
        let project = try await goodRepo.getProject(idOrSlug: "1")
        let vm = SpawnSheetViewModel(entry: .sessionsTab, repository: failRepo, coordinator: coordinator)
        vm.scope = .project
        vm.selectedProject = project

        let activeTab = coordinator.selectedTab
        let before = coordinator.paths[activeTab]?.count ?? 0
        await vm.spawn()
        let after = coordinator.paths[activeTab]?.count ?? 0

        #expect(vm.errorMessage != nil)
        #expect(after == before)
    }
}

// MARK: - Test double

@MainActor
private final class SpawnFailingRepository: TmuxAgentRepository {
    struct Boom: Error {}

    func listProjects() async throws -> [Components.Schemas.Project] { return [] }
    func getProject(idOrSlug: String) async throws -> Components.Schemas.Project { throw Boom() }
    func createProject(_ body: Components.Schemas.CreateProjectRequest) async throws -> Components.Schemas.Project { throw Boom() }
    func updateProject(idOrSlug: String, body: Components.Schemas.UpdateProjectRequest) async throws -> Components.Schemas.Project { throw Boom() }
    func deleteProject(idOrSlug: String) async throws { throw Boom() }
    func listFeatures(projectIDOrSlug: String) async throws -> [Components.Schemas.Feature] { return [] }
    func getFeature(id: Int64) async throws -> Components.Schemas.Feature { throw Boom() }
    func createFeature(projectIDOrSlug: String, body: Components.Schemas.CreateFeatureRequest) async throws -> Components.Schemas.Feature { throw Boom() }
    func updateFeatureStatus(id: Int64, body: Components.Schemas.UpdateFeatureStatusRequest) async throws -> Components.Schemas.Feature { throw Boom() }
    func listTickets(featureID: Int64, status: Components.Schemas.TicketStatus?) async throws -> [Components.Schemas.Ticket] { return [] }
    func getTicket(publicID: String) async throws -> Components.Schemas.Ticket { throw Boom() }
    func createTicket(featureID: Int64, body: Components.Schemas.CreateTicketRequest) async throws -> Components.Schemas.Ticket { throw Boom() }
    func updateTicket(publicID: String, body: Components.Schemas.UpdateTicketRequest) async throws -> Components.Schemas.Ticket { throw Boom() }
    func listCriteria(ticketPublicID: String) async throws -> [Components.Schemas.AcceptanceCriterion] { return [] }
    func createCriterion(ticketPublicID: String, body: Components.Schemas.CreateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion { throw Boom() }
    func updateCriterion(id: Int64, body: Components.Schemas.UpdateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion { throw Boom() }
    func deleteCriterion(id: Int64) async throws { throw Boom() }
    func listFeatureDocs(featureID: Int64) async throws -> [Components.Schemas.Doc] { return [] }
    func getDoc(id: Int64) async throws -> Components.Schemas.Doc { throw Boom() }
    func createFeatureDoc(featureID: Int64, body: Components.Schemas.CreateDocRequest) async throws -> Components.Schemas.Doc { throw Boom() }
    func updateDoc(id: Int64, body: Components.Schemas.UpdateDocRequest) async throws -> Components.Schemas.Doc { throw Boom() }
    func deleteDoc(id: Int64) async throws { throw Boom() }
    func listFeatureDecisions(featureID: Int64) async throws -> [Components.Schemas.Decision] { return [] }
    func createFeatureDecision(featureID: Int64, body: Components.Schemas.CreateDecisionRequest) async throws -> Components.Schemas.Decision { throw Boom() }
    func deleteDecision(id: Int64) async throws { throw Boom() }
    func listActivity(project: String?, feature: Int64?, since: Date?, limit: Int?) async throws -> [Components.Schemas.ActivityEvent] { return [] }
    func getAgentSession(id: Int64) async throws -> Components.Schemas.AgentSession { throw Boom() }
    func listProjectAgentSessions(projectIDOrSlug: String) async throws -> [Components.Schemas.AgentSession] { return [] }
    func listTicketAgentSessions(ticketPublicID: String) async throws -> [Components.Schemas.AgentSession] { return [] }
    func createAgentSession(_ body: Components.Schemas.CreateAgentSessionRequest) async throws -> Components.Schemas.AgentSession { throw Boom() }
    func getTicketDiff(publicID: String) async throws -> Components.Schemas.TicketDiff { throw Boom() }
    func approveTicket(publicID: String) async throws -> Components.Schemas.Ticket { throw Boom() }
    func requestTicketChanges(publicID: String, comment: String?) async throws -> Components.Schemas.Ticket { throw Boom() }
    func sendTicketBack(publicID: String, comment: String?) async throws -> Components.Schemas.Ticket { throw Boom() }
    func listProjectDocuments(projectID: Int64) async throws -> [LocalProjectNote] { return [] }
    func saveDocument(_ document: LocalProjectNote) async throws -> LocalProjectNote { throw Boom() }
    func openProjectSession(idOrSlug: String) async throws -> Components.Schemas.Project { throw Boom() }
    func listSessions(projectID: Int64) async throws -> [Components.Schemas.Session] { throw Boom() }
    func listSessions(featureID: Int64) async throws -> [Components.Schemas.Session] { throw Boom() }
    func listSessions() async throws -> [Components.Schemas.Session] { throw Boom() }
    func listPanes(sessionName: String) async throws -> [Components.Schemas.Pane] { throw Boom() }
    func getPaneOutput(sessionName: String, paneID: Int) async throws -> Components.Schemas.PaneOutput { throw Boom() }
    func sendPaneInput(sessionName: String, paneID: Int, body: Components.Schemas.SendInputRequest) async throws -> Components.Schemas.StatusResponse { throw Boom() }
    func registerDevice(_ body: Components.Schemas.DeviceRegistrationRequest) async throws -> Components.Schemas.DeviceRegistration { throw Boom() }
    func deregisterDevice(token: String) async throws { throw Boom() }
}
