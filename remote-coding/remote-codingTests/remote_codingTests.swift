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
        let project = try await repository.getProject(idOrSlug: "tmux-server-coding-app")
        let session = try await repository.listSessions().first!
        let pane = try await repository.listPanes(sessionName: session.name).first!
        let context = TerminalContext(project: project, feature: nil, session: session, pane: pane)
        let viewModel = TerminalViewModel()

        await viewModel.configure(context: context, repository: repository)
        await viewModel.sendEnter(repository: repository)
        await viewModel.sendKey("C-c", repository: repository)

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
