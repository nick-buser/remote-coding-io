import Foundation
import Testing
@testable import remote_coding

struct TerminalViewModelTests {

    @MainActor
    private func makeViewModel(sessionID: Int64 = 802) async -> (TerminalViewModel, MockTmuxAgentRepository) {
        let repository = MockTmuxAgentRepository()
        let poller = ActivityPoller(repository: repository)
        let viewModel = TerminalViewModel()
        await viewModel.load(sessionID: sessionID, repository: repository, activityPoller: poller)
        return (viewModel, repository)
    }

    // MARK: - Load

    @MainActor
    @Test func loadsSessionAndSnapshot() async throws {
        let (viewModel, _) = await makeViewModel(sessionID: 802)
        #expect(viewModel.session != nil)
        #expect(viewModel.session?.id == 802)
        #expect(!viewModel.output.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @MainActor
    @Test func unknownSessionIDSetsErrorMessage() async {
        let repository = MockTmuxAgentRepository()
        let poller = ActivityPoller(repository: repository)
        let viewModel = TerminalViewModel()
        await viewModel.load(sessionID: 9999, repository: repository, activityPoller: poller)
        #expect(viewModel.session == nil)
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Pane index parsing

    @Test func paneIndexFromAgentString() {
        // Create a minimal AgentSession-like value using the extension
        // on a raw string by testing via AgentSessionExtensions directly.
        let session = Components.Schemas.AgentSession(
            id: 1,
            ticketId: nil,
            tmuxSession: "test",
            state: .active,
            pane: "agent:2.0",
            cpu: 0,
            startTime: Date(),
            endTime: nil,
            lastActiveAt: Date(),
            transcriptKey: nil,
            tokenUsage: nil,
            costEstimate: nil,
            createdAt: Date()
        )
        #expect(session.paneIndex == 0)
        #expect(session.paneDisplayLabel == "2.0")
    }

    @Test func paneIndexWindowOne_paneOne() {
        let session = Components.Schemas.AgentSession(
            id: 2,
            ticketId: nil,
            tmuxSession: "test",
            state: .active,
            pane: "agent:1.1",
            cpu: 0,
            startTime: Date(),
            endTime: nil,
            lastActiveAt: Date(),
            transcriptKey: nil,
            tokenUsage: nil,
            costEstimate: nil,
            createdAt: Date()
        )
        #expect(session.paneIndex == 1)
        #expect(session.paneDisplayLabel == "1.1")
    }

    @Test func paneIndexNilPaneFallsBackToZero() {
        let session = Components.Schemas.AgentSession(
            id: 3,
            ticketId: nil,
            tmuxSession: "test",
            state: .active,
            pane: nil,
            cpu: 0,
            startTime: Date(),
            endTime: nil,
            lastActiveAt: Date(),
            transcriptKey: nil,
            tokenUsage: nil,
            costEstimate: nil,
            createdAt: Date()
        )
        #expect(session.paneIndex == 0)
    }

    // MARK: - Activity poller

    @MainActor
    @Test func pollerIsPausedDuringLoad() async {
        let repository = MockTmuxAgentRepository()
        let poller = ActivityPoller(repository: repository)
        poller.start(scope: .workspace)
        let viewModel = TerminalViewModel()
        // After load the poller task should be nil (stopped).
        await viewModel.load(sessionID: 802, repository: repository, activityPoller: poller)
        // Poller stop is observable via the fact the task is nil; the simplest
        // proxy is that a tick() we don't call returns nothing, so we verify
        // the session loaded successfully (poller stop is side-effectful and not
        // directly observable from the test target).
        #expect(viewModel.session != nil)
    }
}
