import Foundation
import Observation

@MainActor
@Observable
final class TerminalViewModel {
    var session: Components.Schemas.AgentSession?
    var siblingSessionIDs: [Int64] = []
    var siblingSessions: [Components.Schemas.AgentSession] = []
    var output = ""
    var input = ""
    var isLoading = false
    var errorMessage: String?
    var showSpawnSheet = false

    func load(
        sessionID: Int64,
        repository: TmuxAgentRepository,
        activityPoller: ActivityPoller
    ) async {
        guard session == nil else { return }
        isLoading = true
        errorMessage = nil
        activityPoller.stop()
        do {
            let s = try await repository.getAgentSession(id: sessionID)
            session = s
            let snapshot = try await repository.getPaneOutput(
                sessionName: s.tmuxSession,
                paneID: s.paneIndex
            )
            output = snapshot.content
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // Loads sibling sessions from the same project by iterating projects until
    // the current session is found. Called once after the session resolves.
    func loadSiblings(repository: TmuxAgentRepository) async {
        guard let current = session else { return }
        do {
            let projects = try await repository.listProjects()
            for project in projects {
                let sessions = try await repository.listProjectAgentSessions(
                    projectIDOrSlug: String(project.id)
                )
                guard sessions.contains(where: { $0.id == current.id }) else { continue }
                // Active session first, then by lastActiveAt desc.
                siblingSessions = sessions.sorted { lhs, rhs in
                    if lhs.id == current.id { return true }
                    if rhs.id == current.id { return false }
                    return lhs.lastActiveAt > rhs.lastActiveAt
                }
                return
            }
        } catch { }
    }

    func switchSession(to target: Components.Schemas.AgentSession, repository: TmuxAgentRepository) async {
        session = target
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await repository.getPaneOutput(
                sessionName: target.tmuxSession,
                paneID: target.paneIndex
            )
            output = snapshot.content
        } catch {
            errorMessage = "Couldn't reach pane."
        }
        isLoading = false
    }

    func reload(repository: TmuxAgentRepository) async {
        guard let s = session else { return }
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await repository.getPaneOutput(
                sessionName: s.tmuxSession,
                paneID: s.paneIndex
            )
            output = snapshot.content
        } catch {
            errorMessage = "Couldn't reach pane."
        }
        isLoading = false
    }

    func sendInput(_ request: Components.Schemas.SendInputRequest, repository: TmuxAgentRepository) async {
        guard let s = session else { return }
        errorMessage = nil
        do {
            _ = try await repository.sendPaneInput(
                sessionName: s.tmuxSession,
                paneID: s.paneIndex,
                body: request
            )
            let snapshot = try await repository.getPaneOutput(
                sessionName: s.tmuxSession,
                paneID: s.paneIndex
            )
            output = snapshot.content
        } catch {
            errorMessage = "Unable to send input."
        }
    }
}

extension Components.Schemas.SendInputRequest {
    static func text(_ value: String, submit: Bool) -> Self {
        Self(text: value, keys: nil, enter: submit)
    }

    static func key(_ value: String) -> Self {
        Self(text: nil, keys: [value], enter: nil)
    }

    static func enterOnly() -> Self {
        Self(text: nil, keys: ["Enter"], enter: nil)
    }
}
