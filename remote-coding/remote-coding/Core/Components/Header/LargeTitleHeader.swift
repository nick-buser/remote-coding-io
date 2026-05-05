import SwiftUI

/// Top-of-tab header for Inbox / Projects / Roadmap / Sessions / You.
///
/// Renders a 34pt large title flush with the screen edge, plus an
/// optional row of trailing nav icons. Quiet by design — no centered
/// label or back chevron, since these are root tabs.
struct LargeTitleHeader<Trailing: View>: View {
    var title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .themeTitle()
                    .foregroundStyle(Theme.Text.fg(scheme))
                Spacer()
                trailing()
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.Text.fg2(scheme))
            }
        }
        .padding(.horizontal, Theme.Spacing.s4)
        .padding(.top, Theme.Spacing.s2)
    }
}

#Preview("LargeTitleHeader — Inbox") {
    LargeTitleHeader(title: "Inbox", subtitle: "1 thing needs you") {
        HStack(spacing: 8) {
            NavIconButton(name: .filter) {}
            NavIconButton(name: .dots) {}
        }
    }
    .padding(.vertical)
    .background(Theme.Surface.bg(.light))
}

#Preview("LargeTitleHeader — Sessions, dark") {
    LargeTitleHeader(title: "Sessions") {
        NavIconButton(name: .plus, accent: .iris, tinted: true) {}
    }
    .padding(.vertical)
    .background(Theme.Surface.bg(.dark))
    .preferredColorScheme(.dark)
}
