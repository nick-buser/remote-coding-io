import SwiftUI

/// Accent-colored ‹ + label. Lives in the leading slot of `QuietHeader`
/// on every drill-down. The accent defaults to the surrounding accent
/// from the environment so a feature drill-down inherits the feature's
/// accent without each call site repeating itself.
struct BackChevron: View {
    var label: String
    var accent: AccentColor? = nil
    var action: () -> Void

    @Environment(\.accent) private var environmentAccent
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                Text(label)
                    .font(.system(size: 17, weight: .regular))
            }
            .foregroundStyle((accent ?? environmentAccent).value(for: scheme))
        }
        .buttonStyle(.plain)
    }
}

#Preview("BackChevron — variants") {
    VStack(spacing: 16) {
        BackChevron(label: "Projects", accent: .iris) {}
        BackChevron(label: "FEAT-018", accent: .amber) {}
        BackChevron(label: "Inbox", accent: .mint) {}
    }
    .padding()
    .background(Theme.Surface.bg(.light))
}
