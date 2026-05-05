import Foundation
import Observation

enum AppTab: Hashable {
    case projects
    case terminal
    case settings
}

@Observable
final class AppModel {
    @ObservationIgnored var repository: TmuxAgentRepository

    var selectedTab: AppTab = .projects
    var terminalContext: TerminalContext?
    var apiConfiguration: APIConfiguration
    var isUsingMockRepository: Bool
    /// User-selected accent. Persistence + UI for changing this lands
    /// with `service-you-screen`; for now the value is held in memory
    /// and propagates through `\.accent` so theme tokens and components
    /// can read it from any view.
    var accent: AccentColor = .iris

    init(apiConfiguration: APIConfiguration = APIConfigurationStore.load()) {
        self.apiConfiguration = apiConfiguration
        repository = LiveTmuxAgentRepository(configuration: apiConfiguration)
        isUsingMockRepository = false
    }

    init(repository: TmuxAgentRepository, apiConfiguration: APIConfiguration = APIConfigurationStore.load()) {
        self.apiConfiguration = apiConfiguration
        self.repository = repository
        isUsingMockRepository = true
    }

    func openTerminal(project: Components.Schemas.Project, feature: Components.Schemas.Feature?, session: Components.Schemas.Session, pane: Components.Schemas.Pane) {
        terminalContext = TerminalContext(project: project, feature: feature, session: session, pane: pane)
        selectedTab = .terminal
    }

    func updateAPIBaseURL(_ rawValue: String) throws {
        let configuration = try APIConfiguration(baseURLString: rawValue)
        APIConfigurationStore.save(configuration)
        apiConfiguration = configuration
        repository = LiveTmuxAgentRepository(configuration: configuration)
        isUsingMockRepository = false
    }

    func resetAPIBaseURL() {
        let configuration = APIConfiguration.default
        APIConfigurationStore.save(configuration)
        apiConfiguration = configuration
        repository = LiveTmuxAgentRepository(configuration: configuration)
        isUsingMockRepository = false
    }
}

struct TerminalContext: Identifiable, Hashable {
    var id: String {
        "\(project.id)-\(feature?.id ?? 0)-\(session.name)-\(pane.index)"
    }

    let project: Components.Schemas.Project
    let feature: Components.Schemas.Feature?
    let session: Components.Schemas.Session
    let pane: Components.Schemas.Pane
}
