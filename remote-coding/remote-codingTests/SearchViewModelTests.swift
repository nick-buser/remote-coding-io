import Foundation
import Testing
@testable import remote_coding

@MainActor
struct SearchViewModelTests {

    private func loadedViewModel() async -> SearchViewModel {
        let vm = SearchViewModel()
        await vm.load(repository: MockTmuxAgentRepository())
        return vm
    }

    // MARK: - Empty query returns no results

    @Test func emptyQueryReturnsEmpty() async {
        let vm = await loadedViewModel()
        let results = vm.results(for: "")
        #expect(results.isEmpty)
    }

    @Test func whitespaceQueryReturnsEmpty() async {
        let vm = await loadedViewModel()
        let results = vm.results(for: "   ")
        #expect(results.isEmpty)
    }

    // MARK: - Project match

    @Test func projectNameMatch() async {
        let vm = await loadedViewModel()
        let results = vm.results(for: "tmux-agent")
        #expect(results.projects.contains(where: { $0.name.localizedCaseInsensitiveContains("tmux-agent") || $0.slug.localizedCaseInsensitiveContains("tmux-agent") }))
    }

    @Test func projectSlugMatch() async {
        let vm = await loadedViewModel()
        let results = vm.results(for: "tmux_agent")
        #expect(!results.projects.isEmpty)
    }

    // MARK: - Feature match

    @Test func featureTitleMatch() async {
        let vm = await loadedViewModel()
        // Mock repo has features like "Feature context bundle"
        let results = vm.results(for: "context bundle")
        #expect(!results.features.isEmpty)
        #expect(results.features.allSatisfy { $0.feature.title.localizedCaseInsensitiveContains("context bundle") || $0.feature.slug.localizedCaseInsensitiveContains("context bundle") })
    }

    @Test func featureParentProjectPopulated() async {
        let vm = await loadedViewModel()
        let results = vm.results(for: "context bundle")
        #expect(results.features.allSatisfy { !$0.project.name.isEmpty })
    }

    // MARK: - Ticket match

    @Test func ticketPublicIdMatch() async {
        let vm = await loadedViewModel()
        let results = vm.results(for: "TMX-0042")
        #expect(!results.tickets.isEmpty)
        #expect(results.tickets.first?.ticket.publicId == "TMX-0042")
    }

    @Test func ticketTitleMatch() async {
        let vm = await loadedViewModel()
        let results = vm.results(for: "pane registry")
        #expect(!results.tickets.isEmpty)
    }

    // MARK: - Diacritics-insensitive

    @Test func diacriticsInsensitiveMatch() async {
        let vm = await loadedViewModel()
        // "featuré" should match a feature whose title contains "feature"
        let resultsWithDiacritic = vm.results(for: "featuré")
        let resultsPlain = vm.results(for: "feature")
        // Both should find the same features (localizedCaseInsensitiveContains is diacritics-insensitive)
        #expect(resultsWithDiacritic.features.count == resultsPlain.features.count)
    }

    // MARK: - Scoped search

    @Test func scopedSearchLimitsToProject() async {
        let repo = MockTmuxAgentRepository()
        let project = try! await repo.getProject(idOrSlug: "1")
        let vm = SearchViewModel()
        await vm.load(repository: repo)

        let scopedResults = vm.results(for: "tmux", scopeProject: project)
        let globalResults = vm.results(for: "tmux")

        // Scoped results must all belong to the given project
        #expect(scopedResults.features.allSatisfy { $0.project.id == project.id })
        #expect(scopedResults.tickets.allSatisfy { $0.project.id == project.id })
        // Global results may include more items
        #expect(globalResults.features.count >= scopedResults.features.count)
    }

    // MARK: - Caching

    @Test func secondLoadIsNoOp() async {
        let repo = MockTmuxAgentRepository()
        let vm = SearchViewModel()
        await vm.load(repository: repo)
        let countAfterFirst = vm.results(for: "tmux").features.count

        await vm.load(repository: repo)
        let countAfterSecond = vm.results(for: "tmux").features.count

        #expect(countAfterFirst == countAfterSecond)
    }

    @Test func invalidateClearsBundle() async {
        let vm = await loadedViewModel()
        vm.invalidate()
        // After invalidation the bundle is empty, but isLoaded is false so results
        // are empty regardless of query (data not yet re-fetched)
        let results = vm.results(for: "tmux")
        #expect(results.isEmpty)
    }
}
