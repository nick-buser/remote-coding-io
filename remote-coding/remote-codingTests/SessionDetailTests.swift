import Foundation
import Testing
@testable import remote_coding

@MainActor
struct SessionDetailTests {

    // MARK: - killAgentSession

    @Test func killSetsEndedState() async throws {
        let repo = MockTmuxAgentRepository()
        let sessions = try await repo.listProjectAgentSessions(projectIDOrSlug: "1")
        let live = sessions.first(where: { $0.state != .ended })
        guard let session = live else {
            Issue.record("No live session found"); return
        }
        try await repo.killAgentSession(id: session.id)
        let updated = try await repo.getAgentSession(id: session.id)
        #expect(updated.state == .ended)
        #expect(updated.endTime != nil)
        #expect(updated.cpu == 0)
    }

    @Test func killUnknownSessionThrows() async {
        let repo = MockTmuxAgentRepository()
        await #expect(throws: (any Error).self) {
            try await repo.killAgentSession(id: 999_999)
        }
    }

    // MARK: - TerminalViewModel scope loading

    @Test func loadScopeTicket() async throws {
        let repo = MockTmuxAgentRepository()
        // Find a ticket-scoped session in the seed data
        let sessions = try await repo.listProjectAgentSessions(projectIDOrSlug: "1")
        guard let ticketSession = sessions.first(where: { $0.ticketId != nil }) else {
            Issue.record("No ticket-scoped session in seed"); return
        }
        let vm = TerminalViewModel()
        await vm.loadScope(for: ticketSession, repository: repo)
        #expect(vm.scopeTitle != nil)
        #expect(vm.scopeContext?.kind == .ticket)
        #expect(vm.scopeContext?.label.contains("TMX-") == true)
    }

    @Test func loadScopeProject() async throws {
        let repo = MockTmuxAgentRepository()
        // Create a project-scoped session
        let projects = try await repo.listProjects()
        let proj = projects[0]
        let created = try await repo.createAgentSession(
            Components.Schemas.CreateAgentSessionRequest(
                ticketPublicId: nil, featureId: nil, projectId: proj.id,
                tmuxSession: nil, state: .idle, pane: nil, cpu: nil
            )
        )
        let vm = TerminalViewModel()
        await vm.loadScope(for: created, repository: repo)
        #expect(vm.scopeTitle == proj.name)
        #expect(vm.scopeContext?.kind == .project)
    }

    @Test func loadScopeNoMatchLeavesNil() async {
        let repo = MockTmuxAgentRepository()
        let now = Date()
        let orphan = Components.Schemas.AgentSession(
            id: 9999, ticketId: nil, featureId: nil, projectId: nil,
            tmuxSession: "orphan", state: .idle, pane: nil, cpu: 0,
            startTime: now, endTime: nil, lastActiveAt: now,
            transcriptKey: nil, tokenUsage: nil, costEstimate: nil, createdAt: now
        )
        let vm = TerminalViewModel()
        await vm.loadScope(for: orphan, repository: repo)
        #expect(vm.scopeTitle == nil)
        #expect(vm.scopeContext == nil)
    }

    // MARK: - SessionRow scopeTitle

    @Test func sessionRowRendersScopeTitle() {
        // Verify the view model compiles with scopeTitle — structural check.
        let now = Date()
        let session = Components.Schemas.AgentSession(
            id: 1, ticketId: nil, featureId: nil, projectId: nil,
            tmuxSession: "test-session", state: .active, pane: nil, cpu: 0,
            startTime: now, endTime: nil, lastActiveAt: now,
            transcriptKey: nil, tokenUsage: nil, costEstimate: nil, createdAt: now
        )
        // If SessionRow compiles with scopeTitle: that's the structural test.
        let _ = SessionRow(session: session, ticketLabel: nil, scopeTitle: "My ticket", onTap: {})
        // If we get here the initialiser accepts the new parameter.
    }
}
