import SwiftUI

/// Bottom input bar for the terminal — mono text field with an accent
/// send button. Long-press the button to choose between "Send + Enter"
/// (default), "Send only", or "Enter only". The send mode is persisted
/// for the session lifetime.
struct TerminalInputBar: View {
    @Binding var text: String
    let accent: AccentColor
    let isSending: Bool
    let lastPromptHint: String?
    let onSend: (SendMode) -> Void

    enum SendMode: String, CaseIterable, Identifiable {
        case sendAndEnter = "Send + Enter"
        case sendOnly     = "Send"
        case enterOnly    = "Enter only"
        var id: String { rawValue }
    }

    @State private var sendMode: SendMode = .sendAndEnter
    @State private var showDraftSheet = false

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Theme.Text.fg(.dark))
                .tint(accent.value(for: scheme))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.Surface.terminalInput, in: Capsule())
                .onSubmit { fireDefault() }
                .onLongPressGesture { showDraftSheet = true }

            sendButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.Surface.terminalChrome)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
        }
        .sheet(isPresented: $showDraftSheet) {
            MultilineDraftSheet(text: $text, sendMode: sendMode, accent: accent) { mode in
                sendMode = mode
                fireDefault()
                showDraftSheet = false
            }
        }
    }

    // MARK: - Send button

    private var sendButton: some View {
        Button(action: fireDefault) {
            ZStack {
                if isSending {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 34, height: 34)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                }
            }
            .background(accent.value(for: scheme), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(isSending)
        .contextMenu {
            ForEach(SendMode.allCases) { mode in
                Button {
                    sendMode = mode
                    onSend(mode)
                } label: {
                    Label(
                        mode.rawValue,
                        systemImage: sendMode == mode ? "checkmark.circle.fill" : "circle"
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private var placeholder: String {
        lastPromptHint ?? "send a command…"
    }

    private func fireDefault() {
        if text.isEmpty {
            onSend(.enterOnly)
        } else {
            onSend(sendMode)
        }
    }
}

// MARK: - Multiline draft sheet

private struct MultilineDraftSheet: View {
    @Binding var text: String
    let sendMode: TerminalInputBar.SendMode
    let accent: AccentColor
    let onSend: (TerminalInputBar.SendMode) -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Theme.Text.fg(scheme))
                .scrollContentBackground(.hidden)
                .background(Theme.Surface.bg(scheme))
                .padding()
                .navigationTitle("Draft")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Send") { onSend(sendMode) }
                            .tint(accent.value(for: scheme))
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Prompt hint parser

extension TerminalInputBar {
    /// Extracts the last agent prompt from raw buffer content. Looks for lines
    /// ending in "›" or ">" that suggest an interactive prompt. Returns nil
    /// when no such line is found; callers fall back to "send a command…".
    static func extractPromptHint(from raw: String) -> String? {
        let lines = raw.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let last = lines.last else { return nil }
        let trimmed = last.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix("›") || trimmed.hasSuffix(">") || trimmed.hasSuffix("$") || trimmed.hasSuffix("%") else {
            return nil
        }
        // Truncate to a reasonable hint length
        return String(trimmed.prefix(40))
    }
}

#Preview("TerminalInputBar — idle") {
    TerminalInputBar(
        text: .constant(""),
        accent: .iris,
        isSending: false,
        lastPromptHint: "agent › ",
        onSend: { _ in }
    )
    .background(Color.black)
    .preferredColorScheme(.dark)
}

#Preview("TerminalInputBar — sending") {
    TerminalInputBar(
        text: .constant("ls -la"),
        accent: .iris,
        isSending: true,
        lastPromptHint: nil,
        onSend: { _ in }
    )
    .background(Color.black)
    .preferredColorScheme(.dark)
}
