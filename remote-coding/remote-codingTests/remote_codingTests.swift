//
//  remote_codingTests.swift
//  remote-codingTests
//
//  Created by Nick Buser on 4/30/26.
//

import Foundation
import Testing
@testable import remote_coding

struct remote_codingTests {

    // MARK: Repository — fixture decoding into generated types

    @MainActor
    @Test func mockRepositoryDecodesGeneratedSchemaFixtures() async throws {
        let repository = MockTmuxAgentRepository()

        let projects = try await repository.listProjects()
        let features = try await repository.listFeatures(projectIDOrSlug: "tmux-server-coding-app")

        // Idiomatic naming maps git_repo_url → gitRepoUrl (not gitRepoURL).
        // Catches regressions if the generator naming strategy ever flips.
        #expect(projects.first?.localRepoPath.contains("tmux_server_coding_app") == true)
        #expect(projects.first?.gitRepoUrl == "git@github.com:nick-buser/tmux-server-coding-app.git")
        #expect(features.first?.branchName == "service-0031")
        #expect(features.first?.projectId == 1)
        #expect(features.first?.status == .inProgress)
    }

    // MARK: Projects — list / get / update

    @MainActor
    @Test func listProjectsSortsPinnedThenLastTouched() async throws {
        let repository = MockTmuxAgentRepository()

        let projects = try await repository.listProjects()

        #expect(projects.count == 2)
        #expect(projects[0].pinned == true)
        #expect(projects[0].slug == "tmux-server-coding-app")
        #expect(projects[1].pinned == false)
    }

    @MainActor
    @Test func getProjectResolvesByIDAndSlug() async throws {
        let repository = MockTmuxAgentRepository()

        let bySlug = try await repository.getProject(idOrSlug: "remote-coding-ios")
        let byID = try await repository.getProject(idOrSlug: "2")

        #expect(bySlug.id == 2)
        #expect(byID.slug == "remote-coding-ios")
    }

    @MainActor
    @Test func updateProjectMutatesAndReturnsLatest() async throws {
        let repository = MockTmuxAgentRepository()

        let body = Components.Schemas.UpdateProjectRequest(
            name: "tmux server (renamed)",
            slug: nil,
            gitRepoUrl: "git@github.com:nick-buser/renamed.git",
            localRepoPath: "/Users/nickbuser/Projects/personal_coding/tmux_server_coding_app",
            tagline: "renamed tagline",
            description: nil,
            accent: "indigo",
            icon: "terminal",
            status: .active,
            pinned: false
        )
        let updated = try await repository.updateProject(idOrSlug: "tmux-server-coding-app", body: body)

        #expect(updated.name == "tmux server (renamed)")
        #expect(updated.gitRepoUrl == "git@github.com:nick-buser/renamed.git")
        #expect(updated.pinned == false)
        // The next list call should reflect the mutation.
        let after = try await repository.getProject(idOrSlug: "tmux-server-coding-app")
        #expect(after.tagline == "renamed tagline")
    }

    // MARK: Features — list / get

    @MainActor
    @Test func listFeaturesScopedToProject() async throws {
        let repository = MockTmuxAgentRepository()

        let tmuxAgentFeatures = try await repository.listFeatures(projectIDOrSlug: "tmux-server-coding-app")
        let iOSFeatures = try await repository.listFeatures(projectIDOrSlug: "remote-coding-ios")

        #expect(tmuxAgentFeatures.map(\.id).sorted() == [11, 12])
        #expect(iOSFeatures.map(\.id) == [21])
    }

    @MainActor
    @Test func getFeatureReturnsFullSchema() async throws {
        let repository = MockTmuxAgentRepository()

        let feature = try await repository.getFeature(id: 11)

        #expect(feature.title == "Session stream and pane input")
        #expect(feature.projectId == 1)
        #expect(feature.health == "ok")
    }

    // MARK: Tickets — list / get / create / update

