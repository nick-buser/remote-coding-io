import SwiftUI

/// Feature detail PRD sub-tab — kind filter row, doc list, and a
/// `+ New doc` footer that opens `CreateDocSheet`.
///
/// The sub-tab consumes the `FeatureDetailViewModel` directly so newly
/// created docs land in the local list without a full reload. Doc
/// selection pushes `.docDetail(docID:)`, which `ContentView` resolves
/// via `DocViewerDestination`.
struct FeaturePRDTab: View {
    @Bindable var viewModel: FeatureDetailViewModel
    let accent: AccentColor
    var onSelect: (Components.Schemas.Doc) -> Void

    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var scheme

    @State private var selectedKind: Components.Schemas.DocKind?  // nil = All
    @State private var showCreateSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
            kindFilter
            content
            footer
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateDocSheet(featureID: viewModel.feature.id, accent: accent) { created in
                viewModel.docs.insert(created, at: 0)
            }
        }
    }

    // MARK: - Kind filter

    private var kindFilter: some View {
        let kindsPresent = Set(viewModel.docs.map(\.kind))
        let kinds = Self.knownKinds.filter { kindsPresent.contains($0) }
        return Group {
            if !kinds.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            selectedKind = nil
                        } label: {
                            Chip(label: "All", count: viewModel.docs.count, active: selectedKind == nil)
                        }
                        .buttonStyle(.plain)
                        ForEach(kinds, id: \.self) { kind in
                            Button {
                                selectedKind = kind
                            } label: {
                                Chip(
                                    label: Self.label(for: kind),
                                    count: viewModel.docs.filter { $0.kind == kind }.count,
                                    active: selectedKind == kind
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.s4)
                }
            }
        }
    }

    // MARK: - List

    @ViewBuilder
    private var content: some View {
        let visible = sortedDocs
        if viewModel.docs.isEmpty {
            EmptyState(
                systemImage: "doc.text",
                title: "No docs yet",
                message: "Add a PRD or design note to capture this feature's plan."
            )
        } else if visible.isEmpty {
            EmptyState(
                systemImage: "line.3.horizontal.decrease",
                title: "No docs match",
                message: "Switch to All to see every doc in this feature."
            )
        } else {
            RoundedCard {
                VStack(spacing: 8) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, doc in
                        if index > 0 {
                            Divider().background(Theme.Surface.sep(scheme))
                        }
                        FeatureDocRow(doc: doc) { onSelect(doc) }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            PillButton(title: "+ New doc", role: .secondary, accent: accent, wide: true) {
                showCreateSheet = true
            }
        }
        .padding(.horizontal, Theme.Spacing.s4)
        .padding(.top, Theme.Spacing.s2)
    }

    // MARK: - Sorting / labels

    private var sortedDocs: [Components.Schemas.Doc] {
        let filtered = selectedKind.map { kind in
            viewModel.docs.filter { $0.kind == kind }
        } ?? viewModel.docs
        return filtered.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned {
                return lhs.pinned && !rhs.pinned
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    static let knownKinds: [Components.Schemas.DocKind] = [.vision, .prd, .design, .notes, .log, .custom]

    static func label(for kind: Components.Schemas.DocKind) -> String {
        switch kind {
        case .vision: return "Vision"
        case .prd:    return "PRD"
        case .design: return "Design"
        case .notes:  return "Notes"
        case .log:    return "Log"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Row

/// PRD-tab-specific doc row. Denser than
/// `Features/Projects/Detail/DocRow.swift` — drops the parent feature
/// label (the surrounding screen already scopes to one feature) and
/// surfaces an updated-relative timestamp.
struct FeatureDocRow: View {
    let doc: Components.Schemas.Doc
    var onTap: () -> Void = {}

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Theme.Spacing.s3) {
                Image(systemName: kindSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Text.fg2(scheme))
                    .frame(width: 22, height: 22)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    titleLine
                    metaLine
                }
                Spacer(minLength: 0)
                Chevron()
                    .padding(.top, 2)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var titleLine: some View {
        HStack(spacing: 6) {
            Text(doc.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Text.fg(scheme))
                .lineLimit(1)
            if doc.pinned {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Semantic.yellow)
            }
        }
    }

    private var metaLine: some View {
        HStack(spacing: 4) {
            Text("\(doc.wordCount) word\(doc.wordCount == 1 ? "" : "s")")
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
            Text("·")
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
            Text("updated \(InboxRelativeTime.short(doc.updatedAt))")
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
        }
    }

    private var kindSymbol: String {
        switch doc.kind {
        case .vision: return "lightbulb"
        case .prd:    return "doc.text"
        case .design: return "ruler"
        case .notes:  return "note.text"
        case .log:    return "list.bullet.rectangle"
        case .custom: return "doc"
        }
    }
}

// MARK: - Create sheet

/// Modal create form for a new feature doc.
struct CreateDocSheet: View {
    let featureID: Int64
    let accent: AccentColor
    var onCreated: (Components.Schemas.Doc) -> Void

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var title: String = ""
    @State private var kind: Components.Schemas.DocKind = .prd
    @State private var pinned: Bool = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Required", text: $title)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Kind") {
                    Picker("Kind", selection: $kind) {
                        ForEach(FeaturePRDTab.knownKinds, id: \.self) { kind in
                            Text(FeaturePRDTab.label(for: kind)).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Toggle("Pinned", isOn: $pinned)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Theme.Semantic.red)
                            .font(.system(size: 13))
                    }
                }
            }
            .navigationTitle("New doc")
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
        let body = Components.Schemas.CreateDocRequest(
            kind: kind,
            title: trimmedTitle,
            bodyBlocks: nil,
            pinned: pinned
        )
        do {
            let created = try await appModel.repository.createFeatureDoc(featureID: featureID, body: body)
            onCreated(created)
            dismiss()
        } catch {
            errorMessage = "Couldn't create doc: \(error.localizedDescription)"
        }
    }
}
