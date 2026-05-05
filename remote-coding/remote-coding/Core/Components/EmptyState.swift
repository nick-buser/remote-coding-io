import SwiftUI

/// Centered empty-state illustration.
///
/// 72pt outlined circle with a glyph, then a 22pt fg title and a 14pt
/// fg2 body. Used for "All clear" inbox, "No features yet" milestones,
/// "No active sessions", etc.
///
/// The `View.body` requirement clashes with the `body:` parameter name
/// the design uses for the secondary copy — this view spells the
/// secondary copy as `message` to avoid the shadow.
struct EmptyState: View {
    var systemImage: String
    var title: String
    var message: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: Theme.Spacing.s4) {
            ZStack {
                Circle()
                    .strokeBorder(Theme.Text.fg3(scheme), lineWidth: 1.5)
                    .frame(width: 72, height: 72)
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(Theme.Text.fg2(scheme))
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.Text.fg(scheme))
                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.Text.fg2(scheme))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Theme.Spacing.s5)
        .frame(maxWidth: .infinity)
    }
}

#Preview("EmptyState — light") {
    EmptyState(
        systemImage: "tray",
        title: "All clear",
        message: "Nothing needs you right now. New questions and reviews will land here."
    )
    .padding()
    .background(Theme.Surface.bg(.light))
}

#Preview("EmptyState — dark") {
    EmptyState(
        systemImage: "calendar",
        title: "No active milestones",
        message: "Plan a milestone from the Roadmap to start grouping features."
    )
    .padding()
    .background(Theme.Surface.bg(.dark))
    .preferredColorScheme(.dark)
}
