import SwiftUI

private enum FeatureSection: String, CaseIterable, Identifiable {
    case docs = "Docs"
    case sessions = "Sessions"

    var id: String { rawValue }
}

struct FeatureDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(RootCoordinator.self) private var coordinator
    @State private var viewModel: FeatureDetailViewModel
    @State private var selectedSection: FeatureSection = .docs

    init(project: Components.Schemas.Project, feature: Components.Schemas.Feature) {
        _viewModel = State(initialValue: FeatureDetailViewModel(project: project, feature: feature))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.feature.title)
                        .font(.title3.bold())
                    Text(viewModel.feature.branchName ?? viewModel.feature.slug)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    LabeledContent("Status", value: viewModel.feature.status.rawValue)
                }
            }

            Section {
                Picker("Section", selection: $selectedSection) {
                    ForEach(FeatureSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
            }

            switch selectedSection {
            case .docs:
                docsList
            case .sessions:
                sessionList
            }
        }
        .navigationTitle("Feature")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(repository: appModel.repository)
        }
    }

    private var docsList: some View {
        Section("Docs") {
            // Tap routes through .docDetail; the destination is still a
            // RoutePlaceholder until service-feature-prd-tab ships the
            // TipTap renderer that paints body_blocks.
            ForEach(viewModel.docs) { doc in
                Button {
                    coordinator.push(.docDetail(docID: doc.id), in: .projects)
                } label: {
                    HStack {
                        Label(doc.title, systemImage: doc.kind.systemImage)
                        Spacer()
                        if doc.pinned {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                        Chevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sessionList: some View {
        Section("tmux") {
            ForEach(viewModel.sessions) { session in
                VStack(alignment: .leading, spacing: 10) {
                    Text(session.name)
                        .font(.headline)
                    ForEach(viewModel.panes[session.name] ?? []) { pane in
                        Button {
                            // Same shim as ProjectDetailView — pushes the .agentSession
                            // route to the legacy TerminalView prototype until
                            // service-terminal-shell + service-feature-sessions-tab
                            // resolve a real AgentSession.id.
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

extension Components.Schemas.DocKind {
    var systemImage: String {
        switch self {
        case .vision: "lightbulb"
        case .prd: "doc.text"
        case .design: "rectangle.3.group"
        case .notes: "note.text"
        case .log: "list.bullet"
        case .custom: "text.bubble"
        }
    }
}
