import Foundation
import Observation

enum AppTab: Hashable {
    case projects
    case terminal
}

@Observable
final class AppModel {
    @ObservationIgnored let repository: TmuxAgentRepository

    var selectedTab: AppTab = .projects
    var terminalContext: TerminalContext?

    init(repository: TmuxAgentRepository) {
        self.repository = repository
    }

    func openTerminal(project: OpenAPI.Project, feature: OpenAPI.Feature?, session: OpenAPI.Session, pane: OpenAPI.Pane) {
        terminalContext = TerminalContext(project: project, feature: feature, session: session, pane: pane)
        selectedTab = .terminal
    }
}

struct TerminalContext: Identifiable, Hashable {
    var id: String {
        "\(project.id)-\(feature?.id ?? 0)-\(session.name)-\(pane.index)"
    }

    let project: OpenAPI.Project
    let feature: OpenAPI.Feature?
    let session: OpenAPI.Session
    let pane: OpenAPI.Pane
}

