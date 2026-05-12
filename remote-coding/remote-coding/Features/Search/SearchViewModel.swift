import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {

    struct ProjectedFeature {
        let feature: Components.Schemas.Feature
        let project: Components.Schemas.Project
    }

    struct ProjectedTicket {
        let ticket: Components.Schemas.Ticket
        let feature: Components.Schemas.Feature
        let project: Components.Schemas.Project
    }

    struct SearchResults {
        let projects: [Components.Schemas.Project]
        let features: [ProjectedFeature]
        let tickets: [ProjectedTicket]

        static let empty = SearchResults(projects: [], features: [], tickets: [])

        var isEmpty: Bool {
            projects.isEmpty && features.isEmpty && tickets.isEmpty
        }
    }

    var isLoading = false
    var errorMessage: String?

    private var allProjects: [Components.Schemas.Project] = []
    private var allFeatures: [ProjectedFeature] = []
    private var allTickets: [ProjectedTicket] = []
    private var isLoaded = false

    // MARK: - Load

    func load(repository: TmuxAgentRepository) async {
        guard !isLoaded else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let projects = try await repository.listProjects()
            var features: [ProjectedFeature] = []
            var tickets: [ProjectedTicket] = []
            for project in projects {
                let projectFeatures = (try? await repository.listFeatures(projectIDOrSlug: project.slug)) ?? []
                for feature in projectFeatures {
                    features.append(ProjectedFeature(feature: feature, project: project))
                    let featureTickets = (try? await repository.listTickets(featureID: feature.id, status: nil)) ?? []
                    for ticket in featureTickets {
                        tickets.append(ProjectedTicket(ticket: ticket, feature: feature, project: project))
                    }
                }
            }
            allProjects = projects
            allFeatures = features
            allTickets = tickets
            isLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func invalidate() {
        isLoaded = false
        allProjects = []
        allFeatures = []
        allTickets = []
    }

    // MARK: - Filter

    func results(for query: String, scopeProject: Components.Schemas.Project? = nil) -> SearchResults {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return .empty }

        let projects = allProjects
            .filter { scopeProject == nil || $0.id == scopeProject!.id }
            .filter { $0.matchesSearch(q) }

        let features = allFeatures
            .filter { scopeProject == nil || $0.project.id == scopeProject!.id }
            .filter { $0.feature.matchesSearch(q) }

        let tickets = allTickets
            .filter { scopeProject == nil || $0.project.id == scopeProject!.id }
            .filter { $0.ticket.matchesSearch(q) }

        return SearchResults(projects: projects, features: features, tickets: tickets)
    }
}

// MARK: - Search matching

private extension Components.Schemas.Project {
    func matchesSearch(_ query: String) -> Bool {
        name.localizedCaseInsensitiveContains(query)
        || slug.localizedCaseInsensitiveContains(query)
        || (tagline?.localizedCaseInsensitiveContains(query) == true)
        || (description?.localizedCaseInsensitiveContains(query) == true)
    }
}

private extension Components.Schemas.Feature {
    func matchesSearch(_ query: String) -> Bool {
        title.localizedCaseInsensitiveContains(query)
        || slug.localizedCaseInsensitiveContains(query)
        || (vision?.localizedCaseInsensitiveContains(query) == true)
    }
}

private extension Components.Schemas.Ticket {
    func matchesSearch(_ query: String) -> Bool {
        title.localizedCaseInsensitiveContains(query)
        || publicId.localizedCaseInsensitiveContains(query)
        || description.localizedCaseInsensitiveContains(query)
        || branchName.localizedCaseInsensitiveContains(query)
    }
}
