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
