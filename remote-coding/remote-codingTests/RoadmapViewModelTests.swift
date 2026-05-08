import Foundation
import Testing
@testable import remote_coding

struct RoadmapViewModelTests {

    // MARK: - Helpers

    private func makeFeature(
        id: Int64,
        projectID: Int64,
        title: String,
        status: Components.Schemas.FeatureStatus,
        milestone: String?,
        targetDate: String? = nil,
        accent: String = "iris"
    ) -> Components.Schemas.Feature {
        Components.Schemas.Feature(
            id: id,
            projectId: projectID,
            branchName: nil,
            slug: "f-\(id)",
            title: title,
            vision: nil,
            descriptionDocKey: nil,
            status: status,
            accent: accent,
            milestone: milestone,
            targetDate: targetDate,
            health: "ok",
            tags: [],
            progressCached: 0,
            createdAt: Date()
        )
    }

    private func makeProject(id: Int64, name: String) -> Components.Schemas.Project {
        Components.Schemas.Project(
            id: id,
            name: name,
            slug: "p-\(id)",
            gitRepoUrl: nil,
            localRepoPath: "/tmp/p-\(id)",
            tagline: nil,
            description: nil,
            accent: "iris",
            icon: "terminal",
            status: .active,
            pinned: false,
            lastTouchedAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeBundle(
        projects: [Components.Schemas.Project],
        features: [Components.Schemas.Feature]
    ) -> CrossProjectFeatureFetcher.Bundle {
        var byProject: [Int64: [Components.Schemas.Feature]] = [:]
        for project in projects {
            byProject[project.id] = features.filter { $0.projectId == project.id }
        }
        return CrossProjectFeatureFetcher.Bundle(
            projects: projects,
            featuresByProjectID: byProject,
            agentSessionsByProjectID: [:]
        )
    }

    // MARK: - Derivation

    @MainActor
    @Test func milestonesGroupAndSortByEarliestTarget() async {
        let projects = [makeProject(id: 1, name: "A"), makeProject(id: 2, name: "B")]
        let features = [
            makeFeature(id: 1, projectID: 1, title: "Inbox composer",     status: .inProgress, milestone: "v0.4 — Multi-agent", targetDate: "2026-07-12"),
            makeFeature(id: 2, projectID: 1, title: "Pane registry",      status: .inProgress, milestone: "v0.4 — Multi-agent", targetDate: "2026-07-05"),
            makeFeature(id: 3, projectID: 2, title: "Diff viewer",        status: .review,     milestone: "v0.5 — Review UX",   targetDate: "2026-08-01"),
            makeFeature(id: 4, projectID: 2, title: "Loose end",          status: .planned,    milestone: nil),
        ]
        let bundle = makeBundle(projects: projects, features: features)

        let milestones = RoadmapViewModel.derive(from: bundle, projectFilter: nil)

        #expect(milestones.count == 2)
        #expect(milestones[0].rawLabel == "v0.4 — Multi-agent")
        #expect(milestones[1].rawLabel == "v0.5 — Review UX")
        #expect(milestones[0].label == "Multi-agent")
        #expect(milestones[0].idPrefix == "v0.4")
        #expect(milestones[0].earliestTarget == "2026-07-05")
    }

    @MainActor
    @Test func milestoneStateReflectsFeatureStatuses() async {
        let projects = [makeProject(id: 1, name: "A")]
        let bundle = makeBundle(
            projects: projects,
            features: [makeFeature(id: 1, projectID: 1, title: "T", status: .inProgress, milestone: "M1")]
        )

        #expect(RoadmapViewModel.derive(from: bundle, projectFilter: nil).first?.state == .active)

        let shippedBundle = makeBundle(
            projects: projects,
            features: [
                makeFeature(id: 2, projectID: 1, title: "T2", status: .shipped, milestone: "M1"),
                makeFeature(id: 3, projectID: 1, title: "T3", status: .merged,  milestone: "M1"),
            ]
        )
        #expect(RoadmapViewModel.derive(from: shippedBundle, projectFilter: nil).first?.state == .shipped)

        let plannedBundle = makeBundle(
            projects: projects,
            features: [makeFeature(id: 4, projectID: 1, title: "T4", status: .planned, milestone: "M1")]
        )
        #expect(RoadmapViewModel.derive(from: plannedBundle, projectFilter: nil).first?.state == .planned)
    }

    // MARK: - Project filter

    @MainActor
    @Test func projectFilterNarrowsFeaturesButKeepsMilestones() async {
        let projects = [makeProject(id: 1, name: "A"), makeProject(id: 2, name: "B")]
        let bundle = makeBundle(
            projects: projects,
            features: [
                makeFeature(id: 1, projectID: 1, title: "From A", status: .inProgress, milestone: "M1"),
                makeFeature(id: 2, projectID: 2, title: "From B", status: .inProgress, milestone: "M1"),
            ]
        )

        let filtered = RoadmapViewModel.derive(from: bundle, projectFilter: 1)

        #expect(filtered.count == 1)
        #expect(filtered.first?.features.count == 1)
        #expect(filtered.first?.features.first?.id == 1)
    }

    @MainActor
    @Test func projectFilterEmptiesMilestoneWhenNoMatch() async {
        let projects = [makeProject(id: 1, name: "A"), makeProject(id: 2, name: "B")]
        let bundle = makeBundle(
            projects: projects,
            features: [makeFeature(id: 1, projectID: 1, title: "From A", status: .inProgress, milestone: "M1")]
        )

        let filtered = RoadmapViewModel.derive(from: bundle, projectFilter: 2)

        #expect(filtered.count == 1)
        #expect(filtered.first?.features.isEmpty == true)
    }

    // MARK: - ID prefix extraction

    @MainActor
    @Test func extractIDPrefixHandlesVersionAndPlainLabels() async {
        #expect(RoadmapViewModel.extractIDPrefix(from: "v0.4 — Multi-agent") == "v0.4")
        #expect(RoadmapViewModel.extractIDPrefix(from: "M3 — Inbox") == "M3")
        #expect(RoadmapViewModel.extractIDPrefix(from: "Just a label") == "")
        #expect(RoadmapViewModel.trimIDPrefix(from: "v0.4 — Multi-agent") == "Multi-agent")
        #expect(RoadmapViewModel.trimIDPrefix(from: "Just a label") == "Just a label")
    }

    // MARK: - Subtitle

    @MainActor
    @Test func subtitleRespectsFilterAndCount() async {
        let viewModel = RoadmapViewModel()
        let projects = [makeProject(id: 1, name: "A"), makeProject(id: 2, name: "B")]
        viewModel.bundle = makeBundle(
            projects: projects,
            features: [makeFeature(id: 1, projectID: 1, title: "F", status: .inProgress, milestone: "M1")]
        )
        #expect(viewModel.subtitle() == "All projects · 1 milestone")

        viewModel.selectedProjectID = 2
        #expect(viewModel.subtitle() == "B · 1 milestone")
    }
}