    @MainActor
    @Test func listTicketsScopedToFeatureAndExcludesInlineCriteria() async throws {
        let repository = MockTmuxAgentRepository()

        let onFeature11 = try await repository.listTickets(featureID: 11, status: nil)
        let onFeature12 = try await repository.listTickets(featureID: 12, status: nil)
        let onFeature21 = try await repository.listTickets(featureID: 21, status: nil)

        // Distribution mirrors the seed; each feature owns a known slice.
        #expect(onFeature11.map(\.publicId).sorted() == ["TMX-0042", "TMX-0043", "TMX-0044", "TMX-0045", "TMX-0046"])
        #expect(onFeature12.count == 6)
        #expect(onFeature21.count == 4)
        // Contract: list responses omit the inline `criteria` array — counts
        // ride on criteria_total / criteria_done. getTicket is the only
        // place criteria are populated.
        #expect(onFeature11.allSatisfy { $0.criteria == nil })
    }

    @MainActor
    @Test func listTicketsFiltersByStatus() async throws {
        let repository = MockTmuxAgentRepository()

        let inReview = try await repository.listTickets(featureID: 21, status: .review)
        let done = try await repository.listTickets(featureID: 12, status: .done)

        #expect(inReview.map(\.publicId).sorted() == ["TMX-0050", "TMX-0051"])
        #expect(inReview.allSatisfy { $0.status == .review })
        #expect(done.map(\.publicId) == ["TMX-0061"])
    }

    @MainActor
    @Test func getTicketReturnsInlineCriteriaSortedAscending() async throws {
        let repository = MockTmuxAgentRepository()

        let ticket = try await repository.getTicket(publicID: "TMX-0042")

        #expect(ticket.publicId == "TMX-0042")
        #expect(ticket.criteria?.count == 4)
        // Spec: AcceptanceCriterion.sortOrder is opaque to clients, but the
        // repository must return ascending so views don't have to.
        let orders = ticket.criteria?.map(\.sortOrder) ?? []
        #expect(orders == orders.sorted())
    }

    @MainActor
    @Test func createTicketIssuesUniqueTMXPublicID() async throws {
        let repository = MockTmuxAgentRepository()

        let body = Components.Schemas.CreateTicketRequest(
            title: "Wire ticket repository surface",
            description: "Drive the new repository methods from a screen.",
            status: nil,
            estimate: "S",
            branchName: "service-0007"
        )
        let created = try await repository.createTicket(featureID: 21, body: body)

        // Spec parameter pattern: ^TMX-[0-9]{4}$.
        let pattern = #"^TMX-[0-9]{4}$"#
        #expect(created.publicId.range(of: pattern, options: .regularExpression) != nil)
        // Status defaults to .todo when the request omits it (per the
        // generator's default + the spec).
        #expect(created.status == .todo)
        // Created ticket appears in subsequent list calls.
        let listed = try await repository.listTickets(featureID: 21, status: nil)
        #expect(listed.contains(where: { $0.publicId == created.publicId }))
    }

    @MainActor
    @Test func updateTicketMutatesFieldsAndPersists() async throws {
        let repository = MockTmuxAgentRepository()

        let body = Components.Schemas.UpdateTicketRequest(
            title: nil,
            description: "Tightened scope",
            status: .review,
            estimate: "L"
        )
        let updated = try await repository.updateTicket(publicID: "TMX-0042", body: body)

        #expect(updated.status == .review)
        #expect(updated.estimate == "L")
        #expect(updated.description == "Tightened scope")
        let next = try await repository.getTicket(publicID: "TMX-0042")
        #expect(next.status == .review)
    }

    // MARK: Acceptance criteria — list / create / update / delete

    @MainActor
    @Test func createCriterionAppendsToEndWhenSortOrderOmitted() async throws {
        let repository = MockTmuxAgentRepository()

        let before = try await repository.listCriteria(ticketPublicID: "TMX-0042")
        let body = Components.Schemas.CreateAcceptanceCriterionRequest(
            text: "Pane teardown is idempotent",
            done: false,
            sortOrder: nil
        )
        let created = try await repository.createCriterion(ticketPublicID: "TMX-0042", body: body)
        let after = try await repository.listCriteria(ticketPublicID: "TMX-0042")

        // The ticket explicitly calls this out: omitted sort_order appends.
        #expect(created.sortOrder == (before.last?.sortOrder ?? -1) + 1)
        #expect(after.last?.id == created.id)
        #expect(after.count == before.count + 1)
        // Counts on the parent ticket stay in sync.
        let ticket = try await repository.getTicket(publicID: "TMX-0042")
        #expect(ticket.criteriaTotal == after.count)
    }

