import Foundation

/// Compact relative-time formatter for Inbox row timestamps.
///
/// Returns short shapes like `Just now`, `42m`, `2h`, `3d` — matching
/// the design's mono timestamp pinned to the right of each row. The
/// formatter is pure (takes both the event date and a "now" reference)
/// so tests can pin exact strings without depending on wall-clock time.
enum InboxRelativeTime {
    static func short(_ date: Date, now: Date = .now) -> String {
        let interval = now.timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        }
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h"
        }
        let days = hours / 24
        return "\(days)d"
    }
}
