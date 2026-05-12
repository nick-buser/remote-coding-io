import SwiftUI

/// Agent session row for the Project detail Sessions sub-tab. Renders
/// the session's tmux name + state pill + uptime, with a green pulse
/// dot when the session is `active` or `awaiting-input`.
struct SessionRow: View {
    let session: Components.Schemas.AgentSession
    var ticketLabel: String? = nil
    /// Optional human-readable scope title shown below the tmux session name.
    /// E.g. the ticket title, feature title, or project name.
    var scopeTitle: String? = nil
    var onTap: () -> Void = {}

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Theme.Spacing.s3) {
                stateIndicator
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 4) {
                    metaLine
                    Text(session.tmuxSession)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.Text.fg(scheme))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let scopeTitle {
                        Text(scopeTitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Theme.Text.fg2(scheme))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                Spacer(minLength: 0)
                Chevron()
                    .padding(.top, 4)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var stateIndicator: some View {
        Circle()
            .fill(stateColor)
            .frame(width: 8, height: 8)
    }

    private var metaLine: some View {
        HStack(spacing: 6) {
            Text(stateLabel)
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
            if let ticketLabel {
                Text("·")
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
                Text(ticketLabel)
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
            }
            Spacer(minLength: 8)
            Text(session.uptime)
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
        }
    }

    private var stateColor: Color {
        switch session.state {
        case .active:        return Theme.Semantic.green
        case .awaitingInput: return Theme.Semantic.orange
        case .idle:          return Theme.Text.fg3(scheme)
        case .ended:         return Theme.Text.fg3(scheme)
        }
    }

    private var stateLabel: String {
        switch session.state {
        case .active:        return "Active"
        case .awaitingInput: return "Awaiting"
        case .idle:          return "Idle"
        case .ended:         return "Ended"
        }
    }
}
