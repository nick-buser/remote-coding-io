import Foundation
import Testing
@testable import remote_coding

struct ProjectListViewModelTests {

    // MARK: - Helpers

    private static let baseDate = Date(timeIntervalSince1970: 1_730_000_000)

    private func makeProject(
        id: Int64,
        name: String,
        slug: String,
        pinned: Bool,
        lastTouchedAt: Date,
        status: Components.Schemas.ProjectStatus = .active,
        accent: String = "iris",
        icon: String = "terminal"
    ) -> Components.Schemas.Project {
        Components.Schemas.Project(
            id: id,
            name: name,
            slug: slug,
            gitRepoUrl: nil,
            localRepoPath: "/tmp/\(slug)",
            tagline: nil,
            description: nil,
            accent: accent,
            icon: icon,
            status: status,
            pinned: pinned,
            lastTouchedAt: lastTouchedAt,
            createdAt: lastTouchedAt,
            updatedAt: lastTouchedAt
        )
    }

    // MARK: - Sort

    @MainActor
    @Test func sortedPlacesPinnedFirstThenLastTouchedDesc() async {
        let now = Self.baseDate
        let p1 = makeProject(id: 1, name: "Old Pinned",   slug: "old-pinned",  pinned: true,  lastTouchedAt: now.addingTimeInterval(-3600))
        let p2 = makeProject(id: 2, name: "Recent Pin",   slug: "recent-pin",  pinned: true,  lastTouchedAt: now)
        let p3 = makeProject(id: 3, name: "Stale",        slug: "stale",       pinned: false, lastTouchedAt: now.addingTimeInterval(-7200))
        let p4 = makeProject(id: 4, name: "Just Touched", slug: "just",        pinned: false, lastTouchedAt: now.addingTimeInterval(-60))

        let sorted = ProjectListViewModel.sorted([p3, p1, p4, p2])

        #expect(sorted.map(\.id) == [2, 1, 4, 3])
    }

    @MainActor
    @Test func partitionPinnedAndUnpinned() async {
        let viewModel = ProjectListViewModel()
        let now = Self.baseDate
        viewModel.projects = ProjectListViewModel.sorted([
            makeProject(id: 1, name: "A", slug: "a", pinned: true,  lastTouchedAt: now),
            makeProject(id: 2, name: "B", slug: "b", pinned: false, lastTouchedAt: now),
            makeProject(id: 3, name: "C", slug: "c", pinned: true,  lastTouchedAt: now.addingTimeInterval(-60)),
        ])

        #expect(viewModel.pinnedProjects.map(\.id) == [1, 3])
        #expect(viewModel.unpinnedProjects.map(\.id) == [2])
    }

    // MARK: - Subtitle

    @MainActor
    @Test func subtitleOmitsLiveCountUntilLoaded() async {
        let viewModel = ProjectListViewModel()
        let now = Self.baseDate
        viewModel.projects = [
            makeProject(id: 1, name: "A", slug: "a", pinned: true,  lastTouchedAt: now),
            makeProject(id: 2, name: "B", slug: "b", pinned: false, lastTouchedAt: now),
        ]

        #expect(viewModel.subtitle() == "2 projects")
    }

    @MainActor
    @Test func subtitleIncludesLiveCountOnceLoaded() async {
        let viewModel = ProjectListViewModel()
        let now = Self.baseDate
        viewModel.projects = [makeProject(id: 1, name: "A", slug: "a", pinned: true, lastTouchedAt: now)]
        viewModel.liveSessionCounts[1] = 4

        #expect(viewModel.subtitle() == "1 project · 4 live sessions")
    }

    // MARK: - Mock-backed integration

    @MainActor
    @Test func loadFetchesProjectsAndFeatureCounts() async {
        let viewModel = ProjectListViewModel()
        let repository = MockTmuxAgentRepository()

        await viewModel.load(repository: repository)

        #expect(viewModel.projects.count == 2)
        #expect(viewModel.errorMessage == nil)
        // Each seeded project should have a feature count populated.
        for project in viewModel.projects {
            #expect(viewModel.featureCounts[project.id] != nil)
        }
    }

    @MainActor
    @Test func loadLiveSessionCountIsCachedPerProject() async {
        let viewModel = ProjectListViewModel()
        let repository = MockTmuxAgentRepository()
        await viewModel.load(repository: repository)
        let project = viewModel.projects.first(where: { $0.slug == "tmux-server-coding-app" })!

        await viewModel.loadLiveSessionCount(for: project, repository: repository)
        let cached = viewModel.liveSessionCounts[project.id]

        #expect(cached != nil)
        // Calling again should be a no-op (still cached).
        await viewModel.loadLiveSessionCount(for: project, repository: repository)
        #expect(viewModel.liveSessionCounts[project.id] == cached)
    }

    @MainActor
    @Test func togglePinFlipsPinnedAndResorts() async {
        let viewModel = ProjectListViewModel()
        let repository = MockTmuxAgentRepository()
        await viewModel.load(repository: repository)
        // Seed: project 1 ("tmux server") is pinned, project 2 is not.
        let initiallyPinned = viewModel.projects.first { $0.pinned }!

        await viewModel.togglePin(for: initiallyPinned, repository: repository)

        let updated = viewModel.projects.first { $0.id == initiallyPinned.id }
        #expect(updated?.pinned == false)
        // After unpinning the only pinned project, the unpinned section
        // contains both projects sorted by lastTouched desc.
        #expect(viewModel.pinnedProjects.isEmpty)
        #expect(viewModel.unpinnedProjects.count == 2)
    }

    // MARK: - Project status mapping

    @MainActor
    @Test func projectStatusStyleCoversAllCases() async {
        #expect(ProjectStatusStyle.label(for: .active) == "Active")
        #expect(ProjectStatusStyle.label(for: .maintenance) == "Maint.")
        #expect(ProjectStatusStyle.label(for: .paused) == "Paused")
    }

    @MainActor
    @Test func projectAccentMapperCoversV2AndLegacy() async {
        #expect(ProjectAccentMapper.color(for: "iris") == .iris)
        #expect(ProjectAccentMapper.color(for: "indigo") == .iris)
        #expect(ProjectAccentMapper.color(for: "teal") == .mint)
        #expect(ProjectAccentMapper.color(for: "amber") == .amber)
        #expect(ProjectAccentMapper.color(for: "") == .iris)
    }
}
