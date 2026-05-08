import Foundation
import Observation

@MainActor
@Observable
final class ProjectListViewModel {
    var projects: [Components.Schemas.Project] = []
    var isLoading = false
    var errorMessage: String?
    /// Per-project active agent session counts. Populated lazily as
    /// rows scroll into view via `loadLiveSessionCount`.
    var liveSessionCounts: [Int64: Int] = [:]
    /// Per-project feature counts (active vs total). Populated once
    /// during `load` for every project in parallel.
    var featureCounts: [Int64: FeatureCount] = [:]

    struct FeatureCount: Equatable, Sendable {
        var active: Int
        var total: Int
    }

    func load(repository: TmuxAgentRepository) async {
        isLoading = true
        errorMessage = nil
        do {
            let raw = try await repository.listProjects()
            projects = Self.sorted(raw)
            await loadFeatureCounts(for: projects, repository: repository)
        } catch {
            errorMessage = "Couldn't load projects: \(error.localizedDescription)"
        }
        isLoading = false
    }

    /// Lazy per-row live count — call from `task(id:)` so it only
    /// runs once per project rendering. The underlying call hits
    /// `listProjectAgentSessions`, which is cheap on the mock and
    /// scoped on the live backend.
    func loadLiveSessionCount(for project: Components.Schemas.Project, repository: TmuxAgentRepository) async {
        guard liveSessionCounts[project.id] == nil else { return }
        do {
            let sessions = try await repository.listProjectAgentSessions(projectIDOrSlug: project.slug)
            liveSessionCounts[project.id] = sessions.filter { $0.state == .active || $0.state == .awaitingInput }.count
        } catch {
            // Leave the count nil so the next appearance can retry.
        }
    }

    /// Total live (non-idle, non-ended) session count across all
    /// loaded projects. Used in the header subtitle. Returns nil
    /// until at least one row has loaded — we don't want the
    /// subtitle to flicker between "0 live sessions" and the real
    /// count as rows populate.
    var liveSessionCountSubtotal: Int? {
        guard !liveSessionCounts.isEmpty else { return nil }
        return liveSessionCounts.values.reduce(0, +)
    }

    func subtitle() -> String {
        let projectsLabel = "\(projects.count) project\(projects.count == 1 ? "" : "s")"
        if let live = liveSessionCountSubtotal {
            return "\(projectsLabel) · \(live) live session\(live == 1 ? "" : "s")"
        }
        return projectsLabel
    }

    // MARK: - Pin / status mutations

    /// Toggle a project's pinned state through `updateProject`. The
    /// contract's `UpdateProjectRequest` is PUT-shaped (`name` and
    /// `local_repo_path` required), so this round-trips every field
    /// from the local snapshot and only flips `pinned`. The returned
    /// project is patched into the local list so the row resorts
    /// without a full reload.
    func togglePin(for project: Components.Schemas.Project, repository: TmuxAgentRepository) async {
        let body = Components.Schemas.UpdateProjectRequest(
            name: project.name,
            slug: project.slug,
            gitRepoUrl: project.gitRepoUrl,
            localRepoPath: project.localRepoPath,
            tagline: project.tagline,
            description: project.description,
            accent: project.accent,
            icon: project.icon,
            status: project.status,
            pinned: !project.pinned
        )
        do {
            let updated = try await repository.updateProject(idOrSlug: project.slug, body: body)
            replace(updated)
        } catch {
            errorMessage = "Couldn't update pin: \(error.localizedDescription)"
        }
    }

    private func replace(_ updated: Components.Schemas.Project) {
        guard let index = projects.firstIndex(where: { $0.id == updated.id }) else { return }
        projects[index] = updated
        projects = Self.sorted(projects)
    }

    // MARK: - Sort + fan out

    /// Pinned-first, then last_touched_at desc. Stable across
    /// refreshes — sort is pure.
    static func sorted(_ projects: [Components.Schemas.Project]) -> [Components.Schemas.Project] {
        projects.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned {
                return lhs.pinned && !rhs.pinned
            }
            return lhs.lastTouchedAt > rhs.lastTouchedAt
        }
    }

    private func loadFeatureCounts(for projects: [Components.Schemas.Project], repository: TmuxAgentRepository) async {
        // Sequential fan-out — fine for the workspace's small project
        // count. service-0017 introduces a parallel cross-project
        // helper that this method will switch to.
        for project in projects {
            do {
                let features = try await repository.listFeatures(projectIDOrSlug: project.slug)
                let active = features.filter { $0.status == .inProgress || $0.status == .review }.count
                featureCounts[project.id] = FeatureCount(active: active, total: features.count)
            } catch {
                // Leave nil so the next load can retry.
            }
        }
    }

    // MARK: - Pinned / unpinned partition

    var pinnedProjects: [Components.Schemas.Project] {
        projects.filter { $0.pinned }
    }

    var unpinnedProjects: [Components.Schemas.Project] {
        projects.filter { !$0.pinned }
    }
}
