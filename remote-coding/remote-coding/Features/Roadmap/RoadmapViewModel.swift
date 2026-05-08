import Foundation
import Observation

/// View model for the Roadmap screen.
///
/// Loads features across every project via `CrossProjectFeatureFetcher`,
/// groups them by `feature.milestone`, and exposes a sortable list of
/// `Milestone` snapshots plus the active project filter. The view
/// renders one milestone per `TabView` page.
@MainActor
@Observable
final class RoadmapViewModel {
    var bundle: CrossProjectFeatureFetcher.Bundle?
    var selectedProjectID: Int64?  // nil = "All projects"
    var milestoneIndex: Int = 0
    var isLoading = false
    var errorMessage: String?

    // MARK: - Types

    struct Milestone: Equatable, Sendable, Identifiable {
        var id: String { label }
        /// Raw milestone string from `Feature.milestone` (used as the
        /// key when grouping). The displayed label trims the leading
        /// `vN.M — ` prefix when present.
        var rawLabel: String
        /// Numeric / version prefix extracted from the raw label, e.g.
        /// `v0.4` or `M3`. Used for the small mono ID under the
        /// display label. May be empty.
        var idPrefix: String
        /// Trimmed display title, e.g. `Multi-agent`.
        var label: String
        /// Earliest target date among the milestone's features (parsed
        /// via best-effort heuristics; nil when no feature has one).
        var earliestTarget: String?
        var features: [Components.Schemas.Feature]
        var state: State

        enum State: Equatable, Sendable {
            case shipped
            case active
            case planned
        }
    }

    // MARK: - Derivation

    /// Distinct, ordered milestones. Project filter narrows the
    /// `features` list inside each milestone but does not remove
    /// milestones with no matching features — those render an
    /// `EmptyState`.
    var milestones: [Milestone] {
        guard let bundle else { return [] }
        return Self.derive(from: bundle, projectFilter: selectedProjectID)
    }

    var filteredProject: Components.Schemas.Project? {
        guard let bundle, let id = selectedProjectID else { return nil }
        return bundle.projects.first { $0.id == id }
    }

    // MARK: - Subtitle

    func subtitle() -> String {
        guard let bundle else { return "" }
        let label = bundle.projects.first { $0.id == selectedProjectID }?.name ?? "All projects"
        let count = milestones.count
        return "\(label) · \(count) milestone\(count == 1 ? "" : "s")"
    }

    // MARK: - Load

    func load(fetcher: CrossProjectFeatureFetcher) async {
        isLoading = true
        errorMessage = nil
        do {
            bundle = try await fetcher.loadFeatures()
            // Clamp the selected milestone in case it shrinks past the
            // current index after a refresh.
            if milestoneIndex >= milestones.count {
                milestoneIndex = max(0, milestones.count - 1)
            }
        } catch {
            errorMessage = "Couldn't load roadmap: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Pure derivation

    static func derive(
        from bundle: CrossProjectFeatureFetcher.Bundle,
        projectFilter: Int64?
    ) -> [Milestone] {
        // Group every feature (across the workspace) by raw milestone
        // label, ignoring features without a milestone.
        var byLabel: [String: [Components.Schemas.Feature]] = [:]
        for project in bundle.projects {
            for feature in bundle.featuresByProjectID[project.id] ?? [] {
                guard let raw = feature.milestone, !raw.isEmpty else { continue }
                byLabel[raw, default: []].append(feature)
            }
        }

        // Build milestone snapshots from the *unfiltered* set so the
        // page count stays stable while the filter narrows visible
        // rows.
        var milestones: [Milestone] = byLabel.map { (raw, features) in
            let earliest = features.compactMap(\.targetDate).min()
            let visible = projectFilter.map { id in
                features.filter { $0.projectId == id }
            } ?? features
            return Milestone(
                rawLabel: raw,
                idPrefix: extractIDPrefix(from: raw),
                label: trimIDPrefix(from: raw),
                earliestTarget: earliest,
                features: visible,
                state: state(for: features)
            )
        }
        milestones.sort { lhs, rhs in
            // Earliest target first; nil dates sort last. Tie-break by
            // raw label so the order is deterministic across reloads.
            switch (lhs.earliestTarget, rhs.earliestTarget) {
            case let (l?, r?): return l == r ? lhs.rawLabel < rhs.rawLabel : l < r
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return lhs.rawLabel < rhs.rawLabel
            }
        }
        return milestones
    }

    private static func state(for features: [Components.Schemas.Feature]) -> Milestone.State {
        guard !features.isEmpty else { return .planned }
        if features.allSatisfy({ $0.status == .shipped || $0.status == .merged }) {
            return .shipped
        }
        if features.contains(where: { $0.status == .inProgress || $0.status == .review }) {
            return .active
        }
        return .planned
    }

    /// Pull the leading version / id token from a milestone label —
    /// e.g. `"v0.4 — Multi-agent"` → `"v0.4"`. Returns `""` when no
    /// recognisable prefix is present.
    static func extractIDPrefix(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if let separator = trimmed.range(of: " — ") {
            return String(trimmed[..<separator.lowerBound])
        }
        if let space = trimmed.firstIndex(of: " "),
           trimmed[..<space].allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" }),
           !trimmed[..<space].isEmpty {
            return String(trimmed[..<space])
        }
        return ""
    }

    static func trimIDPrefix(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if let separator = trimmed.range(of: " — ") {
            return String(trimmed[separator.upperBound...])
        }
        return trimmed
    }
}
