import SwiftUI

/// Status communicated by `StatusGlyph`. Decoupled from any specific
/// `TicketStatus` / `FeatureStatus` enum so adapters can map both
/// surfaces (and any future ones) into the same visual language.
enum StatusGlyphRole: Hashable, Sendable {
    case shipped
    case review
    case doing
    case planned
    case todo
}

/// The little ringed-circle status indicator from the v2 design.
///
/// Maps `StatusGlyphRole` to:
/// - `.shipped` → solid green disc with white ✓
/// - `.review` → iris ring with 40% iris-tinted fill
/// - `.doing` → orange ring with 60% conic-gradient sweep
/// - `.planned` → dashed muted ring, empty
/// - `.todo` → solid muted ring, empty
struct StatusGlyph: View {
    var role: StatusGlyphRole
    var size: CGFloat = 18

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            switch role {
            case .shipped:
                Circle()
                    .fill(Theme.Semantic.green)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundStyle(.white)
            case .review:
                let iris = AccentColor.iris.value(for: scheme)
                Circle()
                    .fill(iris.opacity(0.4))
                    .overlay(Circle().stroke(iris, lineWidth: lineWidth))
            case .doing:
                Circle()
                    .stroke(Theme.Semantic.orange, lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: 0.6)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Theme.Semantic.orange.opacity(0.0),
                                Theme.Semantic.orange,
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            case .planned:
                Circle()
                    .stroke(
                        Theme.Text.fg3(scheme),
                        style: StrokeStyle(lineWidth: lineWidth, dash: [2, 2])
                    )
            case .todo:
                Circle()
                    .stroke(Theme.Text.fg3(scheme), lineWidth: lineWidth)
            }
        }
        .frame(width: size, height: size)
    }

    private var lineWidth: CGFloat { max(1.25, size * 0.1) }
}

#Preview("StatusGlyph — light") {
    HStack(spacing: 16) {
        VStack { StatusGlyph(role: .shipped); Text("shipped").themeCaption() }
        VStack { StatusGlyph(role: .review);  Text("review").themeCaption() }
        VStack { StatusGlyph(role: .doing);   Text("doing").themeCaption() }
        VStack { StatusGlyph(role: .planned); Text("planned").themeCaption() }
        VStack { StatusGlyph(role: .todo);    Text("todo").themeCaption() }
    }
    .padding()
    .background(Theme.Surface.bg(.light))
}

#Preview("StatusGlyph — dark") {
    HStack(spacing: 16) {
        StatusGlyph(role: .shipped)
        StatusGlyph(role: .review)
        StatusGlyph(role: .doing)
        StatusGlyph(role: .planned)
        StatusGlyph(role: .todo)
    }
    .padding()
    .background(Theme.Surface.bg(.dark))
    .preferredColorScheme(.dark)
}
