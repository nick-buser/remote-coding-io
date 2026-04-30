import Foundation
import Observation

@MainActor
@Observable
final class TerminalViewModel {
    var context: TerminalContext?
    var output = ""
    var input = ""
    var isLoading = false
    var errorMessage: String?
    var lastSentRequest: OpenAPI.SendInputRequest?

    func configure(context: TerminalContext?, repository: TmuxAgentRepository) async {
        guard self.context != context else {
            return
        }
        self.context = context
        await reload(repository: repository)
    }

    func reload(repository: TmuxAgentRepository) async {
        guard let context else {
            output = ""
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await repository.getPaneOutput(sessionName: context.session.name, paneID: context.pane.index)
            output = snapshot.content
        } catch {
            errorMessage = "Unable to load pane output."
        }
        isLoading = false
    }

    func submit(repository: TmuxAgentRepository) async {
        await send(OpenAPI.SendInputRequest.text(input, submit: true), repository: repository)
        input = ""
    }

    func sendEnter(repository: TmuxAgentRepository) async {
        await send(.enterOnly(), repository: repository)
    }

    func sendKey(_ key: String, repository: TmuxAgentRepository) async {
        await send(.key(key), repository: repository)
    }

    private func send(_ request: OpenAPI.SendInputRequest, repository: TmuxAgentRepository) async {
        guard let context else {
            return
        }
        errorMessage = nil
        do {
            _ = try await repository.sendPaneInput(sessionName: context.session.name, paneID: context.pane.index, body: request)
            lastSentRequest = request
            let snapshot = try await repository.getPaneOutput(sessionName: context.session.name, paneID: context.pane.index)
            output = snapshot.content
        } catch {
            errorMessage = "Unable to send input."
        }
    }
}