    @MainActor
    @Test func updateCriterionTogglesDoneAndSurfacesInListAndCounts() async throws {
        let repository = MockTmuxAgentRepository()

        let initial = try await repository.listCriteria(ticketPublicID: "TMX-0042")
        // Seed has 4 criteria with 2 done. Flip one currently-done → not
        // done; counts should drop and the change must surface in the next
        // list call.
        let target = initial.first(where: { $0.done == true })!
        let body = Components.Schemas.UpdateAcceptanceCriterionRequest(
            text: nil,
            done: false,
            sortOrder: nil
        )
        let updated = try await repository.updateCriterion(id: target.id, body: body)
        let after = try await repository.listCriteria(ticketPublicID: "TMX-0042")
        let ticket = try await repository.getTicket(publicID: "TMX-0042")

        #expect(updated.done == false)
        #expect(after.first(where: { $0.id == target.id })?.done == false)
        #expect(ticket.criteriaDone == initial.filter { $0.done }.count - 1)
    }

    @MainActor
    @Test func deleteCriterionRemovesAndRecomputesCounts() async throws {
        let repository = MockTmuxAgentRepository()

        let initial = try await repository.listCriteria(ticketPublicID: "TMX-0044")
        let target = initial.first!
        try await repository.deleteCriterion(id: target.id)
        let after = try await repository.listCriteria(ticketPublicID: "TMX-0044")
        let ticket = try await repository.getTicket(publicID: "TMX-0044")

        #expect(after.contains(where: { $0.id == target.id }) == false)
        #expect(ticket.criteriaTotal == initial.count - 1)
    }

    // MARK: Feature docs

    @MainActor
    @Test func listFeatureDocsReturnsPinnedFirstThenMostRecentlyUpdated() async throws {
        let repository = MockTmuxAgentRepository()

        let docs = try await repository.listFeatureDocs(featureID: 12)

        // Feature 12 seeds with one pinned PRD; it must lead the list. The
        // remaining docs follow updatedAt desc.
        #expect(docs.count == 3)
        #expect(docs.first?.pinned == true)
        #expect(docs.first?.kind == .prd)
        let tail = docs.dropFirst()
        let tailDates = tail.map(\.updatedAt)
        #expect(tailDates == tailDates.sorted(by: >))
    }

    @MainActor
    @Test func createFeatureDocDefaultsBodyBlocksToEmptyJSONArrayWhenOmitted() async throws {
        let repository = MockTmuxAgentRepository()

        let body = Components.Schemas.CreateDocRequest(
            kind: .notes,
            title: "Drafted from the inbox",
            bodyBlocks: nil,
            pinned: nil
        )
        let created = try await repository.createFeatureDoc(featureID: 21, body: body)

        // Spec: bodyBlocks defaults to "[]" when omitted on create.
        #expect(created.bodyBlocks == "[]")
        #expect(created.pinned == false)
        // Word count is recomputed on create as well.
        #expect(created.wordCount == 0)
        // Created doc appears in subsequent list calls.
        let after = try await repository.listFeatureDocs(featureID: 21)
        #expect(after.contains(where: { $0.id == created.id }))
    }

    @MainActor
    @Test func updateDocRecomputesWordCountFromBodyBlocks() async throws {
        let repository = MockTmuxAgentRepository()

        let initial = try await repository.listFeatureDocs(featureID: 11).first!
        let body = Components.Schemas.UpdateDocRequest(
            kind: nil,
            title: nil,
            bodyBlocks: "one two three four five",
            pinned: nil
        )
        let updated = try await repository.updateDoc(id: initial.id, body: body)

        // Mock mimics the contract — server-side word_count is re-derived
        // from body_blocks on PATCH. Five space-separated tokens => 5.
        #expect(updated.wordCount == 5)
        #expect(updated.bodyBlocks == "one two three four five")
        // Subsequent get sees the new word_count, not the seed value.
        let next = try await repository.getDoc(id: initial.id)
        #expect(next.wordCount == 5)
    }

