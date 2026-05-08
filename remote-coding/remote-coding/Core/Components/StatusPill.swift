import SwiftUI

/// Color-coded pill used in feature / ticket detail heroes.
///
/// Visual: a 14% accent fill with accent-tinted text. The accent
/// derives from the role (`.inProgress` → orange, `.review` → iris,
/// `.shipped` → green, `.planned` / `.todo` → muted gray). Reuses
/// `StatusGlyphRole` so feature and ticket status enums map onto a
/// single visual surface.
struct StatusPill: View {
    var role: StatusGlyphRole
    var label: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(fillColor)
            )
    }

    private var fillColor: Color {
        switch role {
        case .doing:   return Theme.Semantic.orange.opacity(0.14)
        case .review:  return AccentColor.iris.value(for: scheme).opacity(0.14)
        case .shipped: return Theme.Semantic.green.opacity(0.14)
        case .planned, .todo:
            return Theme.Text.fg2(scheme).opacity(0.12)
        }
    }

    private var textColor: Color {
        switch role {
        case .doing:   return Theme.Semantic.orange
        case .review:  return AccentColor.iris.value(for: scheme)
        case .shipped: return Theme.Semantic.green
        case .planned, .todo:
            return Theme.Text.fg2(scheme)
        }
    }
}

#Preview("StatusPill — light") {
    VStack(alignment: .leading, spacing: 8) {
        StatusPill(role: .doing,   label: "In progress")
        StatusPill(role: .review,  label: "In review")
        StatusPill(role: .planned, label: "Planned")
        StatusPill(role: .shipped, label: "Shipped")
        StatusPill(role: .todo,    label: "Todo")
    }
    .padding()
    .background(Theme.Surface.bg(.light))
}

#Preview("StatusPill — dark") {
    VStack(alignment: .leading, spacing: 8) {
        StatusPill(role: .doing,   label: "In progress")
        StatusPill(role: .review,  label: "In review")
        StatusPill(role: .shipped, label: "Shipped")
    }
    .padding()
    .background(Theme.Surface.bg(.dark))
    .preferredColorScheme(.dark)
}
