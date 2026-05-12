import Foundation
import Testing
@testable import remote_coding

@MainActor
struct TicketDetailViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(
        repo: MockTmuxAgentRepository = MockTmuxAgentRepository(),
        publicID: String = "TMX-0042"
    ) async throws -> (TicketDetailViewModel, MockTmuxAgentRepository) {
        let ticket = try await repo.getTicket(publicID: publicID)
        let vm = TicketDetailViewModel(ticket: ticket, repository: repo)
        return (vm, repo)
    }

    // MARK: - Loading

    @Test func loadFillsCriteriaAndSessions() async throws {
        let (vm, _) = try await makeViewModel()
        #expect(vm.criteria.isEmpty)
        await vm.load()
        #expect(!vm.criteria.isEmpty)
        #expect(vm.errorMessage == nil)
    }

    @Test func loadFillsSessionsForTicketWithActiveSessions() async throws {
        // TMX-0042 has session-04 bound to ticket id 200
        let (vm, _) = try await makeViewModel()
        await vm.load()
        #expect(!vm.sessions.isEmpty)
    }

    // MARK: - Status (optimistic update + rollback)

    @Test func updateStatusOptimisticallyMutatesTicket() async throws {
        let (vm, repo) = try await makeViewModel()
        #expect(vm.ticket.status == .doing)

        await vm.updateStatus(.done)

        #expect(vm.ticket.status == .done)
        #expect(repo.tickets.first(where: { $0.publicId == "TMX-0042" })?.status == .done)
    }

    @Test func updateStatusRollsBackOnFailure() async throws {
        let failRepo = FailingRepository()
        let ticket = Components.Schemas.Ticket(
            id: 1, publicId: "TMX-0001", featureId: 11,
            title: "Test", description: "",
            status: .todo, estimate: "",
            branchName: "feat/test", criteria: nil,
            criteriaTotal: 0, criteriaDone: 0,
            createdAt: Date(), updatedAt: Date()
        )
        let vm = TicketDetailViewModel(ticket: ticket, repository: failRepo)

        await vm.updateStatus(.done)

        #expect(vm.ticket.status == .todo)
        #expect(vm.errorMessage != nil)
    }

    // MARK: - Criteria toggle (optimistic update + rollback)

    @Test func toggleCriterionOptimisticallyFlipsDone() async throws {
        let (vm, _) = try await makeViewModel()
        await vm.load()
        guard let first = vm.criteria.first else { return }
        let originalDone = first.done

        await vm.toggleCriterion(id: first.id)

        #expect(vm.criteria.first?.done == !originalDone)
    }

    @Test func toggleCriterionRollsBackOnFailure() async throws {
        let failRepo = FailingRepository()
        let criterion = Components.Schemas.AcceptanceCriterion(
            id: 1, ticketId: 1, text: "Some criterion",
            done: false, sortOrder: 0,
            createdAt: Date(), updatedAt: Date()
        )
let ticket = Components.Schemas.Ticket(
            id: 1, publicId: "TMX-0001", featureId: 11,
            title: "Test", description: "",
            status: .todo, estimate: "",
            branchName: "", criteria: nil,
            criteriaTotal: 1, criteriaDone: 0,
            createdAt: Date(), updatedAt: Date()
        )
        let vm = TicketDetailViewModel(ticket: ticket, repository: failRepo)
        vm.criteria = [criterion]

        await vm.toggleCriterion(id: criterion.id)

        #expect(vm.criteria.first?.done == false)
        #expect(vm.errorMessage != nil)
    }

    // MARK: - Add / delete criterion

    @Test func addCriterionAppendsToList() async throws {
        let (vm, _) = try await makeViewModel()
        await vm.load()
        let before = vm.criteria.count

        await vm.addCriterion(text: "New criterion")

        #expect(vm.criteria.count == before + 1)
        #expect(vm.criteria.last?.text == "New criterion")
    }

    @Test func addEmptyCriterionIsNoOp() async throws {
        let (vm, _) = try await makeViewModel()
        await vm.load()
        let before = vm.criteria.count

        await vm.addCriterion(text: "   ")

        #expect(vm.criteria.count == before)
    }

    @Test func deleteCriterionRemovesFromList() async throws {
        let (vm, _) = try await makeViewModel()
        await vm.load()
        guard let first = vm.criteria.first else { return }
        let before = vm.criteria.count

        await vm.deleteCriterion(id: first.id)

        #expect(vm.criteria.count == before - 1)
        #expect(!vm.criteria.contains(where: { $0.id == first.id }))
    }

    // MARK: - Title / description commit

    @Test func commitTitleUpdatesTicketTitle() async throws {
        let (vm, _) = try await makeViewModel()
        vm.editingTitle = "Updated title"

        await vm.commitTitle()

        #expect(vm.ticket.title == "Updated title")
    }

    @Test func commitTitleNoOpWhenUnchanged() async throws {
        let (vm, _) = try await makeViewModel()
        let original = vm.ticket.title
        vm.editingTitle = original

        await vm.commitTitle()

        #expect(vm.ticket.title == original)
        #expect(vm.errorMessage == nil)
    }
}

