import SwiftUI

/// Modal form for creating a new project.
///
/// Hosts a `CreateProjectViewModel`; on success the sheet dismisses
/// and hands the new `Project` to the parent via `onCreated`. The
/// caller decides whether to push detail / refresh the list.
struct CreateProjectSheet: View {
    var onCreated: (Components.Schemas.Project) -> Void

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var viewModel = CreateProjectViewModel()

    var body: some View {
        NavigationStack {
            Form {
                bannerSection
                identitySection
                metaSection
                appearanceSection
                statusSection
            }
            .disabled(viewModel.isSubmitting)
            .navigationTitle("New project")
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
                            Text("Create")
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

    private var identitySection: some View {
        @Bindable var binding = viewModel
        return Section("Identity") {
            VStack(alignment: .leading, spacing: 6) {
                TextField("Name", text: $binding.name)
                    .textInputAutocapitalization(.words)
                    .onChange(of: viewModel.name) { _, newName in
                        viewModel.nameChanged(newName)
                    }
                fieldError(.name)
            }
            VStack(alignment: .leading, spacing: 6) {
                TextField("Slug", text: $binding.slug)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 14, design: .monospaced))
                    .onChange(of: viewModel.slug) { oldValue, newValue in
                        // Skip the auto-derived edits coming from `nameChanged`.
                        if !viewModel.slugWasManuallyEdited, newValue != CreateProjectViewModel.deriveSlug(from: viewModel.name) {
                            viewModel.slugWasManuallyEdited = true
                        }
                    }
                fieldError(.slug)
            }
            VStack(alignment: .leading, spacing: 6) {
                TextField("Local repo path", text: $binding.localRepoPath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 14, design: .monospaced))
                fieldError(.localRepoPath)
            }
        }
    }

    private var metaSection: some View {
        @Bindable var binding = viewModel
        return Section("Details") {
            VStack(alignment: .leading, spacing: 6) {
                TextField("Git repo URL (optional)", text: $binding.gitRepoUrl)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                fieldError(.gitRepoUrl)
            }
            VStack(alignment: .leading, spacing: 6) {
                TextField("Tagline (optional)", text: $binding.tagline)
                    .textInputAutocapitalization(.sentences)
                fieldError(.tagline)
            }
            VStack(alignment: .leading, spacing: 6) {
                TextField("Description (optional)", text: $binding.description, axis: .vertical)
                    .lineLimit(3...8)
                    .textInputAutocapitalization(.sentences)
                fieldError(.description)
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
                fieldError(.accent)
            }
            VStack(alignment: .leading, spacing: 6) {
                TextField("Icon (single char or emoji)", text: $binding.icon)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.icon) { _, newValue in
                        if newValue.count > 4 {
                            viewModel.icon = String(newValue.prefix(4))
                        }
                    }
                fieldError(.icon)
            }
        }
    }

    private var statusSection: some View {
        @Bindable var binding = viewModel
        return Section("Status") {
            Picker("Status", selection: $binding.status) {
                Text("Active").tag(Components.Schemas.ProjectStatus.active)
                Text("Maint.").tag(Components.Schemas.ProjectStatus.maintenance)
                Text("Paused").tag(Components.Schemas.ProjectStatus.paused)
            }
            .pickerStyle(.segmented)
            fieldError(.status)
            Toggle("Pinned", isOn: $binding.pinned)
            fieldError(.pinned)
        }
    }

    // MARK: - Field error helper

    @ViewBuilder
    private func fieldError(_ field: CreateProjectViewModel.Field) -> some View {
        if let message = viewModel.fieldErrors[field] {
            Text(message)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.Semantic.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Submit

    private func submit() async {
        await viewModel.submit(repository: appModel.repository) { project in
            onCreated(project)
            dismiss()
        }
    }
}

#Preview("CreateProjectSheet") {
    CreateProjectSheet { _ in }
        .environment(AppModel(repository: MockTmuxAgentRepository()))
}
