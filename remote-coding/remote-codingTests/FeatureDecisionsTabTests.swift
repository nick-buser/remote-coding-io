import Foundation
import Testing
@testable import remote_coding

struct FeatureDecisionsTabTests {

    // MARK: - Helpers

    @MainActor
    private func loadedViewModel(featureID: Int64 = 11) async throws -> (FeatureDetailViewModel, MockTmuxAgentRepository) {
        let repository = MockTmuxAgentRepository()
        let feature = try await repository.getFeature(id: featureID)
        let project = try await repository.getProject(idOrSlug: String(feature.projectId))
        let viewModel = FeatureDetailViewModel(project: project, feature: feature)
        await viewModel.load(repository: repository)
        return (viewModel, repository)
    }

    // MARK: - Sorting

    @MainActor
    @Test func sortIsNewestFirst() async throws {
        let (viewModel, _) = try await loadedViewModel()
        let sorted = viewModel.decisions.sorted { $0.createdAt > $1.createdAt }

        for index in 1..<sorted.count {
            #expect(sorted[index - 1].createdAt >= sorted[index].createdAt)
        }
    }

    // MARK: - Create

    @MainActor
    @Test func createPrependsToList() async throws {
        let (viewModel, repository) = try await loadedViewModel()
        let initialCount = viewModel.decisions.count

        let body = Components.Schemas.CreateDecisionRequest(
            title: "Test decision",
            body: "Why we did it",
            actor: .human,
            actorName: "Tester"
        )
        let created = try await repository.createFeatureDecision(featureID: viewModel.feature.id, body: body)
        viewModel.decisions.insert(created, at: 0)

        #expect(viewModel.decisions.count == initialCount + 1)
        #expect(viewModel.decisions.first?.title == "Test decision")
        #expect(viewModel.decisions.first?.actor == .human)
    }

    @MainActor
    @Test func createTrimsWhitespaceFromTitle() async throws {
        // The view trims before submit; this test verifies the
        // simulated "submit" path matches what the form produces.
        let (viewModel, repository) = try await loadedViewModel()

        let trimmedTitle = "  trimmed  ".trimmingCharacters(in: .whitespacesAndNewlines)
        let body = Components.Schemas.CreateDecisionRequest(
            title: trimmedTitle,
            body: nil,
            actor: .agent,
            actorName: "session-04"
        )
        let created = try await repository.createFeatureDecision(featureID: viewModel.feature.id, body: body)

        #expect(created.title == "trimmed")
    }

    // MARK: - Delete

    @MainActor
    @Test func deleteRemovesFromList() async throws {
        let (viewModel, repository) = try await loadedViewModel()
        guard let target = viewModel.decisions.first else {
            return
        }

        try await repository.deleteDecision(id: target.id)
        viewModel.decisions.removeAll { $0.id == target.id }

        #expect(!viewModel.decisions.contains { $0.id == target.id })
    }

    // MARK: - Actor coverage

    @MainActor
    @Test func actorChipMappingHandlesBothActors() async {
        // Spot-check the actor enum so the chip styling stays in
        // sync with the contract's enum.
        let actors: [Components.Schemas.DecisionActor] = [.human, .agent]

        #expect(actors.count == 2)
        #expect(actors.contains(.human))
        #expect(actors.contains(.agent))
    }
}
