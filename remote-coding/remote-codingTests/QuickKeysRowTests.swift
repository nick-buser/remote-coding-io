import Foundation
import Testing
@testable import remote_coding

struct QuickKeysRowTests {

    // MARK: - Wire key mapping

    @Test func escMapsToEscape() {
        let spec = QuickKeysRow.primaryKeys.first { $0.label == "esc" }
        #expect(spec?.wireKey == "Escape")
    }

    @Test func tabMapsToTab() {
        let spec = QuickKeysRow.primaryKeys.first { $0.label == "tab" }
        #expect(spec?.wireKey == "Tab")
    }

    @Test func controlCMapsToCC() {
        let spec = QuickKeysRow.primaryKeys.first { $0.label == "⌃C" }
        #expect(spec?.wireKey == "C-c")
    }

    @Test func controlDMapsToCD() {
        let spec = QuickKeysRow.primaryKeys.first { $0.label == "⌃D" }
        #expect(spec?.wireKey == "C-d")
    }

    @Test func enterMapsToEnter() {
        let spec = QuickKeysRow.primaryKeys.first { $0.label == "⏎" }
        #expect(spec?.wireKey == "Enter")
    }

    @Test func arrowsMapped() {
        let labels = QuickKeysRow.primaryKeys.map(\.label)
        #expect(labels.contains("↑"))
        #expect(labels.contains("↓"))
        #expect(labels.contains("←"))
        #expect(labels.contains("→"))
        let upSpec = QuickKeysRow.primaryKeys.first { $0.label == "↑" }
        #expect(upSpec?.wireKey == "Up")
        let downSpec = QuickKeysRow.primaryKeys.first { $0.label == "↓" }
        #expect(downSpec?.wireKey == "Down")
    }

    // MARK: - Empty Enter fires without text

    @MainActor
    @Test func enterKeyFiresWithoutInputText() async {
        let repository = MockTmuxAgentRepository()
        let poller = ActivityPoller(repository: repository)
        let viewModel = TerminalViewModel()
        await viewModel.load(sessionID: 802, repository: repository, activityPoller: poller)
        // input is empty; sending the Enter key should still reach the repo
        viewModel.input = ""
        await viewModel.sendInput(.key("Enter"), repository: repository)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Extra keys present

    @Test func extraKeysBSpacePresent() {
        let spec = QuickKeysRow.extraKeys.first { $0.label == "⌫" }
        #expect(spec?.wireKey == "BSpace")
    }
}
