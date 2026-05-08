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
                    if case .disconnected = viewModel.socketStatus {
                        reconnectingPill
                    }
                    if !viewModel.siblingSessions.isEmpty {
                        PaneChipRow(
                            sessions: viewModel.siblingSessions,
                            activeSessionID: viewModel.session?.id,
                            onSelect: { target in
                                Task { await viewModel.switchSession(to: target, repository: appModel.repository) }
                            },
                            onSpawn: { viewModel.showSpawnSheet = true }
                        )
                    }
                    bufferArea
                    QuickKeysRow { key in
                        Task {
                            await viewModel.sendInput(
                                .key(key),
                                repository: appModel.repository
                            )
                        }
                    }
                    TerminalInputBar(
                        text: Binding(
                            get: { viewModel.input },
                            set: { viewModel.input = $0 }
                        ),
                        accent: appModel.accent,
                        isSending: viewModel.isSending,
                        lastPromptHint: TerminalInputBar.extractPromptHint(from: viewModel.output),
                        onSend: { mode in
                            let text = viewModel.input
                            viewModel.input = ""
                            Task {
                                let request: Components.Schemas.SendInputRequest = switch mode {
                                case .sendAndEnter: .text(text, submit: true)
                                case .sendOnly:     .text(text, submit: false)
                                case .enterOnly:    .enterOnly()
                                }
                                await viewModel.sendInput(request, repository: appModel.repository)
                            }
                        }
                    )
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
                activityPoller: appModel.activityPoller,
                apiConfiguration: appModel.apiConfiguration
            )
        }
        .task(id: viewModel.session?.id) {
            guard viewModel.session != nil else { return }
            await viewModel.loadSiblings(repository: appModel.repository)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showSpawnSheet },
            set: { viewModel.showSpawnSheet = $0 }
        )) {
            EmptyState(
                systemImage: "plus.circle",
                title: "Spawn session",
                message: "Project and feature pickers land in a follow-up ticket."
            )
            .presentationDetents([.medium])
        }
        .onDisappear {
            viewModel.closeSocket()
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

    private var reconnectingPill: some View {
        HStack(spacing: 6) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.white.opacity(0.6))
                .scaleEffect(0.7)
            Text("reconnecting…")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.08), in: Capsule())
        .padding(.vertical, 6)
    }

    // MARK: - Buffer

    private var bufferArea: some View {
        GeometryReader { geo in
            RunestoneTerminalBuffer(
                attributedText: viewModel.renderedBuffer,
                onSizeChange: { sendResize(for: geo.size) }
            )
            .onAppear { sendResize(for: geo.size) }
            .onChange(of: geo.size) { sendResize(for: geo.size) }
        }
    }

        private func sendResize(for size: CGSize) {
        // Approximate character grid from the monospaced 13pt font (~7.8pt wide, 18pt tall).
        let cols = max(1, Int(size.width / 7.8))
        let rows = max(1, Int(size.height / 18))
        Task { await viewModel.sendResize(cols: cols, rows: rows) }
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

// MARK: - Runestone terminal buffer with sticky-bottom

/// UIViewRepresentable bridge that wraps RunestoneTextSurface and adds
/// sticky-bottom scrolling: when the user is at the bottom, new content
/// scrolls the view down automatically; when scrolled up, position is
/// preserved.
private struct RunestoneTerminalBuffer: UIViewRepresentable {
    var attributedText: AttributedString
    var onSizeChange: (() -> Void)?

    func makeUIView(context: Context) -> RunestoneScrollContainer {
        let container = RunestoneScrollContainer()
        container.configure()
        return container
    }

    func updateUIView(_ container: RunestoneScrollContainer, context: Context) {
        let plain = String(attributedText.characters)
        guard container.textView.text != plain else { return }
        let wasAtBottom = container.isAtBottom
        container.textView.setState(TextViewState(text: plain))
        if wasAtBottom {
            container.scrollToBottom(animated: false)
        }
        onSizeChange?()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {}
}

final class RunestoneScrollContainer: UIView {
    let textView = TextView()

    func configure() {
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.backgroundColor = UIColor(Theme.Surface.terminalBg)
        textView.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = UIColor(Theme.Text.fg(.dark))
        textView.contentInset = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        textView.showLineNumbers = false
        textView.lineWrappingEnabled = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    var isAtBottom: Bool {
        let offset = textView.contentOffset.y
        let height = textView.frame.height
        let contentHeight = textView.contentSize.height
        return offset + height >= contentHeight - 20
    }

    func scrollToBottom(animated: Bool) {
        let contentHeight = textView.contentSize.height
        let frameHeight = textView.frame.height
        guard contentHeight > frameHeight else { return }
        let target = CGPoint(x: 0, y: contentHeight - frameHeight)
        textView.setContentOffset(target, animated: animated)
    }
}

// MARK: - Pane chip row

private struct PaneChipRow: View {
    let sessions: [Components.Schemas.AgentSession]
    let activeSessionID: Int64?
    let onSelect: (Components.Schemas.AgentSession) -> Void
    let onSpawn: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(sessions, id: \.id) { session in
                    PaneChip(
                        session: session,
                        isActive: session.id == activeSessionID,
                        onTap: { onSelect(session) }
                    )
                }
                // Spawn chip
                Button(action: onSpawn) {
                    Text("+")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 40)
        .background(Theme.Surface.terminalChrome)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
        }
    }
}

private struct PaneChip: View {
    let session: Components.Schemas.AgentSession
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 6, height: 6)
                    .opacity(session.state == .awaitingInput ? pulseOpacity : 1)
                    .animation(
                        session.state == .awaitingInput
                            ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                            : .default,
                        value: pulseOpacity
                    )
                Text("session-\(session.id)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(isActive ? .white : Color.white.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isActive
                    ? Color.white.opacity(0.14)
                    : Color.white.opacity(0.06),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(isActive ? Color.white.opacity(0.35) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onAppear { if session.state == .awaitingInput { pulseOpacity = 0.3 } }
    }

    @State private var pulseOpacity: Double = 1.0

    private var stateColor: Color {
        switch session.state {
        case .active:        return Theme.Semantic.green
        case .awaitingInput: return Theme.Semantic.orange
        case .idle:          return Color.white.opacity(0.35)
        default:             return Color.white.opacity(0.2)
        }
    }
}

// session-07 in the mock seed has id=802
#Preview("Terminal — session-07") {
    let appModel = AppModel(repository: MockTmuxAgentRepository())
    TerminalView(sessionID: 802)
        .environment(appModel)
}

