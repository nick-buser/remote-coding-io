import Foundation

// Project-level brief / notes the contract does not yet expose. The
// previous `WorkspaceDocument` type also covered feature-level docs;
// those are now driven by `Components.Schemas.Doc`. Once the backend
// adds project-level doc endpoints this stopgap is replaced by the
// contract type.
enum LocalProjectNoteKind: String, CaseIterable, Identifiable, Codable {
    case projectBrief
    case projectNotes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .projectBrief: "Project brief"
        case .projectNotes: "Project notes"
        }
    }

    var systemImage: String {
        switch self {
        case .projectBrief: "doc.text"
        case .projectNotes: "note.text"
        }
    }
}

struct LocalProjectNote: Identifiable, Hashable, Codable {
    let id: String
    var projectID: Int64
    var kind: LocalProjectNoteKind
    var title: String
    var body: String
    var updatedAt: Date
}
