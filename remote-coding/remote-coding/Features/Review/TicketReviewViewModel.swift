import Foundation
import Observation

/// View model for the Ticket review screen.
///
/// Loads the ticket, its acceptance criteria, and the pre-computed
/// `TicketDiff` in parallel. Exposes derived `Stats` (added /
/// removed line totals + file count) so the header pill renders
/// without recomputing the diff.
@MainActor
@Observable
final class TicketReviewViewModel {
    var ticket: Components.Schemas.Ticket?
    var criteria: [Components.Schemas.AcceptanceCriterion] = []
    var diff: Components.Schemas.TicketDiff?
    var isLoading = false
    var errorMessage: String?
    /// Set after `approveTicket` / `requestTicketChanges` /
    /// `sendTicketBack` succeed; the view watches this and pops.
    var didFinishAction = false

    let publicID: String

    init(publicID: String) {
        self.publicID = publicID
    }

    // MARK: - Header derived

    struct DiffStats: Equatable, Sendable {
        var adds: Int
        var dels: Int
        var fileCount: Int
    }

    var diffStats: DiffStats {
        guard let files = diff?.files else { return DiffStats(adds: 0, dels: 0, fileCount: 0) }
        var adds = 0
        var dels = 0
        for file in files where file.binary != true {
            let old = file.oldContent ?? ""
            let new = file.newContent ?? ""
            let s = UnifiedDiff.summary(old: old, new: new)
            adds += s.adds
            dels += s.dels
        }
        return DiffStats(adds: adds, dels: dels, fileCount: files.count)
    }

    var statusRole: StatusGlyphRole {
        TicketStatusStyle.glyphRole(for: ticket?.status ?? .review)
    }

    var statusLabel: String {
        TicketStatusStyle.label(for: ticket?.status ?? .review)
    }

    var checklistDone: Int {
        criteria.filter(\.done).count
    }

    var checklistTotal: Int {
        criteria.count
    }

    /// Group files by change type for the Files sub-tab.
    func filesByChange() -> [(label: String, files: [Components.Schemas.FileDiff])] {
        guard let files = diff?.files else { return [] }
        let groups: [(label: String, change: Components.Schemas.FileChange)] = [
            ("Added", .added),
            ("Modified", .modified),
            ("Deleted", .deleted),
            ("Renamed", .renamed)
        ]
        return groups.compactMap { spec in
            let matching = files.filter { $0.change == spec.change }
            return matching.isEmpty ? nil : (label: spec.label, files: matching)
        }
    }

    // MARK: - Load

    func load(repository: TmuxAgentRepository) async {
        isLoading = true
        errorMessage = nil
        do {
            async let loadedTicket   = repository.getTicket(publicID: publicID)
            async let loadedCriteria = repository.listCriteria(ticketPublicID: publicID)
            async let loadedDiff     = repository.getTicketDiff(publicID: publicID)
            ticket = try await loadedTicket
            criteria = try await loadedCriteria
            diff = try await loadedDiff
        } catch {
            errorMessage = "Couldn't load review: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Actions

    func approve(repository: TmuxAgentRepository) async {
        do {
            _ = try await repository.approveTicket(publicID: publicID)
            didFinishAction = true
        } catch {
            errorMessage = "Approve failed: \(error.localizedDescription)"
        }
    }

    func requestChanges(comment: String?, repository: TmuxAgentRepository) async {
        do {
            _ = try await repository.requestTicketChanges(publicID: publicID, comment: comment)
            didFinishAction = true
        } catch {
            errorMessage = "Request changes failed: \(error.localizedDescription)"
        }
    }

    func sendBack(comment: String?, repository: TmuxAgentRepository) async {
        do {
            _ = try await repository.sendTicketBack(publicID: publicID, comment: comment)
            didFinishAction = true
        } catch {
            errorMessage = "Send back failed: \(error.localizedDescription)"
        }
    }
}
