import Foundation

protocol TmuxAgentRepository {
    func listProjects() async throws -> [OpenAPI.Project]
    func getProject(idOrSlug: String) async throws -> OpenAPI.Project
    func updateProject(idOrSlug: String, body: OpenAPI.UpdateProjectRequest) async throws -> OpenAPI.Project
    func listFeatures(projectIDOrSlug: String) async throws -> [OpenAPI.Feature]
    func getFeature(id: Int64) async throws -> OpenAPI.Feature
    func updateFeatureStatus(id: Int64, body: OpenAPI.UpdateFeatureStatusRequest) async throws -> OpenAPI.Feature
    func listProjectDocuments(projectID: Int64) async throws -> [WorkspaceDocument]
    func listFeatureDocuments(featureID: Int64) async throws -> [WorkspaceDocument]
    func saveDocument(_ document: WorkspaceDocument) async throws -> WorkspaceDocument
    func openProjectSession(idOrSlug: String) async throws -> OpenAPI.Project
    func listSessions() async throws -> [OpenAPI.Session]
    func listPanes(sessionName: String) async throws -> [OpenAPI.Pane]
    func getPaneOutput(sessionName: String, paneID: Int) async throws -> OpenAPI.PaneOutput
    func sendPaneInput(sessionName: String, paneID: Int, body: OpenAPI.SendInputRequest) async throws -> OpenAPI.StatusResponse
}