    @MainActor
    @Test func deleteDocRemovesFromList() async throws {
        let repository = MockTmuxAgentRepository()

        let initial = try await repository.listFeatureDocs(featureID: 21)
        let target = initial.first!
        try await repository.deleteDoc(id: target.id)
        let after = try await repository.listFeatureDocs(featureID: 21)

        #expect(after.contains(where: { $0.id == target.id }) == false)
        #expect(after.count == initial.count - 1)
    }

    // MARK: Feature decisions

    @MainActor
    @Test func listFeatureDecisionsReturnsNewestFirstAndScopedToFeature() async throws {
        let repository = MockTmuxAgentRepository()

        let onFeature11 = try await repository.listFeatureDecisions(featureID: 11)
        let onFeature21 = try await repository.listFeatureDecisions(featureID: 21)

        // Each feature owns its own decisions; cross-feature leakage would
        // be silent until UI shows it on the wrong screen.
        #expect(onFeature11.allSatisfy { $0.featureId == 11 })
        #expect(onFeature21.allSatisfy { $0.featureId == 21 })
        // Spec: createdAt DESC — every consecutive pair is non-increasing.
        let dates = onFeature11.map(\.createdAt)
        #expect(dates == dates.sorted(by: >))
    }

    @MainActor
    @Test func createFeatureDecisionAttachesActorAndAssignsServerCreatedAt() async throws {
        let repository = MockTmuxAgentRepository()

        let before = Date()
        let body = Components.Schemas.CreateDecisionRequest(
            title: "Use Runestone for terminal text",
            body: "Plain monospaced first; Runestone surface is wired in service-terminal-runestone.",
            actor: .human,
            actorName: "Nick"
        )
        let created = try await repository.createFeatureDecision(featureID: 12, body: body)

        // Server-assigned id + createdAt; the request never carried either.
        #expect(created.id >= 700)
        #expect(created.title == body.title)
        #expect(created.actor == .human)
        #expect(created.actorName == "Nick")
        #expect(created.createdAt >= before)
        // Created decision appears in the next list call, sorted to the top.
        let after = try await repository.listFeatureDecisions(featureID: 12)
        #expect(after.first?.id == created.id)
    }

    @MainActor
    @Test func deleteDecisionRemovesItFromTheList() async throws {
        let repository = MockTmuxAgentRepository()

        let initial = try await repository.listFeatureDecisions(featureID: 21)
        let target = initial.first!
        try await repository.deleteDecision(id: target.id)
        let after = try await repository.listFeatureDecisions(featureID: 21)

        #expect(after.contains(where: { $0.id == target.id }) == false)
        #expect(after.count == initial.count - 1)
    }

    // MARK: Activity

    @MainActor
    @Test func listActivityReturnsAllSeededEventsNewestFirstWhenUnfiltered() async throws {
        let repository = MockTmuxAgentRepository()

        let events = try await repository.listActivity(project: nil, feature: nil, since: nil, limit: nil)

        // 10 events from data.jsx are seeded. createdAt DESC must hold.
        #expect(events.count == 10)
        let dates = events.map(\.createdAt)
        #expect(dates == dates.sorted(by: >))
    }

    @MainActor
    @Test func listActivityFiltersByProjectFeatureSinceAndLimit() async throws {
        let repository = MockTmuxAgentRepository()

        // Project filter — slug accepted alongside numeric id.
        let onProject1 = try await repository.listActivity(project: "tmux-server-coding-app", feature: nil, since: nil, limit: nil)
        let onProject2 = try await repository.listActivity(project: "2", feature: nil, since: nil, limit: nil)
        // Feature filter (across all projects).
        let onFeature11 = try await repository.listActivity(project: nil, feature: 11, since: nil, limit: nil)
        // Since filter — strict greater-than the cursor.
        let cursor = onFeature11.last!.createdAt
        let afterCursor = try await repository.listActivity(project: nil, feature: 11, since: cursor, limit: nil)
        // Limit clamps the result.
        let limited = try await repository.listActivity(project: nil, feature: nil, since: nil, limit: 3)

        #expect(onProject1.allSatisfy { $0.projectId == 1 })
        #expect(onProject2.allSatisfy { $0.projectId == 2 })
        #expect(onFeature11.allSatisfy { $0.featureId == 11 })
        // Strict > cursor — the cursor event itself is excluded.
        #expect(afterCursor.contains(where: { $0.createdAt == cursor }) == false)
        #expect(afterCursor.count == onFeature11.count - 1)
        #expect(limited.count == 3)
    }

