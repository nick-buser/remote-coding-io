import Foundation

/// Outcome of routing a push payload — a target tab plus an optional
/// `AppRoute` to push onto that tab's stack. A nil route means "switch
/// tabs but don't push anything" (e.g. fallback for an unrecognised push).
struct PushDestination: Equatable {
    let tab: AppTab
    let route: AppRoute?

    /// Fallback for unrecognised payloads or missing required fields.
    static var inbox: PushDestination { .init(tab: .inbox, route: nil) }
}

/// Pure routing logic for APNs notifications. Takes a `userInfo` dict
/// and returns the destination the app should navigate to.
///
/// Intentionally synchronous + no UIKit imports so it can be unit-tested
/// without standing up `UNUserNotificationCenter` or any view stack.
///
/// Routing rules:
/// - `kind == "question"` + `agent_session_id` → `.agentSession(sessionID:)` on Inbox stack
/// - `kind == "review"` + `ticket_public_id` → `.ticketDetail(publicID:)` on Inbox stack
/// - anything else (missing kind, malformed field, unknown kind) → `.inbox` fallback
///
/// The Inbox tab hosts these routes today because the existing in-app
/// row-tap routing (`InboxView.handleRowTap`) pushes them there too —
/// keeping push-driven navigation on the same stack avoids the user
/// landing on an unfamiliar tab.
struct PushRouter {
    func destination(for payload: [AnyHashable: Any]) -> PushDestination {
        guard let kind = payload["kind"] as? String else {
            return .inbox
        }
        switch kind {
        case "question":
            if let sessionID = Self.int64(payload["agent_session_id"]) {
                return PushDestination(
                    tab: .inbox,
                    route: .agentSession(sessionID: sessionID)
                )
            }
            return .inbox
        case "review":
            if let publicID = payload["ticket_public_id"] as? String, !publicID.isEmpty {
                return PushDestination(
                    tab: .inbox,
                    route: .ticketDetail(publicID: publicID)
                )
            }
            return .inbox
        default:
            return .inbox
        }
    }

    /// Accepts `Int`, `Int64`, `NSNumber`, or numeric `String` — APNs payloads
    /// arrive through JSON deserialisation which can produce any of these.
    private static func int64(_ value: Any?) -> Int64? {
        switch value {
        case let n as Int64: return n
        case let n as Int: return Int64(n)
        case let n as NSNumber: return n.int64Value
        case let s as String: return Int64(s)
        default: return nil
        }
    }
}
