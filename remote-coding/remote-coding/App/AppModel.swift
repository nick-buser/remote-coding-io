import Foundation
import Observation

/// Top-level destinations in the v2 5-tab shell.
///
/// Order matters: the bottom bar renders left-to-right in this order.
/// `inbox` is the default landing tab for new installs.
enum AppTab: String, Hashable, Codable, CaseIterable {
    case inbox
    case projects
    case roadmap
    case sessions
    case you
}

@Observable
final class AppModel {
    @ObservationIgnored var repository: TmuxAgentRepository

    /// Drives the small accent dot on the Inbox tab.
    /// Real wiring lands with `service-repo-activity`; for now it
    /// defaults to `true` so the indicator is visible during the
    /// placeholder shell phase.
    var needsYou: Bool = true
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

/// Bundle of routing context for the terminal surface — the project,
/// optional feature, raw tmux session, and pane the surface is bound to.
///
/// Kept in-tree even though the tab shell no longer drives the terminal
/// directly: `service-app-route-coordinator` reuses it as the payload of
/// the `agentSession` route, and the terminal shell ticket consumes it
/// from there.
struct TerminalContext: Identifiable, Hashable {
    var id: String {
        "\(project.id)-\(feature?.id ?? 0)-\(session.name)-\(pane.index)"
    }

    let project: Components.Schemas.Project
    let feature: Components.Schemas.Feature?
    let session: Components.Schemas.Session
    let pane: Components.Schemas.Pane
}
