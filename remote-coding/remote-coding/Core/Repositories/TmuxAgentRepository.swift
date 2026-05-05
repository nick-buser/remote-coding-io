import Foundation

protocol TmuxAgentRepository {
    func listProjects() async throws -> [Components.Schemas.Project]
    func getProject(idOrSlug: String) async throws -> Components.Schemas.Project
    func updateProject(idOrSlug: String, body: Components.Schemas.UpdateProjectRequest) async throws -> Components.Schemas.Project
    func listFeatures(projectIDOrSlug: String) async throws -> [Components.Schemas.Feature]
    func getFeature(id: Int64) async throws -> Components.Schemas.Feature
    func updateFeatureStatus(id: Int64, body: Components.Schemas.UpdateFeatureStatusRequest) async throws -> Components.Schemas.Feature
    func listProjectDocuments(projectID: Int64) async throws -> [WorkspaceDocument]
    func listFeatureDocuments(featureID: Int64) async throws -> [WorkspaceDocument]
    func saveDocument(_ document: WorkspaceDocument) async throws -> WorkspaceDocument
    func openProjectSession(idOrSlug: String) async throws -> Components.Schemas.Project
    func listSessions(projectID: Int64) async throws -> [Components.Schemas.Session]
    func listSessions(featureID: Int64) async throws -> [Components.Schemas.Session]
    func listSessions() async throws -> [Components.Schemas.Session]
    func listPanes(sessionName: String) async throws -> [Components.Schemas.Pane]
    func getPaneOutput(sessionName: String, paneID: Int) async throws -> Components.Schemas.PaneOutput
    func sendPaneInput(sessionName: String, paneID: Int, body: Components.Schemas.SendInputRequest) async throws -> Components.Schemas.StatusResponse
}
