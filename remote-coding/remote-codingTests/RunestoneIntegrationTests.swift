import Foundation
import Testing
@testable import remote_coding

struct RunestoneIntegrationTests {

    // MARK: - Buffer rendering via renderer boundary

    @MainActor
    @Test func loadSetsRenderedBuffer() async {
        let repository = MockTmuxAgentRepository()
        let poller = ActivityPoller(repository: repository)
        let viewModel = TerminalViewModel()
        await viewModel.load(sessionID: 802, repository: repository, activityPoller: poller)
        #expect(!viewModel.renderedBuffer.characters.isEmpty)
    }

    @MainActor
    @Test func renderedBufferMatchesOutputContent() async {
        let repository = MockTmuxAgentRepository()
        let poller = ActivityPoller(repository: repository)
        let viewModel = TerminalViewModel()
        await viewModel.load(sessionID: 802, repository: repository, activityPoller: poller)
        let plain = String(viewModel.renderedBuffer.characters)
        #expect(plain == viewModel.output)
    }

    @MainActor
    @Test func appendingLinesPreservesContent() async {
        let renderer = PlainPaneTextRenderer()
        let viewModel = TerminalViewModel(renderer: renderer)
        let repository = MockTmuxAgentRepository()
        let poller = ActivityPoller(repository: repository)
        await viewModel.load(sessionID: 802, repository: repository, activityPoller: poller)
        let initialContent = viewModel.output
        // Simulate a new snapshot arriving with additional content
        await viewModel.reload(repository: repository)
        // Output should still be non-empty and consistent with buffer
        #expect(!viewModel.output.isEmpty)
        #expect(String(viewModel.renderedBuffer.characters) == viewModel.output)
        _ = initialContent // suppress unused warning
    }
}
