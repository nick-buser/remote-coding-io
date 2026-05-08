import Foundation

/// Fetches features (and optional per-project agent sessions) across
/// every project in the workspace. Used by the Roadmap and Sessions
/// list screens, both of which need a flat collection of items
/// scoped to "all projects" with optional per-project filtering.
///
/// Loads sequentially at the moment — the workspace's small project
/// count makes parallelism unnecessary, and the Sendable-existential
/// dance to fan out through `withTaskGroup` cleanly isn't worth the
/// complexity. Centralised here so both screens read the same shape
/// and any future parallelism upgrade lands in one place.
@MainActor
struct CrossProjectFeatureFetcher {
    let repository: TmuxAgentRepository

    struct Bundle: Sendable {
        var projects: [Components.Schemas.Project]
        var featuresByProjectID: [Int64: [Components.Schemas.Feature]]
        var agentSessionsByProjectID: [Int64: [Components.Schemas.AgentSession]]
    }

    func loadFeatures() async throws -> Bundle {
        let projects = try await repository.listProjects()
        var featuresByProjectID: [Int64: [Components.Schemas.Feature]] = [:]
        for project in projects {
            featuresByProjectID[project.id] = (try? await repository.listFeatures(projectIDOrSlug: project.slug)) ?? []
        }
        return Bundle(
            projects: projects,
            featuresByProjectID: featuresByProjectID,
            agentSessionsByProjectID: [:]
        )
    }

    func loadFeaturesAndSessions() async throws -> Bundle {
        var bundle = try await loadFeatures()
        for project in bundle.projects {
            let sessions = (try? await repository.listProjectAgentSessions(projectIDOrSlug: project.slug)) ?? []
            bundle.agentSessionsByProjectID[project.id] = sessions
        }
        return bundle
    }
}

extension CrossProjectFeatureFetcher.Bundle {
    /// Flat list of every feature across every project, in project
    /// list order (which is already sorted pinned-first / last-touched
    /// desc by the repository).
    var allFeatures: [Components.Schemas.Feature] {
        projects.flatMap { featuresByProjectID[$0.id] ?? [] }
    }

    /// Flat list of every agent session across every project.
    var allAgentSessions: [Components.Schemas.AgentSession] {
        projects.flatMap { agentSessionsByProjectID[$0.id] ?? [] }
    }

    func project(for featureID: Int64) -> Components.Schemas.Project? {
        for project in projects {
            if (featuresByProjectID[project.id] ?? []).contains(where: { $0.id == featureID }) {
                return project
            }
        }
        return nil
    }
}
