import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

final class LiveTmuxAgentRepository: TmuxAgentRepository {
    private let client: any APIProtocol

    init(configuration: APIConfiguration) {
        self.client = Client(
            serverURL: configuration.baseURL,
            transport: URLSessionTransport()
        )
    }

    init(client: any APIProtocol) {
        self.client = client
    }

    // MARK: Projects

    func listProjects() async throws -> [Components.Schemas.Project] {
        let output = try await client.listProjects(.init())
        switch output {
        case .ok(let response):
            return try response.body.json
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func getProject(idOrSlug: String) async throws -> Components.Schemas.Project {
        let output = try await client.getProject(.init(path: .init(idOrSlug: idOrSlug)))
        switch output {
        case .ok(let response):
            return try response.body.json
        case .badRequest(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func updateProject(idOrSlug: String, body: Components.Schemas.UpdateProjectRequest) async throws -> Components.Schemas.Project {
        let output = try await client.updateProject(.init(
            path: .init(idOrSlug: idOrSlug),
            body: .json(body)
        ))
        switch output {
        case .ok(let response):
            return try response.body.json
        case .badRequest(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func openProjectSession(idOrSlug: String) async throws -> Components.Schemas.Project {
        let output = try await client.openProjectSession(.init(path: .init(idOrSlug: idOrSlug)))
        switch output {
        case .ok(let response):
            return try response.body.json
        case .created(let response):
            return try response.body.json
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .internalServerError(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    // MARK: Features

    func listFeatures(projectIDOrSlug: String) async throws -> [Components.Schemas.Feature] {
        let output = try await client.listFeatures(.init(path: .init(idOrSlug: projectIDOrSlug)))
        switch output {
        case .ok(let response):
            return try response.body.json
        case .badRequest(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func getFeature(id: Int64) async throws -> Components.Schemas.Feature {
        let output = try await client.getFeature(.init(path: .init(id: id)))
        switch output {
        case .ok(let response):
            return try response.body.json
        case .badRequest(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func updateFeatureStatus(id: Int64, body: Components.Schemas.UpdateFeatureStatusRequest) async throws -> Components.Schemas.Feature {
        let output = try await client.updateFeatureStatus(.init(
            path: .init(id: id),
            body: .json(body)
        ))
        switch output {
        case .ok(let response):
            return try response.body.json
        case .badRequest(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    // MARK: Documents (not exposed by the contract yet)

    func listProjectDocuments(projectID: Int64) async throws -> [WorkspaceDocument] { [] }
    func listFeatureDocuments(featureID: Int64) async throws -> [WorkspaceDocument] { [] }

    func saveDocument(_ document: WorkspaceDocument) async throws -> WorkspaceDocument {
        throw RepositoryError.unsupported("Document persistence is not exposed by the backend API yet.")
    }

    // MARK: Sessions

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
        let output = try await client.listSessions(.init())
        switch output {
        case .ok(let response):
            return try response.body.json
        case .internalServerError(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    // MARK: Panes

    func listPanes(sessionName: String) async throws -> [Components.Schemas.Pane] {
        let output = try await client.listPanes(.init(path: .init(name: sessionName)))
        switch output {
        case .ok(let response):
            return try response.body.json
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .internalServerError(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func getPaneOutput(sessionName: String, paneID: Int) async throws -> Components.Schemas.PaneOutput {
        let output = try await client.getPaneOutput(.init(path: .init(name: sessionName, paneId: paneID)))
        switch output {
        case .ok(let response):
            return try response.body.json
        case .badRequest(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .internalServerError(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func sendPaneInput(sessionName: String, paneID: Int, body: Components.Schemas.SendInputRequest) async throws -> Components.Schemas.StatusResponse {
        let output = try await client.sendPaneInput(.init(
            path: .init(name: sessionName, paneId: paneID),
            body: .json(body)
        ))
        switch output {
        case .ok(let response):
            return try response.body.json
        case .badRequest(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .internalServerError(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }
}
