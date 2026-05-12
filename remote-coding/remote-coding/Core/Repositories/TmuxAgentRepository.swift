import Foundation

protocol TmuxAgentRepository {
    func listProjects() async throws -> [Components.Schemas.Project]
    func getProject(idOrSlug: String) async throws -> Components.Schemas.Project
    func createProject(_ body: Components.Schemas.CreateProjectRequest) async throws -> Components.Schemas.Project
    func updateProject(idOrSlug: String, body: Components.Schemas.UpdateProjectRequest) async throws -> Components.Schemas.Project
    func deleteProject(idOrSlug: String) async throws
    func listFeatures(projectIDOrSlug: String) async throws -> [Components.Schemas.Feature]
    func getFeature(id: Int64) async throws -> Components.Schemas.Feature
    func createFeature(projectIDOrSlug: String, body: Components.Schemas.CreateFeatureRequest) async throws -> Components.Schemas.Feature
    func updateFeatureStatus(id: Int64, body: Components.Schemas.UpdateFeatureStatusRequest) async throws -> Components.Schemas.Feature
    func listTickets(featureID: Int64, status: Components.Schemas.TicketStatus?) async throws -> [Components.Schemas.Ticket]
    func getTicket(publicID: String) async throws -> Components.Schemas.Ticket
    func createTicket(featureID: Int64, body: Components.Schemas.CreateTicketRequest) async throws -> Components.Schemas.Ticket
    func updateTicket(publicID: String, body: Components.Schemas.UpdateTicketRequest) async throws -> Components.Schemas.Ticket
    func listCriteria(ticketPublicID: String) async throws -> [Components.Schemas.AcceptanceCriterion]
    func createCriterion(ticketPublicID: String, body: Components.Schemas.CreateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion
    func updateCriterion(id: Int64, body: Components.Schemas.UpdateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion
    func deleteCriterion(id: Int64) async throws
    func listFeatureDocs(featureID: Int64) async throws -> [Components.Schemas.Doc]
    func getDoc(id: Int64) async throws -> Components.Schemas.Doc
    func createFeatureDoc(featureID: Int64, body: Components.Schemas.CreateDocRequest) async throws -> Components.Schemas.Doc
    func updateDoc(id: Int64, body: Components.Schemas.UpdateDocRequest) async throws -> Components.Schemas.Doc
    func deleteDoc(id: Int64) async throws
    func listFeatureDecisions(featureID: Int64) async throws -> [Components.Schemas.Decision]
    func createFeatureDecision(featureID: Int64, body: Components.Schemas.CreateDecisionRequest) async throws -> Components.Schemas.Decision
    func deleteDecision(id: Int64) async throws
    func listActivity(project: String?, feature: Int64?, since: Date?, limit: Int?) async throws -> [Components.Schemas.ActivityEvent]
    func getAgentSession(id: Int64) async throws -> Components.Schemas.AgentSession
    func listProjectAgentSessions(projectIDOrSlug: String) async throws -> [Components.Schemas.AgentSession]
    func listTicketAgentSessions(ticketPublicID: String) async throws -> [Components.Schemas.AgentSession]
    func createAgentSession(_ body: Components.Schemas.CreateAgentSessionRequest) async throws -> Components.Schemas.AgentSession
    func getTicketDiff(publicID: String) async throws -> Components.Schemas.TicketDiff
    func approveTicket(publicID: String) async throws -> Components.Schemas.Ticket
    func requestTicketChanges(publicID: String, comment: String?) async throws -> Components.Schemas.Ticket
    func sendTicketBack(publicID: String, comment: String?) async throws -> Components.Schemas.Ticket
    func listProjectDocuments(projectID: Int64) async throws -> [LocalProjectNote]
    func saveDocument(_ document: LocalProjectNote) async throws -> LocalProjectNote
    func openProjectSession(idOrSlug: String) async throws -> Components.Schemas.Project
    func listSessions(projectID: Int64) async throws -> [Components.Schemas.Session]
    func listSessions(featureID: Int64) async throws -> [Components.Schemas.Session]
    func listSessions() async throws -> [Components.Schemas.Session]
    func listPanes(sessionName: String) async throws -> [Components.Schemas.Pane]
    func getPaneOutput(sessionName: String, paneID: Int) async throws -> Components.Schemas.PaneOutput
    func sendPaneInput(sessionName: String, paneID: Int, body: Components.Schemas.SendInputRequest) async throws -> Components.Schemas.StatusResponse
    func registerDevice(_ body: Components.Schemas.DeviceRegistrationRequest) async throws -> Components.Schemas.DeviceRegistration
    func deregisterDevice(token: String) async throws
}
