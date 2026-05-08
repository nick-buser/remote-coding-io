import SwiftUI

/// Read-only doc viewer mounted on `.docDetail(docID:)`.
///
/// Loads the doc via `repository.getDoc(id:)`, renders its title +
/// meta eyebrow, then hands `body_blocks` off to `DocBlockRenderer`.
/// The trailing dots menu wires `Pin / Unpin` (via `updateDoc`) and
/// `Delete` (via `deleteDoc`); editing the body is intentionally
/// out of scope and lands with the Runestone integration in
/// Phase 4 / 5.
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

    var body: some View {
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

    private var topBar: some View {
        QuietHeader(label: doc?.title ?? "Doc") {
            BackChevron(label: "Back", accent: appModel.accent) { dismiss() }
        } trailing: {
            Menu {
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
            message: "This doc has an empty body. Editing arrives with the Runestone integration."
        )
    }

    private func eyebrow(for doc: Components.Schemas.Doc) -> String {
        let kind = FeaturePRDTab.label(for: doc.kind).uppercased()
        if let feature {
            return "FEAT-\(String(format: "%03d", feature.id)) · \(kind)"
        }
        return kind
    }

    // MARK: - Load + actions

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
