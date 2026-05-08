import SwiftUI

/// The kinds shown by Inbox rows and the activity feed. Mirrors the
/// `kind` field on `ActivityEvent` from the OpenAPI contract, but is
/// kept as its own type so the visual layer doesn't depend on the
/// generated enum directly.
enum ActivityKind: Hashable, Sendable {
    case question
    case review
    case commit
    case decision
    case test
    case doc
    case check
    case approve
}

extension ActivityKind {
    /// Adapter from the generated OpenAPI enum so view code can hand a
    /// raw `event.kind` straight to `KindIcon`. Kept here to keep the
    /// adapter and visual mapping in one place.
    init(_ apiKind: Components.Schemas.ActivityKind) {
        switch apiKind {
        case .commit:   self = .commit
        case .check:    self = .check
        case .review:   self = .review
        case .doc:      self = .doc
        case .decision: self = .decision
        case .question: self = .question
        case .test:     self = .test
        case .approve:  self = .approve
        }
    }
}

private extension ActivityKind {
    var glyph: String {
        switch self {
        case .question: return "?"
        case .review:   return "◐"
        case .commit:   return "↑"
        case .decision: return "◆"
        case .test:     return "✓"
        case .doc:      return "✎"
        case .check:    return "☑"
        case .approve:  return "✓"
        }
    }

    func color(for scheme: ColorScheme) -> Color {
        switch self {
        case .question: return Theme.Semantic.orange
        case .review:   return AccentColor.iris.value(for: scheme)
        case .commit:   return Theme.Semantic.green
        case .decision: return AccentColor.mint.value(for: scheme)
        case .test:     return Theme.Text.fg3(scheme)
        case .doc:      return AccentColor.amber.value(for: scheme)
        case .check:    return Theme.Semantic.green
        case .approve:  return AccentColor.mint.value(for: scheme)
        }
    }
}

/// Colored 32pt (default) rounded square used in Inbox rows.
/// `r:8` matches the design's chip-on-card treatment.
struct KindIcon: View {
    var kind: ActivityKind
    var size: CGFloat = 32

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(kind.color(for: scheme))
            .frame(width: size, height: size)
            .overlay(
                Text(kind.glyph)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

/// 8pt rounded-2pt dot used in the activity feed. Same color mapping
/// as `KindIcon`, different geometry — this is the reduced affordance.
struct KindDot: View {
    var kind: ActivityKind

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(kind.color(for: scheme))
            .frame(width: 8, height: 8)
    }
}

#Preview("KindIcon — light") {
    HStack(spacing: 12) {
        KindIcon(kind: .question)
        KindIcon(kind: .review)
        KindIcon(kind: .commit)
        KindIcon(kind: .decision)
        KindIcon(kind: .test)
        KindIcon(kind: .doc)
        KindIcon(kind: .check)
        KindIcon(kind: .approve)
    }
    .padding()
    .background(Theme.Surface.bg(.light))
}

#Preview("KindIcon — dark") {
    HStack(spacing: 12) {
        KindIcon(kind: .question)
        KindIcon(kind: .review)
        KindIcon(kind: .commit)
        KindIcon(kind: .decision)
        KindIcon(kind: .test)
        KindIcon(kind: .doc)
        KindIcon(kind: .check)
        KindIcon(kind: .approve)
    }
    .padding()
    .background(Theme.Surface.bg(.dark))
    .preferredColorScheme(.dark)
}

#Preview("KindDot — both schemes") {
    HStack(spacing: 12) {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                KindDot(kind: .question)
                KindDot(kind: .review)
                KindDot(kind: .commit)
                KindDot(kind: .decision)
                KindDot(kind: .test)
                KindDot(kind: .doc)
                KindDot(kind: .check)
                KindDot(kind: .approve)
            }
        }
        .padding()
        .background(Theme.Surface.bg(.light))

        VStack(spacing: 8) {
            HStack(spacing: 8) {
                KindDot(kind: .question)
                KindDot(kind: .review)
                KindDot(kind: .commit)
                KindDot(kind: .decision)
                KindDot(kind: .test)
                KindDot(kind: .doc)
                KindDot(kind: .check)
                KindDot(kind: .approve)
            }
        }
        .padding()
        .background(Theme.Surface.bg(.dark))
        .environment(\.colorScheme, .dark)
    }
}
