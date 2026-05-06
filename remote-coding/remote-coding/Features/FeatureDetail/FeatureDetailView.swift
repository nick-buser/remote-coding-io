import SwiftUI

private enum FeatureSection: String, CaseIterable, Identifiable {
    case docs = "Docs"
    case criteria = "Criteria"
    case sessions = "Sessions"

    var id: String { rawValue }
}

struct FeatureDetailView: View {
    @Environment(AppModel.self) private var appModel
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
                documentList(viewModel.documents.filter { $0.kind != .acceptanceCriteria })
            case .criteria:
                documentList(viewModel.documents.filter { $0.kind == .acceptanceCriteria })
            case .sessions:
                sessionList
            }
        }
        .navigationTitle("Feature")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(repository: appModel.repository)
        }
        .navigationDestination(for: WorkspaceDocument.self) { document in
            DocumentEditorView(document: document)
        }
    }

    private func documentList(_ documents: [WorkspaceDocument]) -> some View {
        Section(selectedSection.rawValue) {
            ForEach(documents) { document in
                NavigationLink(value: document) {
                    Label(document.title, systemImage: document.kind.systemImage)
                }
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
                            // service-app-route-coordinator wires this through coordinator.push(.agentSession(...)).
                            // No-op until then so the row stays renderable.
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

