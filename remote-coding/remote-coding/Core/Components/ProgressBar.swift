import SwiftUI

/// 4pt (default) horizontal rule with an accent-tinted percentage fill.
/// Used on `FeatureRow` and the FeatureDetail progress card.
///
/// `value` is clamped to `0...1`.
struct ProgressBar: View {
    var value: Double
    var accent: AccentColor
    var height: CGFloat = 4

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let clamped = max(0, min(1, value))
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.Surface.chip(scheme))
                Capsule()
                    .fill(accent.value(for: scheme))
                    .frame(width: proxy.size.width * clamped)
            }
        }
        .frame(height: height)
    }
}

#Preview("ProgressBar — variants") {
    VStack(spacing: 16) {
        ForEach(AccentColor.allCases, id: \.self) { accent in
            ProgressBar(value: 0.42, accent: accent)
        }
        ProgressBar(value: 0.75, accent: .iris, height: 2)
        ProgressBar(value: 1.0, accent: .mint, height: 6)
    }
    .padding()
    .background(Theme.Surface.bg(.light))
}

#Preview("ProgressBar — dark") {
    VStack(spacing: 16) {
        ForEach(AccentColor.allCases, id: \.self) { accent in
            ProgressBar(value: 0.42, accent: accent)
        }
    }
    .padding()
    .background(Theme.Surface.bg(.dark))
    .preferredColorScheme(.dark)
}
