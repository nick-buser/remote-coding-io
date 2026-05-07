import Foundation

@MainActor
final class MockTmuxAgentRepository: TmuxAgentRepository {
    private var projects: [Components.Schemas.Project]
    private var features: [Components.Schemas.Feature]
    private var sessions: [Components.Schemas.Session]
    private var sessionScopes: [String: SessionScope]
    private var panesBySession: [String: [Components.Schemas.Pane]]
    private var outputsByPane: [String: Components.Schemas.PaneOutput]
    // The contract's Project schema does not carry tmux_session_name.
    // The mock keeps the prototype's project↔tmux-session mapping in a
    // sidecar map so openProjectSession / listSessions(projectID:) can
    // still satisfy preview wiring without leaking a contract-divergent
    // field onto the project type.
    private var tmuxSessionByProjectID: [Int64: String]
    private var documents: [WorkspaceDocument]
    // Tickets are stored without their inline `criteria` array; the
    // single-ticket GET attaches criteria from `criteriaByTicketID` so
    // listTickets can match the contract (criteria omitted) without a
    // second representation.
    private var tickets: [Components.Schemas.Ticket]
    private var criteriaByTicketID: [Int64: [Components.Schemas.AcceptanceCriterion]]
    private var nextTicketID: Int64
    private var nextCriterionID: Int64
    // Next public-id suffix to issue from createTicket. Seeded one past
    // the highest fixture so generated TMX-#### values don't collide.
    private var nextTicketPublicSequence: Int
    private(set) var sentInputs: [SentInput] = []

    init() {
        projects = Self.decode([Components.Schemas.Project].self, from: Self.projectsJSON)
        features = Self.decode([Components.Schemas.Feature].self, from: Self.featuresJSON)
        sessions = Self.decode([Components.Schemas.Session].self, from: Self.sessionsJSON)
        sessionScopes = [
            "tmux_server_coding_app": SessionScope(projectID: 1, featureID: nil),
            "tmux_agent_service_0031": SessionScope(projectID: 1, featureID: 11),
            "remote_coding_ios": SessionScope(projectID: 2, featureID: nil),
            "remote_coding_ios_service_0001": SessionScope(projectID: 2, featureID: 21)
        ]
        tmuxSessionByProjectID = [
            1: "tmux_server_coding_app"
            // Project 2 starts unlinked; openProjectSession assigns it on demand.
        ]

        let tmuxAgentPanes = Self.decode([Components.Schemas.Pane].self, from: Self.tmuxAgentPanesJSON)
        let tmuxAgentFeaturePanes = Self.decode([Components.Schemas.Pane].self, from: Self.tmuxAgentFeaturePanesJSON)
        let iOSProjectPanes = Self.decode([Components.Schemas.Pane].self, from: Self.iOSProjectPanesJSON)
        let iOSFeaturePanes = Self.decode([Components.Schemas.Pane].self, from: Self.iOSFeaturePanesJSON)
        panesBySession = [
            "tmux_server_coding_app": tmuxAgentPanes,
            "tmux_agent_service_0031": tmuxAgentFeaturePanes,
            "remote_coding_ios": iOSProjectPanes,
            "remote_coding_ios_service_0001": iOSFeaturePanes
        ]

        let output = Self.decode(Components.Schemas.PaneOutput.self, from: Self.paneOutputJSON)
        let iOSOutput = Self.decode(Components.Schemas.PaneOutput.self, from: Self.iOSPaneOutputJSON)
        outputsByPane = [
            "tmux_server_coding_app:0": output,
            "remote_coding_ios:0": iOSOutput
        ]

        documents = Self.seedDocuments

        let seed = Self.seedTickets()
        tickets = seed.tickets
        criteriaByTicketID = seed.criteria
        nextTicketID = seed.nextTicketID
        nextCriterionID = seed.nextCriterionID
        nextTicketPublicSequence = seed.nextPublicSequence
    }

