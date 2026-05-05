import SwiftUI

/// Filled rounded square used as a project / feature accent indicator.
/// The default 8×8 with `r:3` matches the spec from
/// `docs/feature_plans/10-design-system.md`.
struct Pip: View {
    var accent: AccentColor
    var size: CGFloat = 8
    var radius: CGFloat = 3

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(accent.value(for: scheme))
            .frame(width: size, height: size)
    }
}

#Preview("Pip — variants") {
    HStack(spacing: 12) {
        ForEach(AccentColor.allCases, id: \.self) { accent in
            VStack(spacing: 6) {
                Pip(accent: accent)
                Pip(accent: accent, size: 12, radius: 4)
                Pip(accent: accent, size: 16, radius: 5)
            }
        }
    }
    .padding()
}

#Preview("Pip — dark") {
    HStack(spacing: 12) {
        ForEach(AccentColor.allCases, id: \.self) { accent in
            Pip(accent: accent, size: 12, radius: 4)
        }
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
