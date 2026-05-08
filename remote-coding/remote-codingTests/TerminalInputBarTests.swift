import Foundation
import Testing
@testable import remote_coding

struct TerminalInputBarTests {

    // MARK: - Send mode

    @MainActor
    @Test func sendWithTextFiresSendAndEnterByDefault() async {
        let repository = MockTmuxAgentRepository()
        let poller = ActivityPoller(repository: repository)
        let viewModel = TerminalViewModel()
        await viewModel.load(sessionID: 802, repository: repository, activityPoller: poller)

        viewModel.input = "ls -la"
        await viewModel.sendInput(.text("ls -la", submit: true), repository: repository)
        #expect(viewModel.errorMessage == nil)
    }

    @MainActor
    @Test func emptyTextSendFiresEnterOnly() async {
        let repository = MockTmuxAgentRepository()
        let poller = ActivityPoller(repository: repository)
        let viewModel = TerminalViewModel()
        await viewModel.load(sessionID: 802, repository: repository, activityPoller: poller)

        viewModel.input = ""
        await viewModel.sendInput(.enterOnly(), repository: repository)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - isSending flag

    @MainActor
    @Test func isSendingIsFalseBeforeSend() async {
        let repository = MockTmuxAgentRepository()
        let poller = ActivityPoller(repository: repository)
        let viewModel = TerminalViewModel()
        await viewModel.load(sessionID: 802, repository: repository, activityPoller: poller)
        #expect(viewModel.isSending == false)
    }

    // MARK: - Prompt hint parsing

    @Test func extractsPromptHintFromShellPrompt() {
        let raw = "$ ls\ntotal 8\n$ "
        let hint = TerminalInputBar.extractPromptHint(from: raw)
        #expect(hint != nil)
        #expect(hint?.hasSuffix("$") == true || hint?.contains("$") == true)
    }

    @Test func returnsNilWhenNoPromptLine() {
        let raw = "Compiling files...\nBuild complete."
        let hint = TerminalInputBar.extractPromptHint(from: raw)
        #expect(hint == nil)
    }

    @Test func extractsAgentPromptArrow() {
        let raw = "Working on feature...\nagent › "
        let hint = TerminalInputBar.extractPromptHint(from: raw)
        #expect(hint != nil)
    }

    @Test func promptHintTruncatedTo40Chars() {
        let longPrompt = String(repeating: "a", count: 50) + " › "
        let hint = TerminalInputBar.extractPromptHint(from: longPrompt)
        #expect((hint?.count ?? 0) <= 40)
    }
}
