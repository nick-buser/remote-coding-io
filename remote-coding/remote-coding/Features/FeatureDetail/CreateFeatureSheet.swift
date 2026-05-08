import SwiftUI

/// Modal form for creating or editing a feature.
///
/// Create mode posts a `CreateFeatureRequest` against the parent
/// project. Edit mode pre-fills from the feature; the contract
/// only exposes `updateFeatureStatus` today, so non-status fields
/// render disabled and the submit only PATCHes status. A banner
/// at the top of the form explains the limitation.
struct CreateFeatureSheet: View {
    let parentSlug: String
    let existing: Components.Schemas.Feature?
    var onSubmitted: (Components.Schemas.Feature) -> Void

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var viewModel: CreateFeatureViewModel

    init(
        parentSlug: String,
        existing: Components.Schemas.Feature? = nil,
        onSubmitted: @escaping (Components.Schemas.Feature) -> Void
    ) {
        self.parentSlug = parentSlug
        self.existing = existing
        self.onSubmitted = onSubmitted
        _viewModel = State(initialValue: CreateFeatureViewModel(parentSlug: parentSlug, existing: existing))
    }

    var body: some View {
        NavigationStack {
            Form {
                bannerSection
                editModeNotice
                identitySection
                bodySection
                appearanceSection
                statusSection
            }
            .disabled(viewModel.isSubmitting)
            .navigationTitle(viewModel.mode == .create ? "New feature" : "Edit feature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                        } else {
                            Text(viewModel.mode == .create ? "Create" : "Save status")
                                .foregroundStyle(viewModel.accent.value(for: scheme))
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var bannerSection: some View {
        if let banner = viewModel.bannerError {
            Section {
                Text(banner)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.Semantic.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var editModeNotice: some View {
        if viewModel.mode == .edit {
            Section {
                Text("The backend only exposes status updates for features today. Other fields are read-only here; edit them via the project tools.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.Text.fg2(scheme))
            }
        }
    }

    private var identitySection: some View {
        @Bindable var binding = viewModel
        return Section("Identity") {
            VStack(alignment: .leading, spacing: 6) {
                TextField("Title", text: $binding.title)
                    .textInputAutocapitalization(.sentences)
                    .disabled(!viewModel.nonStatusFieldsAreEditable)
                    .onChange(of: viewModel.title) { _, newValue in
                        viewModel.titleChanged(newValue)
                    }
                fieldError(.title)
            }
            VStack(alignment: .leading, spacing: 6) {
                TextField("Slug", text: $binding.slug)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 14, design: .monospaced))
                    .disabled(!viewModel.nonStatusFieldsAreEditable)
                    .onChange(of: viewModel.slug) { _, newValue in
                        viewModel.slugChangedExternally(newValue)
                    }
                fieldError(.slug)
            }
            VStack(alignment: .leading, spacing: 6) {
                TextField("Branch name", text: $binding.branchName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 14, design: .monospaced))
                    .disabled(!viewModel.nonStatusFieldsAreEditable)
                    .onChange(of: viewModel.branchName) { _, newValue in
                        viewModel.branchChangedExternally(newValue)
                    }
                fieldError(.branchName)
            }
        }
    }

    private var bodySection: some View {
        @Bindable var binding = viewModel
        return Section("Details") {
            VStack(alignment: .leading, spacing: 6) {
                TextField("Vision (optional)", text: $binding.vision, axis: .vertical)
                    .lineLimit(3...8)
                    .textInputAutocapitalization(.sentences)
                    .disabled(!viewModel.nonStatusFieldsAreEditable)
                fieldError(.vision)
            }
            VStack(alignment: .leading, spacing: 6) {
                TextField("Milestone (optional)", text: $binding.milestone)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(!viewModel.nonStatusFieldsAreEditable)
                fieldError(.milestone)
            }
            VStack(alignment: .leading, spacing: 6) {
                TextField("Target date (e.g. May 12)", text: $binding.targetDate)
                    .disabled(!viewModel.nonStatusFieldsAreEditable)
                fieldError(.targetDate)
            }
            VStack(alignment: .leading, spacing: 6) {
                TextField("Tags (comma-separated)", text: $binding.tagsInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(!viewModel.nonStatusFieldsAreEditable)
                fieldError(.tags)
            }
        }
    }

    private var appearanceSection: some View {
        @Bindable var binding = viewModel
        return Section("Appearance") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Accent")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.Text.fg(scheme))
                AccentSwatchPicker(selection: $binding.accent)
                    .disabled(!viewModel.nonStatusFieldsAreEditable)
                fieldError(.accent)
            }
        }
    }

    private var statusSection: some View {
        @Bindable var binding = viewModel
        return Section("Status & health") {
            Picker("Status", selection: $binding.status) {
                Text("Planned").tag(Components.Schemas.FeatureStatus.planned)
                Text("In progress").tag(Components.Schemas.FeatureStatus.inProgress)
                Text("Review").tag(Components.Schemas.FeatureStatus.review)
                Text("Shipped").tag(Components.Schemas.FeatureStatus.shipped)
                Text("Merged").tag(Components.Schemas.FeatureStatus.merged)
                Text("Abandoned").tag(Components.Schemas.FeatureStatus.abandoned)
            }
            VStack(alignment: .leading, spacing: 6) {
                TextField("Health (e.g. on-track, at-risk)", text: $binding.health)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(!viewModel.nonStatusFieldsAreEditable)
                fieldError(.health)
            }
        }
    }

    // MARK: - Field error helper

    @ViewBuilder
    private func fieldError(_ field: CreateFeatureViewModel.Field) -> some View {
        if let message = viewModel.fieldErrors[field] {
            Text(message)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.Semantic.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Submit

    private func submit() async {
        await viewModel.submit(repository: appModel.repository) { feature in
            onSubmitted(feature)
            dismiss()
        }
    }
}

#Preview("CreateFeatureSheet — new") {
    CreateFeatureSheet(parentSlug: "tmux-server-coding-app") { _ in }
        .environment(AppModel(repository: MockTmuxAgentRepository()))
}
