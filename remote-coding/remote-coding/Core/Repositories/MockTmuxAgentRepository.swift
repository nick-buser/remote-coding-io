import Foundation

@MainActor
final class MockTmuxAgentRepository: TmuxAgentRepository {
    private var projects: [Components.Schemas.Project]
    private var features: [Components.Schemas.Feature]
    private var sessions: [Components.Schemas.Session]
    private var sessionScopes: [String: SessionScope]
    private var panesBySession: [String: [Components.Schemas.Pane]]
    private var outputsByPane: [String: Components.Schemas.PaneOutput]
    // The contract's Project schema does not carry tmux_session_name.
    // The mock keeps the prototype's project↔tmux-session mapping in a
    // sidecar map so openProjectSession / listSessions(projectID:) can
    // still satisfy preview wiring without leaking a contract-divergent
    // field onto the project type.
    private var tmuxSessionByProjectID: [Int64: String]
    private var localNotes: [LocalProjectNote]
    private var docs: [Components.Schemas.Doc]
    private var nextDocID: Int64
    private var decisions: [Components.Schemas.Decision]
    private var nextDecisionID: Int64
    private var activityEvents: [Components.Schemas.ActivityEvent]
    private var nextActivityEventID: Int64
    private var agentSessions: [Components.Schemas.AgentSession]
    private var nextAgentSessionID: Int64
    private var ticketDiffsByPublicID: [String: Components.Schemas.TicketDiff]
    // Tickets are stored without their inline `criteria` array; the
    // single-ticket GET attaches criteria from `criteriaByTicketID` so
    // listTickets can match the contract (criteria omitted) without a
    // second representation.
    private var tickets: [Components.Schemas.Ticket]
    private var criteriaByTicketID: [Int64: [Components.Schemas.AcceptanceCriterion]]
    private var nextTicketID: Int64
    private var nextCriterionID: Int64
    // Next public-id suffix to issue from createTicket. Seeded one past
    // the highest fixture so generated TMX-#### values don't collide.
    private var nextTicketPublicSequence: Int
    private(set) var sentInputs: [SentInput] = []
    private(set) var registeredDevices: [Components.Schemas.DeviceRegistration] = []
    private(set) var deregisteredDeviceTokens: [String] = []

    init() {
        projects = Self.decode([Components.Schemas.Project].self, from: Self.projectsJSON)
        features = Self.decode([Components.Schemas.Feature].self, from: Self.featuresJSON)
        sessions = Self.decode([Components.Schemas.Session].self, from: Self.sessionsJSON)
        sessionScopes = [
            "tmux_agent_main": SessionScope(projectID: 1, featureID: nil),
            "tmux_agent__agent_pane_multiplexer__feat_tmx_0042_pane_registry": SessionScope(projectID: 1, featureID: 11),
            "tmux_agent__feature_context_bundle__feat_tmx_0047_context_bundle": SessionScope(projectID: 1, featureID: 12),
            "tmux_agent__review_diff_checklist__feat_tmx_0050_diff_viewer": SessionScope(projectID: 1, featureID: 13),
            "sift_main": SessionScope(projectID: 2, featureID: nil)
        ]
        tmuxSessionByProjectID = [
            1: "tmux_agent_main"
            // Projects 2-4 start unlinked; openProjectSession assigns on demand.
        ]

        let mainPanes = Self.decode([Components.Schemas.Pane].self, from: Self.tmuxAgentPanesJSON)
        let feature11Panes = Self.decode([Components.Schemas.Pane].self, from: Self.tmuxAgentFeaturePanesJSON)
        panesBySession = [
            "tmux_agent_main": mainPanes,
            "tmux_agent__agent_pane_multiplexer__feat_tmx_0042_pane_registry": feature11Panes,
            "tmux_agent__feature_context_bundle__feat_tmx_0047_context_bundle": feature11Panes,
            "tmux_agent__review_diff_checklist__feat_tmx_0050_diff_viewer": feature11Panes,
            "sift_main": feature11Panes
        ]

        let mainOutput = Self.decode(Components.Schemas.PaneOutput.self, from: Self.paneOutputJSON)
        let reviewOutput = Self.decode(Components.Schemas.PaneOutput.self, from: Self.reviewPaneOutputJSON)
        outputsByPane = [
            "tmux_agent_main:0": mainOutput,
            // session-07 (id=802) pane "agent:2.0" → paneIndex 0
            "tmux_agent__review_diff_checklist__feat_tmx_0050_diff_viewer:0": reviewOutput
        ]

        localNotes = Self.seedLocalNotes
        let docSeed = Self.seedDocs()
        docs = docSeed.docs
        nextDocID = docSeed.nextDocID
        let decisionSeed = Self.seedDecisions()
        decisions = decisionSeed.decisions
        nextDecisionID = decisionSeed.nextDecisionID
        let activitySeed = Self.seedActivityEvents()
        activityEvents = activitySeed.events
        nextActivityEventID = activitySeed.nextID
        let agentSessionSeed = Self.seedAgentSessions()
        agentSessions = agentSessionSeed.sessions
        nextAgentSessionID = agentSessionSeed.nextID
        ticketDiffsByPublicID = Self.seedTicketDiffs()

        let seed = Self.seedTickets()
        tickets = seed.tickets
        criteriaByTicketID = seed.criteria
        nextTicketID = seed.nextTicketID
        nextCriterionID = seed.nextCriterionID
        nextTicketPublicSequence = seed.nextPublicSequence
    }

