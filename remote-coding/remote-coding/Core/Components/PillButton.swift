import SwiftUI

/// Visual role for `PillButton`. Drives fill, stroke, and label color.
enum PillButtonRole: Hashable, Sendable {
    case primary
    case secondary
    case ghost
}

/// A pill button rendered against the surrounding accent.
///
/// - `.primary` is filled with the accent and shows white text.
/// - `.secondary` has a 14% accent fill with accent-colored text.
/// - `.ghost` is text-only.
///
/// `wide:true` lets the button grow inside an HStack — useful for the
/// inbox card's "Reply" / "Send back" pair.
struct PillButton: View {
    var title: String
    var role: PillButtonRole = .primary
    var accent: AccentColor? = nil
    var wide: Bool = false
    var action: () -> Void

    @Environment(\.accent) private var environmentAccent
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(textColor)
                .padding(.horizontal, Theme.Spacing.s4)
                .padding(.vertical, 10)
                .frame(maxWidth: wide ? .infinity : nil)
                .background(
                    Capsule()
                        .fill(fillColor)
                )
        }
        .buttonStyle(.plain)
    }

    private var resolvedAccent: AccentColor {
        accent ?? environmentAccent
    }

    private var fillColor: Color {
        let a = resolvedAccent.value(for: scheme)
        switch role {
        case .primary:   return a
        case .secondary: return a.opacity(0.14)
        case .ghost:     return .clear
        }
    }

    private var textColor: Color {
        switch role {
        case .primary:   return .white
        case .secondary, .ghost: return resolvedAccent.value(for: scheme)
        }
    }
}

#Preview("PillButton — light") {
    VStack(spacing: 12) {
        HStack {
            PillButton(title: "Reply", role: .primary, accent: .iris) {}
            PillButton(title: "Send back", role: .secondary, accent: .iris) {}
            PillButton(title: "Skip", role: .ghost, accent: .iris) {}
        }
        PillButton(title: "Spawn session", role: .primary, accent: .mint, wide: true) {}
    }
    .padding()
    .background(Theme.Surface.bg(.light))
}

#Preview("PillButton — dark") {
    VStack(spacing: 12) {
        PillButton(title: "Approve", role: .primary, accent: .mint, wide: true) {}
        PillButton(title: "Request changes", role: .secondary, accent: .mint, wide: true) {}
    }
    .padding()
    .background(Theme.Surface.bg(.dark))
    .preferredColorScheme(.dark)
}
