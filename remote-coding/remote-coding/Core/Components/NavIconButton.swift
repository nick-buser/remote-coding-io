import SwiftUI

/// Named icons used in the trailing slot of `QuietHeader` and
/// `LargeTitleHeader`. Each maps to an SF Symbol so weights and
/// scales come from the symbol set, not raw glyphs.
enum NavIconName: String, Hashable, Sendable {
    case plus
    case search
    case filter
    case calendar
    case dots
    case share
    case compose

    var symbol: String {
        switch self {
        case .plus:     return "plus"
        case .search:   return "magnifyingglass"
        case .filter:   return "line.3.horizontal.decrease"
        case .calendar: return "calendar"
        case .dots:     return "ellipsis"
        case .share:    return "square.and.arrow.up"
        case .compose:  return "square.and.pencil"
        }
    }
}

/// 22pt nav icon button. The `tinted` variant uses the surrounding
/// accent (used for the primary action — `.plus` / `.compose`); the
/// neutral variant uses `fg` for `.filter` / `.search` / `.dots`.
struct NavIconButton: View {
    var name: NavIconName
    var accent: AccentColor? = nil
    var tinted: Bool = false
    var action: () -> Void

    @Environment(\.accent) private var environmentAccent
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Image(systemName: name.symbol)
                .symbolRenderingMode(.monochrome)
                .imageScale(.medium)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(foreground)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(name.rawValue))
    }

    private var foreground: Color {
        if tinted {
            return (accent ?? environmentAccent).value(for: scheme)
        } else {
            return Theme.Text.fg(scheme)
        }
    }
}

#Preview("NavIconButton — variants") {
    HStack(spacing: 12) {
        NavIconButton(name: .plus, accent: .iris, tinted: true) {}
        NavIconButton(name: .compose, accent: .iris, tinted: true) {}
        NavIconButton(name: .filter) {}
        NavIconButton(name: .search) {}
        NavIconButton(name: .calendar) {}
        NavIconButton(name: .dots) {}
        NavIconButton(name: .share) {}
    }
    .padding()
    .background(Theme.Surface.bg(.light))
}

#Preview("NavIconButton — dark") {
    HStack(spacing: 12) {
        NavIconButton(name: .plus, accent: .amber, tinted: true) {}
        NavIconButton(name: .filter) {}
        NavIconButton(name: .dots) {}
    }
    .padding()
    .background(Theme.Surface.bg(.dark))
    .preferredColorScheme(.dark)
}