    @MainActor
    @Test func activityPollerAdvancesCursorAcrossTwoTicks() async throws {
        let repository = MockTmuxAgentRepository()
        let poller = ActivityPoller(repository: repository, interval: .seconds(60), limit: 100)

        // Tick 1 — pulls every seeded event, cursor pins to the newest.
        let firstBatch = await poller.tick()
        #expect(firstBatch.isEmpty == false)
        let firstCursor = poller.cursor
        #expect(firstCursor != nil)
        #expect(poller.events.count == firstBatch.count)

        // Tick 2 with the buffer at the latest cursor — nothing newer
        // exists, so the poll returns no records and cursor stays put.
        let secondBatch = await poller.tick()
        #expect(secondBatch.isEmpty)
        #expect(poller.cursor == firstCursor)

        // Inject a newer event and verify the next tick picks it up
        // and advances the cursor.
        let injected = Components.Schemas.ActivityEvent(
            id: 999,
            projectId: 1,
            featureId: 11,
            ticketId: nil,
            actor: .agent,
            actorName: "session-04",
            verb: "drafted",
            kind: .doc,
            detail: "fresh fixture",
            createdAt: Date().addingTimeInterval(60)
        )
        repository.appendActivityEvent(injected)
        let thirdBatch = await poller.tick()
        #expect(thirdBatch.count == 1)
        #expect(thirdBatch.first?.id == 999)
        #expect(poller.cursor == injected.createdAt)
        // Newer event lands at the front of the buffer.
        #expect(poller.events.first?.id == 999)
    }

    @MainActor
    @Test func activityPollerNeedsYouFlipsOnQuestionAndResetsAfterMarkSeen() async throws {
        let repository = MockTmuxAgentRepository()
        let poller = ActivityPoller(repository: repository, interval: .seconds(60), limit: 100)

        await poller.tick()
        // Seed already contains a `kind == question` event; needsYou
        // flips on the first tick because no markSeen cursor exists.
        #expect(poller.needsYou == true)

        // markSeen captures the latest event timestamp; needsYou drops
        // because no event is newer than the seen cursor.
        poller.markSeen()
        #expect(poller.needsYou == false)

        // A newly-injected `kind == question` event newer than the seen
        // cursor flips needsYou back on.
        let injected = Components.Schemas.ActivityEvent(
            id: 998,
            projectId: 2,
            featureId: 21,
            ticketId: 208,
            actor: .agent,
            actorName: "session-07",
            verb: "asked",
            kind: .question,
            detail: "is this column expected?",
            createdAt: Date().addingTimeInterval(120)
        )
        repository.appendActivityEvent(injected)
        await poller.tick()
        #expect(poller.needsYou == true)
    }

    // MARK: Agent sessions

    @MainActor
    @Test func listProjectAgentSessionsFiltersByProjectThroughTicket() async throws {
        let repository = MockTmuxAgentRepository()

        let onProject1 = try await repository.listProjectAgentSessions(projectIDOrSlug: "tmux-server-coding-app")
        let onProject2 = try await repository.listProjectAgentSessions(projectIDOrSlug: "remote-coding-ios")

        // Sessions resolve project membership through ticket → feature →
        // project. Project 1 owns features 11/12; project 2 owns 21.
        // Seeded sessions: session-04 (TMX-0042, f11), -05 (TMX-0047, f12),
        // -07 (TMX-0050, f21), -08 (TMX-0048, f12).
        #expect(onProject1.count == 3)
        #expect(onProject2.count == 1)
        // last_active_at desc — most-recently-active leads.
        let dates = onProject1.map(\.lastActiveAt)
        #expect(dates == dates.sorted(by: >))
    }

