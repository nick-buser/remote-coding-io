import SwiftUI

/// Inline reply sheet for question-kind Inbox rows.
///
/// Per the ticket note this is a deliberate hand-off: the sheet
/// composes a single text body and ships it through
/// `repository.sendPaneInput` with `enter: true`. A richer reply
/// experience (with structured kinds, draft persistence, etc.) is
/// out of scope for service-0013.
struct ReplySheet: View {
    let context: ReplyContext

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var bodyText: String = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                Text("Replying to \(context.ticketPublicID ?? "session")")
                    .themeCaption()
                    .foregroundStyle(Theme.Text.fg2(scheme))
                    .padding(.horizontal, Theme.Spacing.s4)
                    .padding(.top, Theme.Spacing.s4)

                TextEditor(text: $bodyText)
                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                    .padding(.horizontal, Theme.Spacing.s4)
                    .frame(minHeight: 120)

                if let errorMessage {
                    Text(errorMessage)
                        .themeCaption()
                        .foregroundStyle(Theme.Semantic.red)
                        .padding(.horizontal, Theme.Spacing.s4)
                }

                Spacer()
            }
            .background(Theme.Surface.bg(scheme))
            .navigationTitle("Reply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await send() }
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("Send")
                        }
                    }
                    .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
            }
        }
    }

    private func send() async {
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        isSending = true
        defer { isSending = false }
        do {
            _ = try await appModel.repository.sendPaneInput(
                sessionName: context.sessionName,
                paneID: context.paneID,
                body: Components.Schemas.SendInputRequest(text: trimmed, keys: nil, enter: true)
            )
            dismiss()
        } catch {
            errorMessage = "Send failed: \(error.localizedDescription)"
        }
    }
}
