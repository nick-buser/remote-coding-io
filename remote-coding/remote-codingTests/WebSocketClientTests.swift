import Foundation
import Testing
@testable import remote_coding

struct WebSocketClientTests {

    // MARK: - URL construction

    @Test func httpSchemeBecomesWS() {
        let config = try! APIConfiguration(baseURLString: "http://localhost:3000")
        let client = WebSocketClient(configuration: config, sessionName: "my-session", paneID: 0)
        let url = client.webSocketURLForTesting()
        #expect(url.scheme == "ws")
    }

    @Test func httpsSchemeBecomesWSS() {
        let config = try! APIConfiguration(baseURLString: "https://example.com")
        let client = WebSocketClient(configuration: config, sessionName: "my-session", paneID: 1)
        let url = client.webSocketURLForTesting()
        #expect(url.scheme == "wss")
    }

    @Test func urlPathContainsSessionAndPane() {
        let config = try! APIConfiguration(baseURLString: "http://localhost:3000")
        let client = WebSocketClient(configuration: config, sessionName: "test-sess", paneID: 2)
        let url = client.webSocketURLForTesting()
        #expect(url.path.contains("test-sess"))
        #expect(url.path.contains("2"))
    }

    // MARK: - Resize message

    @Test func resizeMessageEncodesCorrectly() throws {
        struct ResizeMessage: Decodable {
            struct Dims: Decodable { let cols: Int; let rows: Int }
            let resize: Dims
        }
        let config = try APIConfiguration(baseURLString: "http://localhost:3000")
        let client = WebSocketClient(configuration: config, sessionName: "s", paneID: 0)
        // Access internal resize encoding via the helper method
        let data = try client.encodeResizeForTesting(cols: 120, rows: 40)
        let decoded = try JSONDecoder().decode(ResizeMessage.self, from: data)
        #expect(decoded.resize.cols == 120)
        #expect(decoded.resize.rows == 40)
    }

    // MARK: - Initial status

    @MainActor
    @Test func initialStatusIsDisconnected() {
        let config = try! APIConfiguration(baseURLString: "http://localhost:3000")
        let client = WebSocketClient(configuration: config, sessionName: "s", paneID: 0)
        if case .disconnected = client.status {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected .disconnected initial status")
        }
    }
}