// MARK: - Test double

/// Repository that throws on every mutable operation, for rollback tests.
@MainActor
private final class FailingRepository: TmuxAgentRepository {
    struct Boom: Error {}

    func listProjects() async throws -> [Components.Schemas.Project] { throw Boom() }
    func getProject(idOrSlug: String) async throws -> Components.Schemas.Project { throw Boom() }
    func createProject(_ body: Components.Schemas.CreateProjectRequest) async throws -> Components.Schemas.Project { throw Boom() }
    func updateProject(idOrSlug: String, body: Components.Schemas.UpdateProjectRequest) async throws -> Components.Schemas.Project { throw Boom() }
    func deleteProject(idOrSlug: String) async throws { throw Boom() }
    func listFeatures(projectIDOrSlug: String) async throws -> [Components.Schemas.Feature] { throw Boom() }
    func getFeature(id: Int64) async throws -> Components.Schemas.Feature { throw Boom() }
    func createFeature(projectIDOrSlug: String, body: Components.Schemas.CreateFeatureRequest) async throws -> Components.Schemas.Feature { throw Boom() }
    func updateFeatureStatus(id: Int64, body: Components.Schemas.UpdateFeatureStatusRequest) async throws -> Components.Schemas.Feature { throw Boom() }
    func listTickets(featureID: Int64, status: Components.Schemas.TicketStatus?) async throws -> [Components.Schemas.Ticket] { throw Boom() }
    func getTicket(publicID: String) async throws -> Components.Schemas.Ticket { throw Boom() }
    func createTicket(featureID: Int64, body: Components.Schemas.CreateTicketRequest) async throws -> Components.Schemas.Ticket { throw Boom() }
    func updateTicket(publicID: String, body: Components.Schemas.UpdateTicketRequest) async throws -> Components.Schemas.Ticket { throw Boom() }
    func listCriteria(ticketPublicID: String) async throws -> [Components.Schemas.AcceptanceCriterion] { return [] }
    func createCriterion(ticketPublicID: String, body: Components.Schemas.CreateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion { throw Boom() }
    func updateCriterion(id: Int64, body: Components.Schemas.UpdateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion { throw Boom() }
    func deleteCriterion(id: Int64) async throws { throw Boom() }
    func listFeatureDocs(featureID: Int64) async throws -> [Components.Schemas.Doc] { throw Boom() }
    func getDoc(id: Int64) async throws -> Components.Schemas.Doc { throw Boom() }
    func createFeatureDoc(featureID: Int64, body: Components.Schemas.CreateDocRequest) async throws -> Components.Schemas.Doc { throw Boom() }
    func updateDoc(id: Int64, body: Components.Schemas.UpdateDocRequest) async throws -> Components.Schemas.Doc { throw Boom() }
    func deleteDoc(id: Int64) async throws { throw Boom() }
    func listFeatureDecisions(featureID: Int64) async throws -> [Components.Schemas.Decision] { throw Boom() }
    func createFeatureDecision(featureID: Int64, body: Components.Schemas.CreateDecisionRequest) async throws -> Components.Schemas.Decision { throw Boom() }
    func deleteDecision(id: Int64) async throws { throw Boom() }
    func listActivity(project: String?, feature: Int64?, since: Date?, limit: Int?) async throws -> [Components.Schemas.ActivityEvent] { throw Boom() }
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
