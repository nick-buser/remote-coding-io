import SwiftUI

/// One filter chip — used inside `ScrollChips` rows. The active chip
/// fills with the surrounding accent; counts are mono and trail the
/// label. An optional leading dot is for chips that scope to a project
/// or feature accent.
struct Chip: View {
    var label: String
    var count: Int? = nil
    var dot: Color? = nil
    var active: Bool = false

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accent) private var accent

    var body: some View {
        HStack(spacing: 6) {
            if let dot {
                Circle()
                    .fill(dot)
                    .frame(width: 6, height: 6)
            }
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(textColor)
            if let count {
                Text("\(count)")
                    .themeMonoSm()
                    .foregroundStyle(textColor.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(background)
        )
    }

    private var background: Color {
        active
            ? accent.value(for: scheme)
            : Theme.Surface.chip(scheme)
    }

    private var textColor: Color {
        active ? .white : Theme.Text.fg(scheme)
    }
}

/// Horizontal scrolling row of `Chip`s. Used as the filter bar above
/// list views (Activity, Inbox).
struct ScrollChips<Item: Hashable>: View {
    var items: [Item]
    var content: (Item) -> Chip

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Chip) {
        self.items = items
        self.content = content
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    content(item)
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }
}

#Preview("Chip — variants") {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Chip(label: "All", active: true)
            Chip(label: "Needs you", count: 3)
            Chip(label: "Earlier")
        }
        HStack {
            Chip(label: "remote-coding", dot: AccentColor.iris.value(for: .light))
            Chip(label: "tmux-agent", dot: AccentColor.mint.value(for: .light))
            Chip(label: "infra", dot: AccentColor.amber.value(for: .light), active: true)
        }
    }
    .padding()
    .background(Theme.Surface.bg(.light))
}

#Preview("ScrollChips — dark") {
    ScrollChips(items: ["All", "Reviews", "Questions", "Commits", "Decisions", "Tests", "Docs"]) { label in
        Chip(label: label, active: label == "All")
    }
    .padding(.vertical)
    .background(Theme.Surface.bg(.dark))
    .preferredColorScheme(.dark)
}
