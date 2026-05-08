import Foundation

/// Filter chip selection above the Inbox feed. The `.mentions` case is
/// listed in the ticket / design but does not yet have a backing field
/// on `ActivityEvent`; until the contract surfaces a mention list its
/// predicate is `false` and `displayed` excludes it.
enum InboxFilter: String, Hashable, CaseIterable, Sendable {
    case all
    case questions
    case reviews
    case decisions
    case mentions

    var label: String {
        switch self {
        case .all:       return "All"
        case .questions: return "Questions"
        case .reviews:   return "Reviews"
        case .decisions: return "Decisions"
        case .mentions:  return "Mentions"
        }
    }

    /// Cases rendered in the chip row. `.mentions` is omitted until the
    /// backend exposes mention metadata (tracked in the ticket follow-up).
    static let displayed: [InboxFilter] = [.all, .questions, .reviews, .decisions]

    /// Predicate used to count and filter events for this chip.
    func matches(_ event: Components.Schemas.ActivityEvent) -> Bool {
        switch self {
        case .all:       return true
        case .questions: return event.kind == .question
        case .reviews:   return event.kind == .review
        case .decisions: return event.kind == .decision
        case .mentions:  return false
        }
    }
}