    func listProjects() async throws -> [Components.Schemas.Project] {
        projects.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned {
                return lhs.pinned && !rhs.pinned
            }
            return lhs.lastTouchedAt > rhs.lastTouchedAt
        }
    }

    func getProject(idOrSlug: String) async throws -> Components.Schemas.Project {
        guard let project = projects.first(where: { String($0.id) == idOrSlug || $0.slug == idOrSlug }) else {
            throw MockRepositoryError.notFound
        }
        return project
    }

    func updateProject(idOrSlug: String, body: Components.Schemas.UpdateProjectRequest) async throws -> Components.Schemas.Project {
        guard let index = projects.firstIndex(where: { String($0.id) == idOrSlug || $0.slug == idOrSlug }) else {
            throw MockRepositoryError.notFound
        }
        projects[index].name = body.name
        projects[index].slug = body.slug ?? projects[index].slug
        projects[index].gitRepoUrl = body.gitRepoUrl
        projects[index].localRepoPath = body.localRepoPath
        projects[index].tagline = body.tagline
        projects[index].description = body.description
        projects[index].accent = body.accent
        projects[index].icon = body.icon
        projects[index].status = body.status ?? projects[index].status
        projects[index].pinned = body.pinned ?? projects[index].pinned
        projects[index].updatedAt = Date()
        return projects[index]
    }

    func createProject(_ body: Components.Schemas.CreateProjectRequest) async throws -> Components.Schemas.Project {
        // Mirror the contract's required-field validation so the
        // form's optimistic submit path exercises the same error
        // shape as the live backend.
        guard !body.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MockRepositoryError.problem(field: "name", code: "required",
                                              message: "Name is required.")
        }
        guard !body.localRepoPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MockRepositoryError.problem(field: "local_repo_path", code: "required",
                                              message: "Local repo path is required.")
        }
        let slug = body.slug?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? Self.deriveSlug(from: body.name)
        if projects.contains(where: { $0.slug == slug }) {
            throw MockRepositoryError.problem(field: "slug", code: "conflict",
                                              message: "A project with this slug already exists.")
        }
        let id = (projects.map(\.id).max() ?? 0) + 1
        let now = Date()
        let project = Components.Schemas.Project(
            id: id,
            name: body.name,
            slug: slug,
            gitRepoUrl: body.gitRepoUrl,
            localRepoPath: body.localRepoPath,
            tagline: body.tagline,
            description: body.description,
            accent: body.accent,
            icon: body.icon,
            status: body.status ?? .active,
            pinned: body.pinned ?? false,
            lastTouchedAt: now,
            createdAt: now,
            updatedAt: now
        )
        projects.append(project)
        return project
    }

    func deleteProject(idOrSlug: String) async throws {
        guard let index = projects.firstIndex(where: { String($0.id) == idOrSlug || $0.slug == idOrSlug }) else {
            throw MockRepositoryError.notFound
        }
        let projectID = projects[index].id
        projects.remove(at: index)
        // Cascade child rows so re-creating a project with the same
        // slug doesn't see leftovers.
        let featureIDs = Set(features.filter { $0.projectId == projectID }.map(\.id))
        features.removeAll { $0.projectId == projectID }
        agentSessions.removeAll { session in
            guard let ticketID = session.ticketId else { return false }
            return tickets.first { $0.id == ticketID }
                .map { featureIDs.contains($0.featureId) } ?? false
        }
        let removedTicketIDs = Set(tickets.filter { featureIDs.contains($0.featureId) }.map(\.id))
        tickets.removeAll { featureIDs.contains($0.featureId) }
        for id in removedTicketIDs {
            criteriaByTicketID.removeValue(forKey: id)
        }
        decisions.removeAll { featureIDs.contains($0.featureId) }
        docs.removeAll { featureIDs.contains($0.featureId) }
        activityEvents.removeAll { event in
            event.projectId == projectID
                || (event.featureId.map { featureIDs.contains($0) } ?? false)
        }
        tmuxSessionByProjectID.removeValue(forKey: projectID)
    }

    private static func deriveSlug(from name: String) -> String {
        let lowered = name.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return "-"
        }
        let collapsed = String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? "project-\(Int.random(in: 1000...9999))" : collapsed
    }

    func listFeatures(projectIDOrSlug: String) async throws -> [Components.Schemas.Feature] {
        let project = try await getProject(idOrSlug: projectIDOrSlug)
        return features.filter { $0.projectId == project.id }
    }

    func getFeature(id: Int64) async throws -> Components.Schemas.Feature {
        guard let feature = features.first(where: { $0.id == id }) else {
            throw MockRepositoryError.notFound
        }
        return feature
    }

    func updateFeatureStatus(id: Int64, body: Components.Schemas.UpdateFeatureStatusRequest) async throws -> Components.Schemas.Feature {
        guard let index = features.firstIndex(where: { $0.id == id }) else {
            throw MockRepositoryError.notFound
        }
        features[index].status = body.status
        return features[index]
    }

    func createFeature(projectIDOrSlug: String, body: Components.Schemas.CreateFeatureRequest) async throws -> Components.Schemas.Feature {
        guard !body.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MockRepositoryError.problem(field: "title", code: "required",
                                              message: "Title is required.")
        }
        let project = try await getProject(idOrSlug: projectIDOrSlug)
        let slug = body.slug?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? Self.deriveSlug(from: body.title)
        if features.contains(where: { $0.projectId == project.id && $0.slug == slug }) {
            throw MockRepositoryError.problem(field: "slug", code: "conflict",
                                              message: "A feature with this slug already exists in the project.")
        }
        let id = (features.map(\.id).max() ?? 0) + 1
        let now = Date()
        let feature = Components.Schemas.Feature(
            id: id,
            projectId: project.id,
            branchName: body.branchName ?? "feat/\(slug)",
            slug: slug,
            title: body.title,
            vision: body.vision,
            descriptionDocKey: body.descriptionDocKey,
            status: body.status ?? .planned,
            accent: body.accent ?? project.accent ?? "iris",
            milestone: body.milestone,
            targetDate: body.targetDate,
            health: body.health ?? "on-track",
            tags: body.tags ?? [],
            progressCached: 0,
            createdAt: now,
            mergedAt: nil
        )
        features.append(feature)
        return feature
    }

    // MARK: Tickets

    func listTickets(featureID: Int64, status: Components.Schemas.TicketStatus?) async throws -> [Components.Schemas.Ticket] {
        tickets
            .filter { $0.featureId == featureID }
            .filter { status == nil || $0.status == status }
            .map(strippingCriteria)
    }

    func getTicket(publicID: String) async throws -> Components.Schemas.Ticket {
        guard let ticket = tickets.first(where: { $0.publicId == publicID }) else {
            throw MockRepositoryError.notFound
        }
        var attached = ticket
        attached.criteria = sortedCriteria(forTicketID: ticket.id)
        return attached
    }

    func createTicket(featureID: Int64, body: Components.Schemas.CreateTicketRequest) async throws -> Components.Schemas.Ticket {
        guard features.contains(where: { $0.id == featureID }) else {
            throw MockRepositoryError.notFound
        }
        let now = Date()
        let publicID = String(format: "TMX-%04d", nextTicketPublicSequence)
        nextTicketPublicSequence += 1
        let ticket = Components.Schemas.Ticket(
            id: nextTicketID,
            publicId: publicID,
            featureId: featureID,
            title: body.title,
            description: body.description ?? "",
            status: body.status ?? .todo,
            estimate: body.estimate ?? "",
            branchName: body.branchName ?? "",
            criteria: nil,
            criteriaTotal: 0,
            criteriaDone: 0,
            createdAt: now,
            updatedAt: now
        )
        nextTicketID += 1
        tickets.append(ticket)
        criteriaByTicketID[ticket.id] = []
        return ticket
    }

    func updateTicket(publicID: String, body: Components.Schemas.UpdateTicketRequest) async throws -> Components.Schemas.Ticket {
        guard let index = tickets.firstIndex(where: { $0.publicId == publicID }) else {
            throw MockRepositoryError.notFound
        }
        if let title = body.title { tickets[index].title = title }
        if let description = body.description { tickets[index].description = description }
        if let status = body.status { tickets[index].status = status }
        if let estimate = body.estimate { tickets[index].estimate = estimate }
        tickets[index].updatedAt = Date()
        var updated = tickets[index]
        updated.criteria = sortedCriteria(forTicketID: updated.id)
        return updated
    }

    // MARK: Acceptance criteria

    func listCriteria(ticketPublicID: String) async throws -> [Components.Schemas.AcceptanceCriterion] {
        guard let ticket = tickets.first(where: { $0.publicId == ticketPublicID }) else {
            throw MockRepositoryError.notFound
        }
        return sortedCriteria(forTicketID: ticket.id)
    }

    func createCriterion(ticketPublicID: String, body: Components.Schemas.CreateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion {
        guard let ticketIndex = tickets.firstIndex(where: { $0.publicId == ticketPublicID }) else {
            throw MockRepositoryError.notFound
        }
        let ticketID = tickets[ticketIndex].id
        let existing = criteriaByTicketID[ticketID] ?? []
        let appendedSortOrder = (existing.map { $0.sortOrder }.max() ?? -1) + 1
        let now = Date()
        let criterion = Components.Schemas.AcceptanceCriterion(
            id: nextCriterionID,
            ticketId: ticketID,
            text: body.text,
            done: body.done ?? false,
            sortOrder: body.sortOrder ?? appendedSortOrder,
            createdAt: now,
            updatedAt: now
        )
        nextCriterionID += 1
        criteriaByTicketID[ticketID, default: []].append(criterion)
        recomputeCriteriaCounts(for: ticketID)
        return criterion
    }

    func updateCriterion(id: Int64, body: Components.Schemas.UpdateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion {
        for (ticketID, list) in criteriaByTicketID {
            guard let index = list.firstIndex(where: { $0.id == id }) else { continue }
            var criterion = list[index]
            if let text = body.text { criterion.text = text }
            if let done = body.done { criterion.done = done }
            if let sortOrder = body.sortOrder { criterion.sortOrder = sortOrder }
            criterion.updatedAt = Date()
            criteriaByTicketID[ticketID]?[index] = criterion
            recomputeCriteriaCounts(for: ticketID)
            return criterion
        }
        throw MockRepositoryError.notFound
    }

    func deleteCriterion(id: Int64) async throws {
        for (ticketID, list) in criteriaByTicketID {
            guard let index = list.firstIndex(where: { $0.id == id }) else { continue }
            criteriaByTicketID[ticketID]?.remove(at: index)
            recomputeCriteriaCounts(for: ticketID)
            return
        }
        throw MockRepositoryError.notFound
    }

    private func sortedCriteria(forTicketID ticketID: Int64) -> [Components.Schemas.AcceptanceCriterion] {
        (criteriaByTicketID[ticketID] ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private func strippingCriteria(_ ticket: Components.Schemas.Ticket) -> Components.Schemas.Ticket {
        var copy = ticket
        copy.criteria = nil
        return copy
    }

    private func recomputeCriteriaCounts(for ticketID: Int64) {
        guard let index = tickets.firstIndex(where: { $0.id == ticketID }) else { return }
        let list = criteriaByTicketID[ticketID] ?? []
        tickets[index].criteriaTotal = list.count
        tickets[index].criteriaDone = list.filter { $0.done }.count
        tickets[index].updatedAt = Date()
    }

    // MARK: Feature docs

    func listFeatureDocs(featureID: Int64) async throws -> [Components.Schemas.Doc] {
        guard features.contains(where: { $0.id == featureID }) else {
            throw MockRepositoryError.notFound
        }
        return docs
            .filter { $0.featureId == featureID }
            .sorted { lhs, rhs in
                if lhs.pinned != rhs.pinned {
                    return lhs.pinned && !rhs.pinned
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    func getDoc(id: Int64) async throws -> Components.Schemas.Doc {
        guard let doc = docs.first(where: { $0.id == id }) else {
            throw MockRepositoryError.notFound
        }
        return doc
    }

    func createFeatureDoc(featureID: Int64, body: Components.Schemas.CreateDocRequest) async throws -> Components.Schemas.Doc {
        guard features.contains(where: { $0.id == featureID }) else {
            throw MockRepositoryError.notFound
        }
        let now = Date()
        let bodyBlocks = body.bodyBlocks ?? "[]"
        let doc = Components.Schemas.Doc(
            id: nextDocID,
            featureId: featureID,
            kind: body.kind,
            title: body.title,
            bodyBlocks: bodyBlocks,
            objectKey: nil,
            wordCount: Self.wordCount(of: bodyBlocks),
            pinned: body.pinned ?? false,
            createdAt: now,
            updatedAt: now
        )
        nextDocID += 1
        docs.append(doc)
        return doc
    }

    func updateDoc(id: Int64, body: Components.Schemas.UpdateDocRequest) async throws -> Components.Schemas.Doc {
        guard let index = docs.firstIndex(where: { $0.id == id }) else {
            throw MockRepositoryError.notFound
        }
        if let kind = body.kind { docs[index].kind = kind }
        if let title = body.title { docs[index].title = title }
        if let bodyBlocks = body.bodyBlocks {
            docs[index].bodyBlocks = bodyBlocks
            docs[index].wordCount = Self.wordCount(of: bodyBlocks)
        }
        if let pinned = body.pinned { docs[index].pinned = pinned }
        docs[index].updatedAt = Date()
        return docs[index]
    }

    func deleteDoc(id: Int64) async throws {
        guard let index = docs.firstIndex(where: { $0.id == id }) else {
            throw MockRepositoryError.notFound
        }
        docs.remove(at: index)
    }

    // MARK: Feature decisions

    func listFeatureDecisions(featureID: Int64) async throws -> [Components.Schemas.Decision] {
        guard features.contains(where: { $0.id == featureID }) else {
            throw MockRepositoryError.notFound
        }
        return decisions
            .filter { $0.featureId == featureID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func createFeatureDecision(featureID: Int64, body: Components.Schemas.CreateDecisionRequest) async throws -> Components.Schemas.Decision {
        guard features.contains(where: { $0.id == featureID }) else {
            throw MockRepositoryError.notFound
        }
        let decision = Components.Schemas.Decision(
            id: nextDecisionID,
            featureId: featureID,
            title: body.title,
            body: body.body,
            actor: body.actor,
            actorName: body.actorName,
            createdAt: Date()
        )
        nextDecisionID += 1
        decisions.append(decision)
        return decision
    }

    func deleteDecision(id: Int64) async throws {
        guard let index = decisions.firstIndex(where: { $0.id == id }) else {
            throw MockRepositoryError.notFound
        }
        decisions.remove(at: index)
    }

    // MARK: Activity

    func listActivity(project: String?, feature: Int64?, since: Date?, limit: Int?) async throws -> [Components.Schemas.ActivityEvent] {
        var resolvedProjectID: Int64?
        if let project {
            // Mirrors the contract: the query param accepts numeric id or
            // slug. Resolve to a numeric id locally so the per-event
            // project_id comparison stays simple.
            if let id = Int64(project) {
                resolvedProjectID = id
            } else if let resolved = projects.first(where: { $0.slug == project })?.id {
                resolvedProjectID = resolved
            } else {
                resolvedProjectID = nil
            }
        }
        var filtered = activityEvents
        if let resolvedProjectID {
            filtered = filtered.filter { $0.projectId == resolvedProjectID }
        }
        if let feature {
            filtered = filtered.filter { $0.featureId == feature }
        }
        if let since {
            // Spec: only events strictly newer than `since`. The poller
            // advances on the latest createdAt it has already seen, so
            // strict-greater-than prevents duplicates on the next tick.
            filtered = filtered.filter { $0.createdAt > since }
        }
        let sorted = filtered.sorted { $0.createdAt > $1.createdAt }
        let cap = max(min(limit ?? 100, 500), 1)
        return Array(sorted.prefix(cap))
    }

    // Test helper. Lets ActivityPollerTests inject a controllable
    // fixture without rebuilding the whole repository surface.
    func appendActivityEvent(_ event: Components.Schemas.ActivityEvent) {
        activityEvents.append(event)
    }

    // MARK: Agent sessions

    func getAgentSession(id: Int64) async throws -> Components.Schemas.AgentSession {
        guard let session = agentSessions.first(where: { $0.id == id }) else {
            throw MockRepositoryError.notFound
        }
        return session
    }

    func listProjectAgentSessions(projectIDOrSlug: String) async throws -> [Components.Schemas.AgentSession] {
        let project = try await getProject(idOrSlug: projectIDOrSlug)
        let projectFeatureIDs = Set(features.filter { $0.projectId == project.id }.map(\.id))
        return agentSessions
            .filter { session in
                guard let ticketID = session.ticketId,
                      let ticket = tickets.first(where: { $0.id == ticketID }) else {
                    return false
                }
                return projectFeatureIDs.contains(ticket.featureId)
            }
            .sorted { $0.lastActiveAt > $1.lastActiveAt }
    }

    func listTicketAgentSessions(ticketPublicID: String) async throws -> [Components.Schemas.AgentSession] {
        guard let ticket = tickets.first(where: { $0.publicId == ticketPublicID }) else {
            throw MockRepositoryError.notFound
        }
        return agentSessions
            .filter { $0.ticketId == ticket.id }
            .sorted { $0.lastActiveAt > $1.lastActiveAt }
    }

    func createAgentSession(_ body: Components.Schemas.CreateAgentSessionRequest) async throws -> Components.Schemas.AgentSession {
        guard let ticket = tickets.first(where: { $0.publicId == body.ticketPublicId }) else {
            throw MockRepositoryError.notFound
        }
        guard let feature = features.first(where: { $0.id == ticket.featureId }) else {
            throw MockRepositoryError.notFound
        }
        guard let project = projects.first(where: { $0.id == feature.projectId }) else {
            throw MockRepositoryError.notFound
        }
        let now = Date()
        let derivedTmux = body.tmuxSession ?? Self.derivedTmuxSessionName(
            project: project, feature: feature, ticket: ticket
        )
        let session = Components.Schemas.AgentSession(
            id: nextAgentSessionID,
            ticketId: ticket.id,
            tmuxSession: derivedTmux,
            state: body.state ?? .idle,
            pane: body.pane,
            cpu: body.cpu ?? 0,
            startTime: now,
            endTime: nil,
            lastActiveAt: now,
            transcriptKey: nil,
            tokenUsage: nil,
            costEstimate: nil,
            createdAt: now
        )
        nextAgentSessionID += 1
        agentSessions.append(session)
        // Activity feed mirror — service-repo-activity is in place, so
        // the poller / Inbox sees the spawn without an extra fetch.
        activityEvents.append(Components.Schemas.ActivityEvent(
            id: nextActivityEventID,
            projectId: project.id,
            featureId: feature.id,
            ticketId: ticket.id,
            actor: .agent,
            actorName: derivedTmux,
            verb: "spawned session",
            kind: .check,
            detail: "tmux: \(derivedTmux)",
            createdAt: now
        ))
        nextActivityEventID += 1
        return session
    }

    private static func derivedTmuxSessionName(
        project: Components.Schemas.Project,
        feature: Components.Schemas.Feature,
        ticket: Components.Schemas.Ticket
    ) -> String {
        let projectSlug = sluggify(project.slug)
        let featureSlug = sluggify(feature.slug)
        let branch = ticket.branchName.isEmpty ? ticket.publicId : ticket.branchName
        let branchSlug = sluggify(branch)
        return "\(projectSlug)__\(featureSlug)__\(branchSlug)"
    }

    private static func sluggify(_ source: String) -> String {
        source
            .lowercased()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    // MARK: Ticket review

    func getTicketDiff(publicID: String) async throws -> Components.Schemas.TicketDiff {
        guard let diff = ticketDiffsByPublicID[publicID] else {
            throw MockRepositoryError.notFound
        }
        return diff
    }

    func approveTicket(publicID: String) async throws -> Components.Schemas.Ticket {
        guard let index = tickets.firstIndex(where: { $0.publicId == publicID }) else {
            throw MockRepositoryError.notFound
        }
        tickets[index].status = .done
        tickets[index].updatedAt = Date()
        emitReviewActivity(ticket: tickets[index], kind: .approve, detail: "Approved")
        var updated = tickets[index]
        updated.criteria = sortedCriteria(forTicketID: updated.id)
        return updated
    }

    func requestTicketChanges(publicID: String, comment: String?) async throws -> Components.Schemas.Ticket {
        guard let index = tickets.firstIndex(where: { $0.publicId == publicID }) else {
            throw MockRepositoryError.notFound
        }
        // Spec: stays in `review` — the reviewer wants the agent to push
        // more commits onto the same branch, not redo the whole ticket.
        tickets[index].status = .review
        tickets[index].updatedAt = Date()
        emitReviewActivity(ticket: tickets[index], kind: .review,
                           detail: comment ?? "Requested changes")
        var updated = tickets[index]
        updated.criteria = sortedCriteria(forTicketID: updated.id)
        return updated
    }

    func sendTicketBack(publicID: String, comment: String?) async throws -> Components.Schemas.Ticket {
        guard let index = tickets.firstIndex(where: { $0.publicId == publicID }) else {
            throw MockRepositoryError.notFound
        }
        // Spec: drops back to `doing` — the review failed and more work
        // is needed on the original branch.
        tickets[index].status = .doing
        tickets[index].updatedAt = Date()
        emitReviewActivity(ticket: tickets[index], kind: .check,
                           detail: comment ?? "Sent back")
        var updated = tickets[index]
        updated.criteria = sortedCriteria(forTicketID: updated.id)
        return updated
    }

    private func emitReviewActivity(
        ticket: Components.Schemas.Ticket,
        kind: Components.Schemas.ActivityKind,
        detail: String
    ) {
        let feature = features.first(where: { $0.id == ticket.featureId })
        let projectID = feature.flatMap { feat in
            projects.first(where: { $0.id == feat.projectId })?.id
        }
        let verb: String
        switch kind {
        case .approve: verb = "approved"
        case .review: verb = "requested changes"
        case .check: verb = "sent back"
        default: verb = "reviewed"
        }
        activityEvents.append(Components.Schemas.ActivityEvent(
            id: nextActivityEventID,
            projectId: projectID,
            featureId: ticket.featureId,
            ticketId: ticket.id,
            actor: .human,
            actorName: "you",
            verb: verb,
            kind: kind,
            detail: detail,
            createdAt: Date()
        ))
        nextActivityEventID += 1
    }

    // MARK: Local project notes

    func listProjectDocuments(projectID: Int64) async throws -> [LocalProjectNote] {
        localNotes.filter { $0.projectID == projectID }
    }

    func saveDocument(_ document: LocalProjectNote) async throws -> LocalProjectNote {
        var saved = document
        saved.updatedAt = Date()
        if let index = localNotes.firstIndex(where: { $0.id == document.id }) {
            localNotes[index] = saved
        } else {
            localNotes.append(saved)
        }
        return saved
    }

    private static func wordCount(of bodyBlocks: String) -> Int {
        bodyBlocks
            .split(whereSeparator: { $0.isWhitespace })
            .filter { !$0.isEmpty }
            .count
    }

    func openProjectSession(idOrSlug: String) async throws -> Components.Schemas.Project {
        let project = try await getProject(idOrSlug: idOrSlug)
        if tmuxSessionByProjectID[project.id] == nil {
            tmuxSessionByProjectID[project.id] = defaultSessionName(for: project)
        }
        return project
    }

    func listSessions(projectID: Int64) async throws -> [Components.Schemas.Session] {
        scopedSessions { scope in
            scope.projectID == projectID && scope.featureID == nil
        }
    }

    func listSessions(featureID: Int64) async throws -> [Components.Schemas.Session] {
        guard let feature = features.first(where: { $0.id == featureID }) else {
            throw MockRepositoryError.notFound
        }
        let featureSessions = scopedSessions { scope in
            scope.featureID == featureID
        }
        if !featureSessions.isEmpty {
            return featureSessions
        }
        return try await listSessions(projectID: feature.projectId)
    }

    func listSessions() async throws -> [Components.Schemas.Session] {
        sessions
    }

    func listPanes(sessionName: String) async throws -> [Components.Schemas.Pane] {
        panesBySession[sessionName] ?? []
    }

    func getPaneOutput(sessionName: String, paneID: Int) async throws -> Components.Schemas.PaneOutput {
        outputsByPane["\(sessionName):\(paneID)"] ?? Components.Schemas.PaneOutput(
            sessionName: sessionName,
            paneIndex: paneID,
            content: ""
        )
    }

    func sendPaneInput(sessionName: String, paneID: Int, body: Components.Schemas.SendInputRequest) async throws -> Components.Schemas.StatusResponse {
        sentInputs.append(SentInput(sessionName: sessionName, paneID: paneID, body: body))
        let key = "\(sessionName):\(paneID)"
        var output = outputsByPane[key] ?? Components.Schemas.PaneOutput(sessionName: sessionName, paneIndex: paneID, content: "")
        output.content += transcriptLine(for: body)
        outputsByPane[key] = output
        return Components.Schemas.StatusResponse(status: "sent")
    }

    func registerDevice(_ body: Components.Schemas.DeviceRegistrationRequest) async throws -> Components.Schemas.DeviceRegistration {
        let now = Date()
        let existingIndex = registeredDevices.firstIndex { $0.deviceToken == body.deviceToken }
        let createdAt = existingIndex.map { registeredDevices[$0].createdAt ?? now } ?? now
        let registration = Components.Schemas.DeviceRegistration(
            deviceToken: body.deviceToken,
            environment: body.environment,
            mutedProjectIds: body.mutedProjectIds,
            quietHoursStart: body.quietHoursStart,
            quietHoursEnd: body.quietHoursEnd,
            createdAt: createdAt,
            updatedAt: now
        )
        if let index = existingIndex {
            registeredDevices[index] = registration
        } else {
            registeredDevices.append(registration)
        }
        return registration
    }

    func deregisterDevice(token: String) async throws {
        deregisteredDeviceTokens.append(token)
        registeredDevices.removeAll { $0.deviceToken == token }
    }

    private func transcriptLine(for body: Components.Schemas.SendInputRequest) -> String {
        let typed = body.text ?? ""
        let keyText = body.keys?.joined(separator: " ") ?? ""
        if typed.isEmpty && (body.enter == true || body.keys?.contains("Enter") == true) {
            return "\n$ <enter>\n"
        }
        if !keyText.isEmpty {
            return "\n$ <\(keyText)>\n"
        }
        if body.enter == true {
            return "\n$ \(typed)\n"
        }
        return typed
    }

    private func scopedSessions(matching predicate: (SessionScope) -> Bool) -> [Components.Schemas.Session] {
        sessions.filter { session in
            guard let scope = sessionScopes[session.name] else {
                return false
            }
            return predicate(scope)
        }
    }

    private func defaultSessionName(for project: Components.Schemas.Project) -> String {
        "\(project.slug.replacingOccurrences(of: "-", with: "_"))_main"
    }

    private static func decode<T: Decodable>(_ type: T.Type, from json: String) -> T {
        do {
            return try JSONDecoder.openAPI.decode(T.self, from: Data(json.utf8))
        } catch {
            fatalError("Invalid OpenAPI mock fixture: \(error)")
        }
    }
}

private struct SessionScope: Hashable {
    let projectID: Int64
    let featureID: Int64?
}

struct SentInput: Hashable {
    let sessionName: String
    let paneID: Int
    let body: Components.Schemas.SendInputRequest
}

enum MockRepositoryError: Error {
    case notFound
    /// Mirrors a `ProblemDetails` with a single `FieldError` for the
    /// validation paths exercised by create / edit sheets.
    case problem(field: String, code: String, message: String)
}

extension MockRepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notFound: return "Not found."
        case .problem(_, _, let message): return message
        }
    }
}

private extension String {
    /// Helper for create-project's slug fallback. Returns `nil` when
    /// trimming would produce an empty string.
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension MockTmuxAgentRepository {
    static let projectsJSON = """
    [
      {
        "id": 1,
        "name": "tmux-agent",
        "slug": "tmux-agent",
        "git_repo_url": "git@github.com:nick-buser/tmux-agent.git",
        "local_repo_path": "/Users/nickbuser/Projects/tmux-agent",
        "tagline": "Local agent runner inside tmux",
        "description": "A solo-dev orchestrator for running multiple Claude/Codex sessions in tmux panes, each bound to a feature's context bundle.",
        "accent": "iris",
        "icon": "terminal",
        "status": "active",
        "pinned": true,
        "last_touched_at": "2026-04-25T14:18:00Z",
        "created_at": "2026-04-05T04:00:00Z",
        "updated_at": "2026-04-25T14:18:00Z"
      },
      {
        "id": 2,
        "name": "sift",
        "slug": "sift",
        "git_repo_url": "git@github.com:nick-buser/sift.git",
        "local_repo_path": "/Users/nickbuser/Projects/sift",
        "tagline": "Local-first log search",
        "description": "A grep-meets-OpenSearch tool: index every project log directory locally, query with structured filters, no daemon.",
        "accent": "amber",
        "icon": "magnifyingglass",
        "status": "active",
        "pinned": true,
        "last_touched_at": "2026-04-23T09:00:00Z",
        "created_at": "2026-03-01T04:00:00Z",
        "updated_at": "2026-04-23T09:00:00Z"
      },
      {
        "id": 3,
        "name": "paper-cuts",
        "slug": "paper-cuts",
        "git_repo_url": "git@github.com:nick-buser/paper-cuts.git",
        "local_repo_path": "/Users/nickbuser/Projects/paper-cuts",
        "tagline": "Personal site + writing",
        "description": "Static site generator + essays. Mostly content; occasional engine work when a post needs a new layout.",
        "accent": "mint",
        "icon": "doc.text",
        "status": "maintenance",
        "pinned": false,
        "last_touched_at": "2026-04-19T10:00:00Z",
        "created_at": "2025-09-01T04:00:00Z",
        "updated_at": "2026-04-19T10:00:00Z"
      },
      {
        "id": 4,
        "name": "ledger-mini",
        "slug": "ledger-mini",
        "git_repo_url": "git@github.com:nick-buser/ledger-mini.git",
        "local_repo_path": "/Users/nickbuser/Projects/ledger-mini",
        "tagline": "Plain-text accounting CLI",
        "description": "Hobby project: a single-file accounting tool with envelope budgets and CSV import. No active feature work right now.",
        "accent": "slate",
        "icon": "list.number",
        "status": "paused",
        "pinned": false,
        "last_touched_at": "2026-04-04T08:00:00Z",
        "created_at": "2025-06-01T04:00:00Z",
        "updated_at": "2026-04-04T08:00:00Z"
      }
    ]
    """

    static let featuresJSON = """
    [
      {
        "id": 11,
        "project_id": 1,
        "branch_name": "feat/agent-pane-multiplexer",
        "slug": "agent-pane-multiplexer",
        "title": "Agent pane multiplexer",
        "vision": "Run multiple agent sessions in a single tmux window with split-pane navigation, scrollback search, and per-pane state badges.",
        "status": "in_progress",
        "accent": "iris",
        "milestone": "v0.4",
        "health": "on-track",
        "tags": ["terminal", "agent", "core"],
        "progress_cached": 0.62,
        "created_at": "2026-04-10T04:00:00Z",
        "merged_at": null
      },
      {
        "id": 12,
        "project_id": 1,
        "branch_name": "feat/feature-context-bundle",
        "slug": "feature-context-bundle",
        "title": "Feature ↔ session context bundle",
        "vision": "Bind every agent session to its feature's PRD, design notes, and acceptance checklist so resuming work loads the full context window.",
        "status": "in_progress",
        "accent": "iris",
        "milestone": "v0.4",
        "health": "on-track",
        "tags": ["agent", "context", "docs"],
        "progress_cached": 0.34,
        "created_at": "2026-04-12T04:00:00Z",
        "merged_at": null
      },
      {
        "id": 13,
        "project_id": 1,
        "branch_name": "feat/review-diff-checklist",
        "slug": "review-diff-checklist",
        "title": "Review surface — diff + acceptance checklist",
        "vision": "A side-by-side diff with the ticket's acceptance criteria pinned next to it; approve, request changes, or send back to the agent inline.",
        "status": "review",
        "accent": "amber",
        "milestone": "v0.4",
        "health": "at-risk",
        "tags": ["review", "ui"],
        "progress_cached": 0.88,
        "created_at": "2026-04-15T04:00:00Z",
        "merged_at": null
      },
      {
        "id": 14,
        "project_id": 1,
        "branch_name": "feat/roadmap-timeline",
        "slug": "roadmap-timeline",
        "title": "Roadmap timeline view",
        "vision": "Single horizontal timeline of features by target milestone — drag to reschedule, click to drill in.",
        "status": "planned",
        "accent": "mint",
        "milestone": "v0.5",
        "health": "planned",
        "tags": ["ui", "planning"],
        "progress_cached": 0.05,
        "created_at": "2026-04-20T04:00:00Z",
        "merged_at": null
      },
      {
        "id": 15,
        "project_id": 1,
        "branch_name": "feat/decisions-log",
        "slug": "decisions-log",
        "title": "Per-feature decisions log",
        "vision": "Append-only log of architectural decisions tied to each feature, surfaced into agent context on resume.",
        "status": "planned",
        "accent": "mint",
        "milestone": "v0.5",
        "health": "planned",
        "tags": ["docs", "context"],
        "progress_cached": 0,
        "created_at": "2026-04-20T04:00:00Z",
        "merged_at": null
      },
      {
        "id": 16,
        "project_id": 1,
        "branch_name": "feat/sqlite-store",
        "slug": "sqlite-store",
        "title": "SQLite store + migrations",
        "vision": "Local SQLite-backed persistence with auto-migration on boot. No external db dependency.",
        "status": "shipped",
        "accent": "slate",
        "milestone": "v0.3",
        "health": "shipped",
        "tags": ["infra", "storage"],
        "progress_cached": 1,
        "created_at": "2026-03-20T04:00:00Z",
        "merged_at": "2026-04-14T10:00:00Z"
      },
      {
        "id": 21,
        "project_id": 2,
        "branch_name": "feat/structured-query-grammar",
        "slug": "structured-query-grammar",
        "title": "Structured query grammar",
        "vision": "Parser for filter expressions like `level:error path:~/work` with autocomplete and saved queries.",
        "status": "in_progress",
        "accent": "amber",
        "milestone": "v0.2",
        "health": "on-track",
        "tags": ["parser", "query"],
        "progress_cached": 0.41,
        "created_at": "2026-04-01T04:00:00Z",
        "merged_at": null
      },
      {
        "id": 22,
        "project_id": 2,
        "branch_name": "feat/incremental-indexer",
        "slug": "incremental-indexer",
        "title": "Incremental indexer",
        "vision": "Watch log directories and update the local index without re-scanning. Dedup via inode + offset.",
        "status": "planned",
        "accent": "amber",
        "milestone": "v0.3",
        "health": "planned",
        "tags": ["infra", "fs"],
        "progress_cached": 0,
        "created_at": "2026-04-05T04:00:00Z",
        "merged_at": null
      },
      {
        "id": 31,
        "project_id": 3,
        "branch_name": "feat/footnote-popovers",
        "slug": "footnote-popovers",
        "title": "Footnote popovers",
        "vision": "Inline preview popovers for footnotes on hover, falling back to anchor scroll on touch.",
        "status": "planned",
        "accent": "mint",
        "milestone": "v1.4",
        "health": "planned",
        "tags": ["ui", "reading"],
        "progress_cached": 0.1,
        "created_at": "2026-04-08T04:00:00Z",
        "merged_at": null
      }
    ]
    """

    static let sessionsJSON = """
    [
      {
        "name": "tmux_agent_main",
        "attached": false,
        "created": "2026-04-25T12:00:00Z",
        "windows": 1,
        "directory": "/Users/nickbuser/Projects/tmux-agent"
      },
      {
        "name": "tmux_agent__agent_pane_multiplexer__feat_tmx_0042_pane_registry",
        "attached": false,
        "created": "2026-04-25T12:11:00Z",
        "windows": 1,
        "directory": "/Users/nickbuser/Projects/tmux-agent"
      },
      {
        "name": "tmux_agent__feature_context_bundle__feat_tmx_0047_context_bundle",
        "attached": false,
        "created": "2026-04-25T10:08:00Z",
        "windows": 1,
        "directory": "/Users/nickbuser/Projects/tmux-agent"
      },
      {
        "name": "tmux_agent__review_diff_checklist__feat_tmx_0050_diff_viewer",
        "attached": false,
        "created": "2026-04-25T13:43:00Z",
        "windows": 1,
        "directory": "/Users/nickbuser/Projects/tmux-agent"
      },
      {
        "name": "sift_main",
        "attached": false,
        "created": "2026-04-23T08:00:00Z",
        "windows": 1,
        "directory": "/Users/nickbuser/Projects/sift"
      }
    ]
    """

    static let tmuxAgentPanesJSON = """
    [
      {
        "index": 0,
        "title": "codex",
        "width": 120,
        "height": 40,
        "active": true,
        "directory": "/Users/nickbuser/Projects/tmux-agent"
      },
      {
        "index": 1,
        "title": "server",
        "width": 120,
        "height": 40,
        "active": false,
        "directory": "/Users/nickbuser/Projects/tmux-agent"
      }
    ]
    """

    static let tmuxAgentFeaturePanesJSON = """
    [
      {
        "index": 0,
        "title": "agent",
        "width": 120,
        "height": 40,
        "active": true,
        "directory": "/Users/nickbuser/Projects/tmux-agent"
      }
    ]
    """

    static let paneOutputJSON = """
    {
      "session_name": "tmux_agent_main",
      "pane_index": 0,
      "content": "\u{1B}[1;32m$\u{1B}[0m go test ./...\\n\u{1B}[32mok\u{1B}[0m  github.com/nickbuser/tmux-agent/internal/store/sqlite  0.412s\\n\u{1B}[33m?\u{1B}[0m   github.com/nickbuser/tmux-agent/cmd  [no test files]\\n\\nContinue with generated client wiring? \u{1B}[1m[y/N]\u{1B}[0m "
    }
    """

    static let reviewPaneOutputJSON = """
    {
      "session_name": "tmux_agent__review_diff_checklist__feat_tmx_0050_diff_viewer",
      "pane_index": 0,
      "content": "\u{1B}[1;32m$\u{1B}[0m git diff main...HEAD --stat\\n\u{1B}[33mFeatures/Review/DiffViewer.swift\u{1B}[0m  | \u{1B}[32m+24\u{1B}[0m \u{1B}[31m-8\u{1B}[0m\\n\u{1B}[33mFeatures/Review/DiffPaneView.swift\u{1B}[0m | \u{1B}[32m+38\u{1B}[0m\\n\\nUse unified diff or split? \u{1B}[1m[defaulting to split]\u{1B}[0m "
    }
    """

    // Tickets mirror data.jsx (TMX-0042..TMX-0070). Feature mapping:
    // • feature 11 (FEAT-018 agent-pane-multiplexer): TMX-0042..0046
    // • feature 12 (FEAT-019 feature-context-bundle): TMX-0047..0049
    // • feature 13 (FEAT-020 review-diff-checklist): TMX-0050..0052
    // • feature 21 (FEAT-031 structured-query-grammar, sift): TMX-0061..0063
    // • feature 31 (FEAT-040 footnote-popovers, paper-cuts): TMX-0070
    static func seedTickets() -> (
        tickets: [Components.Schemas.Ticket],
        criteria: [Int64: [Components.Schemas.AcceptanceCriterion]],
        nextTicketID: Int64,
        nextCriterionID: Int64,
        nextPublicSequence: Int
    ) {
        struct Spec {
            let publicID: String
            let featureID: Int64
            let title: String
            let description: String
            let status: Components.Schemas.TicketStatus
            let estimate: String
            let branchName: String
            let criteriaCount: Int
            let criteriaDone: Int
            let hoursAgo: Double
        }
        let specs: [Spec] = [
            Spec(publicID: "TMX-0042", featureID: 11, title: "Pane registry + lifecycle hooks",
                 description: "Track every spawned pane in a registry that fires lifecycle hooks on attach, detach, and exit.",
                 status: .doing, estimate: "M", branchName: "feat/tmx-0042-pane-registry",
                 criteriaCount: 4, criteriaDone: 2, hoursAgo: 0.2),
            Spec(publicID: "TMX-0043", featureID: 11, title: "Split layout grammar (h/v/grid)",
                 description: "Define a tiny grammar for splitting panes horizontally, vertically, or into a grid.",
                 status: .doing, estimate: "L", branchName: "feat/tmx-0043-split-grammar",
                 criteriaCount: 5, criteriaDone: 3, hoursAgo: 0.6),
            Spec(publicID: "TMX-0044", featureID: 11, title: "Per-pane status badge stream",
                 description: "Stream per-pane status (idle, busy, awaiting-input) so badges stay in sync without polling.",
                 status: .review, estimate: "S", branchName: "feat/tmx-0044-status-badge",
                 criteriaCount: 3, criteriaDone: 3, hoursAgo: 1),
            Spec(publicID: "TMX-0045", featureID: 11, title: "Scrollback search (regex + jump)",
                 description: "Regex-aware scrollback search with jump-to-match navigation.",
                 status: .todo, estimate: "M", branchName: "",
                 criteriaCount: 4, criteriaDone: 0, hoursAgo: 24),
            Spec(publicID: "TMX-0046", featureID: 11, title: "Keyboard map: pane navigation",
                 description: "Bind pane navigation to a keyboard map that respects the user's existing chord layout.",
                 status: .todo, estimate: "S", branchName: "",
                 criteriaCount: 3, criteriaDone: 0, hoursAgo: 24),
            Spec(publicID: "TMX-0047", featureID: 12, title: "Context bundle schema",
                 description: "Schema for the context bundle each session ships to the agent on resume.",
                 status: .doing, estimate: "M", branchName: "feat/tmx-0047-context-bundle",
                 criteriaCount: 5, criteriaDone: 4, hoursAgo: 1),
            Spec(publicID: "TMX-0048", featureID: 12, title: "PRD/notes resolver per session",
                 description: "Resolve the right PRD and notes for a session based on its ticket and feature.",
                 status: .doing, estimate: "M", branchName: "feat/tmx-0048-prd-resolver",
                 criteriaCount: 4, criteriaDone: 1, hoursAgo: 3),
            Spec(publicID: "TMX-0049", featureID: 12, title: "Resume hook: re-inject context",
                 description: "When a session resumes, re-inject the context bundle into the agent's prompt.",
                 status: .todo, estimate: "S", branchName: "",
                 criteriaCount: 3, criteriaDone: 0, hoursAgo: 48),
            Spec(publicID: "TMX-0050", featureID: 13, title: "Diff viewer component",
                 description: "Side-by-side diff viewer with line-level highlighting.",
                 status: .review, estimate: "L", branchName: "feat/tmx-0050-diff-viewer",
                 criteriaCount: 6, criteriaDone: 6, hoursAgo: 3),
            Spec(publicID: "TMX-0051", featureID: 13, title: "Acceptance checklist binding",
                 description: "Bind the acceptance checklist to the diff so reviewers can tick items as they read.",
                 status: .review, estimate: "S", branchName: "feat/tmx-0051-checklist",
                 criteriaCount: 4, criteriaDone: 4, hoursAgo: 4),
            Spec(publicID: "TMX-0052", featureID: 13, title: "Approve / request-changes actions",
                 description: "Reviewer actions: approve, request changes, send back to doing.",
                 status: .doing, estimate: "S", branchName: "feat/tmx-0052-review-actions",
                 criteriaCount: 3, criteriaDone: 2, hoursAgo: 6),
            Spec(publicID: "TMX-0061", featureID: 21, title: "Lex tokens + grammar",
                 description: "Lex query tokens and define the grammar for the saved-query DSL.",
                 status: .doing, estimate: "M", branchName: "feat/tmx-0061-lex",
                 criteriaCount: 4, criteriaDone: 2, hoursAgo: 48),
            Spec(publicID: "TMX-0062", featureID: 21, title: "Autocomplete provider",
                 description: "Autocomplete suggestions for query operators and field names.",
                 status: .todo, estimate: "S", branchName: "",
                 criteriaCount: 3, criteriaDone: 0, hoursAgo: 72),
            Spec(publicID: "TMX-0063", featureID: 21, title: "Saved-query store",
                 description: "Persist saved queries and surface them in the autocomplete history list.",
                 status: .todo, estimate: "S", branchName: "",
                 criteriaCount: 3, criteriaDone: 0, hoursAgo: 96),
            Spec(publicID: "TMX-0070", featureID: 31, title: "Hover popover component",
                 description: "Reusable hover popover used by footnote link previews.",
                 status: .todo, estimate: "S", branchName: "",
                 criteriaCount: 2, criteriaDone: 0, hoursAgo: 144)
        ]

        var tickets: [Components.Schemas.Ticket] = []
        var criteria: [Int64: [Components.Schemas.AcceptanceCriterion]] = [:]
        var ticketID: Int64 = 200
        var criterionID: Int64 = 1000
        let now = Date()

        for spec in specs {
            let updatedAt = now.addingTimeInterval(-spec.hoursAgo * 3600)
            let createdAt = updatedAt.addingTimeInterval(-72 * 3600)

            var ticketCriteria: [Components.Schemas.AcceptanceCriterion] = []
            for index in 0..<spec.criteriaCount {
                let isDone = index < spec.criteriaDone
                ticketCriteria.append(Components.Schemas.AcceptanceCriterion(
                    id: criterionID,
                    ticketId: ticketID,
                    text: "\(spec.title) — step \(index + 1)",
                    done: isDone,
                    sortOrder: index,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                ))
                criterionID += 1
            }

            tickets.append(Components.Schemas.Ticket(
                id: ticketID,
                publicId: spec.publicID,
                featureId: spec.featureID,
                title: spec.title,
                description: spec.description,
                status: spec.status,
                estimate: spec.estimate,
                branchName: spec.branchName,
                criteria: nil,
                criteriaTotal: ticketCriteria.count,
                criteriaDone: ticketCriteria.filter { $0.done }.count,
                createdAt: createdAt,
                updatedAt: updatedAt
            ))
            criteria[ticketID] = ticketCriteria
            ticketID += 1
        }

        // Highest seeded public ID is TMX-0070; next created ticket starts at 0071.
        return (tickets, criteria, ticketID, criterionID, 71)
    }

    static var seedLocalNotes: [LocalProjectNote] {
        [
            LocalProjectNote(
                id: "project-1-brief",
                projectID: 1,
                kind: .projectBrief,
                title: "Project brief",
                body: "Build a backend and native clients for launching, monitoring, and steering tmux-backed coding sessions.",
                updatedAt: Date()
            ),
            LocalProjectNote(
                id: "project-1-notes",
                projectID: 1,
                kind: .projectNotes,
                title: "Project notes",
                body: "OpenAPI remains the source of truth. Sessions currently hang off projects/features; ticket endpoints are planned but not exposed yet.",
                updatedAt: Date()
            )
        ]
    }

    // Seed feature-level Docs with TipTap-shaped body_blocks JSON. The
    // contract treats body_blocks as opaque text; the renderer view
    // (service-feature-prd-tab) is what parses it. Pinned docs surface
    // first per the contract's list ordering, with the rest sorted by
    // updatedAt desc (handled in listFeatureDocs).
    static func seedDocs() -> (docs: [Components.Schemas.Doc], nextDocID: Int64) {
        struct Spec {
            let featureID: Int64
            let kind: Components.Schemas.DocKind
            let title: String
            let bodyBlocks: String
            let pinned: Bool
            let hoursAgo: Double
        }
        let visionBlocks = """
        [{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Vision"}]},\
        {"type":"paragraph","content":[{"type":"text","text":"Stream pane output over WebSocket and send tmux input through the REST endpoint."}]},\
        {"type":"paragraph","content":[{"type":"text","text":"The terminal becomes a first-class drill-down surface, not a tab."}]}]
        """
        let prdBlocks = """
        [{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Problem"}]},\
        {"type":"paragraph","content":[{"type":"text","text":"Mobile users need to read tmux output and steer agents without falling back to SSH."}]},\
        {"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Plan"}]},\
        {"type":"paragraph","content":[{"type":"text","text":"Implement the smallest path that lets a mobile client pick a pane, see output, submit empty Enter, and send control commands."}]}]
        """
        let notesBlocks = """
        [{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Notes"}]},\
        {"type":"bulletList","content":[\
        {"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"Use Runestone for the text surface so prompt-block segmentation can come later."}]}]},\
        {"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"Don't conflate raw tmux Sessions with persistent AgentSession records."}]}]}]}]
        """
        let designBlocks = """
        [{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Layout"}]},\
        {"type":"paragraph","content":[{"type":"text","text":"Three deep links: Tickets, PRD, Sessions. Hero: status pill + title + vision."}]},\
        {"type":"heading","attrs":{"level":3},"content":[{"type":"text","text":"Progress bar"}]},\
        {"type":"paragraph","content":[{"type":"text","text":"Reads progress_cached on the feature; recomputed server-side on ticket transitions."}]}]
        """
        let logBlocks = """
        [{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Build log"}]},\
        {"type":"paragraph","content":[{"type":"text","text":"Service-0006 closed the routing primitive; per-tab paths persist."}]},\
        {"type":"paragraph","content":[{"type":"text","text":"Service-0007 landed Tickets + AcceptanceCriteria end-to-end."}]}]
        """
        let customBlocks = """
        [{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Prompt buildout"}]},\
        {"type":"paragraph","content":[{"type":"text","text":"Prefer native list navigation, editor panes for project/feature docs, and a terminal that keeps context visible."}]}]
        """

        let specs: [Spec] = [
            // Feature 11 — Agent pane multiplexer (FEAT-018)
            Spec(featureID: 11, kind: .vision, title: "Pane multiplexer vision",
                 bodyBlocks: visionBlocks, pinned: true, hoursAgo: 0.5),
            Spec(featureID: 11, kind: .prd, title: "Pane multiplexer PRD",
                 bodyBlocks: prdBlocks, pinned: false, hoursAgo: 6),
            Spec(featureID: 11, kind: .notes, title: "Implementation notes",
                 bodyBlocks: notesBlocks, pinned: false, hoursAgo: 24),
            // Feature 12 — Feature context bundle (FEAT-019)
            Spec(featureID: 12, kind: .prd, title: "Context bundle PRD",
                 bodyBlocks: prdBlocks, pinned: true, hoursAgo: 1),
            Spec(featureID: 12, kind: .design, title: "Context schema design",
                 bodyBlocks: designBlocks, pinned: false, hoursAgo: 48),
            Spec(featureID: 12, kind: .log, title: "Build log",
                 bodyBlocks: logBlocks, pinned: false, hoursAgo: 12),
            // Feature 13 — Review diff + checklist (FEAT-020)
            Spec(featureID: 13, kind: .vision, title: "Review surface vision",
                 bodyBlocks: visionBlocks, pinned: false, hoursAgo: 4),
            Spec(featureID: 13, kind: .custom, title: "Eng design v2",
                 bodyBlocks: customBlocks, pinned: true, hoursAgo: 2),
            Spec(featureID: 13, kind: .notes, title: "Review UX notes",
                 bodyBlocks: notesBlocks, pinned: false, hoursAgo: 20),
            // Feature 21 — Structured query grammar (FEAT-031, sift)
            Spec(featureID: 21, kind: .prd, title: "Query grammar PRD",
                 bodyBlocks: prdBlocks, pinned: true, hoursAgo: 3),
            Spec(featureID: 21, kind: .notes, title: "Parser notes",
                 bodyBlocks: notesBlocks, pinned: false, hoursAgo: 36)
        ]

        var docs: [Components.Schemas.Doc] = []
        var docID: Int64 = 500
        let now = Date()

        for spec in specs {
            let updatedAt = now.addingTimeInterval(-spec.hoursAgo * 3600)
            let createdAt = updatedAt.addingTimeInterval(-72 * 3600)
            docs.append(Components.Schemas.Doc(
                id: docID,
                featureId: spec.featureID,
                kind: spec.kind,
                title: spec.title,
                bodyBlocks: spec.bodyBlocks,
                objectKey: nil,
                wordCount: wordCount(of: spec.bodyBlocks),
                pinned: spec.pinned,
                createdAt: createdAt,
                updatedAt: updatedAt
            ))
            docID += 1
        }

        return (docs, docID)
    }

    // Seeds 2–3 decisions per active feature with mixed human / agent
    // actors so the future Decisions sub-tab has something to render and
    // tests can exercise the actor enum. Backend emits an activity event
    // when a Decision is created via POST /decisions; the mock does NOT
    // chain that — service-repo-activity owns the activity surface and
    // ships separately.
    static func seedDecisions() -> (decisions: [Components.Schemas.Decision], nextDecisionID: Int64) {
        struct Spec {
            let featureID: Int64
            let title: String
            let body: String
            let actor: Components.Schemas.DecisionActor
            let actorName: String
            let hoursAgo: Double
        }
        let specs: [Spec] = [
            // Feature 11 — Agent pane multiplexer (FEAT-018)
            Spec(featureID: 11,
                 title: "Use one WebSocket per pane",
                 body: "Multiplexing all panes onto a single socket complicates resize + reconnect. One stream per pane keeps ownership clear.",
                 actor: .human, actorName: "Nick", hoursAgo: 2),
            Spec(featureID: 11,
                 title: "REST snapshot is the recovery path",
                 body: "When the WebSocket drops we re-seed from /panes/{id}/output rather than buffering on the server.",
                 actor: .agent, actorName: "Codex", hoursAgo: 26),
            Spec(featureID: 11,
                 title: "Empty-Enter is a first-class action",
                 body: "Users send literal Enter often enough (REPL prompts, prompts waiting on confirmation) that we expose it explicitly.",
                 actor: .human, actorName: "Nick", hoursAgo: 96),
            // Feature 12 — Feature context bundle (FEAT-019)
            Spec(featureID: 12,
                 title: "Terminal is a drill-down, not a tab",
                 body: "Five tabs; the terminal lives under Sessions / Inbox / Feature Sessions sub-tab. Tab bar hides while the terminal is presented.",
                 actor: .human, actorName: "Nick", hoursAgo: 6),
            Spec(featureID: 12,
                 title: "Default tab is Inbox",
                 body: "Inbox surfaces the agent's needs-you queue; users open the app to triage, not to browse projects.",
                 actor: .human, actorName: "Nick", hoursAgo: 30),
            // Feature 13 — Review diff + checklist (FEAT-020)
            Spec(featureID: 13,
                 title: "Don't conflate AgentSession with raw tmux Session",
                 body: "AgentSession is the persistent record (state, transcript_key, cost). Raw Session/Pane stay for the WebSocket transport.",
                 actor: .agent, actorName: "Codex", hoursAgo: 8),
            Spec(featureID: 13,
                 title: "OpenAPI is the single source of truth",
                 body: "Mobile + web both consume generated types. Hand-rolled DTOs that duplicate the contract get deleted on sight.",
                 actor: .human, actorName: "Nick", hoursAgo: 72),
            // Feature 21 — Structured query grammar (FEAT-031, sift)
            Spec(featureID: 21,
                 title: "Use PEG parser, not hand-rolled",
                 body: "PEG gives us a declarative grammar that's easy to extend for new filter operators without rewriting the tokenizer.",
                 actor: .agent, actorName: "Codex", hoursAgo: 36),
            Spec(featureID: 21,
                 title: "Autocomplete reads the index schema, not a static list",
                 body: "The field list changes as users add log sources; dynamic schema introspection keeps completions accurate.",
                 actor: .human, actorName: "Nick", hoursAgo: 60)
        ]

        var decisions: [Components.Schemas.Decision] = []
        var decisionID: Int64 = 700
        let now = Date()

        for spec in specs {
            decisions.append(Components.Schemas.Decision(
                id: decisionID,
                featureId: spec.featureID,
                title: spec.title,
                body: spec.body,
                actor: spec.actor,
                actorName: spec.actorName,
                createdAt: now.addingTimeInterval(-spec.hoursAgo * 3600)
            ))
            decisionID += 1
        }

        return (decisions, decisionID)
    }

    // Seeds the 10 fixture activity events from the design's data.jsx.
    // Feature mapping: FEAT-018 → feature 11 (project 1), FEAT-019 → feature 12
    // (project 1), FEAT-020 → feature 13 (project 1). Ticket numeric ids
    // mirror seedTickets — TMX-0042 = 200, TMX-0043 = 201, TMX-0044 =
    // 202, TMX-0050 = 208, TMX-0051 = 209.
    static func seedActivityEvents() -> (events: [Components.Schemas.ActivityEvent], nextID: Int64) {
        struct Spec {
            let actor: Components.Schemas.ActivityActor
            let actorName: String
            let verb: String
            let kind: Components.Schemas.ActivityKind
            let detail: String
            let projectID: Int64?
            let featureID: Int64?
            let ticketID: Int64?
            let minutesAgo: Double
        }
        let specs: [Spec] = [
            Spec(actor: .agent, actorName: "session-04", verb: "pushed 3 commits",
                 kind: .commit, detail: "pane registry skeleton + tests",
                 projectID: 1, featureID: 11, ticketID: 200, minutesAgo: 12),
            Spec(actor: .agent, actorName: "session-04", verb: "updated checklist",
                 kind: .check, detail: "2/4 acceptance criteria met",
                 projectID: 1, featureID: 11, ticketID: 200, minutesAgo: 14),
            Spec(actor: .agent, actorName: "session-07", verb: "opened review",
                 kind: .review, detail: "+412 / −37 across 9 files",
                 projectID: 1, featureID: 13, ticketID: 208, minutesAgo: 32),
            Spec(actor: .human, actorName: "you", verb: "edited PRD",
                 kind: .doc, detail: "\"Resume hook re-injects last 200 lines\"",
                 projectID: 1, featureID: 12, ticketID: nil, minutesAgo: 60),
            Spec(actor: .agent, actorName: "session-05", verb: "logged decision",
                 kind: .decision, detail: "use slug+sha as bundle key, not branch",
                 projectID: 1, featureID: 12, ticketID: nil, minutesAgo: 65),
            Spec(actor: .agent, actorName: "session-07", verb: "requested input",
                 kind: .question, detail: "\"Use unified diff or split? defaulting to split.\"",
                 projectID: 1, featureID: 13, ticketID: 208, minutesAgo: 120),
            Spec(actor: .agent, actorName: "session-04", verb: "ran tests",
                 kind: .test, detail: "go test ./... — 142 passed, 0 failed",
                 projectID: 1, featureID: 11, ticketID: 201, minutesAgo: 180),
            Spec(actor: .human, actorName: "you", verb: "approved",
                 kind: .approve, detail: "merged into FEAT-018",
                 projectID: 1, featureID: 11, ticketID: 202, minutesAgo: 240),
            Spec(actor: .agent, actorName: "session-05", verb: "drafted spec",
                 kind: .doc, detail: "Eng design v2 — 8 sections, 1.4k words",
                 projectID: 1, featureID: 12, ticketID: nil, minutesAgo: 300),
            Spec(actor: .agent, actorName: "session-07", verb: "rebased",
                 kind: .commit, detail: "on FEAT-020 head, no conflicts",
                 projectID: 1, featureID: 13, ticketID: 209, minutesAgo: 360)
        ]

        var events: [Components.Schemas.ActivityEvent] = []
        var eventID: Int64 = 900
        let now = Date()

        for spec in specs {
            events.append(Components.Schemas.ActivityEvent(
                id: eventID,
                projectId: spec.projectID,
                featureId: spec.featureID,
                ticketId: spec.ticketID,
                actor: spec.actor,
                actorName: spec.actorName,
                verb: spec.verb,
                kind: spec.kind,
                detail: spec.detail,
                createdAt: now.addingTimeInterval(-spec.minutesAgo * 60)
            ))
            eventID += 1
        }

        return (events, eventID)
    }

    // Seeds the four agent sessions from the design's data.jsx
    // (session-04, -05, -07, -08) onto seeded ticket ids. State,
    // pane, and CPU come straight from the fixture; uptime is
    // derived from the elapsed time since startTime so views can
    // exercise AgentSessionExtensions.uptime against realistic
    // values.
    static func seedAgentSessions() -> (sessions: [Components.Schemas.AgentSession], nextID: Int64) {
        struct Spec {
            let ticketID: Int64?
            let tmuxSession: String
            let state: Components.Schemas.SessionState
            let pane: String
            let cpu: Double
            let startMinutesAgo: Double
            let lastActiveMinutesAgo: Double
        }
        let specs: [Spec] = [
            // session-04 → TMX-0042 (ticket id 200), idle, 2h 14m uptime
            Spec(ticketID: 200, tmuxSession: "tmux_agent__agent_pane_multiplexer__feat_tmx_0042_pane_registry",
                 state: .idle, pane: "agent:0.0", cpu: 2,
                 startMinutesAgo: 134, lastActiveMinutesAgo: 6),
            // session-05 → TMX-0047 (ticket id 205), awaiting-input, 4h 02m
            Spec(ticketID: 205, tmuxSession: "tmux_agent__feature_context_bundle__feat_tmx_0047_context_bundle",
                 state: .awaitingInput, pane: "agent:1.0", cpu: 0,
                 startMinutesAgo: 242, lastActiveMinutesAgo: 12),
            // session-07 → TMX-0050 (ticket id 208), active, 47m
            Spec(ticketID: 208, tmuxSession: "tmux_agent__review_diff_checklist__feat_tmx_0050_diff_viewer",
                 state: .active, pane: "agent:2.0", cpu: 31,
                 startMinutesAgo: 47, lastActiveMinutesAgo: 1),
            // session-08 → TMX-0048 (ticket id 206), active, 22m
            Spec(ticketID: 206, tmuxSession: "tmux_agent__feature_context_bundle__feat_tmx_0048_prd_resolver",
                 state: .active, pane: "agent:1.1", cpu: 18,
                 startMinutesAgo: 22, lastActiveMinutesAgo: 1)
        ]

        var sessions: [Components.Schemas.AgentSession] = []
        var sessionID: Int64 = 800
        let now = Date()

        for spec in specs {
            sessions.append(Components.Schemas.AgentSession(
                id: sessionID,
                ticketId: spec.ticketID,
                tmuxSession: spec.tmuxSession,
                state: spec.state,
                pane: spec.pane,
                cpu: spec.cpu,
                startTime: now.addingTimeInterval(-spec.startMinutesAgo * 60),
                endTime: nil,
                lastActiveAt: now.addingTimeInterval(-spec.lastActiveMinutesAgo * 60),
                transcriptKey: nil,
                tokenUsage: nil,
                costEstimate: nil,
                createdAt: now.addingTimeInterval(-spec.startMinutesAgo * 60)
            ))
            sessionID += 1
        }

        return (sessions, sessionID)
    }

    // Seeds a fixture TicketDiff for TMX-0050 (the design's example).
    // Two FileDiffs — one .modified, one .added — with old / new
    // content five-plus lines apart so a unified-diff render exercises
    // +/- and context lines plus a hunk header.
    static func seedTicketDiffs() -> [String: Components.Schemas.TicketDiff] {
        let modifiedOld = """
        struct DiffViewer: View {
            let files: [FileDiff]
            var body: some View {
                List(files) { file in
                    Text(file.path)
                }
            }
        }
        """
        let modifiedNew = """
        struct DiffViewer: View {
            let files: [FileDiff]
            @State private var selected: FileDiff?
            var body: some View {
                NavigationSplitView {
                    List(files, selection: $selected) { file in
                        DiffFileRow(file: file)
                    }
                } detail: {
                    if let file = selected {
                        DiffPaneView(file: file)
                    } else {
                        ContentUnavailableView("Pick a file", systemImage: "doc.text")
                    }
                }
            }
        }
        """
        let addedNew = """
        struct DiffPaneView: View {
            let file: FileDiff
            var body: some View {
                ScrollView {
                    UnifiedDiffText(old: file.oldContent, new: file.newContent)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
                .navigationTitle(file.path)
            }
        }
        """
        let diff = Components.Schemas.TicketDiff(
            ticketPublicId: "TMX-0050",
            base: "main",
            branch: "feat/tmx-0050-diff-viewer",
            files: [
                Components.Schemas.FileDiff(
                    path: "tmux-agent/Features/Review/DiffViewer.swift",
                    oldPath: nil,
                    change: .modified,
                    binary: false,
                    oldContent: modifiedOld,
                    newContent: modifiedNew
                ),
                Components.Schemas.FileDiff(
                    path: "tmux-agent/Features/Review/DiffPaneView.swift",
                    oldPath: nil,
                    change: .added,
                    binary: false,
                    oldContent: "",
                    newContent: addedNew
                )
            ]
        )
        return ["TMX-0050": diff]
    }
}
