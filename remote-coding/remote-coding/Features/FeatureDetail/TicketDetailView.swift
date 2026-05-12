import SwiftUI
import UIKit

/// Full-screen ticket detail: editable title + description, toggleable
/// criteria, and a linked agent-sessions section with a spawn button.
struct TicketDetailView: View {
    @State var viewModel: TicketDetailViewModel

    @Environment(AppModel.self) private var appModel
    @Environment(RootCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    // Inline-edit focus state
    @FocusState private var titleFocused: Bool
    @FocusState private var descriptionFocused: Bool

    // Sheet state
    @State private var showStatusPicker = false
    @State private var showSpawnSheet = false
    @State private var newCriterionText = ""
    @FocusState private var addCriterionFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                topBar
                hero
                titleSection
                descriptionSection
                branchSection
                criteriaSection
                sessionsSection
            }
            .padding(.bottom, Theme.Spacing.s5)
        }
        .background(Theme.Surface.bg(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
        .overlay(alignment: .top) {
            if let msg = viewModel.errorMessage {
                errorBanner(msg)
            }
        }
        .sheet(isPresented: $showStatusPicker) {
            statusPickerSheet
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        QuietHeader(label: viewModel.ticket.publicId) {
            BackChevron(label: "Back", accent: appModel.accent) { dismiss() }
        } trailing: {
            Color.clear.frame(width: 28, height: 28)
        }
    }

    // MARK: - Hero (publicId + status + estimate)

    private var hero: some View {
        HStack(spacing: 8) {
            Text(viewModel.ticket.publicId)
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
            Button {
                showStatusPicker = true
            } label: {
                StatusPill(
                    role: TicketStatusStyle.glyphRole(for: viewModel.ticket.status),
                    label: TicketStatusStyle.label(for: viewModel.ticket.status)
                )
            }
            .buttonStyle(.plain)
            Spacer()
            if let estimate = viewModel.ticket.estimate, !estimate.isEmpty {
                Text(estimate)
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
        .padding(.horizontal, Theme.Spacing.s4)
    }

    // MARK: - Editable title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
            Text("TITLE")
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
                .padding(.horizontal, Theme.Spacing.s4)
            RoundedCard {
                TextField("Title", text: $viewModel.editingTitle, axis: .vertical)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Text.fg(scheme))
                    .focused($titleFocused)
                    .onSubmit {
                        Task { await viewModel.commitTitle() }
                    }
                    .onChange(of: titleFocused) { _, focused in
                        if !focused {
                            Task { await viewModel.commitTitle() }
                        }
                    }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }

    // MARK: - Editable description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
            Text("DESCRIPTION")
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
                .padding(.horizontal, Theme.Spacing.s4)
            RoundedCard {
                TextField("Description", text: $viewModel.editingDescription, axis: .vertical)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.Text.fg(scheme))
                    .focused($descriptionFocused)
                    .onChange(of: descriptionFocused) { _, focused in
                        if !focused {
                            Task { await viewModel.commitDescription() }
                        }
                    }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }

    // MARK: - Branch chip

    @ViewBuilder
    private var branchSection: some View {
        if !viewModel.ticket.branchName.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
                Text("BRANCH")
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
                    .padding(.horizontal, Theme.Spacing.s4)
                Button {
                    UIPasteboard.general.string = viewModel.ticket.branchName
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Text.fg2(scheme))
                        Text(viewModel.ticket.branchName)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(Theme.Text.fg(scheme))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.Surface.card(scheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.Surface.sep(scheme), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.s4)
            }
        }
    }

    // MARK: - Criteria

    private var criteriaSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
            Text("ACCEPTANCE CRITERIA")
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
                .padding(.horizontal, Theme.Spacing.s4)
            RoundedCard {
                if viewModel.isLoading && viewModel.criteria.isEmpty {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 0) {
                        ForEach(viewModel.criteria) { criterion in
                            AcceptanceCriterionRow(criterion: criterion) {
                                Task { await viewModel.toggleCriterion(id: criterion.id) }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteCriterion(id: criterion.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            if criterion.id != viewModel.criteria.last?.id {
                                Divider().background(Theme.Surface.sep(scheme))
                            }
                        }
                        addCriterionRow
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }

    private var addCriterionRow: some View {
        HStack(spacing: Theme.Spacing.s2) {
            Image(systemName: "plus.circle")
                .font(.system(size: 14))
                .foregroundStyle(appModel.accent)
            TextField("Add criterion", text: $newCriterionText)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Text.fg(scheme))
                .focused($addCriterionFocused)
                .onSubmit {
                    let text = newCriterionText
                    newCriterionText = ""
                    Task { await viewModel.addCriterion(text: text) }
                }
        }
        .padding(.top, viewModel.criteria.isEmpty ? 0 : 12)
    }

    // MARK: - Agent sessions

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
            Text("AGENT SESSIONS")
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
                .padding(.horizontal, Theme.Spacing.s4)
            RoundedCard {
                VStack(spacing: 0) {
                    if viewModel.sessions.isEmpty && !viewModel.isLoading {
                        Text("No sessions yet.")
                            .themeCaption()
                            .foregroundStyle(Theme.Text.fg2(scheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(viewModel.sessions) { session in
                            SessionRow(session: session) {
                                coordinator.push(.agentSession(sessionID: session.id))
                            }
                            if session.id != viewModel.sessions.last?.id {
                                Divider().background(Theme.Surface.sep(scheme))
                            }
                        }
                    }
                    Divider().background(Theme.Surface.sep(scheme))
                        .padding(.top, viewModel.sessions.isEmpty ? 0 : 4)
                    Button {
                        showSpawnSheet = true
                    } label: {
                        Label("Spawn session", systemImage: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(appModel.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }

    // MARK: - Status picker sheet

    private var statusPickerSheet: some View {
        NavigationStack {
            List {
                statusOption(.todo,   label: "Todo")
                statusOption(.doing,  label: "Doing")
                statusOption(.review, label: "Review")
                statusOption(.done,   label: "Done")
            }
            .navigationTitle("Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showStatusPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func statusOption(_ status: Components.Schemas.TicketStatus, label: String) -> some View {
        Button {
            showStatusPicker = false
            Task { await viewModel.updateStatus(status) }
        } label: {
            HStack {
                StatusGlyph(role: TicketStatusStyle.glyphRole(for: status), size: 16)
                Text(label)
                    .foregroundStyle(Theme.Text.fg(scheme))
                Spacer()
                if viewModel.ticket.status == status {
                    Image(systemName: "checkmark")
                        .foregroundStyle(appModel.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.Semantic.red)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.fg(scheme))
                .lineLimit(2)
            Spacer()
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Text.fg2(scheme))
            }
        }
        .padding(Theme.Spacing.s3)
        .background(Theme.Surface.card(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Semantic.red.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, Theme.Spacing.s4)
        .padding(.top, Theme.Spacing.s2)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(duration: 0.3), value: viewModel.errorMessage)
    }
}

/// Resolves a ticket by public id and dispatches to either
/// `TicketReviewView` (review-status tickets) or `TicketDetailView`.
/// Mounted from `ContentView` on the `.ticketDetail` route.
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
                    TicketDetailView(
                        viewModel: TicketDetailViewModel(
                            ticket: ticket,
                            repository: appModel.repository
                        )
                    )
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

#if DEBUG
#Preview("TicketDetailView") {
    let repo = MockTmuxAgentRepository()
    let model = AppModel(repository: repo)
    let ticket = (try? await repo.getTicket(publicID: "TMX-0042"))
        ?? Components.Schemas.Ticket(
            id: 200, publicId: "TMX-0042", featureId: 11,
            title: "Pane registry — register pane on launch",
            description: "Track every pane so the server can route pushes to the right window.",
            status: .doing, estimate: "S",
            branchName: "feat/tmx-0042-pane-registry", criteria: nil,
            criteriaTotal: 3, criteriaDone: 1,
            createdAt: Date(), updatedAt: Date()
        )
    NavigationStack {
        TicketDetailView(
            viewModel: TicketDetailViewModel(ticket: ticket, repository: repo)
        )
        .environment(model)
        .environment(RootCoordinator())
    }
}
#endif
