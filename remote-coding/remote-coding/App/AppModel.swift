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
@MainActor
final class AppModel {
    @ObservationIgnored var repository: TmuxAgentRepository

    /// Workspace-scoped activity feed. The Inbox dot derives from
    /// `activityPoller.needsYou`; per-screen pollers can be spawned
    /// alongside this one without conflict.
    var activityPoller: ActivityPoller

    /// Drives the small accent dot on the Inbox tab. Mirrors
    /// `activityPoller.needsYou` so views can keep reading
    /// `appModel.needsYou`.
    var needsYou: Bool { activityPoller.needsYou }
    var apiConfiguration: APIConfiguration
    var isUsingMockRepository: Bool
    /// User-selected accent. Persistence + UI for changing this lands
    /// with `service-you-screen`; for now the value is held in memory
    /// and propagates through `\.accent` so theme tokens and components
    /// can read it from any view.
    var accent: AccentColor = .iris

    init(apiConfiguration: APIConfiguration = APIConfigurationStore.load()) {
        self.apiConfiguration = apiConfiguration
        let repository = LiveTmuxAgentRepository(configuration: apiConfiguration)
        self.repository = repository
        self.activityPoller = ActivityPoller(repository: repository)
        isUsingMockRepository = false
    }

    init(repository: TmuxAgentRepository, apiConfiguration: APIConfiguration = APIConfigurationStore.load()) {
        self.apiConfiguration = apiConfiguration
        self.repository = repository
        self.activityPoller = ActivityPoller(repository: repository)
        isUsingMockRepository = true
    }

    func updateAPIBaseURL(_ rawValue: String) throws {
        let configuration = try APIConfiguration(baseURLString: rawValue)
        APIConfigurationStore.save(configuration)
        apiConfiguration = configuration
        let repository = LiveTmuxAgentRepository(configuration: configuration)
        self.repository = repository
        activityPoller.stop()
        activityPoller = ActivityPoller(repository: repository)
        isUsingMockRepository = false
    }

    func resetAPIBaseURL() {
        let configuration = APIConfiguration.default
        APIConfigurationStore.save(configuration)
        apiConfiguration = configuration
        let repository = LiveTmuxAgentRepository(configuration: configuration)
        self.repository = repository
        activityPoller.stop()
        activityPoller = ActivityPoller(repository: repository)
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
