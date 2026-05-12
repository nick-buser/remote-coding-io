import Foundation
import Observation

/// Which scope the spawned session will target.
enum SpawnScope: String, CaseIterable {
    case ticket  = "Ticket"
    case feature = "Feature"
    case project = "Project"
}

/// What context the spawn sheet was opened from.
/// The entry pre-fills higher levels of the hierarchy and constrains
/// which scope options are visible.
enum SpawnEntry {
    /// Sessions tab `+` button — nothing pre-filled, full scope selector.
    case sessionsTab
    /// ProjectDetail — project pre-filled; Feature or Project scope only.
    case project(Components.Schemas.Project)
    /// FeatureDetail — project + feature pre-filled; Ticket or Feature scope.
    case feature(Components.Schemas.Feature, Components.Schemas.Project)
}

@MainActor
@Observable
final class SpawnSheetViewModel {

    // MARK: - Scope state
    var scope: SpawnScope

    // MARK: - Picker state
    var projects: [Components.Schemas.Project] = []
    var features: [Components.Schemas.Feature] = []
    var tickets: [Components.Schemas.Ticket] = []

    var selectedProject: Components.Schemas.Project?
    var selectedFeature: Components.Schemas.Feature?
    var selectedTicket: Components.Schemas.Ticket?

    // Pre-filled from entry (displayed as labels, not editable)
    let lockedProject: Components.Schemas.Project?
    let lockedFeature: Components.Schemas.Feature?

    // Pre-selected from TicketDetailView (scope locked to .ticket)
    var preselectedTicket: Components.Schemas.Ticket?

    // MARK: - Inline ticket creation
    var showingNewTicketForm = false
    var newTicketTitle = ""
    var newTicketEstimate = ""
    var isCreatingTicket = false

    // MARK: - Spawn
    var isSpawning = false
    var errorMessage: String?

    // MARK: - Constraints from entry
    let availableScopes: [SpawnScope]

    private let repository: TmuxAgentRepository
    private let coordinator: RootCoordinator

    init(entry: SpawnEntry, repository: TmuxAgentRepository, coordinator: RootCoordinator) {
        self.repository = repository
        self.coordinator = coordinator

        switch entry {
        case .sessionsTab:
            self.lockedProject = nil
            self.lockedFeature = nil
            self.availableScopes = SpawnScope.allCases
            self.scope = .ticket
            self.selectedProject = nil

        case .project(let proj):
            self.lockedProject = proj
            self.lockedFeature = nil
            self.availableScopes = [.feature, .project]
            self.scope = .feature
            self.selectedProject = proj

        case .feature(let feat, let proj):
            self.lockedProject = proj
            self.lockedFeature = feat
            self.availableScopes = [.ticket, .feature]
            self.scope = .ticket
            self.selectedProject = proj
            self.selectedFeature = feat
        }
    }

    // MARK: - Computed

    var isSpawnEnabled: Bool {
        guard !isSpawning else { return false }
        if let _ = preselectedTicket { return true }
        switch scope {
        case .project: return selectedProject != nil
        case .feature: return selectedProject != nil && selectedFeature != nil
        case .ticket:  return selectedProject != nil && selectedFeature != nil && selectedTicket != nil
        }
    }

    var sessionNamePreview: String {
        let proj = (lockedProject ?? selectedProject).map { sluggify($0.slug) } ?? "<project>"
        switch scope {
        case .project:
            return "\(proj)__session_<epoch>"
        case .feature:
            let feat = (lockedFeature ?? selectedFeature).map { sluggify($0.slug) } ?? "<feature>"
            return "\(proj)__\(feat)__session_<epoch>"
        case .ticket:
            let feat = (lockedFeature ?? selectedFeature).map { sluggify($0.slug) } ?? "<feature>"
            let branch: String
            if let t = preselectedTicket ?? selectedTicket {
                let b = t.branchName.isEmpty ? t.publicId : t.branchName
                branch = sluggify(b)
            } else {
                branch = "<branch>"
            }
            return "\(proj)__\(feat)__\(branch)"
        }
    }

