import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

final class LiveTmuxAgentRepository: TmuxAgentRepository {
    private let client: any APIProtocol
    private let localNoteStore: LocalProjectNoteStore

    init(configuration: APIConfiguration, userDefaults: UserDefaults = .standard) {
        self.client = Client(
            serverURL: configuration.baseURL,
            transport: URLSessionTransport()
        )
        self.localNoteStore = LocalProjectNoteStore(userDefaults: userDefaults)
    }

    init(client: any APIProtocol, userDefaults: UserDefaults = .standard) {
        self.client = client
        self.localNoteStore = LocalProjectNoteStore(userDefaults: userDefaults)
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

    func createProject(_ body: Components.Schemas.CreateProjectRequest) async throws -> Components.Schemas.Project {
        let output = try await client.createProject(.init(body: .json(body)))
        switch output {
        case .created(let response):
            return try response.body.json
        case .badRequest(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .conflict(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func deleteProject(idOrSlug: String) async throws {
        let output = try await client.deleteProject(.init(path: .init(idOrSlug: idOrSlug)))
        switch output {
        case .noContent:
            return
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

    func createFeature(projectIDOrSlug: String, body: Components.Schemas.CreateFeatureRequest) async throws -> Components.Schemas.Feature {
        let output = try await client.createFeature(.init(
            path: .init(idOrSlug: projectIDOrSlug),
            body: .json(body)
        ))
        switch output {
        case .created(let response):
            return try response.body.json
        case .badRequest(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .conflict(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    // MARK: Tickets

    func listTickets(featureID: Int64, status: Components.Schemas.TicketStatus?) async throws -> [Components.Schemas.Ticket] {
        let output = try await client.listTickets(.init(
            path: .init(id: featureID),
            query: .init(status: status)
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

    func getTicket(publicID: String) async throws -> Components.Schemas.Ticket {
        let output = try await client.getTicket(.init(path: .init(publicId: publicID)))
        switch output {
        case .ok(let response):
            return try response.body.json
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func createTicket(featureID: Int64, body: Components.Schemas.CreateTicketRequest) async throws -> Components.Schemas.Ticket {
        let output = try await client.createTicket(.init(
            path: .init(id: featureID),
            body: .json(body)
        ))
        switch output {
        case .created(let response):
            return try response.body.json
        case .badRequest(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .conflict(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func updateTicket(publicID: String, body: Components.Schemas.UpdateTicketRequest) async throws -> Components.Schemas.Ticket {
        let output = try await client.updateTicket(.init(
            path: .init(publicId: publicID),
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

    // MARK: Acceptance criteria

    func listCriteria(ticketPublicID: String) async throws -> [Components.Schemas.AcceptanceCriterion] {
        let output = try await client.listTicketCriteria(.init(path: .init(publicId: ticketPublicID)))
        switch output {
        case .ok(let response):
            let criteria = try response.body.json
            return criteria.sorted { $0.sortOrder < $1.sortOrder }
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func createCriterion(ticketPublicID: String, body: Components.Schemas.CreateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion {
        let output = try await client.createTicketCriterion(.init(
            path: .init(publicId: ticketPublicID),
            body: .json(body)
        ))
        switch output {
        case .created(let response):
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

    func updateCriterion(id: Int64, body: Components.Schemas.UpdateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion {
        let output = try await client.updateCriterion(.init(
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

    func deleteCriterion(id: Int64) async throws {
        let output = try await client.deleteCriterion(.init(path: .init(id: id)))
        switch output {
        case .noContent:
            return
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    // MARK: Feature docs (live, contract-backed)

    func listFeatureDocs(featureID: Int64) async throws -> [Components.Schemas.Doc] {
        let output = try await client.listFeatureDocs(.init(path: .init(id: featureID)))
        switch output {
        case .ok(let response):
            let docs = try response.body.json
            return docs.sorted { lhs, rhs in
                if lhs.pinned != rhs.pinned {
                    return lhs.pinned && !rhs.pinned
                }
                return lhs.updatedAt > rhs.updatedAt
            }
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func getDoc(id: Int64) async throws -> Components.Schemas.Doc {
        let output = try await client.getDoc(.init(path: .init(id: id)))
        switch output {
        case .ok(let response):
            return try response.body.json
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func createFeatureDoc(featureID: Int64, body: Components.Schemas.CreateDocRequest) async throws -> Components.Schemas.Doc {
        let output = try await client.createFeatureDoc(.init(
            path: .init(id: featureID),
            body: .json(body)
        ))
        switch output {
        case .created(let response):
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

    func updateDoc(id: Int64, body: Components.Schemas.UpdateDocRequest) async throws -> Components.Schemas.Doc {
        let output = try await client.updateDoc(.init(
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

    func deleteDoc(id: Int64) async throws {
        let output = try await client.deleteDoc(.init(path: .init(id: id)))
        switch output {
        case .noContent:
            return
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    // MARK: Feature decisions

    func listFeatureDecisions(featureID: Int64) async throws -> [Components.Schemas.Decision] {
        let output = try await client.listFeatureDecisions(.init(path: .init(id: featureID)))
        switch output {
        case .ok(let response):
            let decisions = try response.body.json
            return decisions.sorted { $0.createdAt > $1.createdAt }
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func createFeatureDecision(featureID: Int64, body: Components.Schemas.CreateDecisionRequest) async throws -> Components.Schemas.Decision {
        let output = try await client.createFeatureDecision(.init(
            path: .init(id: featureID),
            body: .json(body)
        ))
        switch output {
        case .created(let response):
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

    func deleteDecision(id: Int64) async throws {
        let output = try await client.deleteDecision(.init(path: .init(id: id)))
        switch output {
        case .noContent:
            return
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    // MARK: Activity

    func listActivity(project: String?, feature: Int64?, since: Date?, limit: Int?) async throws -> [Components.Schemas.ActivityEvent] {
        let output = try await client.listActivity(.init(query: .init(
            project: project,
            feature: feature,
            since: since,
            limit: limit
        )))
        switch output {
        case .ok(let response):
            return try response.body.json
        case .badRequest(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    // MARK: Agent sessions

    func listProjectAgentSessions(projectIDOrSlug: String) async throws -> [Components.Schemas.AgentSession] {
        let output = try await client.listProjectSessions(.init(path: .init(idOrSlug: projectIDOrSlug)))
        switch output {
        case .ok(let response):
            let sessions = try response.body.json
            return sessions.sorted { $0.lastActiveAt > $1.lastActiveAt }
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func listTicketAgentSessions(ticketPublicID: String) async throws -> [Components.Schemas.AgentSession] {
        let output = try await client.listTicketSessions(.init(path: .init(publicId: ticketPublicID)))
        switch output {
        case .ok(let response):
            let sessions = try response.body.json
            return sessions.sorted { $0.lastActiveAt > $1.lastActiveAt }
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func createAgentSession(_ body: Components.Schemas.CreateAgentSessionRequest) async throws -> Components.Schemas.AgentSession {
        let output = try await client.createAgentSession(.init(body: .json(body)))
        switch output {
        case .created(let response):
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

    // MARK: Ticket review

    func getTicketDiff(publicID: String) async throws -> Components.Schemas.TicketDiff {
        let output = try await client.getTicketDiff(.init(path: .init(publicId: publicID)))
        switch output {
        case .ok(let response):
            return try response.body.json
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func approveTicket(publicID: String) async throws -> Components.Schemas.Ticket {
        let output = try await client.approveTicket(.init(path: .init(publicId: publicID)))
        switch output {
        case .ok(let response):
            return try response.body.json
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func requestTicketChanges(publicID: String, comment: String?) async throws -> Components.Schemas.Ticket {
        let body = Components.Schemas.ReviewActionRequest(comment: comment)
        let output = try await client.requestTicketChanges(.init(
            path: .init(publicId: publicID),
            body: .json(body)
        ))
        switch output {
        case .ok(let response):
            return try response.body.json
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    func sendTicketBack(publicID: String, comment: String?) async throws -> Components.Schemas.Ticket {
        let body = Components.Schemas.ReviewActionRequest(comment: comment)
        let output = try await client.sendTicketBack(.init(
            path: .init(publicId: publicID),
            body: .json(body)
        ))
        switch output {
        case .ok(let response):
            return try response.body.json
        case .notFound(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .serviceUnavailable(let response):
            throw RepositoryError.problem(try response.body.applicationProblemJson)
        case .undocumented(let statusCode, _):
            throw RepositoryError.http(statusCode)
        }
    }

    // MARK: Local project notes (UserDefaults — no contract endpoint yet)

    func listProjectDocuments(projectID: Int64) async throws -> [LocalProjectNote] {
        localNoteStore.list(projectID: projectID)
    }

    func saveDocument(_ document: LocalProjectNote) async throws -> LocalProjectNote {
        localNoteStore.save(document)
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
