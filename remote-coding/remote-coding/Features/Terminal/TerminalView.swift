import SwiftUI

struct TerminalView: View {
    let sessionID: Int64

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TerminalViewModel()

    var body: some View {
        ZStack {
            Theme.Surface.terminalBg.ignoresSafeArea()

            if viewModel.isLoading && viewModel.session == nil {
                ProgressView().tint(.white)
            } else if let msg = viewModel.errorMessage, viewModel.session == nil {
                errorView(message: msg)
            } else {
                VStack(spacing: 0) {
                    contextBar
                    hairline
                    bufferArea
                    quickKeysPlaceholder
                    inputBarPlaceholder
                }
            }
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.load(
                sessionID: sessionID,
                repository: appModel.repository,
                activityPoller: appModel.activityPoller
            )
        }
        .onDisappear {
            appModel.activityPoller.start(scope: .workspace)
        }
    }

    // MARK: - Context bar

    private var contextBar: some View {
        ZStack {
            HStack {
                BackChevron(label: "Sessions", accent: appModel.accent) {
                    dismiss()
                }
                Spacer()
                Button {
                    // dots menu — future ticket
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }

            if let s = viewModel.session {
                VStack(spacing: 2) {
                    Text("session-\(s.id)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(s.tmuxSession) · \(s.paneDisplayLabel) · \(s.uptime)")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(Theme.Text.fg2(.dark))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 88)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
        .background(Theme.Surface.terminalChrome)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 0.5)
    }

    // MARK: - Buffer

    private var bufferArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(viewModel.output.isEmpty ? " " : viewModel.output)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Theme.Text.fg(.dark))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .id("terminalBottom")
            }
            .frame(maxHeight: .infinity)
            .onChange(of: viewModel.output) {
                proxy.scrollTo("terminalBottom", anchor: .bottom)
            }
            .onAppear {
                proxy.scrollTo("terminalBottom", anchor: .bottom)
            }
        }
    }

    // MARK: - Placeholders (filled by later tickets)

    private var quickKeysPlaceholder: some View {
        Color.clear
            .frame(height: 44)
            .background(Theme.Surface.terminalChrome)
            .overlay(alignment: .top) { hairline }
    }

    private var inputBarPlaceholder: some View {
        HStack {
            Text("send a command…")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Theme.Text.fg3(.dark))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Surface.terminalInput, in: Capsule())
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.Surface.terminalChrome)
        .overlay(alignment: .top) { hairline }
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            EmptyState(
                systemImage: "terminal",
                title: "Couldn't reach pane",
                message: message
            )
            Button("Retry") {
                Task { await viewModel.reload(repository: appModel.repository) }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// session-07 in the mock seed has id=802
#Preview("Terminal — session-07") {
    let appModel = AppModel(repository: MockTmuxAgentRepository())
    TerminalView(sessionID: 802)
        .environment(appModel)
}
