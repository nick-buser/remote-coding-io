import SwiftUI

// Operates on `LocalProjectNote` only. Feature-level docs use the
// generated `Components.Schemas.Doc` type whose `body_blocks` is opaque
// TipTap JSON; the renderer for that surface ships with
// `service-feature-prd-tab`.
struct DocumentEditorView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: DocumentEditorViewModel

    init(document: LocalProjectNote) {
        _viewModel = State(initialValue: DocumentEditorViewModel(document: document))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.red.opacity(0.08))
            }

            RunestoneTextSurface(
                text: Binding(
                    get: { viewModel.draft },
                    set: { viewModel.draft = $0 }
                ),
                isEditable: true
            )
        }
        .navigationTitle(viewModel.document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                Task {
                    await viewModel.save(repository: appModel.repository)
                }
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Label("Save", systemImage: "checkmark")
                }
            }
            .disabled(!viewModel.hasChanges || viewModel.isSaving)
        }
    }
}
