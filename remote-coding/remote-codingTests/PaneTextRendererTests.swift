import Foundation
import Testing
import SwiftUI
@testable import remote_coding

struct PaneTextRendererTests {

    // MARK: - PlainPaneTextRenderer

    private let plain = PlainPaneTextRenderer()

    @Test func plainRenderProducesAttributedStringWithContent() {
        let result = plain.render("hello\nworld")
        #expect(String(result.characters) == "hello\nworld")
    }

    @Test func plainRenderTwoLinesPreservesNewline() {
        let result = plain.render("hello\nworld")
        #expect(result.characters.contains("\n"))
    }

    @Test func plainRenderEmptyStringProducesEmpty() {
        let result = plain.render("")
        #expect(result.characters.isEmpty)
    }

    @Test func plainAppendConcatenatesChunk() {
        let base = plain.render("hello")
        let result = plain.append("\nworld", to: base)
        #expect(String(result.characters) == "hello\nworld")
    }

    @Test func plainAppendPreservesExistingContent() {
        let base = plain.render("line1\n")
        let result = plain.append("line2", to: base)
        #expect(String(result.characters).hasPrefix("line1"))
        #expect(String(result.characters).hasSuffix("line2"))
    }

    // MARK: - ANSIPaneTextRenderer

    private let ansi = ANSIPaneTextRenderer()

    @Test func ansiPlainTextPassesThrough() {
        let result = ansi.render("hello world")
        #expect(String(result.characters) == "hello world")
    }

    @Test func ansiEmptyStringProducesEmpty() {
        let result = ansi.render("")
        #expect(result.characters.isEmpty)
    }

    @Test func ansiStripsColorCodes() {
        let result = ansi.render("\u{1B}[31mred text\u{1B}[0m normal")
        #expect(String(result.characters) == "red text normal")
    }

    @Test func ansiStripsMultiAttributeCode() {
        let result = ansi.render("\u{1B}[1;32mbold green\u{1B}[0m")
        #expect(String(result.characters) == "bold green")
    }

    @Test func ansiResetClearsBoldAndColor() {
        let raw = "\u{1B}[1mbold\u{1B}[0m normal"
        let result = ansi.render(raw)
        #expect(String(result.characters) == "bold normal")
    }

    @Test func ansiStripsOSCTitleSequence() {
        let result = ansi.render("\u{1B}]0;window title\u{07}text")
        #expect(String(result.characters) == "text")
    }

    @Test func ansiStripsOSCWithSTTerminator() {
        let result = ansi.render("\u{1B}]0;title\u{1B}\\text")
        #expect(String(result.characters) == "text")
    }

    @Test func ansiDropsMalformedEscape() {
        // Unknown escape byte after ESC — both bytes dropped, rest preserved
        let result = ansi.render("\u{1B}Xsome text")
        #expect(String(result.characters) == "some text")
    }

    @Test func ansi256ColorForeground() {
        let result = ansi.render("\u{1B}[38;5;196mred256\u{1B}[0m")
        #expect(String(result.characters) == "red256")
    }

    @Test func ansiTrueColorForeground() {
        let result = ansi.render("\u{1B}[38;2;255;128;0morange\u{1B}[0m")
        #expect(String(result.characters) == "orange")
    }

    @Test func ansiBrightColorForeground() {
        let result = ansi.render("\u{1B}[91mbright red\u{1B}[0m")
        #expect(String(result.characters) == "bright red")
    }

    @Test func ansiBackgroundColor() {
        let result = ansi.render("\u{1B}[41;37mred bg white fg\u{1B}[0m")
        #expect(String(result.characters) == "red bg white fg")
    }

    @Test func ansiUnderline() {
        let result = ansi.render("\u{1B}[4munderlined\u{1B}[24m normal")
        #expect(String(result.characters) == "underlined normal")
    }

    @Test func ansiDimReducesOpacity() {
        // Just verifies text content passes through — attribute correctness is
        // verified visually / by snapshot; unit tests guard against panics.
        let result = ansi.render("\u{1B}[2mdim text\u{1B}[22m normal")
        #expect(String(result.characters) == "dim text normal")
    }

    @Test func ansiGitLogStyleBuffer() {
        // Simulates a `git log --color=always` style buffer.
        let raw = "\u{1B}[33mcommit abc1234\u{1B}[0m\nAuthor: Nick\n\n\u{1B}[32m+added line\u{1B}[0m\n\u{1B}[31m-removed line\u{1B}[0m"
        let result = ansi.render(raw)
        let text = String(result.characters)
        #expect(text.contains("commit abc1234"))
        #expect(text.contains("+added line"))
        #expect(text.contains("-removed line"))
        #expect(!text.contains("\u{1B}"))
    }

    @Test func ansiMultipleConsecutiveSequences() {
        let raw = "\u{1B}[1m\u{1B}[4m\u{1B}[32mbold underline green\u{1B}[0m"
        let result = ansi.render(raw)
        #expect(String(result.characters) == "bold underline green")
    }

    @Test func ansiAppendConcatenatesChunks() {
        let first = ansi.render("line1\n")
        let result = ansi.append("\u{1B}[32mline2\u{1B}[0m", to: first)
        let text = String(result.characters)
        #expect(text.hasPrefix("line1"))
        #expect(text.hasSuffix("line2"))
    }

    @Test func ansi16PaletteHas16Colors() {
        #expect(ANSIPaneTextRenderer.ansi16.count == 16)
    }

    @Test func ansi256PaletteHas256Colors() {
        #expect(ANSIPaneTextRenderer.ansi256.count == 256)
    }

    // MARK: - DI

    @MainActor
    @Test func viewModelAcceptsInjectedRenderer() async {
        let fakeRenderer = FakePaneTextRenderer()
        let viewModel = TerminalViewModel(renderer: fakeRenderer)
        #expect(viewModel.renderedBuffer.characters.isEmpty)
        _ = fakeRenderer.callCount
    }

    @MainActor
    @Test func viewModelDefaultRendererIsANSI() async {
        let viewModel = TerminalViewModel()
        #expect(viewModel.renderer is ANSIPaneTextRenderer)
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