    // MARK: - Load

    func loadInitial() async {
        if lockedProject == nil {
            await loadProjects()
        } else if lockedFeature == nil {
            await loadFeatures()
        } else {
            await loadTickets()
        }
    }

    func loadProjects() async {
        do {
            projects = try await repository.listProjects()
                .sorted { $0.name < $1.name }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func onProjectSelected(_ project: Components.Schemas.Project) async {
        selectedProject = project
        selectedFeature = nil
        selectedTicket = nil
        features = []
        tickets = []
        await loadFeatures()
    }

    func loadFeatures() async {
        guard let proj = lockedProject ?? selectedProject else { return }
        do {
            features = try await repository.listFeatures(projectIDOrSlug: String(proj.id))
                .sorted { $0.title < $1.title }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func onFeatureSelected(_ feature: Components.Schemas.Feature) async {
        selectedFeature = feature
        selectedTicket = nil
        tickets = []
        if scope == .ticket {
            await loadTickets()
        }
    }

    func loadTickets() async {
        guard let feat = lockedFeature ?? selectedFeature else { return }
        do {
            // Show open tickets (todo + doing); review tickets are active work too.
            let all = try await repository.listTickets(featureID: feat.id, status: nil)
            tickets = all
                .filter { $0.status != .done }
                .sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func onScopeChanged(_ newScope: SpawnScope) async {
        scope = newScope
        selectedTicket = nil
        if newScope == .ticket && selectedFeature != nil {
            await loadTickets()
        }
    }

    // MARK: - Inline ticket creation

    func createInlineTicket() async {
        let title = newTicketTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty,
              let feat = lockedFeature ?? selectedFeature
        else { return }
        isCreatingTicket = true
        defer { isCreatingTicket = false }
        do {
            let estimate = newTicketEstimate.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = Components.Schemas.CreateTicketRequest(
                title: title,
                description: nil,
                status: .todo,
                estimate: estimate.isEmpty ? nil : estimate,
                branchName: nil
            )
            let created = try await repository.createTicket(featureID: feat.id, body: body)
            tickets.insert(created, at: 0)
            selectedTicket = created
            newTicketTitle = ""
            newTicketEstimate = ""
            showingNewTicketForm = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Spawn

    func spawn() async {
        guard isSpawnEnabled, !isSpawning else { return }
        isSpawning = true
        defer { isSpawning = false }
        do {
            let body = makeRequest()
            let session = try await repository.createAgentSession(body)
            coordinator.push(.agentSession(sessionID: session.id))
        } catch {
            errorMessage = "Couldn't spawn: \(error.localizedDescription)"
        }
    }

    private func makeRequest() -> Components.Schemas.CreateAgentSessionRequest {
        if let ticket = preselectedTicket ?? selectedTicket {
            return Components.Schemas.CreateAgentSessionRequest(
                ticketPublicId: ticket.publicId,
                tmuxSession: nil, state: nil, pane: nil, cpu: nil
            )
        }
        switch scope {
        case .ticket:
            // Should not reach here without a ticket (spawn disabled)
            return Components.Schemas.CreateAgentSessionRequest(
                tmuxSession: nil, state: nil, pane: nil, cpu: nil
            )
        case .feature:
            return Components.Schemas.CreateAgentSessionRequest(
                featureId: (lockedFeature ?? selectedFeature)?.id,
                tmuxSession: nil, state: nil, pane: nil, cpu: nil
            )
        case .project:
            return Components.Schemas.CreateAgentSessionRequest(
                projectId: (lockedProject ?? selectedProject)?.id,
                tmuxSession: nil, state: nil, pane: nil, cpu: nil
            )
        }
    }

    // MARK: - Helpers

    private func sluggify(_ source: String) -> String {
        source
            .lowercased()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }
}
