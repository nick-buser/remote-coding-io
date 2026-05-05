import SwiftUI

/// Five accent circles with a selected ring around the active one.
/// Used on the You screen to set the user's preferred accent.
struct AccentSwatchPicker: View {
    @Binding var selection: AccentColor

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: Theme.Spacing.s3) {
            ForEach(AccentColor.allCases, id: \.self) { accent in
                let isSelected = accent == selection
                Button {
                    selection = accent
                } label: {
                    ZStack {
                        Circle()
                            .fill(accent.value(for: scheme))
                            .frame(width: 28, height: 28)
                        Circle()
                            .strokeBorder(
                                Theme.Text.fg(scheme),
                                lineWidth: isSelected ? 2 : 0
                            )
                            .frame(width: 36, height: 36)
                    }
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(accent.rawValue.capitalized))
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }
}

#Preview("AccentSwatchPicker — light") {
    StatefulPreviewWrapper(AccentColor.iris) { selection in
        AccentSwatchPicker(selection: selection)
            .padding()
            .background(Theme.Surface.bg(.light))
    }
}

#Preview("AccentSwatchPicker — dark") {
    StatefulPreviewWrapper(AccentColor.mint) { selection in
        AccentSwatchPicker(selection: selection)
            .padding()
            .background(Theme.Surface.bg(.dark))
            .preferredColorScheme(.dark)
    }
}

/// Tiny `@State` shim so `#Preview` blocks can drive a binding without
/// the host view owning state. Keeps preview-only mutability out of
/// production call sites.
private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initial)
        self.content = content
    }

    var body: some View { content($value) }
}
