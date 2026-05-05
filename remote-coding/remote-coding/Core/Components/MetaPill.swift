import SwiftUI

/// Inline label with an optional leading dot — used for compact metadata
/// rows like "Active · 4 live · 3/5 features" on the Project list.
///
/// The dot uses an explicit `iconColor`; pass the project / feature accent
/// to make the dot pick up scope, or `Theme.Semantic.green` for live state.
struct MetaPill: View {
    var icon: String?
    var iconColor: Color?
    var label: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: Theme.Spacing.s1) {
            if icon != nil {
                Circle()
                    .fill(iconColor ?? Theme.Text.fg2(scheme))
                    .frame(width: 6, height: 6)
            }
            Text(label)
                .themeCaption()
                .foregroundStyle(Theme.Text.fg2(scheme))
        }
    }
}

#Preview("MetaPill — light") {
    VStack(alignment: .leading, spacing: 8) {
        MetaPill(icon: "dot", iconColor: Theme.Semantic.green, label: "Active")
        MetaPill(icon: "dot", iconColor: nil, label: "4 live")
        MetaPill(icon: nil, iconColor: nil, label: "3/5 features")
    }
    .padding()
    .background(Theme.Surface.bg(.light))
}

#Preview("MetaPill — dark") {
    VStack(alignment: .leading, spacing: 8) {
        MetaPill(icon: "dot", iconColor: Theme.Semantic.green, label: "Active")
        MetaPill(icon: nil, iconColor: nil, label: "Idle")
    }
    .padding()
    .background(Theme.Surface.bg(.dark))
    .preferredColorScheme(.dark)
}
