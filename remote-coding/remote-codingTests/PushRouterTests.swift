import Foundation
import Testing
@testable import remote_coding

struct PushRouterTests {

    // MARK: - question

    @Test func questionWithSessionIDRoutesToAgentSession() async {
        let router = PushRouter()
        let payload: [AnyHashable: Any] = [
            "kind": "question",
            "agent_session_id": 802
        ]
        let destination = router.destination(for: payload)

        #expect(destination.tab == .inbox)
        if case .agentSession(let sessionID) = destination.route {
            #expect(sessionID == 802)
        } else {
            Issue.record("expected .agentSession route, got \(String(describing: destination.route))")
        }
    }

    @Test func questionAcceptsInt64SessionID() async {
        let router = PushRouter()
        let payload: [AnyHashable: Any] = [
            "kind": "question",
            "agent_session_id": Int64(900)
        ]
        let destination = router.destination(for: payload)

        if case .agentSession(let sessionID) = destination.route {
            #expect(sessionID == 900)
        } else {
            Issue.record("expected .agentSession route")
        }
    }

    @Test func questionAcceptsNSNumberSessionID() async {
        let router = PushRouter()
        let payload: [AnyHashable: Any] = [
            "kind": "question",
            "agent_session_id": NSNumber(value: 901)
        ]
        let destination = router.destination(for: payload)

        if case .agentSession(let sessionID) = destination.route {
            #expect(sessionID == 901)
        } else {
            Issue.record("expected .agentSession route")
        }
    }

    @Test func questionAcceptsNumericString() async {
        let router = PushRouter()
        let payload: [AnyHashable: Any] = [
            "kind": "question",
            "agent_session_id": "902"
        ]
        let destination = router.destination(for: payload)

        if case .agentSession(let sessionID) = destination.route {
            #expect(sessionID == 902)
        } else {
            Issue.record("expected .agentSession route")
        }
    }

    @Test func questionWithoutSessionIDFallsBackToInbox() async {
        let router = PushRouter()
        let payload: [AnyHashable: Any] = ["kind": "question"]
        let destination = router.destination(for: payload)

        #expect(destination == .inbox)
    }

    @Test func questionWithMalformedSessionIDFallsBackToInbox() async {
        let router = PushRouter()
        let payload: [AnyHashable: Any] = [
            "kind": "question",
            "agent_session_id": "not-a-number"
        ]
        let destination = router.destination(for: payload)

        #expect(destination == .inbox)
    }

    // MARK: - review

    @Test func reviewWithPublicIDRoutesToTicketDetail() async {
        let router = PushRouter()
        let payload: [AnyHashable: Any] = [
            "kind": "review",
            "ticket_public_id": "TMX-0050"
        ]
        let destination = router.destination(for: payload)

        #expect(destination.tab == .inbox)
        if case .ticketDetail(let publicID) = destination.route {
            #expect(publicID == "TMX-0050")
        } else {
            Issue.record("expected .ticketDetail route, got \(String(describing: destination.route))")
        }
    }

    @Test func reviewWithoutPublicIDFallsBackToInbox() async {
        let router = PushRouter()
        let payload: [AnyHashable: Any] = [
            "kind": "review",
            "ticket_id": 208
        ]
        let destination = router.destination(for: payload)

        #expect(destination == .inbox)
    }

    @Test func reviewWithEmptyPublicIDFallsBackToInbox() async {
        let router = PushRouter()
        let payload: [AnyHashable: Any] = [
            "kind": "review",
            "ticket_public_id": ""
        ]
        let destination = router.destination(for: payload)

        #expect(destination == .inbox)
    }

    // MARK: - default

    @Test func emptyPayloadFallsBackToInbox() async {
        let router = PushRouter()
        let destination = router.destination(for: [:])
        #expect(destination == .inbox)
    }

    @Test func unknownKindFallsBackToInbox() async {
        let router = PushRouter()
        let payload: [AnyHashable: Any] = [
            "kind": "commit",
            "agent_session_id": 1
        ]
        let destination = router.destination(for: payload)

        #expect(destination == .inbox)
    }

    @Test func missingKindFallsBackToInbox() async {
        let router = PushRouter()
        let payload: [AnyHashable: Any] = ["agent_session_id": 1]
        let destination = router.destination(for: payload)

        #expect(destination == .inbox)
    }
}
