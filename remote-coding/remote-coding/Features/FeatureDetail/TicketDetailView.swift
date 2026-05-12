import SwiftUI

/// Lightweight ticket detail screen used for tickets that aren't in
/// `review` status. Shows the description plus a read-only criteria
/// checklist; no Approve / Request changes footer (those live on
/// `TicketReviewView` for review-status tickets).
///
/// This view sits behind `TicketDetailRouter` — the
/// `.ticketDetail(publicID:)` route fetches the ticket, then routes to
/// either this view or `TicketReviewView` based on status.
struct TicketDetailView: View {
    let ticket: Components.Schemas.Ticket

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var criteria: [Components.Schemas.AcceptanceCriterion] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                topBar
                hero
                descriptionBody
                criteriaBody
            }
            .padding(.bottom, Theme.Spacing.s5)
        }
        .background(Theme.Surface.bg(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadCriteria()
        }
        .refreshable {
            await loadCriteria()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        QuietHeader(label: ticket.publicId) {
            BackChevron(label: "Back", accent: appModel.accent) { dismiss() }
        } trailing: {
            Color.clear.frame(width: 28, height: 28)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(ticket.publicId)
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
                StatusPill(role: TicketStatusStyle.glyphRole(for: ticket.status), label: TicketStatusStyle.label(for: ticket.status))
                Spacer()
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
            Text(ticket.title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.Text.fg(scheme))
                .lineLimit(3)
        }
        .padding(.horizontal, Theme.Spacing.s4)
    }

    // MARK: - Description

    @ViewBuilder
    private var descriptionBody: some View {
        // `description` is in the schema's `required` list, so the
        // generator surfaces it as a non-optional `String`. Trim
        // whitespace before checking so empty strings don't render
        // an empty card.
        let trimmed = ticket.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
                Text("DESCRIPTION")
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
                    .padding(.horizontal, Theme.Spacing.s4)
                RoundedCard {
                    Text(trimmed)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Theme.Text.fg(scheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, Theme.Spacing.s4)
            }
        }
    }

    // MARK: - Criteria

    private var criteriaBody: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
            Text("ACCEPTANCE CRITERIA")
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
                .padding(.horizontal, Theme.Spacing.s4)
            RoundedCard {
                if isLoading && criteria.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let errorMessage, criteria.isEmpty {
                    Text(errorMessage)
                        .themeCaption()
                        .foregroundStyle(Theme.Semantic.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if criteria.isEmpty {
                    Text("No criteria defined.")
                        .themeCaption()
                        .foregroundStyle(Theme.Text.fg2(scheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(criteria.enumerated()), id: \.element.id) { index, criterion in
                            if index > 0 {
                                Divider().background(Theme.Surface.sep(scheme))
                            }
                            criterionRow(for: criterion)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }

    private func criterionRow(for criterion: Components.Schemas.AcceptanceCriterion) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s3) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(criterion.done ? Theme.Semantic.green : Color.clear)
                    .frame(width: 18, height: 18)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(criterion.done ? Theme.Semantic.green : Theme.Text.fg3(scheme), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                if criterion.done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.top, 2)
            Text(criterion.text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(criterion.done ? Theme.Text.fg2(scheme) : Theme.Text.fg(scheme))
                .strikethrough(criterion.done, color: Theme.Text.fg2(scheme))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Load

    @MainActor
    private func loadCriteria() async {
        isLoading = true
        defer { isLoading = false }
        do {
            criteria = try await appModel.repository.listCriteria(ticketPublicID: ticket.publicId)
        } catch {
            errorMessage = "Couldn't load criteria: \(error.localizedDescription)"
        }
    }
}

/// Resolves a ticket by public id and dispatches to either
/// `TicketReviewView` (for review-status tickets) or
/// `TicketDetailView`. Mounted from `ContentView` on the
/// `.ticketDetail` route.
struct TicketDetailRouter: View {
    let publicID: String

    @Environment(AppModel.self) private var appModel
    @State private var ticket: Components.Schemas.Ticket?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let ticket {
                if ticket.status == .review {
                    TicketReviewView(publicID: ticket.publicId)
                } else {
                    TicketDetailView(ticket: ticket)
                }
            } else if let errorMessage {
                ContentUnavailableView(
                    "Ticket unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView()
            }
        }
        .task(id: publicID) {
            do {
                ticket = try await appModel.repository.getTicket(publicID: publicID)
            } catch {
                errorMessage = String(describing: error)
            }
        }
    }
}