#Preview("PaneChipRow — 4 chips") {
    let now = Date()
    let sessions: [Components.Schemas.AgentSession] = [
        Components.Schemas.AgentSession(id: 800, ticketId: nil, tmuxSession: "s1", state: .active, pane: "agent:0.0", cpu: 10, startTime: now, endTime: nil, lastActiveAt: now, transcriptKey: nil, tokenUsage: nil, costEstimate: nil, createdAt: now),
        Components.Schemas.AgentSession(id: 801, ticketId: nil, tmuxSession: "s2", state: .awaitingInput, pane: "agent:1.0", cpu: 0, startTime: now, endTime: nil, lastActiveAt: now, transcriptKey: nil, tokenUsage: nil, costEstimate: nil, createdAt: now),
        Components.Schemas.AgentSession(id: 802, ticketId: nil, tmuxSession: "s3", state: .active, pane: "agent:2.0", cpu: 5, startTime: now, endTime: nil, lastActiveAt: now, transcriptKey: nil, tokenUsage: nil, costEstimate: nil, createdAt: now),
        Components.Schemas.AgentSession(id: 803, ticketId: nil, tmuxSession: "s4", state: .idle, pane: "agent:3.0", cpu: 0, startTime: now, endTime: nil, lastActiveAt: now, transcriptKey: nil, tokenUsage: nil, costEstimate: nil, createdAt: now)
    ]
    PaneChipRow(sessions: sessions, activeSessionID: 802, onSelect: { _ in }, onSpawn: { })
        .background(Color.black)
        .preferredColorScheme(.dark)
}
