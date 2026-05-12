import SwiftUI

/// Multi-scope session spawn sheet. The `SpawnEntry` pre-fills project /
/// feature context and constrains the available scope options.
///
/// Pass `preselectedTicket` when opening from `TicketDetailView` to lock
/// the scope to `.ticket` and skip the ticket picker.
struct SpawnSheet: View {
    @State var viewModel: SpawnSheetViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(AppModel.self) private var appModel

    var body: some View {
        NavigationStack {
            Form {
                scopeSection
                projectSection
                featureSection
                ticketSection
                previewSection
                if let msg = viewModel.errorMessage {
                    Section {
                        Text(msg)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.Semantic.red)
                    }
                }
            }
            .navigationTitle("Spawn session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isSpawning)
                }
                ToolbarItem(placement: .confirmationAction) {
                    spawnButton
                }
            }
            .task { await viewModel.loadInitial() }
        }
        .presentationDetents([.large])
    }

    // MARK: - Scope selector

    @ViewBuilder
    private var scopeSection: some View {
        if viewModel.availableScopes.count > 1 {
            Section("Scope") {
                Picker("Scope", selection: Binding(
                    get: { viewModel.scope },
                    set: { newScope in Task { await viewModel.onScopeChanged(newScope) } }
                )) {
                    ForEach(viewModel.availableScopes, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    // MARK: - Project

    @ViewBuilder
    private var projectSection: some View {
        if let locked = viewModel.lockedProject {
            Section("Project") {
                Text(locked.name)
                    .foregroundStyle(Theme.Text.fg(scheme))
            }
        } else {
            Section("Project") {
                if viewModel.projects.isEmpty {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Picker("Project", selection: Binding(
                        get: { viewModel.selectedProject?.id },
                        set: { id in
                            guard let proj = viewModel.projects.first(where: { $0.id == id }) else { return }
                            Task { await viewModel.onProjectSelected(proj) }
                        }
                    )) {
                        Text("Select…").tag(Optional<Int64>.none)
                        ForEach(viewModel.projects) { proj in
                            Text(proj.name).tag(Optional(proj.id))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        }
    }

    // MARK: - Feature

    @ViewBuilder
    private var featureSection: some View {
        if viewModel.scope != .project {
            if let locked = viewModel.lockedFeature {
                Section("Feature") {
                    Text(locked.title)
                        .foregroundStyle(Theme.Text.fg(scheme))
                }
            } else if viewModel.selectedProject != nil || viewModel.lockedProject != nil {
                Section("Feature") {
                    if viewModel.features.isEmpty {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Picker("Feature", selection: Binding(
                            get: { viewModel.selectedFeature?.id },
                            set: { id in
                                guard let feat = viewModel.features.first(where: { $0.id == id }) else { return }
                                Task { await viewModel.onFeatureSelected(feat) }
                            }
                        )) {
                            Text("Select…").tag(Optional<Int64>.none)
                            ForEach(viewModel.features) { feat in
                                Text(feat.title).tag(Optional(feat.id))
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
            }
        }
    }

    // MARK: - Ticket

    @ViewBuilder
    private var ticketSection: some View {
        if viewModel.scope == .ticket {
            if let preselected = viewModel.preselectedTicket {
                Section("Ticket") {
                    Text("\(preselected.publicId) · \(preselected.title)")
                        .foregroundStyle(Theme.Text.fg(scheme))
                }
            } else if viewModel.selectedFeature != nil || viewModel.lockedFeature != nil {
                Section("Ticket") {
                    if viewModel.tickets.isEmpty && !viewModel.showingNewTicketForm {
                        Text("No open tickets.")
                            .foregroundStyle(Theme.Text.fg2(scheme))
                    } else {
                        Picker("Ticket", selection: Binding(
                            get: { viewModel.selectedTicket?.id },
                            set: { id in
                                viewModel.selectedTicket = viewModel.tickets.first(where: { $0.id == id })
                            }
                        )) {
                            Text("Select…").tag(Optional<Int64>.none)
                            ForEach(viewModel.tickets) { ticket in
                                Text("\(ticket.publicId) · \(ticket.title)").tag(Optional(ticket.id))
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                    newTicketRow
                }
            }
        }
    }

    @ViewBuilder
    private var newTicketRow: some View {
        if viewModel.showingNewTicketForm {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Ticket title", text: $viewModel.newTicketTitle)
                    .textInputAutocapitalization(.sentences)
                HStack {
                    TextField("Estimate (optional)", text: $viewModel.newTicketEstimate)
                        .frame(maxWidth: 120)
                    Spacer()
                    Button("Create") {
                        Task { await viewModel.createInlineTicket() }
                    }
                    .disabled(viewModel.newTicketTitle.trimmingCharacters(in: .whitespaces).isEmpty
                              || viewModel.isCreatingTicket)
                    Button("Cancel") {
                        viewModel.showingNewTicketForm = false
                        viewModel.newTicketTitle = ""
                        viewModel.newTicketEstimate = ""
                    }
                    .foregroundStyle(Theme.Text.fg2(scheme))
                }
            }
            .font(.system(size: 14))
        } else {
            Button {
                viewModel.showingNewTicketForm = true
            } label: {
                Label("New ticket…", systemImage: "plus")
                    .foregroundStyle(appModel.accent.value(for: scheme))
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Preview footer

    private var previewSection: some View {
        Section(footer: Text(viewModel.sessionNamePreview)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Theme.Text.fg2(scheme))
            .frame(maxWidth: .infinity, alignment: .leading)
        ) {
            EmptyView()
        }
    }

    // MARK: - Spawn button

    private var spawnButton: some View {
        Button {
            Task {
                await viewModel.spawn()
                if viewModel.errorMessage == nil {
                    dismiss()
                }
            }
        } label: {
            if viewModel.isSpawning {
                ProgressView()
            } else {
                Text("Spawn")
                    .foregroundStyle(appModel.accent.value(for: scheme))
                    .fontWeight(.semibold)
            }
        }
        .disabled(!viewModel.isSpawnEnabled)
    }
}

#if DEBUG
#Preview("SpawnSheet — sessionsTab") {
    let repo = MockTmuxAgentRepository()
    let coordinator = RootCoordinator()
    let model = AppModel(repository: repo)
    SpawnSheet(
        viewModel: SpawnSheetViewModel(
            entry: .sessionsTab,
            repository: repo,
            coordinator: coordinator
        )
    )
    .environment(model)
    .environment(coordinator)
}

#Preview("SpawnSheet — feature entry") {
    let repo = MockTmuxAgentRepository()
    let coordinator = RootCoordinator()
    let model = AppModel(repository: repo)
    let feature = (try? await repo.getFeature(id: 12)) ?? Components.Schemas.Feature(
        id: 12, projectId: 1, title: "Feature context bundle",
        slug: "feature-context-bundle", status: .active,
        accent: "mint", health: .healthy, tags: [],
        progressCached: 0, createdAt: Date()
    )
    let project = (try? await repo.getProject(idOrSlug: "1")) ?? Components.Schemas.Project(
        id: 1, name: "tmux-agent", slug: "tmux_agent",
        description: "", localRepoPath: nil,
        accent: "mint", health: .healthy, tags: [],
        progressCached: 0, createdAt: Date()
    )
    SpawnSheet(
        viewModel: SpawnSheetViewModel(
            entry: .feature(feature, project),
            repository: repo,
            coordinator: coordinator
        )
    )
    .environment(model)
    .environment(coordinator)
}
#endif
