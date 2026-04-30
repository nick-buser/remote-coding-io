import Foundation

enum WorkspaceDocumentKind: String, CaseIterable, Identifiable {
    case projectBrief
    case projectNotes
    case featureDescription
    case promptBuildout
    case acceptanceCriteria

    var id: String { rawValue }

    var title: String {
        switch self {
        case .projectBrief: "Project brief"
        case .projectNotes: "Project notes"
        case .featureDescription: "Description"
        case .promptBuildout: "Prompt buildout"
        case .acceptanceCriteria: "Acceptance criteria"
        }
    }

    var systemImage: String {
        switch self {
        case .projectBrief: "doc.text"
        case .projectNotes: "note.text"
        case .featureDescription: "text.page"
        case .promptBuildout: "text.bubble"
        case .acceptanceCriteria: "checklist"
        }
    }
}

enum WorkspaceDocumentOwner: Hashable {
    case project(Int64)
    case feature(Int64)
}

struct WorkspaceDocument: Identifiable, Hashable {
    let id: String
    var owner: WorkspaceDocumentOwner
    var kind: WorkspaceDocumentKind
    var title: String
    var body: String
    var updatedAt: Date
}

