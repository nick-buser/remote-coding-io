import SwiftUI

/// Full-screen search sheet. Pass `scopeProject` to limit results to a
/// single project; omit it for cross-workspace search.
///
/// The caller is responsible for providing the shared `SearchViewModel`
/// (held on `AppModel.searchViewModel`) so the data bundle is loaded once
/// per session and re-used across every search presentation.
struct SearchView: View {
    let scopeProject: Components.Schemas.Project?
    @State private var viewModel: SearchViewModel

    @Environment(AppModel.self) private var appModel
    @Environment(RootCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var query = ""
    @State private var results = SearchViewModel.SearchResults.empty
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var fieldFocused: Bool

    init(scopeProject: Components.Schemas.Project? = nil, viewModel: SearchViewModel) {
        self.scopeProject = scopeProject
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                Divider().background(Theme.Surface.sep(scheme))
                bodyContent
            }
            .background(Theme.Surface.bg(scheme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .task {
            await viewModel.load(repository: appModel.repository)
            fieldFocused = true
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: Theme.Spacing.s2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(Theme.Text.fg2(scheme))
            TextField(
                scopeProject.map { "Search \($0.name)…" } ?? "Projects, features, tickets…",
                text: $query
            )
            .focused($fieldFocused)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .onChange(of: query) { _, newValue in
                scheduleSearch(for: newValue)
            }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = .empty
                    searchTask?.cancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Text.fg3(scheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.s4)
        .padding(.vertical, 10)
    }

    // MARK: - Body

    @ViewBuilder
    private var bodyContent: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !query.isEmpty && results.isEmpty {
            emptyState
        } else if query.isEmpty {
            hint
        } else {
            resultsList
        }
    }

    private var hint: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Theme.Text.fg3(scheme))
            Text("Search for projects, features, or tickets")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Text.fg2(scheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Theme.Spacing.s4)
    }

    private var emptyState: some View {
        EmptyState(
            systemImage: "magnifyingglass",
            title: "No results",
            message: "No results for "\(query)"."
        )
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsList: some View {
        List {
            if !results.projects.isEmpty {
                Section {
                    ForEach(results.projects) { project in
                        ProjectResultRow(project: project)
                            .contentShape(Rectangle())
                            .onTapGesture { navigate(to: .projectDetail(idOrSlug: project.slug)) }
                            .listRowBackground(Theme.Surface.card(scheme))
                    }
                } header: {
                    sectionHeader("Projects", count: results.projects.count)
                }
            }
            if !results.features.isEmpty {
                Section {
                    ForEach(results.features, id: \.feature.id) { pf in
                        FeatureResultRow(feature: pf.feature, projectName: pf.project.name)
                            .contentShape(Rectangle())
                            .onTapGesture { navigate(to: .featureDetail(featureID: pf.feature.id)) }
                            .listRowBackground(Theme.Surface.card(scheme))
                    }
                } header: {
                    sectionHeader("Features", count: results.features.count)
                }
            }
            if !results.tickets.isEmpty {
                Section {
                    ForEach(results.tickets, id: \.ticket.id) { pt in
                        TicketResultRow(ticket: pt.ticket, featureName: pt.feature.title)
                            .contentShape(Rectangle())
                            .onTapGesture { navigate(to: .ticketDetail(publicID: pt.ticket.publicId)) }
                            .listRowBackground(Theme.Surface.card(scheme))
                    }
                } header: {
                    sectionHeader("Tickets", count: results.tickets.count)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.immediately)
    }

    private func sectionHeader(_ label: String, count: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.Text.fg2(scheme))
            Spacer()
            Text("\(count)")
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
        }
    }

    // MARK: - Helpers

    private func navigate(to route: AppRoute) {
        coordinator.push(route)
        dismiss()
    }

    private func scheduleSearch(for query: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            results = viewModel.results(for: query, scopeProject: scopeProject)
        }
    }
}

// MARK: - Result rows

private struct ProjectResultRow: View {
    let project: Components.Schemas.Project

    @Environment(\.colorScheme) private var scheme

    private var accent: AccentColor {
        AccentColor(rawValue: project.accent ?? "") ?? .iris
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.s3) {
            Pip(accent: accent, size: 10, radius: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Text.fg(scheme))
                Text(project.slug)
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
            }
            Spacer(minLength: 0)
            Chevron()
        }
        .padding(.vertical, 4)
    }
}

private struct FeatureResultRow: View {
    let feature: Components.Schemas.Feature
    let projectName: String

    @Environment(\.colorScheme) private var scheme

    private var publicLabel: String {
        "FEAT-\(String(format: "%03d", feature.id))"
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.s3) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(publicLabel)
                        .themeMonoSm()
                        .foregroundStyle(Theme.Text.fg2(scheme))
                    Text("·")
                        .themeMonoSm()
                        .foregroundStyle(Theme.Text.fg3(scheme))
                    Text(projectName)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Text.fg2(scheme))
                }
                Text(feature.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Text.fg(scheme))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Chevron()
        }
        .padding(.vertical, 4)
    }
}

private struct TicketResultRow: View {
    let ticket: Components.Schemas.Ticket
    let featureName: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: Theme.Spacing.s3) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(ticket.publicId)
                        .themeMonoSm()
                        .foregroundStyle(Theme.Text.fg2(scheme))
                    Text("·")
                        .themeMonoSm()
                        .foregroundStyle(Theme.Text.fg3(scheme))
                    Text(featureName)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Text.fg2(scheme))
                        .lineLimit(1)
                }
                Text(ticket.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Text.fg(scheme))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Chevron()
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview("SearchView — global") {
    let repo = MockTmuxAgentRepository()
    let model = AppModel(repository: repo)
    let vm = SearchViewModel()
    SearchView(viewModel: vm)
        .environment(model)
        .environment(RootCoordinator())
}

#Preview("SearchView — scoped") {
    let repo = MockTmuxAgentRepository()
    let model = AppModel(repository: repo)
    let vm = SearchViewModel()
    let project = (try? await repo.getProject(idOrSlug: "1"))
        ?? Components.Schemas.Project(
            id: 1, name: "tmux-agent", slug: "tmux_agent",
            tagline: "Local agent runner", description: nil,
            accent: "mint", icon: nil, status: .active,
            pinned: false, health: .healthy, tags: [],
            progressCached: 0, gitRepoUrl: nil, localRepoPath: nil,
            lastTouchedAt: Date(), createdAt: Date(), updatedAt: Date()
        )
    SearchView(scopeProject: project, viewModel: vm)
        .environment(model)
        .environment(RootCoordinator())
}
#endif
