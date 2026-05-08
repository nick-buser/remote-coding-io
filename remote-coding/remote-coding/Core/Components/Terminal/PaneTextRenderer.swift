import Foundation
import SwiftUI

/// Boundary between raw pane string content and the attributed string
/// consumed by the terminal buffer view. Implementations can be swapped
/// without touching the view: PlainPaneTextRenderer (default), a future
/// ANSIPaneTextRenderer, or a test fake.
protocol PaneTextRenderer {
    /// Convert a full raw pane snapshot to a displayable AttributedString.
    func render(_ raw: String) -> AttributedString
    /// Append a new chunk onto an existing attributed buffer. Used by the
    /// WebSocket tick when incremental updates become available; for now
    /// callers treat each message as a full replacement and call render(_:).
    func append(_ chunk: String, to existing: AttributedString) -> AttributedString
}

// MARK: - Default implementation

/// Plain monospaced renderer — no colour, no parsing. The buffer view applies
/// foreground tint via `.foregroundStyle(Theme.Text.fg(.dark))`. ANSI parsing
/// lands in a future ANSIPaneTextRenderer via the same boundary.
struct PlainPaneTextRenderer: PaneTextRenderer {
    func render(_ raw: String) -> AttributedString {
        var attributed = AttributedString(raw)
        attributed.font = .init(.system(size: 13, design: .monospaced))
        return attributed
    }

    func append(_ chunk: String, to existing: AttributedString) -> AttributedString {
        existing + render(chunk)
    }
}
