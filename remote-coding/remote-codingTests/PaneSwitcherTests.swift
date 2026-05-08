import Foundation
import Testing
@testable import remote_coding

struct PaneSwitcherTests {

    @MainActor
    private func loadedViewModel(sessionID: Int64 = 802) async -> (TerminalViewModel, MockTmuxAgentRepository) {
        let repository = MockTmuxAgentRepository()
        let poller = ActivityPoller(repository: repository)
        let viewModel = TerminalViewModel()
        await viewModel.load(sessionID: sessionID, repository: repository, activityPoller: poller)
        await viewModel.loadSiblings(repository: repository)
        return (viewModel, repository)
    }

    // MARK: - Sibling loading

    @MainActor
    @Test func siblingsLoadedForSameProject() async throws {
        let (viewModel, _) = await loadedViewModel()
        // session-07 (id=802) shares a project with other seeded sessions
        #expect(!viewModel.siblingSessions.isEmpty)
    }

    @MainActor
    @Test func activeSessions​IsListedFirst() async throws {
        let (viewModel, _) = await loadedViewModel()
        guard let first = viewModel.siblingSessions.first else {
            return
        }
        // The loaded session should appear first
        #expect(first.id == viewModel.session?.id)
    }

    // MARK: - Switching

    @MainActor
    @Test func switchSessionReloadsBuffer() async throws {
        let (viewModel, repository) = await loadedViewModel()
        let initialSession = viewModel.session
        guard let sibling = viewModel.siblingSessions.first(where: { $0.id != initialSession?.id }) else {
            return
        }
        await viewModel.switchSession(to: sibling, repository: repository)
        #expect(viewModel.session?.id == sibling.id)
        // Buffer reload succeeds (no error)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Spawn sheet

    @MainActor
    @Test func spawnSheetStartsClosed() async throws {
        let (viewModel, _) = await loadedViewModel()
        #expect(viewModel.showSpawnSheet == false)
    }
}
