import SwiftUI

/// Compact ticket row used inside the Project / Feature detail
/// "Tickets" sub-tabs. The status glyph is derived from `TicketStatus`;
/// the row renders the public id (`TMX-####`), title, and a `<done>/
/// <total>` criteria pill on the right.
struct TicketRow: View {
    let ticket: Components.Schemas.Ticket
    /// Optional FEAT-### context label rendered as a small mono pip
    /// to the left of the public id. Used by the project-scope flat
    /// list so a row carries its parent feature; pass nil when the
    /// surrounding section already scopes to a feature.
    var featureLabel: String? = nil
    var onTap: () -> Void = {}

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Theme.Spacing.s3) {
                StatusGlyph(role: TicketStatusStyle.glyphRole(for: ticket.status), size: 16)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 4) {
                    metaLine
                    Text(ticket.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Text.fg(scheme))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                criteriaPill
                    .padding(.top, 4)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var metaLine: some View {
        HStack(spacing: 6) {
            if let featureLabel {
                Text(featureLabel)
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
                Text("·")
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
            }
            Text(ticket.publicId)
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
            if let estimate = ticket.estimate, !estimate.isEmpty {
                Text("· \(estimate)")
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
            }
        }
    }

    private var criteriaPill: some View {
        Text("\(ticket.criteriaDone)/\(ticket.criteriaTotal)")
            .themeMonoSm()
            .foregroundStyle(Theme.Text.fg2(scheme))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Theme.Surface.chip(scheme))
            )
    }
}

/// Maps `TicketStatus` onto the shared `StatusGlyphRole` set.
enum TicketStatusStyle {
    static func glyphRole(for status: Components.Schemas.TicketStatus) -> StatusGlyphRole {
        switch status {
        case .todo:   return .todo
        case .doing:  return .doing
        case .review: return .review
        case .done:   return .shipped
        }
    }

    static func label(for status: Components.Schemas.TicketStatus) -> String {
        switch status {
        case .todo:   return "Todo"
        case .doing:  return "Doing"
        case .review: return "In review"
        case .done:   return "Done"
        }
    }
}
