import Foundation

final class LiveTmuxAgentRepository: TmuxAgentRepository {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func listProjects() async throws -> [Components.Schemas.Project] {
        try await client.get(APIPath.join("api", "v1", "projects"))
    }

    func getProject(idOrSlug: String) async throws -> Components.Schemas.Project {
        try await client.get(APIPath.join("api", "v1", "projects", idOrSlug))
    }

    func updateProject(idOrSlug: String, body: Components.Schemas.UpdateProjectRequest) async throws -> Components.Schemas.Project {
        try await client.send(APIPath.join("api", "v1", "projects", idOrSlug), method: "PUT", body: body)
    }

    func listFeatures(projectIDOrSlug: String) async throws -> [Components.Schemas.Feature] {
        try await client.get(APIPath.join("api", "v1", "projects", projectIDOrSlug, "features"))
    }

    func getFeature(id: Int64) async throws -> Components.Schemas.Feature {
        try await client.get(APIPath.join("api", "v1", "features", String(id)))
    }

    func updateFeatureStatus(id: Int64, body: Components.Schemas.UpdateFeatureStatusRequest) async throws -> Components.Schemas.Feature {
        try await client.send(APIPath.join("api", "v1", "features", String(id)), method: "PUT", body: body)
    }

    func listProjectDocuments(projectID: Int64) async throws -> [WorkspaceDocument] {
        []
    }

    func listFeatureDocuments(featureID: Int64) async throws -> [WorkspaceDocument] {
        []
    }

    func saveDocument(_ document: WorkspaceDocument) async throws -> WorkspaceDocument {
        throw RepositoryError.unsupported("Document persistence is not exposed by the backend API yet.")
    }

    func openProjectSession(idOrSlug: String) async throws -> Components.Schemas.Project {
        try await client.send(APIPath.join("api", "v1", "projects", idOrSlug, "session"), method: "POST")
    }

    func listSessions(projectID: Int64) async throws -> [Components.Schemas.Session] {
        // The hand-rolled Project carried tmux_session_name, which the
        // contract does not expose. Until service-repo-agent-sessions wires
        // /api/v1/projects/{idOrSlug}/sessions (listProjectSessions, returning
        // AgentSession), surface no raw tmux sessions here.
        []
    }

    func listSessions(featureID: Int64) async throws -> [Components.Schemas.Session] {
        let feature = try await getFeature(id: featureID)
        return try await listSessions(projectID: feature.projectId)
    }

    func listSessions() async throws -> [Components.Schemas.Session] {
        try await client.get(APIPath.join("api", "v1", "sessions"))
    }

    func listPanes(sessionName: String) async throws -> [Components.Schemas.Pane] {
        try await client.get(APIPath.join("api", "v1", "sessions", sessionName, "panes"))
    }

    func getPaneOutput(sessionName: String, paneID: Int) async throws -> Components.Schemas.PaneOutput {
        try await client.get(APIPath.join("api", "v1", "sessions", sessionName, "panes", String(paneID), "output"))
    }

    func sendPaneInput(sessionName: String, paneID: Int, body: Components.Schemas.SendInputRequest) async throws -> Components.Schemas.StatusResponse {
        try await client.send(APIPath.join("api", "v1", "sessions", sessionName, "panes", String(paneID), "input"), method: "POST", body: body)
    }
}
