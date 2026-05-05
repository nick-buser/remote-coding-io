import SwiftUI

/// A surface that hosts content with the design's card treatment.
///
/// Light mode: white background, no border, 4% drop shadow.
/// Dark mode: card background with a 0.5pt hairline at `Theme.Surface.sep`.
///
/// Padding defaults to `Theme.Spacing.s4` (16pt) but the design varies it
/// per context (12 / 16 / 18 / 20 / 22pt) — pass an explicit value when
/// composing.
struct RoundedCard<Content: View>: View {
    var radius: CGFloat = Theme.Radius.r4
    var padding: CGFloat = Theme.Spacing.s4
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.Surface.card(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        Theme.Surface.sep(scheme),
                        lineWidth: scheme == .dark ? 0.5 : 0
                    )
            )
            .shadow(
                color: Color.black.opacity(scheme == .dark ? 0 : 0.04),
                radius: 8,
                x: 0,
                y: 2
            )
    }
}

#Preview("RoundedCard — light") {
    VStack(spacing: 16) {
        RoundedCard {
            Text("Default radius (r4) and padding (s4)").themeBody()
        }
        RoundedCard(radius: Theme.Radius.r6, padding: Theme.Spacing.s5) {
            Text("Inbox hero — r6 / s5").themeDisplayMedium()
        }
    }
    .padding()
    .background(Theme.Surface.bg(.light))
}

#Preview("RoundedCard — dark") {
    VStack(spacing: 16) {
        RoundedCard {
            Text("Hairline visible in dark").themeBody()
        }
    }
    .padding()
    .background(Theme.Surface.bg(.dark))
    .preferredColorScheme(.dark)
}
