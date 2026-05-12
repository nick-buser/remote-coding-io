import SwiftUI

/// Doc viewer + editor mounted on `.docDetail(docID:)`.
///
/// In view mode renders the title/meta hero + `DocBlockRenderer`.
/// In edit mode the hero collapses to a `TextField` and the body is
/// replaced by a Runestone-backed Markdown editor. Tapping "Done"
/// re-encodes the Markdown through `DocMarkdownParser` + `DocTipTapEncoder`
/// and calls `updateDoc`.
struct DocViewerView: View {
    let docID: Int64

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var doc: Components.Schemas.Doc?
    @State private var feature: Components.Schemas.Feature?
    @State private var blocks: [DocBlock] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didDelete = false

    // Edit mode
    @State private var isEditing = false
    @State private var draftTitle = ""
    @State private var draftMarkdown = ""
    @State private var isSaving = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                editorLayout
            } else {
                viewerLayout
            }
        }
        .background(Theme.Surface.bg(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .task(id: docID) {
            await load()
        }
        .refreshable {
            await load()
        }
        .onChange(of: didDelete) { _, finished in
            if finished { dismiss() }
        }
    }

    // MARK: - Viewer layout

    private var viewerLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                topBar
                if let doc {
                    hero(for: doc)
                    if blocks.isEmpty {
                        emptyBody
                    } else {
                        DocBlockRenderer(blocks: blocks)
                            .padding(.horizontal, Theme.Spacing.s4)
                    }
                } else if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Theme.Spacing.s5)
                } else if let errorMessage {
                    EmptyState(systemImage: "wifi.exclamationmark", title: "Couldn't load doc", message: errorMessage)
                }
            }
            .padding(.bottom, Theme.Spacing.s5)
        }
    }

    // MARK: - Editor layout

    private var editorLayout: some View {
        VStack(spacing: 0) {
            editorTopBar
            Divider().background(Theme.Surface.sep(scheme))
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    titleField
                    Divider()
                        .padding(.horizontal, Theme.Spacing.s4)
                        .padding(.vertical, Theme.Spacing.s2)
                    RunestoneTextSurface(
                        attributedText: AttributedString(draftMarkdown),
                        isEditable: true,
                        onChange: { draftMarkdown = $0 },
                        theme: .docLight
                    )
                    .frame(minHeight: 420)
                }
                .padding(.bottom, Theme.Spacing.s5)
            }
        }
    }

    private var editorTopBar: some View {
        HStack {
            Button("Cancel") {
                isEditing = false
            }
            .foregroundStyle(Theme.Text.fg2(scheme))
            Spacer()
            Text("Edit Doc")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Text.fg(scheme))
            Spacer()
            Button(isSaving ? "Saving…" : "Done") {
                Task { await commitEdits() }
            }
            .disabled(isSaving)
            .foregroundStyle(appModel.accent.value(for: scheme))
            .fontWeight(.semibold)
        }
        .padding(.horizontal, Theme.Spacing.s4)
        .padding(.vertical, 12)
    }

    private var titleField: some View {
        TextField("Title", text: $draftTitle)
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(Theme.Text.fg(scheme))
            .padding(.horizontal, Theme.Spacing.s4)
            .padding(.top, Theme.Spacing.s3)
            .padding(.bottom, Theme.Spacing.s2)
            .focused($titleFocused)
    }

    // MARK: - Viewer sub-views

    private var topBar: some View {
        QuietHeader(label: doc?.title ?? "Doc") {
            BackChevron(label: "Back", accent: appModel.accent) { dismiss() }
        } trailing: {
            Menu {
                Button("Edit") { enterEditMode() }
                    .disabled(doc == nil)
                Button(doc?.pinned == true ? "Unpin" : "Pin") {
                    Task { await togglePin() }
                }
                .disabled(doc == nil)
                Button(role: .destructive) {
                    Task { await deleteDoc() }
                } label: {
                    Text("Delete")
                }
                .disabled(doc == nil)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Text.fg(scheme))
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Doc actions")
        }
    }

    private func hero(for doc: Components.Schemas.Doc) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow(for: doc))
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
            HStack(spacing: 8) {
                Text(doc.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.Text.fg(scheme))
                    .lineLimit(2)
                if doc.pinned {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Semantic.yellow)
                }
            }
            Text("\(doc.wordCount) word\(doc.wordCount == 1 ? "" : "s") · updated \(InboxRelativeTime.short(doc.updatedAt))")
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
        }
        .padding(.horizontal, Theme.Spacing.s4)
    }

    private var emptyBody: some View {
        EmptyState(
            systemImage: "doc.append",
            title: "No content yet",
            message: "Tap ··· → Edit to start writing."
        )
    }

    private func eyebrow(for doc: Components.Schemas.Doc) -> String {
        let kind = FeaturePRDTab.label(for: doc.kind).uppercased()
        if let feature {
            return "FEAT-\(String(format: "%03d", feature.id)) · \(kind)"
        }
        return kind
    }

    // MARK: - Actions

    private func enterEditMode() {
        guard let doc else { return }
        draftTitle = doc.title
        draftMarkdown = DocMarkdownSerializer.serialize(blocks)
        isEditing = true
    }

    @MainActor
    private func commitEdits() async {
        guard let current = doc else { return }
        isSaving = true
        defer { isSaving = false }
        let newBlocks = DocMarkdownParser.parse(draftMarkdown)
        let newBodyBlocks = DocTipTapEncoder.encode(newBlocks)
        let titleChanged = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines) != current.title
        let body = Components.Schemas.UpdateDocRequest(
            kind: nil,
            title: titleChanged ? draftTitle.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            bodyBlocks: newBodyBlocks,
            pinned: nil
        )
        do {
            let updated = try await appModel.repository.updateDoc(id: current.id, body: body)
            doc = updated
            blocks = DocBlockDecoder.decode(updated.bodyBlocks)
            isEditing = false
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loadedDoc = try await appModel.repository.getDoc(id: docID)
            doc = loadedDoc
            blocks = DocBlockDecoder.decode(loadedDoc.bodyBlocks)
            feature = try? await appModel.repository.getFeature(id: loadedDoc.featureId)
        } catch {
            errorMessage = "Couldn't load doc: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func togglePin() async {
        guard let current = doc else { return }
        let body = Components.Schemas.UpdateDocRequest(
            kind: nil,
            title: nil,
            bodyBlocks: nil,
            pinned: !current.pinned
        )
        do {
            doc = try await appModel.repository.updateDoc(id: current.id, body: body)
        } catch {
            errorMessage = "Couldn't update pin: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func deleteDoc() async {
        guard let current = doc else { return }
        do {
            try await appModel.repository.deleteDoc(id: current.id)
            didDelete = true
        } catch {
            errorMessage = "Couldn't delete doc: \(error.localizedDescription)"
        }
    }
}

#Preview("DocViewer — light") {
    let appModel = AppModel(repository: MockTmuxAgentRepository())
    return NavigationStack {
        DocViewerView(docID: 1)
    }
    .environment(appModel)
}

#Preview("DocViewer — dark") {
    let appModel = AppModel(repository: MockTmuxAgentRepository())
    return NavigationStack {
        DocViewerView(docID: 1)
    }
    .environment(appModel)
    .preferredColorScheme(.dark)
}
