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

    init(apiConfiguration: APIConfiguration = APIConfigurationStore.load()) {
        self.apiConfiguration = apiConfiguration
        repository = LiveTmuxAgentRepository(client: APIClient(configuration: apiConfiguration))
        isUsingMockRepository = false
    }

    init(repository: TmuxAgentRepository, apiConfiguration: APIConfiguration = APIConfigurationStore.load()) {
        self.apiConfiguration = apiConfiguration
        self.repository = repository
        isUsingMockRepository = true
    }

    func openTerminal(project: OpenAPI.Project, feature: OpenAPI.Feature?, session: OpenAPI.Session, pane: OpenAPI.Pane) {
        terminalContext = TerminalContext(project: project, feature: feature, session: session, pane: pane)
        selectedTab = .terminal
    }

    func updateAPIBaseURL(_ rawValue: String) throws {
        let configuration = try APIConfiguration(baseURLString: rawValue)
        APIConfigurationStore.save(configuration)
        apiConfiguration = configuration
        repository = LiveTmuxAgentRepository(client: APIClient(configuration: configuration))
        isUsingMockRepository = false
    }

    func resetAPIBaseURL() {
        let configuration = APIConfiguration.default
        APIConfigurationStore.save(configuration)
        apiConfiguration = configuration
        repository = LiveTmuxAgentRepository(client: APIClient(configuration: configuration))
        isUsingMockRepository = false
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
