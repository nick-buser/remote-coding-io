import Foundation
import Observation

@MainActor
@Observable
final class TerminalViewModel {
    var session: Components.Schemas.AgentSession?
    var siblingSessionIDs: [Int64] = []
    var siblingSessions: [Components.Schemas.AgentSession] = []
    /// Raw string buffer — kept alongside `renderedBuffer` so callers that
    /// don't yet use the renderer (tests, placeholder views) can read plain text.
    var output = ""
    /// Attributed buffer produced by the renderer. Views should prefer this
    /// over `output` once `service-terminal-renderer-boundary` lands.
    var renderedBuffer = AttributedString()
    var input = ""
    var isLoading = false
    var isSending = false
    var errorMessage: String?
    var showSpawnSheet = false

    private(set) var socketStatus: WebSocketStatus = .disconnected(nil)

    @ObservationIgnored let renderer: any PaneTextRenderer
    @ObservationIgnored private var socketClient: WebSocketClient?
    @ObservationIgnored private var streamTask: Task<Void, Never>?

    init(renderer: any PaneTextRenderer = ANSIPaneTextRenderer()) {
        self.renderer = renderer
    }

    func load(
        sessionID: Int64,
        repository: TmuxAgentRepository,
        activityPoller: ActivityPoller,
        apiConfiguration: APIConfiguration? = nil
    ) async {
        guard session == nil else { return }
        isLoading = true
        errorMessage = nil
        activityPoller.stop()
        do {
            let s = try await repository.getAgentSession(id: sessionID)
            session = s
            let snapshot = try await repository.getPaneOutput(
                sessionName: s.tmuxSession,
                paneID: s.paneIndex
            )
            setBuffer(snapshot.content)
            if let config = apiConfiguration {
                openSocket(session: s, configuration: config)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // Loads sibling sessions from the same project by iterating projects until
    // the current session is found. Called once after the session resolves.
    func loadSiblings(repository: TmuxAgentRepository) async {
        guard let current = session else { return }
        do {
            let projects = try await repository.listProjects()
            for project in projects {
                let sessions = try await repository.listProjectAgentSessions(
                    projectIDOrSlug: String(project.id)
                )
                guard sessions.contains(where: { $0.id == current.id }) else { continue }
                // Active session first, then by lastActiveAt desc.
                siblingSessions = sessions.sorted { lhs, rhs in
                    if lhs.id == current.id { return true }
                    if rhs.id == current.id { return false }
                    return lhs.lastActiveAt > rhs.lastActiveAt
                }
                return
            }
        } catch { }
    }

    func switchSession(
        to target: Components.Schemas.AgentSession,
        repository: TmuxAgentRepository,
        apiConfiguration: APIConfiguration? = nil
    ) async {
        closeSocket()
        session = target
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await repository.getPaneOutput(
                sessionName: target.tmuxSession,
                paneID: target.paneIndex
            )
            setBuffer(snapshot.content)
            if let config = apiConfiguration {
                openSocket(session: target, configuration: config)
            }
        } catch {
            errorMessage = "Couldn't reach pane."
        }
        isLoading = false
    }

    func closeSocket() {
        streamTask?.cancel()
        streamTask = nil
        socketClient?.disconnect()
        socketClient = nil
        socketStatus = .disconnected(nil)
    }

    func reload(repository: TmuxAgentRepository) async {
        guard let s = session else { return }
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await repository.getPaneOutput(
                sessionName: s.tmuxSession,
                paneID: s.paneIndex
            )
            setBuffer(snapshot.content)
        } catch {
            errorMessage = "Couldn't reach pane."
        }
        isLoading = false
    }

    func sendInput(_ request: Components.Schemas.SendInputRequest, repository: TmuxAgentRepository) async {
        guard let s = session else { return }
        isSending = true
        errorMessage = nil
        do {
            _ = try await repository.sendPaneInput(
                sessionName: s.tmuxSession,
                paneID: s.paneIndex,
                body: request
            )
            let snapshot = try await repository.getPaneOutput(
                sessionName: s.tmuxSession,
                paneID: s.paneIndex
            )
            setBuffer(snapshot.content)
        } catch {
            errorMessage = "Unable to send input."
        }
        isSending = false
    }

    func sendResize(cols: Int, rows: Int) async {
        try? await socketClient?.sendResize(cols: cols, rows: rows)
    }

    // MARK: - Private

    private func openSocket(session s: Components.Schemas.AgentSession, configuration: APIConfiguration) {
        let client = WebSocketClient(
            configuration: configuration,
            sessionName: s.tmuxSession,
            paneID: s.paneIndex
        )
        socketClient = client
        streamTask = Task { [weak self] in
            guard let self else { return }
            await client.connect()
            for await message in client.messages {
                guard !Task.isCancelled else { break }
                self.socketStatus = client.status
                self.setBuffer(message.content)
            }
        }
    }

    private func setBuffer(_ raw: String) {
        output = raw
        renderedBuffer = renderer.render(raw)
    }
}

extension Components.Schemas.SendInputRequest {
    static func text(_ value: String, submit: Bool) -> Self {
        Self(text: value, keys: nil, enter: submit)
    }

    static func key(_ value: String) -> Self {
        Self(text: nil, keys: [value], enter: nil)
    }

    static func enterOnly() -> Self {
        Self(text: nil, keys: ["Enter"], enter: nil)
    }
}
