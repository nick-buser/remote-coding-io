import SwiftUI

/// Feature detail Sessions sub-tab — list of `AgentSession`s scoped
/// to the feature. Groups by state when there are ≥4 sessions; flat
/// otherwise. The `Spawn session` flow is presented from
/// `FeatureDetailView` (so the same sheet is reachable from the
/// Tickets-tab footer too); this tab also exposes a footer
/// `Spawn session` button as a fallback when the user is already
/// looking at the sessions list.
struct FeatureSessionsTab: View {
    @Bindable var viewModel: FeatureDetailViewModel
    let accent: AccentColor
    @Binding var showSpawnSheet: Bool
    var onSelect: (Components.Schemas.AgentSession) -> Void

    @Environment(\.colorScheme) private var scheme

    /// Threshold beyond which the list groups sessions by state.
    private let groupingThreshold = 4

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
            content
            footer
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.agentSessions.isEmpty {
            EmptyState(
                systemImage: "terminal",
                title: "No sessions yet",
                message: "Spawn a session to start working on a ticket."
            )
        } else if viewModel.agentSessions.count >= groupingThreshold {
            groupedBody
        } else {
            flatBody
        }
    }

    private var groupedBody: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
            ForEach(Self.stateGroups, id: \.label) { group in
                let sessions = viewModel.agentSessions.filter { group.states.contains($0.state) }
                if !sessions.isEmpty {
                    section(title: group.label, sessions: sessions)
                }
            }
        }
    }

    private var flatBody: some View {
        section(title: "Sessions", sessions: viewModel.agentSessions)
    }

    private func section(title: String, sessions: [Components.Schemas.AgentSession]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
            Text(title.uppercased())
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
                .padding(.horizontal, Theme.Spacing.s4)
            RoundedCard {
                VStack(spacing: 8) {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                        if index > 0 {
                            Divider().background(Theme.Surface.sep(scheme))
                        }
                        sessionRow(for: session)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }

    private func sessionRow(for session: Components.Schemas.AgentSession) -> some View {
        let ticket = viewModel.tickets.first(where: { $0.id == session.ticketId })
        return SessionRow(
            session: session,
            ticketLabel: ticket?.publicId,
            onTap: { onSelect(session) }
        )
    }

    // MARK: - Footer

    private var footer: some View {
        PillButton(title: "Spawn session", role: .secondary, accent: accent, wide: true) {
            showSpawnSheet = true
        }
        .padding(.horizontal, Theme.Spacing.s4)
        .padding(.top, Theme.Spacing.s2)
    }

    // MARK: - State groupings

    static let stateGroups: [(label: String, states: [Components.Schemas.SessionState])] = [
        ("Active",   [.active]),
        ("Awaiting", [.awaitingInput]),
        ("Idle",     [.idle]),
        ("Ended",    [.ended])
    ]
}

