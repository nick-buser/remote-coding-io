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
