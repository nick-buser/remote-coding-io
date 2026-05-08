import Foundation
import Observation

// MARK: - Status

enum WebSocketStatus: Equatable {
    case connecting
    case connected
    case disconnected(Error?)

    static func == (lhs: WebSocketStatus, rhs: WebSocketStatus) -> Bool {
        switch (lhs, rhs) {
        case (.connecting, .connecting):    return true
        case (.connected, .connected):      return true
        case (.disconnected, .disconnected): return true
        default: return false
        }
    }
}

// MARK: - Client

/// Observable WebSocket client for a single tmux pane stream.
///
/// Lifecycle:
/// - Call connect() to open; messages arrive on the messages AsyncStream.
/// - Call disconnect() on view disappear.
/// - The client reconnects with exponential backoff (1 2 4 8 … 30s) on drops.
/// - Backgrounded apps trigger disconnect; foreground triggers a REST snapshot
///   then reconnect (wired by TerminalViewModel via scene-phase observation).
@Observable
@MainActor
final class WebSocketClient {
    private(set) var status: WebSocketStatus = .disconnected(nil)

    private let configuration: APIConfiguration
    private let sessionName: String
    private let paneID: Int

    @ObservationIgnored private var task: URLSessionWebSocketTask?
    @ObservationIgnored private var receiveLoop: Task<Void, Never>?
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var backoffSeconds: Double = 1

    // Continuation that feeds the messages stream.
    @ObservationIgnored private var continuation: AsyncStream<Components.Schemas.PaneStreamMessage>.Continuation?
    private(set) var messages: AsyncStream<Components.Schemas.PaneStreamMessage>

    init(configuration: APIConfiguration, sessionName: String, paneID: Int) {
        self.configuration = configuration
        self.sessionName = sessionName
        self.paneID = paneID
        var continuation: AsyncStream<Components.Schemas.PaneStreamMessage>.Continuation?
        self.messages = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    // MARK: - Connect / disconnect

    func connect() async {
        guard status != .connected, status != .connecting else { return }
        status = .connecting
        openSocket()
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveLoop?.cancel()
        receiveLoop = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        status = .disconnected(nil)
        backoffSeconds = 1
    }

    // MARK: - Resize

    func sendResize(cols: Int, rows: Int) async throws {
        guard let task, status == .connected else { return }
        let payload = ResizeMessage(resize: .init(cols: cols, rows: rows))
        let data = try JSONEncoder().encode(payload)
        try await task.send(.data(data))
    }

    // MARK: - Private

    private func openSocket() {
        let url = webSocketURL()
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let session = URLSession(configuration: .default)
        let newTask = session.webSocketTask(with: request)
        self.task = newTask
        newTask.resume()
        // Log only the URL, never message bodies.
        if backoffSeconds <= 1 {
            print("[WebSocketClient] Connecting to \(url.absoluteString)")
        }
        startReceiveLoop(task: newTask)
    }

    private func startReceiveLoop(task: URLSessionWebSocketTask) {
        receiveLoop?.cancel()
        receiveLoop = Task { [weak self] in
            guard let self else { return }
            do {
                // First receive confirms the upgrade succeeded.
                let firstMessage = try await task.receive()
                await MainActor.run { self.status = .connected; self.backoffSeconds = 1 }
                if let parsed = self.parseMessage(firstMessage) {
                    self.continuation?.yield(parsed)
                }
                // Subsequent receives
                while !Task.isCancelled {
                    let msg = try await task.receive()
                    if let parsed = self.parseMessage(msg) {
                        self.continuation?.yield(parsed)
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.status = .disconnected(error)
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        let delay = backoffSeconds
        backoffSeconds = min(backoffSeconds * 2, 30)
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self.connect()
        }
    }

    private func parseMessage(_ message: URLSessionWebSocketTask.Message) -> Components.Schemas.PaneStreamMessage? {
        switch message {
        case .data(let data):
            return try? JSONDecoder().decode(Components.Schemas.PaneStreamMessage.self, from: data)
        case .string(let text):
            guard let data = text.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(Components.Schemas.PaneStreamMessage.self, from: data)
        @unknown default:
            return nil
        }
    }

    private func webSocketURL() -> URL {
        var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false)!
        // http → ws, https → wss (exact scheme match per spec).
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/api/v1/ws/sessions/\(sessionName)/panes/\(paneID)"
        return components.url!
    }
}

// MARK: - Test helpers (internal visibility, not shipped in release builds)

extension WebSocketClient {
    func webSocketURLForTesting() -> URL { webSocketURL() }
    func encodeResizeForTesting(cols: Int, rows: Int) throws -> Data {
        let payload = ResizeMessage(resize: .init(cols: cols, rows: rows))
        return try JSONEncoder().encode(payload)
    }
}

// MARK: - Resize wire type

private struct ResizeMessage: Encodable {
    struct Dims: Encodable { let cols: Int; let rows: Int }
    let resize: Dims
}
