import Foundation
import Testing
@testable import remote_coding

@MainActor
struct SpawnMockTests {

    private func makeRepo() -> MockTmuxAgentRepository {
        MockTmuxAgentRepository()
    }

    // MARK: - Fixture sessions

    @Test func fixtureIncludesFeatureScopedSession() async throws {
        let repo = makeRepo()
        // session-09: feature-scoped, feature 12
        let sessions = try await repo.listProjectAgentSessions(projectIDOrSlug: "1")
        let featureScoped = sessions.filter { $0.featureId != nil }
        #expect(!featureScoped.isEmpty)
        #expect(featureScoped.first?.featureId == 12)
    }

    @Test func fixtureIncludesProjectScopedSession() async throws {
        let repo = makeRepo()
        // session-10: project-scoped, project 1
        let sessions = try await repo.listProjectAgentSessions(projectIDOrSlug: "1")
        let projectScoped = sessions.filter { $0.projectId != nil }
        #expect(!projectScoped.isEmpty)
        #expect(projectScoped.first?.projectId == 1)
    }

    @Test func listProjectAgentSessionsIncludesAllScopes() async throws {
        let repo = makeRepo()
        let sessions = try await repo.listProjectAgentSessions(projectIDOrSlug: "1")
        let hasTicketScoped = sessions.contains { $0.ticketId != nil }
        let hasFeatureScoped = sessions.contains { $0.featureId != nil }
        let hasProjectScoped = sessions.contains { $0.projectId != nil }
        #expect(hasTicketScoped)
        #expect(hasFeatureScoped)
        #expect(hasProjectScoped)
    }

    // MARK: - createAgentSession multi-scope

    @Test func createTicketScopedSession() async throws {
        let repo = makeRepo()
        let body = Components.Schemas.CreateAgentSessionRequest(
            ticketPublicId: "TMX-0042",
            tmuxSession: nil, state: .idle, pane: nil, cpu: nil
        )
        let session = try await repo.createAgentSession(body)
        #expect(session.ticketId != nil)
        #expect(session.featureId == nil)
        #expect(session.projectId == nil)
    }

    @Test func createFeatureScopedSession() async throws {
        let repo = makeRepo()
        let body = Components.Schemas.CreateAgentSessionRequest(
            featureId: 12,
            tmuxSession: nil, state: .idle, pane: nil, cpu: nil
        )
        let session = try await repo.createAgentSession(body)
        #expect(session.featureId == 12)
        #expect(session.ticketId == nil)
        #expect(session.projectId == nil)
        #expect(session.tmuxSession.contains("feature_context_bundle"))
    }

    @Test func createProjectScopedSession() async throws {
        let repo = makeRepo()
        let body = Components.Schemas.CreateAgentSessionRequest(
            projectId: 1,
            tmuxSession: nil, state: .idle, pane: nil, cpu: nil
        )
        let session = try await repo.createAgentSession(body)
        #expect(session.projectId == 1)
        #expect(session.ticketId == nil)
        #expect(session.featureId == nil)
        #expect(session.tmuxSession.contains("tmux_agent"))
    }

    @Test func createSessionWithNoScopeThrows() async throws {
        let repo = makeRepo()
        let body = Components.Schemas.CreateAgentSessionRequest(
            tmuxSession: nil, state: nil, pane: nil, cpu: nil
        )
        await #expect(throws: (any Error).self) {
            _ = try await repo.createAgentSession(body)
        }
    }

    @Test func featureScopedSessionAppearsInProjectList() async throws {
        let repo = makeRepo()
        let before = try await repo.listProjectAgentSessions(projectIDOrSlug: "1")
        let body = Components.Schemas.CreateAgentSessionRequest(
            featureId: 11, state: .active
        )
        let created = try await repo.createAgentSession(body)
        let after = try await repo.listProjectAgentSessions(projectIDOrSlug: "1")
        #expect(after.count == before.count + 1)
        #expect(after.contains { $0.id == created.id })
    }

    @Test func projectScopedSessionAppearsInProjectList() async throws {
        let repo = makeRepo()
        let before = try await repo.listProjectAgentSessions(projectIDOrSlug: "1")
        let body = Components.Schemas.CreateAgentSessionRequest(
            projectId: 1, state: .idle
        )
        let created = try await repo.createAgentSession(body)
        let after = try await repo.listProjectAgentSessions(projectIDOrSlug: "1")
        #expect(after.count == before.count + 1)
        #expect(after.contains { $0.id == created.id })
    }
}
