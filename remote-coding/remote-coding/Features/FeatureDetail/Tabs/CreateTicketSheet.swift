import SwiftUI

/// Modal sheet for creating a new ticket scoped to a feature.
///
/// Submits via `repository.createTicket(featureID:body:)` and hands the
/// new ticket back to the parent view-model so the list updates without
/// a full reload.
struct CreateTicketSheet: View {
    let featureID: Int64
    let accent: AccentColor
    var onCreated: (Components.Schemas.Ticket) -> Void

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var status: Components.Schemas.TicketStatus = .todo
    @State private var estimate: String = ""
    @State private var branchName: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Required", text: $title, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Description") {
                    TextField("Optional context", text: $description, axis: .vertical)
                        .lineLimit(3...8)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Status") {
                    Picker("Status", selection: $status) {
                        Text("Todo").tag(Components.Schemas.TicketStatus.todo)
                        Text("Doing").tag(Components.Schemas.TicketStatus.doing)
                        Text("Review").tag(Components.Schemas.TicketStatus.review)
                        Text("Done").tag(Components.Schemas.TicketStatus.done)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Details") {
                    TextField("Estimate (S, M, L, XL)", text: $estimate)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Branch name (optional)", text: $branchName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Theme.Semantic.red)
                            .font(.system(size: 13))
                    }
                }
            }
            .navigationTitle("New ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Create")
                                .foregroundStyle(accent.value(for: scheme))
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let trimmedBranch = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEstimate = estimate.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = Components.Schemas.CreateTicketRequest(
            title: trimmedTitle,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            status: status,
            estimate: trimmedEstimate.isEmpty ? nil : trimmedEstimate,
            branchName: trimmedBranch.isEmpty ? nil : trimmedBranch
        )
        do {
            let created = try await appModel.repository.createTicket(featureID: featureID, body: body)
            onCreated(created)
            dismiss()
        } catch {
            errorMessage = "Couldn't create ticket: \(error.localizedDescription)"
        }
    }
}
