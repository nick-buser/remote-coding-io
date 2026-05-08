import SwiftUI

/// Horizontally scrolling row of quick-key buttons between the buffer and
/// the input bar. Each button fires `SendInputRequest(keys: [wireKey])` so
/// the agent receives control sequences directly without text in the input
/// field.
struct QuickKeysRow: View {
    let onKey: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(primaryKeys, id: \.label) { item in
                    QuickKey(label: item.label, onTap: { onKey(item.wireKey) })
                }
                // More-keys overflow (less-common sequences)
                ForEach(extraKeys, id: \.label) { item in
                    QuickKey(label: item.label, onTap: { onKey(item.wireKey) })
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 44)
        .background(Theme.Surface.terminalChrome)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
        }
    }

    // MARK: - Key tables

    struct KeySpec {
        let label: String
        let wireKey: String
    }

    static let primaryKeys: [KeySpec] = [
        KeySpec(label: "esc",  wireKey: "Escape"),
        KeySpec(label: "tab",  wireKey: "Tab"),
        KeySpec(label: "⌃C",   wireKey: "C-c"),
        KeySpec(label: "⌃D",   wireKey: "C-d"),
        KeySpec(label: "↑",    wireKey: "Up"),
        KeySpec(label: "↓",    wireKey: "Down"),
        KeySpec(label: "←",    wireKey: "Left"),
        KeySpec(label: "→",    wireKey: "Right"),
        KeySpec(label: "⏎",    wireKey: "Enter")
    ]

    static let extraKeys: [KeySpec] = [
        KeySpec(label: "⌃Z",  wireKey: "C-z"),
        KeySpec(label: "⌃L",  wireKey: "C-l"),
        KeySpec(label: "⌃A",  wireKey: "C-a"),
        KeySpec(label: "⌃E",  wireKey: "C-e"),
        KeySpec(label: "PgUp", wireKey: "PPage"),
        KeySpec(label: "PgDn", wireKey: "NPage"),
        KeySpec(label: "Home", wireKey: "Home"),
        KeySpec(label: "End",  wireKey: "End"),
        KeySpec(label: "⌫",   wireKey: "BSpace"),
        KeySpec(label: "⇤",   wireKey: "BTab")
    ]
}

// MARK: - Single key button

private struct QuickKey: View {
    let label: String
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeIn(duration: 0.1)) { isPressed = false }
            }
            onTap()
        }) {
            Text(label)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(isPressed ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .scaleEffect(isPressed ? 0.88 : 1.0)
                .opacity(isPressed ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

#Preview("QuickKeysRow — dark") {
    QuickKeysRow(onKey: { _ in })
        .background(Color.black)
        .preferredColorScheme(.dark)
}
