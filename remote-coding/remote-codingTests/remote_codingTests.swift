//
//  remote_codingTests.swift
//  remote-codingTests
//
//  Created by Nick Buser on 4/30/26.
//

import Testing
@testable import remote_coding

struct remote_codingTests {

    @MainActor
    @Test func mockRepositoryDecodesOpenAPISchemaFixtures() async throws {
        let repository = MockTmuxAgentRepository()

        let projects = try await repository.listProjects()
        let features = try await repository.listFeatures(projectIDOrSlug: "tmux-server-coding-app")

        #expect(projects.first?.localRepoPath.contains("tmux_server_coding_app") == true)
        #expect(features.first?.branchName == "service-0031")
        #expect(features.first?.status == .inProgress)
    }

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

}
