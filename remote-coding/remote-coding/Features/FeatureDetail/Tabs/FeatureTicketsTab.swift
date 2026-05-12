import SwiftUI

/// Feature detail Tickets sub-tab — list of `TicketRow`s with criteria
/// dots, optional grouping by status when the count is high, and a
/// long-press context menu for status mutations.
///
/// The view consumes `FeatureDetailViewModel` directly (not a copy) so
/// status mutations route through the same view-model the rest of the
/// detail screen uses. The `+ New ticket` footer button on the parent
/// view drives `showCreateSheet` via a `Binding`.
struct FeatureTicketsTab: View {
    @Bindable var viewModel: FeatureDetailViewModel
    @Binding var showCreateSheet: Bool
    let repository: TmuxAgentRepository
    var onSelect: (Components.Schemas.Ticket) -> Void

    @Environment(\.colorScheme) private var scheme

    /// Threshold beyond which the list groups tickets by status.
    private let groupingThreshold = 6

    var body: some View {
        Group {
            if viewModel.tickets.isEmpty {
                EmptyState(
                    systemImage: "list.bullet.rectangle",
                    title: "No tickets yet",
                    message: "Tap + New ticket to start scoping work for this feature."
                )
            } else if viewModel.tickets.count >= groupingThreshold {
                groupedBody
            } else {
                flatBody
            }
        }
    }

    // MARK: - Body shapes

    private var groupedBody: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
            ForEach(Self.statusGroups, id: \.label) { group in
                let tickets = viewModel.tickets.filter { group.statuses.contains($0.status) }
                if !tickets.isEmpty {
                    section(title: group.label, tickets: tickets)
                }
            }
        }
    }

    private var flatBody: some View {
        section(title: "Tickets", tickets: viewModel.tickets)
    }

    private func section(title: String, tickets: [Components.Schemas.Ticket]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
            Text(title.uppercased())
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
                .padding(.horizontal, Theme.Spacing.s4)
            RoundedCard {
                VStack(spacing: 8) {
                    ForEach(Array(tickets.enumerated()), id: \.element.id) { index, ticket in
                        if index > 0 {
                            Divider().background(Theme.Surface.sep(scheme))
                        }
                        ticketRow(for: ticket)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }

    // MARK: - Row

    private func ticketRow(for ticket: Components.Schemas.Ticket) -> some View {
        FeatureTicketRow(
            ticket: ticket,
            isLive: isLive(for: ticket.id),
            onTap: { onSelect(ticket) }
        )
        .contextMenu {
            ForEach(Self.statusMenuItems, id: \.self) { item in
                Button(item.label(for: ticket.status)) {
                    setStatus(item.target, on: ticket)
                }
                .disabled(ticket.status == item.target)
            }
            Button("Edit") { /* edit sheet — follow-up */ }
                .disabled(true)
            Button("Spawn session") {
                // Pre-filled spawn lands with service-feature-sessions-tab.
            }
            .disabled(true)
        }
    }

    // MARK: - Helpers

    private func isLive(for ticketID: Int64) -> Bool {
        viewModel.agentSessions.contains { session in
            session.ticketId == ticketID
                && (session.state == .active || session.state == .awaitingInput)
        }
    }

    private func setStatus(_ status: Components.Schemas.TicketStatus, on ticket: Components.Schemas.Ticket) {
        Task {
            await mutateStatus(ticket: ticket, status: status)
        }
    }

    @MainActor
    private func mutateStatus(ticket: Components.Schemas.Ticket, status: Components.Schemas.TicketStatus) async {
        do {
            let body = Components.Schemas.UpdateTicketRequest(
                title: nil,
                description: nil,
                status: status,
                estimate: nil
            )
            let updated = try await repository.updateTicket(publicID: ticket.publicId, body: body)
            if let index = viewModel.tickets.firstIndex(where: { $0.id == updated.id }) {
                viewModel.tickets[index] = updated
            }
        } catch {
            viewModel.errorMessage = "Couldn't update ticket: \(error.localizedDescription)"
        }
    }

    // MARK: - Static groupings

    static let statusGroups: [(label: String, statuses: [Components.Schemas.TicketStatus])] = [
        ("Doing",  [.doing]),
        ("Review", [.review]),
        ("Todo",   [.todo]),
        ("Done",   [.done])
    ]

    private struct StatusMenuItem: Hashable {
        let target: Components.Schemas.TicketStatus
        let title: String

        func label(for current: Components.Schemas.TicketStatus) -> String {
            current == target ? "✓ \(title)" : title
        }
    }

    private static let statusMenuItems: [StatusMenuItem] = [
        StatusMenuItem(target: .doing,  title: "Mark doing"),
        StatusMenuItem(target: .review, title: "Mark review"),
        StatusMenuItem(target: .done,   title: "Mark done")
    ]
}

// MARK: - Row visual

/// A denser ticket row than `Features/Projects/Detail/TicketRow.swift`,
/// matching the design's per-feature ticket list. Keeps live-session
/// state, criteria dots, and an estimate badge.
struct FeatureTicketRow: View {
    let ticket: Components.Schemas.Ticket
    var isLive: Bool = false
    var onTap: () -> Void = {}

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Theme.Spacing.s3) {
                StatusGlyph(role: TicketStatusStyle.glyphRole(for: ticket.status), size: 14)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 4) {
                    metaLine
                    Text(ticket.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Text.fg(scheme))
                        .lineLimit(1)
                    criteriaLine
                }
                Spacer(minLength: 0)
                trailingStack
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var metaLine: some View {
        HStack(spacing: 6) {
            Text(ticket.publicId)
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
            if isLive {
                Circle()
                    .fill(Theme.Semantic.green)
                    .frame(width: 6, height: 6)
                Text("live")
                    .themeMonoSm()
                    .foregroundStyle(Theme.Semantic.green)
            }
            Spacer(minLength: 8)
            Text(updatedRelative)
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
        }
    }

    private var criteriaLine: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(0, Int(ticket.criteriaTotal)), id: \.self) { index in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(index < Int(ticket.criteriaDone) ? Theme.Semantic.green : Theme.Text.fg3(scheme))
                    .frame(width: 8, height: 4)
            }
            if ticket.criteriaTotal > 0 {
                Text("\(ticket.criteriaDone)/\(ticket.criteriaTotal)")
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
                    .padding(.leading, 4)
            }
        }
    }

    private var trailingStack: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if !ticket.estimate.isEmpty {
                Text(ticket.estimate)
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg(scheme))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Theme.Text.fg3(scheme), lineWidth: 1)
                    )
            }
        }
        .padding(.top, 2)
    }

    private var updatedRelative: String {
        InboxRelativeTime.short(ticket.updatedAt)
    }
}