    @MainActor
    @Test func listTicketAgentSessionsFiltersByTicketID() async throws {
        let repository = MockTmuxAgentRepository()

        let onTMX0050 = try await repository.listTicketAgentSessions(ticketPublicID: "TMX-0050")
        let onTMX0046 = try await repository.listTicketAgentSessions(ticketPublicID: "TMX-0046")

        #expect(onTMX0050.count == 1)
        #expect(onTMX0050.first?.state == .active)
        #expect(onTMX0050.first?.cpu == 31)
        // TMX-0046 has no seeded session — empty list, not 404.
        #expect(onTMX0046.isEmpty)
    }

    @MainActor
    @Test func createAgentSessionDerivesTmuxSessionWhenOmitted() async throws {
        let repository = MockTmuxAgentRepository()

        let body = Components.Schemas.CreateAgentSessionRequest(
            ticketPublicId: "TMX-0042",
            tmuxSession: nil,
            state: nil,
            pane: nil,
            cpu: nil
        )
        let created = try await repository.createAgentSession(body)

        // Derived format: <project_slug>__<feature_slug>__<branch_slug>.
        // TMX-0042 hangs off feature 11 (slug session-stream-and-pane-input)
        // on project 1 (slug tmux-server-coding-app); ticket branch_name is
        // feat/tmx-0042-pane-registry.
        #expect(created.tmuxSession.contains("tmux_server_coding_app"))
        #expect(created.tmuxSession.contains("session_stream_and_pane_input"))
        #expect(created.tmuxSession.contains("feat_tmx_0042_pane_registry"))
        // Default state on omit is .idle.
        #expect(created.state == .idle)
        #expect(created.ticketId == 200)
    }

    @MainActor
    @Test func createAgentSessionEmitsActivityEventOnSpawn() async throws {
        let repository = MockTmuxAgentRepository()

        let before = try await repository.listActivity(project: nil, feature: nil, since: nil, limit: nil)
        let body = Components.Schemas.CreateAgentSessionRequest(
            ticketPublicId: "TMX-0050",
            tmuxSession: "explicit-override",
            state: .active,
            pane: "agent:9.0",
            cpu: 5
        )
        let created = try await repository.createAgentSession(body)
        let after = try await repository.listActivity(project: nil, feature: nil, since: nil, limit: nil)

        // Explicit tmux_session honoured verbatim; the request beats the
        // derivation rule.
        #expect(created.tmuxSession == "explicit-override")
        // Activity feed gains a kind == .check event for the spawn so
        // the Inbox / poller picks it up. Newest-first means it leads
        // the after list.
        #expect(after.count == before.count + 1)
        #expect(after.first?.kind == .check)
        #expect(after.first?.ticketId == 208)
    }

    @MainActor
    @Test func agentSessionUptimeFormatsHumanReadableDuration() {
        let now = Date()
        let twoHourFifteen = Components.Schemas.AgentSession(
            id: 1, ticketId: nil, tmuxSession: "x", state: .idle,
            pane: nil, cpu: 0,
            startTime: now.addingTimeInterval(-(2 * 3600 + 15 * 60)),
            endTime: nil, lastActiveAt: now,
            transcriptKey: nil, tokenUsage: nil, costEstimate: nil,
            createdAt: now
        )
        let fortySevenMinutes = Components.Schemas.AgentSession(
            id: 2, ticketId: nil, tmuxSession: "y", state: .active,
            pane: nil, cpu: 0,
            startTime: now.addingTimeInterval(-47 * 60),
            endTime: nil, lastActiveAt: now,
            transcriptKey: nil, tokenUsage: nil, costEstimate: nil,
            createdAt: now
        )
        let threeDays = Components.Schemas.AgentSession(
            id: 3, ticketId: nil, tmuxSession: "z", state: .idle,
            pane: nil, cpu: 0,
            startTime: now.addingTimeInterval(-3 * 24 * 3600),
            endTime: nil, lastActiveAt: now,
            transcriptKey: nil, tokenUsage: nil, costEstimate: nil,
            createdAt: now
        )

        #expect(twoHourFifteen.uptime == "2h 15m")
        #expect(fortySevenMinutes.uptime == "47m")
        #expect(threeDays.uptime == "3d")
    }

