import Foundation

extension Components.Schemas.AgentSession {
    /// Human-readable uptime since `start_time`. Used by the Sessions
    /// list and feature Sessions sub-tab so views don't repeat the
    /// duration math.
    ///
    /// Returns shapes like `"47m"`, `"2h 14m"`, `"3d"` matching the
    /// design's session row.
    var uptime: String {
        let interval = Date().timeIntervalSince(startTime)
        guard interval > 0 else { return "0m" }
        let totalMinutes = Int(interval / 60)
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes % (60 * 24)) / 60
        let minutes = totalMinutes % 60
        if days > 0 {
            return "\(days)d"
        }
        if hours > 0 {
            return "\(hours)h \(String(format: "%02d", minutes))m"
        }
        return "\(minutes)m"
    }
}
