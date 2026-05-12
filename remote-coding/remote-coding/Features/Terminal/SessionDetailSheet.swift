import SwiftUI

/// Sheet presented from the terminal context bar's ··· menu.
///
/// Shows the session's scope context (ticket / feature / project), live stats
/// (state, CPU, uptime, token usage, cost), and a destructive "Kill session"
/// action that calls `killAgentSession` and dismisses.
struct SessionDetailSheet: View {
    let session: Components.Schemas.AgentSession
    let scopeContext: TerminalViewModel.ScopeContext?
    let onKill: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var isKilling = false
    @State private var killError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                    scopeBlock
                    statsBlock
                    killBlock
                }
                .padding(.horizontal, Theme.Spacing.s4)
                .padding(.vertical, Theme.Spacing.s3)
            }
            .background(Theme.Surface.bg(scheme))
            .navigationTitle("Session \(session.id)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Scope

    private var scopeBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
            Text("SCOPE")
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
            RoundedCard {
                if let ctx = scopeContext {
                    scopeRow(icon: scopeIcon(ctx.kind), label: ctx.label)
                    if let parent = ctx.parentLabel {
                        Divider().background(Theme.Surface.sep(scheme))
                        scopeRow(icon: "arrowshape.up", label: parent)
                    }
                } else {
                    scopeRow(icon: "terminal", label: session.tmuxSession)
                }
            }
        }
    }

    private func scopeRow(icon: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Text.fg2(scheme))
                .frame(width: 18)
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Theme.Text.fg(scheme))
                .lineLimit(2)
        }
        .padding(.vertical, 6)
    }

    private func scopeIcon(_ kind: TerminalViewModel.ScopeContext.Kind) -> String {
        switch kind {
        case .ticket:  return "ticket"
        case .feature: return "sparkles"
        case .project: return "folder"
        }
    }

    // MARK: - Stats

    private var statsBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
            Text("STATS")
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
            RoundedCard {
                VStack(spacing: 0) {
                    statRow(label: "State", value: stateLabel)
                    Divider().background(Theme.Surface.sep(scheme))
                    statRow(label: "Uptime", value: session.uptime)
                    Divider().background(Theme.Surface.sep(scheme))
                    statRow(label: "Started", value: InboxRelativeTime.short(session.startTime))
                    if session.cpu > 0 {
                        Divider().background(Theme.Surface.sep(scheme))
                        statRow(label: "CPU", value: String(format: "%.1f%%", session.cpu))
                    }
                    if let tokens = session.tokenUsage, !tokens.isEmpty {
                        Divider().background(Theme.Surface.sep(scheme))
                        statRow(label: "Tokens", value: tokens)
                    }
                    if let cost = session.costEstimate, cost > 0 {
                        Divider().background(Theme.Surface.sep(scheme))
                        statRow(label: "Est. cost", value: String(format: "$%.4f", cost))
                    }
                }
            }
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Text.fg2(scheme))
            Spacer()
            Text(value)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Theme.Text.fg(scheme))
        }
        .padding(.vertical, 10)
    }

    private var stateLabel: String {
        switch session.state {
        case .active:        return "Active"
        case .awaitingInput: return "Awaiting input"
        case .idle:          return "Idle"
        case .ended:         return "Ended"
        }
    }

    // MARK: - Kill

    private var killBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
            if let err = killError {
                Text(err)
                    .themeCaption()
                    .foregroundStyle(Theme.Semantic.orange)
            }
            if session.state != .ended {
                Button(role: .destructive) {
                    Task { await confirmKill() }
                } label: {
                    HStack {
                        if isKilling {
                            ProgressView().progressViewStyle(.circular).scaleEffect(0.8)
                        }
                        Text(isKilling ? "Killing…" : "Kill session")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 14)
                    .background(Theme.Semantic.red.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.r3, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.r3, style: .continuous)
                            .stroke(Theme.Semantic.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Semantic.red)
                .disabled(isKilling)
            }
        }
    }

    @MainActor
    private func confirmKill() async {
        isKilling = true
        killError = nil
        await onKill()
        isKilling = false
        dismiss()
    }
}

#Preview("SessionDetailSheet — ticket scope") {
    let now = Date()
    let session = Components.Schemas.AgentSession(
        id: 42, ticketId: 7, featureId: nil, projectId: nil,
        tmuxSession: "tmux-agent__auth__TMX-0042",
        state: .awaitingInput, pane: "agent:0.0", cpu: 12.4,
        startTime: now.addingTimeInterval(-3600), endTime: nil,
        lastActiveAt: now,
        transcriptKey: nil, tokenUsage: "128k", costEstimate: 0.0034,
        createdAt: now.addingTimeInterval(-3600)
    )
    let ctx = TerminalViewModel.ScopeContext(
        kind: .ticket,
        label: "TMX-0042 · Pane registry cleanup",
        parentLabel: "Terminal streaming · tmux-agent"
    )
    SessionDetailSheet(session: session, scopeContext: ctx, onKill: {})
}
