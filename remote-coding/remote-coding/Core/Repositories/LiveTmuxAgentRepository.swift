import Foundation

final class LiveTmuxAgentRepository: TmuxAgentRepository {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func listProjects() async throws -> [OpenAPI.Project] {
        try await client.get(APIPath.join("api", "v1", "projects"))
    }

    func getProject(idOrSlug: String) async throws -> OpenAPI.Project {
        try await client.get(APIPath.join("api", "v1", "projects", idOrSlug))
    }

    func updateProject(idOrSlug: String, body: OpenAPI.UpdateProjectRequest) async throws -> OpenAPI.Project {
        try await client.send(APIPath.join("api", "v1", "projects", idOrSlug), method: "PUT", body: body)
    }

    func listFeatures(projectIDOrSlug: String) async throws -> [OpenAPI.Feature] {
        try await client.get(APIPath.join("api", "v1", "projects", projectIDOrSlug, "features"))
    }

    func getFeature(id: Int64) async throws -> OpenAPI.Feature {
        try await client.get(APIPath.join("api", "v1", "features", String(id)))
    }

    func updateFeatureStatus(id: Int64, body: OpenAPI.UpdateFeatureStatusRequest) async throws -> OpenAPI.Feature {
        try await client.send(APIPath.join("api", "v1", "features", String(id)), method: "PUT", body: body)
    }

    func listProjectDocuments(projectID: Int64) async throws -> [WorkspaceDocument] {
        []
    }

    func listFeatureDocuments(featureID: Int64) async throws -> [WorkspaceDocument] {
        []
    }

    func saveDocument(_ document: WorkspaceDocument) async throws -> WorkspaceDocument {
        throw APIClientError.unsupported("Document persistence is not exposed by the backend API yet.")
    }

    func openProjectSession(idOrSlug: String) async throws -> OpenAPI.Project {
        try await client.send(APIPath.join("api", "v1", "projects", idOrSlug, "session"), method: "POST")
    }

    func listSessions(projectID: Int64) async throws -> [OpenAPI.Session] {
        let project = try await getProject(idOrSlug: String(projectID))
        guard let sessionName = project.tmuxSessionName, !sessionName.isEmpty else {
            return []
        }
        return try await listSessions().filter { $0.name == sessionName }
    }

    func listSessions(featureID: Int64) async throws -> [OpenAPI.Session] {
        let feature = try await getFeature(id: featureID)
        return try await listSessions(projectID: feature.projectID)
    }

    func listSessions() async throws -> [OpenAPI.Session] {
        try await client.get(APIPath.join("api", "v1", "sessions"))
    }

    func listPanes(sessionName: String) async throws -> [OpenAPI.Pane] {
        try await client.get(APIPath.join("api", "v1", "sessions", sessionName, "panes"))
    }

    func getPaneOutput(sessionName: String, paneID: Int) async throws -> OpenAPI.PaneOutput {
        try await client.get(APIPath.join("api", "v1", "sessions", sessionName, "panes", String(paneID), "output"))
    }

    func sendPaneInput(sessionName: String, paneID: Int, body: OpenAPI.SendInputRequest) async throws -> OpenAPI.StatusResponse {
        try await client.send(APIPath.join("api", "v1", "sessions", sessionName, "panes", String(paneID), "input"), method: "POST", body: body)
    }
}

