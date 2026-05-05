import SwiftUI

/// The drill-down header from the v2 design — leading slot (typically a
/// `BackChevron`), centered label, trailing slot (typically a row of
/// `NavIconButton`s).
///
/// Optional `largeTitle` and `subtitle` render below the bar — used on
/// project / feature detail screens where the screen has its own
/// hero block.
struct QuietHeader<Leading: View, Trailing: View>: View {
    var label: String
    var largeTitle: String? = nil
    var subtitle: String? = nil
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s3) {
            ZStack {
                Text(label)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Text.fg(scheme))
                HStack(spacing: 0) {
                    leading()
                    Spacer()
                    trailing()
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
            .frame(height: 44)

            if largeTitle != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let largeTitle {
                        Text(largeTitle)
                            .themeDisplayLarge()
                            .foregroundStyle(Theme.Text.fg(scheme))
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Theme.Text.fg2(scheme))
                    }
                }
                .padding(.horizontal, Theme.Spacing.s4)
            }
        }
    }
}

#Preview("QuietHeader — drill-down") {
    QuietHeader(
        label: "FEAT-018",
        largeTitle: "Inbox composer",
        subtitle: "Direct mentions land first; everything else groups into Earlier today."
    ) {
        BackChevron(label: "Projects", accent: .iris) {}
    } trailing: {
        HStack(spacing: 8) {
            NavIconButton(name: .filter) {}
            NavIconButton(name: .dots) {}
        }
    }
    .padding(.vertical)
    .background(Theme.Surface.bg(.light))
}

#Preview("QuietHeader — dark, no hero") {
    QuietHeader(label: "Sessions") {
        BackChevron(label: "Inbox", accent: .mint) {}
    } trailing: {
        NavIconButton(name: .plus, accent: .mint, tinted: true) {}
    }
    .padding(.vertical)
    .background(Theme.Surface.bg(.dark))
    .preferredColorScheme(.dark)
}
