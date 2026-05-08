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
        Group {
            if viewModel.tickets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    PillButton(title: "Spawn session", role: .secondary, accent: accent, wide: true) {}
                        .disabled(true)
                    Text("Create a ticket first.")
                        .themeCaption()
                        .foregroundStyle(Theme.Text.fg2(scheme))
                }
            } else {
                PillButton(title: "Spawn session", role: .secondary, accent: accent, wide: true) {
                    showSpawnSheet = true
                }
            }
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

// MARK: - Spawn sheet

/// Modal form that creates a new `AgentSession` bound to a ticket.
///
/// Required: ticket pick (defaults to the feature's most-recently-updated
/// ticket). Advanced toggles surface optional `tmux_session` override
/// and starting `state`. On success, dismisses the sheet and pushes
/// `.agentSession(sessionID:)` onto the active tab's stack.
struct SpawnSessionSheet: View {
    let feature: Components.Schemas.Feature
    let tickets: [Components.Schemas.Ticket]
    let accent: AccentColor
    var onSpawned: (Components.Schemas.AgentSession) -> Void

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var selectedTicketID: Int64?
    @State private var tmuxSessionOverride: String = ""
    @State private var startingState: Components.Schemas.SessionState = .idle
    @State private var showAdvanced = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Ticket") {
                    Picker("Ticket", selection: $selectedTicketID) {
                        ForEach(sortedTickets, id: \.id) { ticket in
                            Text("\(ticket.publicId) · \(ticket.title)").tag(Optional(ticket.id))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                        TextField("tmux_session override (optional)", text: $tmuxSessionOverride)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 14, design: .monospaced))
                        Picker("Starting state", selection: $startingState) {
                            Text("Idle").tag(Components.Schemas.SessionState.idle)
                            Text("Active").tag(Components.Schemas.SessionState.active)
                            Text("Awaiting").tag(Components.Schemas.SessionState.awaitingInput)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Theme.Semantic.red)
                            .font(.system(size: 13))
                    }
                }
            }
            .navigationTitle("Spawn session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Spawn")
                                .foregroundStyle(accent.value(for: scheme))
                        }
                    }
                    .disabled(selectedTicketID == nil || isSubmitting)
                }
            }
            .task {
                if selectedTicketID == nil {
                    selectedTicketID = sortedTickets.first?.id
                }
            }
        }
    }

    private var sortedTickets: [Components.Schemas.Ticket] {
        tickets.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func submit() async {
        guard let ticketID = selectedTicketID,
              let ticket = tickets.first(where: { $0.id == ticketID }),
              !isSubmitting
        else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let trimmedOverride = tmuxSessionOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = Components.Schemas.CreateAgentSessionRequest(
            ticketPublicId: ticket.publicId,
            tmuxSession: trimmedOverride.isEmpty ? nil : trimmedOverride,
            state: showAdvanced ? startingState : nil,
            pane: nil,
            cpu: nil
        )
        do {
            let created = try await appModel.repository.createAgentSession(body)
            onSpawned(created)
            dismiss()
        } catch {
            errorMessage = "Couldn't spawn session: \(error.localizedDescription)"
        }
    }
}
