import SwiftUI

/// A single row inside the Inbox feed cards.
///
/// Composition (per `docs/feature_plans/30-screens.md` §1):
///
///   [32pt KindIcon]   TMX-####  · session-07                       2h
///                     event.detail (or .verb if detail is empty)
///                     [Reply] [Open pane]   ← question rows only
///
/// The row's accent comes from the parent — `InboxView` resolves it via
/// `InboxViewModel.accent(forProjectID:)` so each row reflects its
/// project's accent without doing its own repository fetch.
struct InboxRow: View {
    let event: Components.Schemas.ActivityEvent
    var rowAccent: AccentColor = .iris
    var onTap: () -> Void = {}
    var onPrimaryAction: () -> Void = {}
    var onSecondaryAction: () -> Void = {}

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                KindIcon(kind: ActivityKind(event.kind), size: 32)

                VStack(alignment: .leading, spacing: 4) {
                    metaLine
                    bodyText
                    if hasInlineActions {
                        inlineActions
                            .padding(.top, 4)
                    }
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
    }

    private var metaLine: some View {
        HStack(spacing: 6) {
            Text(targetLabel)
                .themeMonoSm()
                .foregroundStyle(rowAccent.value(for: scheme))
            if let actorName = displayActorName {
                Text("· \(actorName)")
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
            }
            Spacer(minLength: 8)
            Text(InboxRelativeTime.short(event.createdAt))
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
        }
    }

    private var bodyText: some View {
        Text(displayBody)
            .font(.system(size: 14))
            .foregroundStyle(Theme.Text.fg(scheme))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var inlineActions: some View {
        switch event.kind {
        case .question:
            HStack(spacing: 8) {
                PillButton(title: "Reply", role: .primary, accent: rowAccent, action: onPrimaryAction)
                PillButton(title: "Open pane", role: .secondary, accent: rowAccent, action: onSecondaryAction)
            }
        case .review:
            HStack(spacing: 8) {
                PillButton(title: "Approve", role: .primary, accent: rowAccent, action: onPrimaryAction)
                PillButton(title: "Open diff", role: .secondary, accent: rowAccent, action: onSecondaryAction)
            }
        default:
            EmptyView()
        }
    }

    private var hasInlineActions: Bool {
        event.kind == .question || event.kind == .review
    }

    private var displayBody: String {
        if let detail = event.detail, !detail.isEmpty {
            return detail
        }
        return event.verb
    }

    private var displayActorName: String? {
        guard let name = event.actorName, !name.isEmpty else { return nil }
        return name
    }

    /// Synchronous label derived from the event's ids. The design calls
    /// for the canonical public id (TMX-####, FEAT-###); without a
    /// cheap public-id lookup the row falls back to `T-<id>` /
    /// `FEAT-<id>`. A future ticket can prime a public-id cache and
    /// pass labels in via the parent.
    private var targetLabel: String {
        if let ticketId = event.ticketId {
            return "T-\(ticketId)"
        }
        if let featureId = event.featureId {
            return "FEAT-\(featureId)"
        }
        return ""
    }
}

#Preview("InboxRow — question, light") {
    let event = Components.Schemas.ActivityEvent(
        id: 1,
        projectId: 2,
        featureId: 21,
        ticketId: 208,
        actor: .agent,
        actorName: "session-07",
        verb: "requested input",
        kind: .question,
        detail: "Use unified diff or split? defaulting to split.",
        createdAt: Date().addingTimeInterval(-2 * 3600)
    )
    return RoundedCard {
        InboxRow(event: event, rowAccent: .iris)
    }
    .padding()
    .background(Theme.Surface.bg(.light))
}

#Preview("InboxRow — review, dark") {
    let event = Components.Schemas.ActivityEvent(
        id: 2,
        projectId: 2,
        featureId: 21,
        ticketId: 208,
        actor: .agent,
        actorName: "session-07",
        verb: "opened review",
        kind: .review,
        detail: "+412 / −37 across 9 files",
        createdAt: Date().addingTimeInterval(-30 * 60)
    )
    return RoundedCard {
        InboxRow(event: event, rowAccent: .mint)
    }
    .padding()
    .background(Theme.Surface.bg(.dark))
    .preferredColorScheme(.dark)
}

#Preview("InboxRow — commit, no actions") {
    let event = Components.Schemas.ActivityEvent(
        id: 3,
        projectId: 1,
        featureId: 11,
        ticketId: 200,
        actor: .agent,
        actorName: "session-04",
        verb: "pushed 3 commits",
        kind: .commit,
        detail: "pane registry skeleton + tests",
        createdAt: Date().addingTimeInterval(-12 * 60)
    )
    return RoundedCard {
        InboxRow(event: event, rowAccent: .iris)
    }
    .padding()
    .background(Theme.Surface.bg(.light))
}
