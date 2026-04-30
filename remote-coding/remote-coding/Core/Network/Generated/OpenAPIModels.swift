import Foundation

// Generated from ../../api/openapi.yaml for the prototype target.
// Keep this file aligned with the OpenAPI schema and replace it with
// Swift OpenAPI Generator output once the package plugin is wired in.
enum OpenAPI {
    enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
        case active
        case maintenance
        case paused

        var id: String { rawValue }
    }

    enum FeatureStatus: String, Codable, CaseIterable, Identifiable {
        case inProgress = "in_progress"
        case merged
        case abandoned

        var id: String { rawValue }
    }

    struct HealthResponse: Codable, Hashable {
        let status: String
        let tmux: TmuxStatus

        struct TmuxStatus: Codable, Hashable {
            let available: Bool
            let running: Bool
        }
    }

    struct Project: Codable, Identifiable, Hashable {
        let id: Int64
        var name: String
        var slug: String
        var gitRepoURL: String?
        var localRepoPath: String
        var tmuxSessionName: String?
        var tagline: String?
        var description: String?
        var accent: String?
        var icon: String?
        var status: ProjectStatus
        var pinned: Bool
        var lastTouchedAt: Date
        var createdAt: Date
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case slug
            case gitRepoURL = "git_repo_url"
            case localRepoPath = "local_repo_path"
            case tmuxSessionName = "tmux_session_name"
            case tagline
            case description
            case accent
            case icon
            case status
            case pinned
            case lastTouchedAt = "last_touched_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    struct CreateProjectRequest: Codable, Hashable {
        var name: String
        var slug: String?
        var gitRepoURL: String?
        var localRepoPath: String
        var tmuxSessionName: String?
        var tagline: String?
        var description: String?
        var accent: String?
        var icon: String?
        var status: ProjectStatus?
        var pinned: Bool?

        enum CodingKeys: String, CodingKey {
            case name
            case slug
            case gitRepoURL = "git_repo_url"
            case localRepoPath = "local_repo_path"
            case tmuxSessionName = "tmux_session_name"
            case tagline
            case description
            case accent
            case icon
            case status
            case pinned
        }
    }

    typealias UpdateProjectRequest = CreateProjectRequest

    struct Feature: Codable, Identifiable, Hashable {
        let id: Int64
        let projectID: Int64
        var branchName: String
        var title: String
        var descriptionDocKey: String?
        var status: FeatureStatus
        var createdAt: Date
        var mergedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id
            case projectID = "project_id"
            case branchName = "branch_name"
            case title
            case descriptionDocKey = "description_doc_key"
            case status
            case createdAt = "created_at"
            case mergedAt = "merged_at"
        }
    }

    struct CreateFeatureRequest: Codable, Hashable {
        var branchName: String
        var title: String
        var descriptionDocKey: String?

        enum CodingKeys: String, CodingKey {
            case branchName = "branch_name"
            case title
            case descriptionDocKey = "description_doc_key"
        }
    }

    struct UpdateFeatureStatusRequest: Codable, Hashable {
        var status: FeatureStatus
    }

    struct Session: Codable, Identifiable, Hashable {
        var id: String { name }

        let name: String
        let attached: Bool
        let created: Date
        let windows: Int
        let directory: String
    }

    struct Pane: Codable, Identifiable, Hashable {
        var id: Int { index }

        let index: Int
        let title: String
        let width: Int
        let height: Int
        let active: Bool
        let directory: String
    }

    struct PaneOutput: Codable, Hashable {
        let sessionName: String
        let paneIndex: Int
        var content: String

        enum CodingKeys: String, CodingKey {
            case sessionName = "session_name"
            case paneIndex = "pane_index"
            case content
        }
    }

    struct CreateSessionRequest: Codable, Hashable {
        var name: String
        var startDir: String?

        enum CodingKeys: String, CodingKey {
            case name
            case startDir = "start_dir"
        }
    }

    struct SendInputRequest: Codable, Hashable {
        var text: String?
        var keys: [String]?
        var enter: Bool?

        static func text(_ value: String, submit: Bool) -> SendInputRequest {
            SendInputRequest(text: value, keys: nil, enter: submit)
        }

        static func key(_ value: String) -> SendInputRequest {
            SendInputRequest(text: nil, keys: [value], enter: nil)
        }

        static func enterOnly() -> SendInputRequest {
            SendInputRequest(text: nil, keys: ["Enter"], enter: nil)
        }
    }

    struct SessionCreatedResponse: Codable, Hashable {
        let name: String
        let status: String
    }

    struct StatusResponse: Codable, Hashable {
        let status: String
    }

    struct PaneStreamMessage: Codable, Hashable {
        var content: String
        var timestamp: Date
    }

    struct PaneResizeRequest: Codable, Hashable {
        var resize: Size?

        struct Size: Codable, Hashable {
            var cols: Int
            var rows: Int
        }
    }

    struct ProblemDetails: Codable, Hashable {
        let type: String
        let title: String
        let status: Int
        let detail: String?
        let instance: String?
        let requestID: String?
        let errors: [FieldError]?

        enum CodingKeys: String, CodingKey {
            case type
            case title
            case status
            case detail
            case instance
            case requestID = "request_id"
            case errors
        }
    }

    struct FieldError: Codable, Hashable {
        let field: String
        let code: String
        let message: String
    }
}

extension JSONDecoder {
    static var openAPI: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var openAPI: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

