import Foundation
import Observation

@MainActor
@Observable
final class DocumentEditorViewModel {
    var document: LocalProjectNote
    var draft: String
    var isSaving = false
    var errorMessage: String?

    init(document: LocalProjectNote) {
        self.document = document
        draft = document.body
    }

    var hasChanges: Bool {
        draft != document.body
    }

    func save(repository: TmuxAgentRepository) async {
        isSaving = true
        errorMessage = nil
        do {
            var updated = document
            updated.body = draft
            document = try await repository.saveDocument(updated)
            draft = document.body
        } catch {
            errorMessage = "Unable to save document."
        }
        isSaving = false
    }
}
