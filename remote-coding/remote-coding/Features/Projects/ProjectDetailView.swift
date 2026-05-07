import SwiftUI

private enum ProjectSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case features = "Features"
    case docs = "Docs"
    case sessions = "Sessions"

    var id: String { rawValue }
}

struct ProjectDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(RootCoordinator.self) private var coordinator
    @State private var viewModel: ProjectDetailViewModel
    @State private var selectedSection: ProjectSection = .overview

    init(project: Components.Schemas.Project) {
        _viewModel = State(initialValue: ProjectDetailViewModel(project: project))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.project.tagline ?? viewModel.project.name)
                        .font(.headline)
                    Text(viewModel.project.description ?? viewModel.project.localRepoPath)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label(viewModel.project.localRepoPath, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }

            Section {
                Picker("Section", selection: $selectedSection) {
                    ForEach(ProjectSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
            }

            switch selectedSection {
            case .overview:
                overviewRows
            case .features:
                featureRows
            case .docs:
                documentRows
            case .sessions:
                sessionRows
            }
        }
        .navigationTitle(viewModel.project.name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .task {
            await viewModel.load(repository: appModel.repository)
        }
        .toolbar {
            Button {
                Task {
                    await viewModel.openProjectSession(repository: appModel.repository)
                }
            } label: {
                Label("Open Session", systemImage: "terminal")
            }
        }
        .navigationDestination(for: LocalProjectNote.self) { note in
            DocumentEditorView(document: note)
        }
    }

    private var overviewRows: some View {
        Section("Status") {
            LabeledContent("State", value: viewModel.project.status.rawValue)
            LabeledContent("Slug", value: viewModel.project.slug)
            // The contract Project schema does not carry a tmux session
            // name; that surface returns when service-repo-agent-sessions
            // wires the listProjectSessions endpoint.
        }
    }

    private var featureRows: some View {
        Section("Features") {
            ForEach(viewModel.features) { feature in
                Button {
                    coordinator.push(.featureDetail(featureID: feature.id), in: .projects)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(feature.title)
                                .font(.headline)
                            Text(feature.branchName ?? feature.slug)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Chevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var documentRows: some View {
        Section("Documents") {
            ForEach(viewModel.notes) { note in
                NavigationLink(value: note) {
                    Label(note.title, systemImage: note.kind.systemImage)
                }
            }
        }
    }

    private var sessionRows: some View {
        Section("tmux") {
            ForEach(viewModel.sessions) { session in
                VStack(alignment: .leading, spacing: 10) {
                    Text(session.name)
                        .font(.headline)
                    Text(session.directory)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    ForEach(viewModel.panes[session.name] ?? []) { pane in
                        Button {
                            // The .agentSession destination still resolves to the legacy
                            // TerminalView prototype until service-terminal-shell ships;
                            // a real AgentSession.id replaces this Int64(pane.index)
                            // shim once service-feature-sessions-tab maps tmux panes to
                            // persistent agent-session records.
                            coordinator.push(
                                .agentSession(sessionID: Int64(pane.index)),
                                in: .projects
                            )
                        } label: {
                            HStack {
                                Label("Pane \(pane.index)", systemImage: pane.active ? "terminal.fill" : "terminal")
                                Spacer()
                                Text(pane.title)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