    // MARK: Ticket review

    @MainActor
    @Test func getTicketDiffReturnsFileDiffsWithPopulatedContent() async throws {
        let repository = MockTmuxAgentRepository()

        let diff = try await repository.getTicketDiff(publicID: "TMX-0050")

        // Spec fixture: TMX-0050 carries at least one .modified and one
        // .added FileDiff with non-empty content.
        #expect(diff.ticketPublicId == "TMX-0050")
        #expect(diff.files.count >= 2)
        #expect(diff.files.contains(where: { $0.change == .modified }))
        #expect(diff.files.contains(where: { $0.change == .added }))
        // Non-binary text files must carry old + new content the
        // unified-diff renderer can paint.
        let textFiles = diff.files.filter { $0.binary != true }
        #expect(textFiles.allSatisfy { !$0.newContent.isEmpty || $0.change == .deleted })
    }

    @MainActor
    @Test func approveTicketFlipsStatusToDoneAndEmitsApproveActivity() async throws {
        let repository = MockTmuxAgentRepository()

        let beforeActivity = try await repository.listActivity(project: nil, feature: nil, since: nil, limit: nil)
        let updated = try await repository.approveTicket(publicID: "TMX-0050")
        let afterActivity = try await repository.listActivity(project: nil, feature: nil, since: nil, limit: nil)
        let next = try await repository.getTicket(publicID: "TMX-0050")

        #expect(updated.status == .done)
        #expect(next.status == .done)
        // ActivityEvent(kind: .approve) lands at the head of the feed.
        #expect(afterActivity.count == beforeActivity.count + 1)
        #expect(afterActivity.first?.kind == .approve)
        #expect(afterActivity.first?.ticketId == 208)
    }

    @MainActor
    @Test func requestTicketChangesKeepsStatusInReviewAndCarriesCommentIntoActivity() async throws {
        let repository = MockTmuxAgentRepository()

        let updated = try await repository.requestTicketChanges(
            publicID: "TMX-0051",
            comment: "Tighten copy on the empty state."
        )
        let activity = try await repository.listActivity(project: nil, feature: nil, since: nil, limit: nil)

        // Spec: status stays in .review — agent pushes more commits to
        // the same branch.
        #expect(updated.status == .review)
        #expect(activity.first?.kind == .review)
        #expect(activity.first?.detail == "Tighten copy on the empty state.")
    }

    @MainActor
    @Test func sendTicketBackDropsStatusToDoingAndEmitsCheckActivity() async throws {
        let repository = MockTmuxAgentRepository()

        let updated = try await repository.sendTicketBack(
            publicID: "TMX-0050",
            comment: "Diff viewer needs a unified mode."
        )
        let activity = try await repository.listActivity(project: nil, feature: nil, since: nil, limit: nil)

        // Spec: drops back to .doing — the review failed and more work
        // is needed on the original branch.
        #expect(updated.status == .doing)
        #expect(activity.first?.kind == .check)
        #expect(activity.first?.detail == "Diff viewer needs a unified mode.")
    }

    // MARK: Local project notes

    @MainActor
    @Test func listProjectDocumentsReturnsSeededLocalNotesScopedByProject() async throws {
        let repository = MockTmuxAgentRepository()

        let onProject1 = try await repository.listProjectDocuments(projectID: 1)
        let onProject2 = try await repository.listProjectDocuments(projectID: 2)

        #expect(onProject1.map(\.kind).sorted(by: { $0.rawValue < $1.rawValue }) == [.projectBrief, .projectNotes])
        #expect(onProject2.isEmpty)
    }

    @MainActor
    @Test func saveLocalProjectNoteRoundTripsThroughList() async throws {
        let repository = MockTmuxAgentRepository()

        let initial = try await repository.listProjectDocuments(projectID: 1)
        let target = initial.first(where: { $0.kind == .projectBrief })!
        var edited = target
        edited.body = "Tightened brief — sessions are persistent agent records."
        let saved = try await repository.saveDocument(edited)
        let after = try await repository.listProjectDocuments(projectID: 1)

        #expect(saved.body == edited.body)
        #expect(saved.updatedAt > target.updatedAt)
        #expect(after.first(where: { $0.id == target.id })?.body == edited.body)
    }

