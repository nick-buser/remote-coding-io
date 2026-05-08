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
                Group {
                    if viewModel.renderedBuffer.characters.isEmpty {
                        Text(" ")
                    } else {
                        Text(viewModel.renderedBuffer)
                    }
                }
                .foregroundStyle(Theme.Text.fg(.dark))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .id("terminalBottom")
            }
            .frame(maxHeight: .infinity)
            .onChange(of: viewModel.renderedBuffer) {
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
