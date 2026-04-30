import Foundation

@MainActor
final class MockTmuxAgentRepository: TmuxAgentRepository {
    private var projects: [OpenAPI.Project]
    private var features: [OpenAPI.Feature]
    private var sessions: [OpenAPI.Session]
    private var panesBySession: [String: [OpenAPI.Pane]]
    private var outputsByPane: [String: OpenAPI.PaneOutput]
    private var documents: [WorkspaceDocument]
    private(set) var sentInputs: [SentInput] = []

    init() {
        projects = Self.decode([OpenAPI.Project].self, from: Self.projectsJSON)
        features = Self.decode([OpenAPI.Feature].self, from: Self.featuresJSON)
        sessions = Self.decode([OpenAPI.Session].self, from: Self.sessionsJSON)

        let panes = Self.decode([OpenAPI.Pane].self, from: Self.panesJSON)
        panesBySession = ["tmux_server_coding_app": panes]

        let output = Self.decode(OpenAPI.PaneOutput.self, from: Self.paneOutputJSON)
        outputsByPane = ["tmux_server_coding_app:0": output]

        documents = Self.seedDocuments
    }

    func listProjects() async throws -> [OpenAPI.Project] {
        projects.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned {
                return lhs.pinned && !rhs.pinned
            }
            return lhs.lastTouchedAt > rhs.lastTouchedAt
        }
    }

    func getProject(idOrSlug: String) async throws -> OpenAPI.Project {
        guard let project = projects.first(where: { String($0.id) == idOrSlug || $0.slug == idOrSlug }) else {
            throw MockRepositoryError.notFound
        }
        return project
    }

    func updateProject(idOrSlug: String, body: OpenAPI.UpdateProjectRequest) async throws -> OpenAPI.Project {
        guard let index = projects.firstIndex(where: { String($0.id) == idOrSlug || $0.slug == idOrSlug }) else {
            throw MockRepositoryError.notFound
        }
        projects[index].name = body.name
        projects[index].slug = body.slug ?? projects[index].slug
        projects[index].gitRepoURL = body.gitRepoURL
        projects[index].localRepoPath = body.localRepoPath
        projects[index].tmuxSessionName = body.tmuxSessionName
        projects[index].tagline = body.tagline
        projects[index].description = body.description
        projects[index].accent = body.accent
        projects[index].icon = body.icon
        projects[index].status = body.status ?? projects[index].status
        projects[index].pinned = body.pinned ?? projects[index].pinned
        projects[index].updatedAt = Date()
        return projects[index]
    }

    func listFeatures(projectIDOrSlug: String) async throws -> [OpenAPI.Feature] {
        let project = try await getProject(idOrSlug: projectIDOrSlug)
        return features.filter { $0.projectID == project.id }
    }

    func getFeature(id: Int64) async throws -> OpenAPI.Feature {
        guard let feature = features.first(where: { $0.id == id }) else {
            throw MockRepositoryError.notFound
        }
        return feature
    }

    func updateFeatureStatus(id: Int64, body: OpenAPI.UpdateFeatureStatusRequest) async throws -> OpenAPI.Feature {
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

    func openProjectSession(idOrSlug: String) async throws -> OpenAPI.Project {
        var project = try await getProject(idOrSlug: idOrSlug)
        if project.tmuxSessionName == nil {
            project.tmuxSessionName = project.name
        }
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        }
        return project
    }

    func listSessions() async throws -> [OpenAPI.Session] {
        sessions
    }

    func listPanes(sessionName: String) async throws -> [OpenAPI.Pane] {
        panesBySession[sessionName] ?? []
    }

    func getPaneOutput(sessionName: String, paneID: Int) async throws -> OpenAPI.PaneOutput {
        outputsByPane["\(sessionName):\(paneID)"] ?? OpenAPI.PaneOutput(
            sessionName: sessionName,
            paneIndex: paneID,
            content: ""
        )
    }

    func sendPaneInput(sessionName: String, paneID: Int, body: OpenAPI.SendInputRequest) async throws -> OpenAPI.StatusResponse {
        sentInputs.append(SentInput(sessionName: sessionName, paneID: paneID, body: body))
        let key = "\(sessionName):\(paneID)"
        var output = outputsByPane[key] ?? OpenAPI.PaneOutput(sessionName: sessionName, paneIndex: paneID, content: "")
        output.content += transcriptLine(for: body)
        outputsByPane[key] = output
        return OpenAPI.StatusResponse(status: "sent")
    }

    private func transcriptLine(for body: OpenAPI.SendInputRequest) -> String {
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

    private static func decode<T: Decodable>(_ type: T.Type, from json: String) -> T {
        do {
            return try JSONDecoder.openAPI.decode(T.self, from: Data(json.utf8))
        } catch {
            fatalError("Invalid OpenAPI mock fixture: \(error)")
        }
    }
}

struct SentInput: Hashable {
    let sessionName: String
    let paneID: Int
    let body: OpenAPI.SendInputRequest
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
        "tmux_session_name": "tmux_server_coding_app",
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
        "tmux_session_name": null,
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
        "title": "Session stream and pane input",
        "description_doc_key": "features/service-0031/description.md",
        "status": "in_progress",
        "created_at": "2026-04-29T14:00:00Z",
        "merged_at": null
      },
      {
        "id": 12,
        "project_id": 1,
        "branch_name": "docs-0032",
        "title": "Mobile client planning",
        "description_doc_key": "features/docs-0032/description.md",
        "status": "in_progress",
        "created_at": "2026-04-30T02:00:00Z",
        "merged_at": null
      },
      {
        "id": 21,
        "project_id": 2,
        "branch_name": "service-0001",
        "title": "Project hierarchy prototype",
        "description_doc_key": "features/service-0001/description.md",
        "status": "in_progress",
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
      }
    ]
    """

    static let panesJSON = """
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

    static let paneOutputJSON = """
    {
      "session_name": "tmux_server_coding_app",
      "pane_index": 0,
      "content": "$ go test ./...\\nok  github.com/nickbuser/tmux-agent/internal/store/sqlite  0.412s\\n?   github.com/nickbuser/tmux-agent/cmd  [no test files]\\n\\nContinue with generated client wiring? [y/N] "
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

