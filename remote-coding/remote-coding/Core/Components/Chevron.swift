import SwiftUI

/// Trailing 7×12 disclosure indicator. Used on every drill-down row.
/// The 7×12 frame is the design's; the SF Symbol is rendered at 12pt
/// weight `.semibold` to match.
struct Chevron: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.Text.fg3(scheme))
            .frame(width: 7, height: 12)
    }
}

#Preview("Chevron — both schemes") {
    HStack(spacing: 32) {
        VStack {
            Chevron()
            Text("light").themeCaption()
        }
        .padding()
        .background(Theme.Surface.bg(.light))

        VStack {
            Chevron()
                .foregroundStyle(Theme.Text.fg3(.dark))
            Text("dark").themeCaption()
        }
        .padding()
        .background(Theme.Surface.bg(.dark))
        .environment(\.colorScheme, .dark)
    }
}
