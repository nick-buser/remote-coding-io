import Foundation
import Testing
@testable import remote_coding

struct PaneTextRendererTests {
    private let renderer = PlainPaneTextRenderer()

    @Test func renderProducesAttributedStringWithContent() {
        let result = renderer.render("hello\nworld")
        #expect(String(result.characters) == "hello\nworld")
    }

    @Test func renderTwoLinesPreservesNewline() {
        let result = renderer.render("hello\nworld")
        #expect(result.characters.contains("\n"))
    }

    @Test func renderEmptyStringProducesEmpty() {
        let result = renderer.render("")
        #expect(result.characters.isEmpty)
    }

    @Test func appendConcatenatesChunk() {
        let base = renderer.render("hello")
        let result = renderer.append("\nworld", to: base)
        #expect(String(result.characters) == "hello\nworld")
    }

    @Test func appendPreservesExistingContent() {
        let base = renderer.render("line1\n")
        let result = renderer.append("line2", to: base)
        #expect(String(result.characters).hasPrefix("line1"))
        #expect(String(result.characters).hasSuffix("line2"))
    }

    // MARK: - DI

    @MainActor
    @Test func viewModelAcceptsInjectedRenderer() async {
        let fakeRenderer = FakePaneTextRenderer()
        let viewModel = TerminalViewModel(renderer: fakeRenderer)
        #expect(viewModel.renderedBuffer.characters.isEmpty)
        _ = fakeRenderer.callCount // baseline: 0 before load
    }
}

// Minimal fake for injection tests
final class FakePaneTextRenderer: PaneTextRenderer {
    var callCount = 0

    func render(_ raw: String) -> AttributedString {
        callCount += 1
        return AttributedString(raw)
    }

    func append(_ chunk: String, to existing: AttributedString) -> AttributedString {
        callCount += 1
        return existing + AttributedString(chunk)
    }
}
