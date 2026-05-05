import SwiftUI

/// Apple-style segmented control — chip-tinted track, white pill for the
/// active item. Reach for this instead of `Picker(.segmented)` so the
/// track tint and active-pill shadow match the design exactly.
///
/// The selection is bound; items are rendered as plain `String` labels
/// (matching the design source's usage). For richer items, build a
/// view-model-side mapping and feed labels in.
struct SegmentedControl: View {
    var items: [String]
    @Binding var selection: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                let isActive = item == selection
                Button {
                    selection = item
                } label: {
                    Text(item)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            isActive
                                ? Theme.Text.fg(scheme)
                                : Theme.Text.fg2(scheme)
                        )
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(
                                cornerRadius: Theme.Radius.r2,
                                style: .continuous
                            )
                            .fill(isActive ? activePill : .clear)
                            .shadow(
                                color: Color.black.opacity(isActive && scheme == .light ? 0.06 : 0),
                                radius: 2,
                                x: 0,
                                y: 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.r2, style: .continuous)
                .fill(Theme.Surface.chip(scheme))
        )
    }

    private var activePill: Color {
        scheme == .dark
            ? Theme.Surface.card(scheme)
            : .white
    }
}

#Preview("SegmentedControl — light") {
    StatefulPreviewWrapper("Features") { selection in
        SegmentedControl(
            items: ["Features", "Tickets", "Docs", "Sessions"],
            selection: selection
        )
        .padding()
        .background(Theme.Surface.bg(.light))
    }
}

#Preview("SegmentedControl — dark") {
    StatefulPreviewWrapper("Tickets") { selection in
        SegmentedControl(
            items: ["Tickets", "PRD", "Decisions", "Sessions"],
            selection: selection
        )
        .padding()
        .background(Theme.Surface.bg(.dark))
        .preferredColorScheme(.dark)
    }
}

private struct StatefulPreviewWrapper<Content: View>: View {
    @State private var value: String
    let content: (Binding<String>) -> Content

    init(_ initial: String, @ViewBuilder content: @escaping (Binding<String>) -> Content) {
        self._value = State(initialValue: initial)
        self.content = content
    }

    var body: some View { content($value) }
}
