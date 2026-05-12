import Foundation
import Observation

@MainActor
@Observable
final class TicketDetailViewModel {
    var ticket: Components.Schemas.Ticket
    var criteria: [Components.Schemas.AcceptanceCriterion] = []
    var sessions: [Components.Schemas.AgentSession] = []
    var isLoading = false
    var errorMessage: String?

    // Inline-edit buffers — kept in sync with ticket on successful saves.
    var editingTitle: String
    var editingDescription: String

    // Loaded after initial load for spawn context; nil until resolved.
    var feature: Components.Schemas.Feature?
    var project: Components.Schemas.Project?

    private let repository: TmuxAgentRepository

    init(ticket: Components.Schemas.Ticket, repository: TmuxAgentRepository) {
        self.ticket = ticket
        self.editingTitle = ticket.title
        self.editingDescription = ticket.description
        self.repository = repository
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let c = repository.listCriteria(ticketPublicID: ticket.publicId)
            async let s = repository.listTicketAgentSessions(ticketPublicID: ticket.publicId)
            criteria = try await c
            sessions = try await s
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        // Load feature + project for spawn context; failures are non-fatal.
        if let feat = try? await repository.getFeature(id: ticket.featureId) {
            feature = feat
            project = try? await repository.getProject(idOrSlug: String(feat.projectId))
        }
    }

    // MARK: - Title / description

    func commitTitle() async {
        let trimmed = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != ticket.title else { return }
        let previous = ticket.title
        ticket.title = trimmed
        do {
            let updated = try await repository.updateTicket(
                publicID: ticket.publicId,
                body: .init(title: trimmed, description: nil, status: nil, estimate: nil)
            )
            ticket = updated
        } catch {
            ticket.title = previous
            editingTitle = previous
            errorMessage = error.localizedDescription
        }
    }

    func commitDescription() async {
        let previous = ticket.description
        guard editingDescription != previous else { return }
        ticket.description = editingDescription
        do {
            let updated = try await repository.updateTicket(
                publicID: ticket.publicId,
                body: .init(title: nil, description: editingDescription, status: nil, estimate: nil)
            )
            ticket = updated
        } catch {
            ticket.description = previous
            editingDescription = previous
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Status (optimistic)

    func updateStatus(_ status: Components.Schemas.TicketStatus) async {
        let previous = ticket.status
        ticket.status = status
        do {
            let updated = try await repository.updateTicket(
                publicID: ticket.publicId,
                body: .init(title: nil, description: nil, status: status, estimate: nil)
            )
            ticket = updated
        } catch {
            ticket.status = previous
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Criteria (optimistic)

    func toggleCriterion(id: Int64) async {
        guard let index = criteria.firstIndex(where: { $0.id == id }) else { return }
        let previous = criteria[index].done
        criteria[index].done = !previous
        do {
            let updated = try await repository.updateCriterion(
                id: id,
                body: .init(text: nil, done: !previous, sortOrder: nil)
            )
            if let i = criteria.firstIndex(where: { $0.id == id }) {
                criteria[i] = updated
            }
        } catch {
            if let i = criteria.firstIndex(where: { $0.id == id }) {
                criteria[i].done = previous
            }
            errorMessage = error.localizedDescription
        }
    }

    func addCriterion(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let created = try await repository.createCriterion(
                ticketPublicID: ticket.publicId,
                body: .init(text: trimmed, done: nil, sortOrder: nil)
            )
            criteria.append(created)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCriterion(id: Int64) async {
        let backup = criteria
        criteria.removeAll { $0.id == id }
        do {
            try await repository.deleteCriterion(id: id)
        } catch {
            criteria = backup
            errorMessage = error.localizedDescription
        }
    }
}
