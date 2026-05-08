import SwiftUI

/// Feature detail Decisions sub-tab — append-only list newest-first
/// plus a `+ Log decision` footer button. Decisions render as quiet
/// prose (no `RoundedCard` wrapper, just timestamp / title / body /
/// trailing actor chip).
struct FeatureDecisionsTab: View {
    @Bindable var viewModel: FeatureDetailViewModel
    let accent: AccentColor

    @Environment(AppModel.self) private var appModel
    @Environment(UserPreferences.self) private var prefs
    @Environment(\.colorScheme) private var scheme

    @State private var showLogSheet = false
    @State private var decisionPendingDeletion: Components.Schemas.Decision?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
            content
            footer
        }
        .sheet(isPresented: $showLogSheet) {
            LogDecisionSheet(
                featureID: viewModel.feature.id,
                accent: accent,
                defaultActorName: prefs.displayName
            ) { created in
                viewModel.decisions.insert(created, at: 0)
            }
        }
        .confirmationDialog(
            "Remove decision?",
            isPresented: Binding(
                get: { decisionPendingDeletion != nil },
                set: { if !$0 { decisionPendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: decisionPendingDeletion
        ) { decision in
            Button("Remove", role: .destructive) {
                Task { await delete(decision) }
            }
            Button("Cancel", role: .cancel) {
                decisionPendingDeletion = nil
            }
        } message: { decision in
            Text("This is for typo recovery; the decision log is otherwise append-only.\n\n“\(decision.title)”")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let sorted = viewModel.decisions.sorted { $0.createdAt > $1.createdAt }
        if sorted.isEmpty {
            EmptyState(
                systemImage: "scribble.variable",
                title: "No decisions yet",
                message: "Log decisions as you make them so the next reader sees the why."
            )
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                ForEach(sorted, id: \.id) { decision in
                    DecisionRow(decision: decision)
                        .contextMenu {
                            Button(role: .destructive) {
                                decisionPendingDeletion = decision
                            } label: {
                                Label("Remove (typo)", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        PillButton(title: "+ Log decision", role: .secondary, accent: accent, wide: true) {
            showLogSheet = true
        }
        .padding(.horizontal, Theme.Spacing.s4)
        .padding(.top, Theme.Spacing.s2)
    }

    // MARK: - Delete

    @MainActor
    private func delete(_ decision: Components.Schemas.Decision) async {
        do {
            try await appModel.repository.deleteDecision(id: decision.id)
            viewModel.decisions.removeAll { $0.id == decision.id }
        } catch {
            viewModel.errorMessage = "Couldn't remove decision: \(error.localizedDescription)"
        }
        decisionPendingDeletion = nil
    }
}

// MARK: - Row

struct DecisionRow: View {
    let decision: Components.Schemas.Decision

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(InboxRelativeTime.short(decision.createdAt))
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
                Spacer(minLength: 8)
                actorChip
            }
            Text(decision.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Text.fg(scheme))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let body = decision.body, !body.isEmpty {
                Text(body)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(Theme.Text.fg2(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var actorChip: some View {
        let label = displayActorLabel
        switch decision.actor {
        case .agent:
            Text(label)
                .themeMonoSm()
                .foregroundStyle(AccentColor.iris.value(for: scheme))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(AccentColor.iris.value(for: scheme).opacity(0.14))
                )
        case .human:
            Text(label)
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Theme.Surface.chip(scheme))
                )
        }
    }

    private var displayActorLabel: String {
        if let name = decision.actorName, !name.isEmpty {
            return name
        }
        switch decision.actor {
        case .agent: return "agent"
        case .human: return "human"
        }
    }
}

// MARK: - Log decision sheet

struct LogDecisionSheet: View {
    let featureID: Int64
    let accent: AccentColor
    let defaultActorName: String
    var onCreated: (Components.Schemas.Decision) -> Void

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var title: String = ""
    @State private var body: String = ""
    @State private var actor: Components.Schemas.DecisionActor = .human
    @State private var actorName: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("What did you decide?", text: $title, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Body") {
                    TextField("Why? (optional)", text: $body, axis: .vertical)
                        .lineLimit(3...8)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Actor") {
                    Picker("Actor", selection: $actor) {
                        Text("Human").tag(Components.Schemas.DecisionActor.human)
                        Text("Agent").tag(Components.Schemas.DecisionActor.agent)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: actor) { _, newValue in
                        if newValue == .human, actorName.trimmingCharacters(in: .whitespaces).isEmpty {
                            actorName = defaultActorName
                        }
                    }
                    TextField("Actor name", text: $actorName)
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
            .navigationTitle("Log decision")
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
                            Text("Log")
                                .foregroundStyle(accent.value(for: scheme))
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .task {
                if actorName.trimmingCharacters(in: .whitespaces).isEmpty {
                    actorName = defaultActorName
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
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedActor = actorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = Components.Schemas.CreateDecisionRequest(
            title: trimmedTitle,
            body: trimmedBody.isEmpty ? nil : trimmedBody,
            actor: actor,
            actorName: trimmedActor.isEmpty ? nil : trimmedActor
        )
        do {
            let created = try await appModel.repository.createFeatureDecision(featureID: featureID, body: request)
            onCreated(created)
            dismiss()
        } catch {
            errorMessage = "Couldn't log decision: \(error.localizedDescription)"
        }
    }
}