    func listProjects() async throws -> [Components.Schemas.Project] {
        projects.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned {
                return lhs.pinned && !rhs.pinned
            }
            return lhs.lastTouchedAt > rhs.lastTouchedAt
        }
    }

    func getProject(idOrSlug: String) async throws -> Components.Schemas.Project {
        guard let project = projects.first(where: { String($0.id) == idOrSlug || $0.slug == idOrSlug }) else {
            throw MockRepositoryError.notFound
        }
        return project
    }

    func updateProject(idOrSlug: String, body: Components.Schemas.UpdateProjectRequest) async throws -> Components.Schemas.Project {
        guard let index = projects.firstIndex(where: { String($0.id) == idOrSlug || $0.slug == idOrSlug }) else {
            throw MockRepositoryError.notFound
        }
        projects[index].name = body.name
        projects[index].slug = body.slug ?? projects[index].slug
        projects[index].gitRepoUrl = body.gitRepoUrl
        projects[index].localRepoPath = body.localRepoPath
        projects[index].tagline = body.tagline
        projects[index].description = body.description
        projects[index].accent = body.accent
        projects[index].icon = body.icon
        projects[index].status = body.status ?? projects[index].status
        projects[index].pinned = body.pinned ?? projects[index].pinned
        projects[index].updatedAt = Date()
        return projects[index]
    }

    func listFeatures(projectIDOrSlug: String) async throws -> [Components.Schemas.Feature] {
        let project = try await getProject(idOrSlug: projectIDOrSlug)
        return features.filter { $0.projectId == project.id }
    }

    func getFeature(id: Int64) async throws -> Components.Schemas.Feature {
        guard let feature = features.first(where: { $0.id == id }) else {
            throw MockRepositoryError.notFound
        }
        return feature
    }

    func updateFeatureStatus(id: Int64, body: Components.Schemas.UpdateFeatureStatusRequest) async throws -> Components.Schemas.Feature {
        guard let index = features.firstIndex(where: { $0.id == id }) else {
            throw MockRepositoryError.notFound
        }
        features[index].status = body.status
        return features[index]
    }

    // MARK: Tickets

    func listTickets(featureID: Int64, status: Components.Schemas.TicketStatus?) async throws -> [Components.Schemas.Ticket] {
        tickets
            .filter { $0.featureId == featureID }
            .filter { status == nil || $0.status == status }
            .map(strippingCriteria)
    }

    func getTicket(publicID: String) async throws -> Components.Schemas.Ticket {
        guard let ticket = tickets.first(where: { $0.publicId == publicID }) else {
            throw MockRepositoryError.notFound
        }
        var attached = ticket
        attached.criteria = sortedCriteria(forTicketID: ticket.id)
        return attached
    }

    func createTicket(featureID: Int64, body: Components.Schemas.CreateTicketRequest) async throws -> Components.Schemas.Ticket {
        guard features.contains(where: { $0.id == featureID }) else {
            throw MockRepositoryError.notFound
        }
        let now = Date()
        let publicID = String(format: "TMX-%04d", nextTicketPublicSequence)
        nextTicketPublicSequence += 1
        let ticket = Components.Schemas.Ticket(
            id: nextTicketID,
            publicId: publicID,
            featureId: featureID,
            title: body.title,
            description: body.description ?? "",
            status: body.status ?? .todo,
            estimate: body.estimate ?? "",
            branchName: body.branchName ?? "",
            criteria: nil,
            criteriaTotal: 0,
            criteriaDone: 0,
            createdAt: now,
            updatedAt: now
        )
        nextTicketID += 1
        tickets.append(ticket)
        criteriaByTicketID[ticket.id] = []
        return ticket
    }

    func updateTicket(publicID: String, body: Components.Schemas.UpdateTicketRequest) async throws -> Components.Schemas.Ticket {
        guard let index = tickets.firstIndex(where: { $0.publicId == publicID }) else {
            throw MockRepositoryError.notFound
        }
        if let title = body.title { tickets[index].title = title }
        if let description = body.description { tickets[index].description = description }
        if let status = body.status { tickets[index].status = status }
        if let estimate = body.estimate { tickets[index].estimate = estimate }
        tickets[index].updatedAt = Date()
        var updated = tickets[index]
        updated.criteria = sortedCriteria(forTicketID: updated.id)
        return updated
    }

    // MARK: Acceptance criteria

    func listCriteria(ticketPublicID: String) async throws -> [Components.Schemas.AcceptanceCriterion] {
        guard let ticket = tickets.first(where: { $0.publicId == ticketPublicID }) else {
            throw MockRepositoryError.notFound
        }
        return sortedCriteria(forTicketID: ticket.id)
    }

    func createCriterion(ticketPublicID: String, body: Components.Schemas.CreateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion {
        guard let ticketIndex = tickets.firstIndex(where: { $0.publicId == ticketPublicID }) else {
            throw MockRepositoryError.notFound
        }
        let ticketID = tickets[ticketIndex].id
        let existing = criteriaByTicketID[ticketID] ?? []
        let appendedSortOrder = (existing.map { $0.sortOrder }.max() ?? -1) + 1
        let now = Date()
        let criterion = Components.Schemas.AcceptanceCriterion(
            id: nextCriterionID,
            ticketId: ticketID,
            text: body.text,
            done: body.done ?? false,
            sortOrder: body.sortOrder ?? appendedSortOrder,
            createdAt: now,
            updatedAt: now
        )
        nextCriterionID += 1
        criteriaByTicketID[ticketID, default: []].append(criterion)
        recomputeCriteriaCounts(for: ticketID)
        return criterion
    }

    func updateCriterion(id: Int64, body: Components.Schemas.UpdateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion {
        for (ticketID, list) in criteriaByTicketID {
            guard let index = list.firstIndex(where: { $0.id == id }) else { continue }
            var criterion = list[index]
            if let text = body.text { criterion.text = text }
            if let done = body.done { criterion.done = done }
            if let sortOrder = body.sortOrder { criterion.sortOrder = sortOrder }
            criterion.updatedAt = Date()
            criteriaByTicketID[ticketID]?[index] = criterion
            recomputeCriteriaCounts(for: ticketID)
            return criterion
        }
        throw MockRepositoryError.notFound
    }

    func deleteCriterion(id: Int64) async throws {
        for (ticketID, list) in criteriaByTicketID {
            guard let index = list.firstIndex(where: { $0.id == id }) else { continue }
            criteriaByTicketID[ticketID]?.remove(at: index)
            recomputeCriteriaCounts(for: ticketID)
            return
        }
        throw MockRepositoryError.notFound
    }

    private func sortedCriteria(forTicketID ticketID: Int64) -> [Components.Schemas.AcceptanceCriterion] {
        (criteriaByTicketID[ticketID] ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private func strippingCriteria(_ ticket: Components.Schemas.Ticket) -> Components.Schemas.Ticket {
        var copy = ticket
        copy.criteria = nil
        return copy
    }

    private func recomputeCriteriaCounts(for ticketID: Int64) {
        guard let index = tickets.firstIndex(where: { $0.id == ticketID }) else { return }
        let list = criteriaByTicketID[ticketID] ?? []
        tickets[index].criteriaTotal = list.count
        tickets[index].criteriaDone = list.filter { $0.done }.count
        tickets[index].updatedAt = Date()
    }

    func listProjectDocuments(projectID: Int64) async throws -> [WorkspaceDocument] {
        documents.filter {
            if case .project(projectID) = $0.owner {
                return true
            }
            return false
        }
    }

    func listFeatureDocuments(featureID: Int64) async throws -> [WorkspaceDocument] {
        documents.filter {
            if case .feature(featureID) = $0.owner {
                return true
            }
            return false
        }
    }

    func saveDocument(_ document: WorkspaceDocument) async throws -> WorkspaceDocument {
        var saved = document
        saved.updatedAt = Date()
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index] = saved
        } else {
            documents.append(saved)
        }
        return saved
    }

    func openProjectSession(idOrSlug: String) async throws -> Components.Schemas.Project {
        let project = try await getProject(idOrSlug: idOrSlug)
        if tmuxSessionByProjectID[project.id] == nil {
            tmuxSessionByProjectID[project.id] = defaultSessionName(for: project)
        }
        return project
    }

    func listSessions(projectID: Int64) async throws -> [Components.Schemas.Session] {
        scopedSessions { scope in
            scope.projectID == projectID && scope.featureID == nil
        }
    }

    func listSessions(featureID: Int64) async throws -> [Components.Schemas.Session] {
        guard let feature = features.first(where: { $0.id == featureID }) else {
            throw MockRepositoryError.notFound
        }
        let featureSessions = scopedSessions { scope in
            scope.featureID == featureID
        }
        if !featureSessions.isEmpty {
            return featureSessions
        }
        return try await listSessions(projectID: feature.projectId)
    }

    func listSessions() async throws -> [Components.Schemas.Session] {
        sessions
    }

    func listPanes(sessionName: String) async throws -> [Components.Schemas.Pane] {
        panesBySession[sessionName] ?? []
    }

    func getPaneOutput(sessionName: String, paneID: Int) async throws -> Components.Schemas.PaneOutput {
        outputsByPane["\(sessionName):\(paneID)"] ?? Components.Schemas.PaneOutput(
            sessionName: sessionName,
            paneIndex: paneID,
            content: ""
        )
    }

    func sendPaneInput(sessionName: String, paneID: Int, body: Components.Schemas.SendInputRequest) async throws -> Components.Schemas.StatusResponse {
        sentInputs.append(SentInput(sessionName: sessionName, paneID: paneID, body: body))
        let key = "\(sessionName):\(paneID)"
        var output = outputsByPane[key] ?? Components.Schemas.PaneOutput(sessionName: sessionName, paneIndex: paneID, content: "")
        output.content += transcriptLine(for: body)
        outputsByPane[key] = output
        return Components.Schemas.StatusResponse(status: "sent")
    }

    private func transcriptLine(for body: Components.Schemas.SendInputRequest) -> String {
        let typed = body.text ?? ""
        let keyText = body.keys?.joined(separator: " ") ?? ""
        if typed.isEmpty && (body.enter == true || body.keys?.contains("Enter") == true) {
            return "\n$ <enter>\n"
        }
        if !keyText.isEmpty {
            return "\n$ <\(keyText)>\n"
        }
        if body.enter == true {
            return "\n$ \(typed)\n"
        }
        return typed
    }

    private func scopedSessions(matching predicate: (SessionScope) -> Bool) -> [Components.Schemas.Session] {
        sessions.filter { session in
            guard let scope = sessionScopes[session.name] else {
                return false
            }
            return predicate(scope)
        }
    }

    private func defaultSessionName(for project: Components.Schemas.Project) -> String {
        switch project.id {
        case 1: "tmux_server_coding_app"
        case 2: "remote_coding_ios"
        default: project.slug.replacingOccurrences(of: "-", with: "_")
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from json: String) -> T {
        do {
            return try JSONDecoder.openAPI.decode(T.self, from: Data(json.utf8))
        } catch {
            fatalError("Invalid OpenAPI mock fixture: \(error)")
        }
    }
}

private struct SessionScope: Hashable {
    let projectID: Int64
    let featureID: Int64?
}

struct SentInput: Hashable {
    let sessionName: String
    let paneID: Int
    let body: Components.Schemas.SendInputRequest
}

enum MockRepositoryError: Error {
    case notFound
}

private extension MockTmuxAgentRepository {
    static let projectsJSON = """
    [
      {
        "id": 1,
        "name": "tmux server coding app",
        "slug": "tmux-server-coding-app",
        "git_repo_url": "git@github.com:nick-buser/tmux-server-coding-app.git",
        "local_repo_path": "/Users/nickbuser/Projects/personal_coding/tmux_server_coding_app",
        "tagline": "Remote coding through managed tmux sessions",
        "description": "Backend and clients for managing projects, features, and tmux-backed coding sessions.",
        "accent": "indigo",
        "icon": "terminal",
        "status": "active",
        "pinned": true,
        "last_touched_at": "2026-04-30T05:20:00Z",
        "created_at": "2026-04-05T04:00:00Z",
        "updated_at": "2026-04-30T05:20:00Z"
      },
      {
        "id": 2,
        "name": "remote coding iOS",
        "slug": "remote-coding-ios",
        "git_repo_url": "git@github.com:nick-buser/remote-coding-io.git",
        "local_repo_path": "/Users/nickbuser/Projects/personal_coding/tmux_server_coding_app/ios_apps",
        "tagline": "Native mobile client for tmux-agent",
        "description": "SwiftUI client for project navigation, feature docs, and mobile terminal I/O.",
        "accent": "teal",
        "icon": "iphone",
        "status": "active",
        "pinned": false,
        "last_touched_at": "2026-04-30T05:25:00Z",
        "created_at": "2026-04-30T04:00:00Z",
        "updated_at": "2026-04-30T05:25:00Z"
      }
    ]
    """

    static let featuresJSON = """
    [
      {
        "id": 11,
        "project_id": 1,
        "branch_name": "service-0031",
        "slug": "session-stream-and-pane-input",
        "title": "Session stream and pane input",
        "description_doc_key": "features/service-0031/description.md",
        "status": "in_progress",
        "accent": "indigo",
        "health": "ok",
        "tags": [],
        "progress_cached": 0.4,
        "created_at": "2026-04-29T14:00:00Z",
        "merged_at": null
      },
      {
        "id": 12,
        "project_id": 1,
        "branch_name": "docs-0032",
        "slug": "mobile-client-planning",
        "title": "Mobile client planning",
        "description_doc_key": "features/docs-0032/description.md",
        "status": "in_progress",
        "accent": "amber",
        "health": "ok",
        "tags": [],
        "progress_cached": 0.2,
        "created_at": "2026-04-30T02:00:00Z",
        "merged_at": null
      },
      {
        "id": 21,
        "project_id": 2,
        "branch_name": "service-0001",
        "slug": "project-hierarchy-prototype",
        "title": "Project hierarchy prototype",
        "description_doc_key": "features/service-0001/description.md",
        "status": "in_progress",
        "accent": "teal",
        "health": "ok",
        "tags": [],
        "progress_cached": 0.6,
        "created_at": "2026-04-30T05:30:00Z",
        "merged_at": null
      }
    ]
    """

    static let sessionsJSON = """
    [
      {
        "name": "tmux_server_coding_app",
        "attached": false,
        "created": "2026-04-30T05:10:00Z",
        "windows": 1,
        "directory": "/Users/nickbuser/Projects/personal_coding/tmux_server_coding_app"
      },
      {
        "name": "tmux_agent_service_0031",
        "attached": false,
        "created": "2026-04-30T05:40:00Z",
        "windows": 1,
        "directory": "/Users/nickbuser/Projects/personal_coding/tmux_server_coding_app"
      },
      {
        "name": "remote_coding_ios",
        "attached": false,
        "created": "2026-04-30T06:00:00Z",
        "windows": 1,
        "directory": "/Users/nickbuser/Projects/personal_coding/tmux_server_coding_app/ios_apps"
      },
      {
        "name": "remote_coding_ios_service_0001",
        "attached": false,
        "created": "2026-04-30T06:10:00Z",
        "windows": 1,
        "directory": "/Users/nickbuser/Projects/personal_coding/tmux_server_coding_app/ios_apps"
      }
    ]
    """

    static let tmuxAgentPanesJSON = """
    [
      {
        "index": 0,
        "title": "codex",
        "width": 120,
        "height": 40,
        "active": true,
        "directory": "/Users/nickbuser/Projects/personal_coding/tmux_server_coding_app"
      },
      {
        "index": 1,
        "title": "server",
        "width": 120,
        "height": 40,
        "active": false,
        "directory": "/Users/nickbuser/Projects/personal_coding/tmux_server_coding_app"
      }
    ]
    """

    static let tmuxAgentFeaturePanesJSON = """
    [
      {
        "index": 0,
        "title": "service-0031",
        "width": 120,
        "height": 40,
        "active": true,
        "directory": "/Users/nickbuser/Projects/personal_coding/tmux_server_coding_app"
      }
    ]
    """

    static let iOSProjectPanesJSON = """
    [
      {
        "index": 0,
        "title": "ios-plan",
        "width": 96,
        "height": 34,
        "active": true,
        "directory": "/Users/nickbuser/Projects/personal_coding/tmux_server_coding_app/ios_apps"
      }
    ]
    """

    static let iOSFeaturePanesJSON = """
    [
      {
        "index": 0,
        "title": "service-0001",
        "width": 96,
        "height": 34,
        "active": true,
        "directory": "/Users/nickbuser/Projects/personal_coding/tmux_server_coding_app/ios_apps"
      }
    ]
    """

    static let paneOutputJSON = """
    {
      "session_name": "tmux_server_coding_app",
      "pane_index": 0,
      "content": "$ go test ./...\\nok  github.com/nickbuser/tmux-agent/internal/store/sqlite  0.412s\\n?   github.com/nickbuser/tmux-agent/cmd  [no test files]\\n\\nContinue with generated client wiring? [y/N] "
    }
    """

    static let iOSPaneOutputJSON = """
    {
      "session_name": "remote_coding_ios",
      "pane_index": 0,
      "content": "$ xcodebuild build-for-testing ...\\n** TEST BUILD SUCCEEDED **\\n\\nReady to refine project-scoped pane routing. "
    }
    """

    // Tickets are seeded from the design fixtures
    // (claude_design_references/.../data.jsx, TMX-0042..TMX-0070), remapped
    // onto the existing mock features 11 / 12 / 21. The design's FEAT-018
    // tmux-pane tickets land on feature 11 (Session stream and pane input);
    // FEAT-019 context tickets land on feature 12 (Mobile client planning);
    // FEAT-020 review tickets land on feature 21 (Project hierarchy
    // prototype). One ticket is `done` so the status filter test sees all
    // four states. service-mock-rich-seed is the eventual replacement that
    // will rebuild fixtures one-for-one with the design.
    static func seedTickets() -> (
        tickets: [Components.Schemas.Ticket],
        criteria: [Int64: [Components.Schemas.AcceptanceCriterion]],
        nextTicketID: Int64,
        nextCriterionID: Int64,
        nextPublicSequence: Int
    ) {
        struct Spec {
            let publicID: String
            let featureID: Int64
            let title: String
            let description: String
            let status: Components.Schemas.TicketStatus
            let estimate: String
            let branchName: String
            let criteriaCount: Int
            let criteriaDone: Int
            let hoursAgo: Double
        }
        let specs: [Spec] = [
            Spec(publicID: "TMX-0042", featureID: 11, title: "Pane registry + lifecycle hooks",
                 description: "Track every spawned pane in a registry that fires lifecycle hooks on attach, detach, and exit.",
                 status: .doing, estimate: "M", branchName: "feat/tmx-0042-pane-registry",
                 criteriaCount: 4, criteriaDone: 2, hoursAgo: 0.2),
            Spec(publicID: "TMX-0043", featureID: 11, title: "Split layout grammar (h/v/grid)",
                 description: "Define a tiny grammar for splitting panes horizontally, vertically, or into a grid.",
                 status: .doing, estimate: "L", branchName: "feat/tmx-0043-split-grammar",
                 criteriaCount: 5, criteriaDone: 3, hoursAgo: 0.6),
            Spec(publicID: "TMX-0044", featureID: 11, title: "Per-pane status badge stream",
                 description: "Stream per-pane status (idle, busy, awaiting-input) so badges stay in sync without polling.",
                 status: .review, estimate: "S", branchName: "feat/tmx-0044-status-badge",
                 criteriaCount: 3, criteriaDone: 3, hoursAgo: 1),
            Spec(publicID: "TMX-0045", featureID: 11, title: "Scrollback search (regex + jump)",
                 description: "Regex-aware scrollback search with jump-to-match navigation.",
                 status: .todo, estimate: "M", branchName: "",
                 criteriaCount: 4, criteriaDone: 0, hoursAgo: 24),
            Spec(publicID: "TMX-0046", featureID: 11, title: "Keyboard map: pane navigation",
                 description: "Bind pane navigation to a keyboard map that respects the user's existing chord layout.",
                 status: .todo, estimate: "S", branchName: "",
                 criteriaCount: 3, criteriaDone: 0, hoursAgo: 24),
            Spec(publicID: "TMX-0047", featureID: 12, title: "Context bundle schema",
                 description: "Schema for the context bundle each session ships to the agent on resume.",
                 status: .doing, estimate: "M", branchName: "feat/tmx-0047-context-bundle",
                 criteriaCount: 5, criteriaDone: 4, hoursAgo: 1),
            Spec(publicID: "TMX-0048", featureID: 12, title: "PRD/notes resolver per session",
                 description: "Resolve the right PRD and notes for a session based on its ticket and feature.",
                 status: .doing, estimate: "M", branchName: "feat/tmx-0048-prd-resolver",
                 criteriaCount: 4, criteriaDone: 1, hoursAgo: 3),
            Spec(publicID: "TMX-0049", featureID: 12, title: "Resume hook: re-inject context",
                 description: "When a session resumes, re-inject the context bundle into the agent's prompt.",
                 status: .todo, estimate: "S", branchName: "",
                 criteriaCount: 3, criteriaDone: 0, hoursAgo: 48),
            Spec(publicID: "TMX-0050", featureID: 21, title: "Diff viewer component",
                 description: "Side-by-side diff viewer with line-level highlighting.",
                 status: .review, estimate: "L", branchName: "feat/tmx-0050-diff-viewer",
                 criteriaCount: 6, criteriaDone: 6, hoursAgo: 3),
            Spec(publicID: "TMX-0051", featureID: 21, title: "Acceptance checklist binding",
                 description: "Bind the acceptance checklist to the diff so reviewers can tick items as they read.",
                 status: .review, estimate: "S", branchName: "feat/tmx-0051-checklist",
                 criteriaCount: 4, criteriaDone: 4, hoursAgo: 4),
            Spec(publicID: "TMX-0052", featureID: 21, title: "Approve / request-changes actions",
                 description: "Reviewer actions: approve, request changes, send back to doing.",
                 status: .doing, estimate: "S", branchName: "feat/tmx-0052-review-actions",
                 criteriaCount: 3, criteriaDone: 2, hoursAgo: 6),
            Spec(publicID: "TMX-0061", featureID: 12, title: "Lex tokens + grammar",
                 description: "Lex query tokens and define the grammar for the saved-query DSL.",
                 status: .done, estimate: "M", branchName: "feat/tmx-0061-lex",
                 criteriaCount: 4, criteriaDone: 4, hoursAgo: 48),
            Spec(publicID: "TMX-0062", featureID: 12, title: "Autocomplete provider",
                 description: "Autocomplete suggestions for query operators and field names.",
                 status: .todo, estimate: "S", branchName: "",
                 criteriaCount: 3, criteriaDone: 0, hoursAgo: 72),
            Spec(publicID: "TMX-0063", featureID: 12, title: "Saved-query store",
                 description: "Persist saved queries and surface them in the autocomplete history list.",
                 status: .todo, estimate: "S", branchName: "",
                 criteriaCount: 3, criteriaDone: 0, hoursAgo: 96),
            Spec(publicID: "TMX-0070", featureID: 21, title: "Hover popover component",
                 description: "Reusable hover popover used by the diff viewer's annotations.",
                 status: .todo, estimate: "S", branchName: "",
                 criteriaCount: 2, criteriaDone: 0, hoursAgo: 144)
        ]

        var tickets: [Components.Schemas.Ticket] = []
        var criteria: [Int64: [Components.Schemas.AcceptanceCriterion]] = [:]
        var ticketID: Int64 = 200
        var criterionID: Int64 = 1000
        let now = Date()

        for spec in specs {
            let updatedAt = now.addingTimeInterval(-spec.hoursAgo * 3600)
            let createdAt = updatedAt.addingTimeInterval(-72 * 3600)

            var ticketCriteria: [Components.Schemas.AcceptanceCriterion] = []
            for index in 0..<spec.criteriaCount {
                let isDone = index < spec.criteriaDone
                ticketCriteria.append(Components.Schemas.AcceptanceCriterion(
                    id: criterionID,
                    ticketId: ticketID,
                    text: "\(spec.title) — step \(index + 1)",
                    done: isDone,
                    sortOrder: index,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                ))
                criterionID += 1
            }

            tickets.append(Components.Schemas.Ticket(
                id: ticketID,
                publicId: spec.publicID,
                featureId: spec.featureID,
                title: spec.title,
                description: spec.description,
                status: spec.status,
                estimate: spec.estimate,
                branchName: spec.branchName,
                criteria: nil,
                criteriaTotal: ticketCriteria.count,
                criteriaDone: ticketCriteria.filter { $0.done }.count,
                createdAt: createdAt,
                updatedAt: updatedAt
            ))
            criteria[ticketID] = ticketCriteria
            ticketID += 1
        }

        // Highest seeded TMX is 0070; next created ticket starts at 0071.
        return (tickets, criteria, ticketID, criterionID, 71)
    }

    static var seedDocuments: [WorkspaceDocument] {
        [
            WorkspaceDocument(
                id: "project-1-brief",
                owner: .project(1),
                kind: .projectBrief,
                title: "Project brief",
                body: "Build a backend and native clients for launching, monitoring, and steering tmux-backed coding sessions.",
                updatedAt: Date()
            ),
            WorkspaceDocument(
                id: "project-1-notes",
                owner: .project(1),
                kind: .projectNotes,
                title: "Project notes",
                body: "OpenAPI remains the source of truth. Sessions currently hang off projects/features; ticket endpoints are planned but not exposed yet.",
                updatedAt: Date()
            ),
            WorkspaceDocument(
                id: "feature-11-description",
                owner: .feature(11),
                kind: .featureDescription,
                title: "Description",
                body: "Stream pane output over WebSocket and send tmux input through the REST endpoint.",
                updatedAt: Date()
            ),
            WorkspaceDocument(
                id: "feature-11-prompt",
                owner: .feature(11),
                kind: .promptBuildout,
                title: "Prompt buildout",
                body: "Implement the smallest path that lets a mobile client pick a pane, see output, submit empty Enter, and send control commands.",
                updatedAt: Date()
            ),
            WorkspaceDocument(
                id: "feature-11-criteria",
                owner: .feature(11),
                kind: .acceptanceCriteria,
                title: "Acceptance criteria",
                body: "- [ ] Empty Enter sends a request with no text payload.\\n- [ ] Ctrl-C and Ctrl-D are available as explicit keys.\\n- [ ] Pane output can recover from a REST snapshot.",
                updatedAt: Date()
            ),
            WorkspaceDocument(
                id: "feature-21-description",
                owner: .feature(21),
                kind: .featureDescription,
                title: "Description",
                body: "Create the first native iOS project hierarchy and terminal prototype using OpenAPI-shaped mocks.",
                updatedAt: Date()
            ),
            WorkspaceDocument(
                id: "feature-21-prompt",
                owner: .feature(21),
                kind: .promptBuildout,
                title: "Prompt buildout",
                body: "Prefer native list navigation, editor panes for project/feature docs, and a terminal tab that keeps context visible.",
                updatedAt: Date()
            ),
            WorkspaceDocument(
                id: "feature-21-criteria",
                owner: .feature(21),
                kind: .acceptanceCriteria,
                title: "Acceptance criteria",
                body: "- [ ] Project list drills into project detail.\\n- [ ] Feature detail exposes editable description, prompt, and criteria.\\n- [ ] Terminal input supports empty Enter and tmux control keys.",
                updatedAt: Date()
            )
        ]
    }
}
