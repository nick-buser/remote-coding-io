import SwiftUI

struct TerminalView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel = TerminalViewModel()

    private let quickKeys = ["Enter", "Escape", "Tab", "BSpace", "Up", "Down", "Left", "Right", "C-c", "C-d"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let context = viewModel.context {
                    TerminalContextHeader(context: context)
                        .padding()
                        .background(.thinMaterial)
                } else {
                    ContentUnavailableView("No pane selected", systemImage: "terminal", description: Text("Open a pane from a project or feature session."))
                        .frame(maxHeight: .infinity)
                }

                if viewModel.context != nil {
                    RunestoneTextSurface(
                        text: Binding(
                            get: { viewModel.output },
                            set: { viewModel.output = $0 }
                        ),
                        isEditable: false
                    )

                    TerminalInputBar(
                        input: Binding(
                            get: { viewModel.input },
                            set: { viewModel.input = $0 }
                        ),
                        quickKeys: quickKeys,
                        onSubmit: {
                            Task {
                                await viewModel.submit(repository: appModel.repository)
                            }
                        },
                        onEnter: {
                            Task {
                                await viewModel.sendEnter(repository: appModel.repository)
                            }
                        },
                        onKey: { key in
                            Task {
                                await viewModel.sendKey(key, repository: appModel.repository)
                            }
                        }
                    )
                }
            }
            .navigationTitle("Terminal")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: appModel.terminalContext) {
                await viewModel.configure(context: appModel.terminalContext, repository: appModel.repository)
            }
            .toolbar {
                Button {
                    Task {
                        await viewModel.reload(repository: appModel.repository)
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.context == nil || viewModel.isLoading)
            }
        }
    }
}

private struct TerminalContextHeader: View {
    let context: TerminalContext

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(context.project.name, systemImage: "folder")
                    .font(.headline)
                Spacer()
                Text("Pane \(context.pane.index)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
            if let feature = context.feature {
                Label(feature.title, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Label(context.session.name, systemImage: "terminal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct TerminalInputBar: View {
    @Binding var input: String

    let quickKeys: [String]
    let onSubmit: () -> Void
    let onEnter: () -> Void
    let onKey: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickKeys, id: \.self) { key in
                        Button(key) {
                            if key == "Enter" {
                                onEnter()
                            } else {
                                onKey(key)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal)
            }

            HStack(spacing: 8) {
                TextField("Command or response", text: $input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit(onSubmit)

                Button(action: onSubmit) {
                    Image(systemName: "paperplane.fill")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onEnter) {
                    Image(systemName: "return")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .padding(.top, 8)
        .background(.background)
    }
}

#Preview {
    let repository = MockTmuxAgentRepository()
    let appModel = AppModel(repository: repository)
    TerminalView()
        .environment(appModel)
}