    @MainActor
    @Test func localProjectNoteStorePersistsAcrossInstances() throws {
        let suiteName = "LocalProjectNoteStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LocalProjectNoteStore(userDefaults: defaults)
        let note = LocalProjectNote(
            id: "fresh-brief",
            projectID: 9,
            kind: .projectBrief,
            title: "Fresh",
            body: "Body",
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let saved = store.save(note)
        let other = LocalProjectNoteStore(userDefaults: defaults)

        // A second store reading the same defaults sees the saved note.
        let listed = other.list(projectID: 9)
        #expect(listed.count == 1)
        #expect(listed.first?.id == "fresh-brief")
        #expect(listed.first?.body == "Body")
        // saveDocument bumps updatedAt; the persisted record reflects the
        // bumped value, not the input.
        #expect(saved.updatedAt > Date(timeIntervalSince1970: 0))
    }

    // MARK: Sessions

    @MainActor
    @Test func sessionsAreScopedToProjectAndFeature() async throws {
        let repository = MockTmuxAgentRepository()

        let tmuxAgentSessions = try await repository.listSessions(projectID: 1)
        let iOSSessions = try await repository.listSessions(projectID: 2)
        let iOSFeatureSessions = try await repository.listSessions(featureID: 21)

        #expect(tmuxAgentSessions.map(\.name) == ["tmux_server_coding_app"])
        #expect(iOSSessions.map(\.name) == ["remote_coding_ios"])
        #expect(iOSFeatureSessions.map(\.name) == ["remote_coding_ios_service_0001"])
    }

    // MARK: Pane I/O

    @MainActor
    @Test func paneOutputDecodesSnakeCaseFixture() async throws {
        let repository = MockTmuxAgentRepository()

        let snapshot = try await repository.getPaneOutput(sessionName: "tmux_server_coding_app", paneID: 0)

        // session_name → sessionName, pane_index → paneIndex via CodingKeys.
        #expect(snapshot.sessionName == "tmux_server_coding_app")
        #expect(snapshot.paneIndex == 0)
        #expect(snapshot.content.contains("go test") == true)
    }

    @MainActor
    @Test func sendPaneInputRecordsRequestAndAppendsTranscript() async throws {
        let repository = MockTmuxAgentRepository()

        _ = try await repository.sendPaneInput(
            sessionName: "tmux_server_coding_app",
            paneID: 0,
            body: .text("ls -la", submit: true)
        )
        _ = try await repository.sendPaneInput(
            sessionName: "tmux_server_coding_app",
            paneID: 0,
            body: .key("C-c")
        )

        #expect(repository.sentInputs.count == 2)
        #expect(repository.sentInputs[0].body.text == "ls -la")
        #expect(repository.sentInputs[0].body.enter == true)
        #expect(repository.sentInputs[1].body.keys == ["C-c"])
    }

    // MARK: Terminal end-to-end

    @MainActor
    @Test func terminalSupportsEmptyEnterAndControlKeys() async throws {
        let repository = MockTmuxAgentRepository()
        let agentSession = try await repository.getAgentSession(id: 800)
        let viewModel = TerminalViewModel()
        viewModel.session = agentSession

        await viewModel.sendInput(.enterOnly(), repository: repository)
        await viewModel.sendInput(.key("C-c"), repository: repository)

        #expect(repository.sentInputs[0].body.text == nil)
        #expect(repository.sentInputs[0].body.keys == ["Enter"])
        #expect(repository.sentInputs[1].body.keys == ["C-c"])
    }

    // MARK: Configuration

    @Test func apiConfigurationValidatesAndNormalizesBaseURL() throws {
        let configuration = try APIConfiguration(baseURLString: "  http://192.168.1.10:8080/  ")

        #expect(configuration.baseURL.absoluteString == "http://192.168.1.10:8080")
        #expect(throws: APIConfigurationError.self) {
            _ = try APIConfiguration(baseURLString: "ftp://example.com")
        }
    }
}
