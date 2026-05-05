import Foundation

// SwiftUI requires Identifiable for List/ForEach without an explicit id key
// path. The generated Components.Schemas types are Codable, Hashable, Sendable
// but the generator does not emit Identifiable conformance — add it here for
// the schemas the UI iterates over.

extension Components.Schemas.Project: Identifiable {}
extension Components.Schemas.Feature: Identifiable {}

extension Components.Schemas.Session: Identifiable {
    internal var id: String { name }
}

extension Components.Schemas.Pane: Identifiable {
    internal var id: Int { index }
}
