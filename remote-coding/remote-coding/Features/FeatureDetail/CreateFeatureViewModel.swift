import Foundation
import Observation

/// View model behind `CreateFeatureSheet`.
///
/// In create mode the form posts a `CreateFeatureRequest` against
/// the supplied parent project. In edit mode (constructed with
/// `existing:`) the form pre-fills from the feature; the contract
/// only exposes `updateFeatureStatus` today, so non-status fields
/// render disabled and the submit only PATCHes status.
@MainActor
@Observable
final class CreateFeatureViewModel {
    // Identity
    var title: String = ""
    var slug: String = ""
    var branchName: String = ""

    // Body
    var vision: String = ""
    var milestone: String = ""
    var targetDate: String = ""

    // Visual / state
    var accent: AccentColor = .iris
    var status: Components.Schemas.FeatureStatus = .planned
    var health: String = "on-track"
    var tagsInput: String = ""

    // Auto-derivation locks
    var slugWasManuallyEdited: Bool = false
    var branchWasManuallyEdited: Bool = false

    // Submit lifecycle
    var isSubmitting: Bool = false
    var fieldErrors: [Field: String] = [:]
    var bannerError: String?

    let parentSlug: String
    let existing: Components.Schemas.Feature?

    var mode: Mode { existing == nil ? .create : .edit }

    enum Mode: Hashable, Sendable {
        case create
        case edit
    }

    enum Field: String, Hashable, Sendable {
        case title
        case slug
        case branchName
        case vision
        case milestone
        case targetDate
        case accent
        case status
        case health
        case tags
    }

    init(parentSlug: String, existing: Components.Schemas.Feature? = nil) {
        self.parentSlug = parentSlug
        self.existing = existing
        if let feature = existing {
            self.title = feature.title
            self.slug = feature.slug
            self.branchName = feature.branchName ?? ""
            self.vision = feature.vision ?? ""
            self.milestone = feature.milestone ?? ""
            self.targetDate = feature.targetDate ?? ""
            self.accent = ProjectAccentMapper.color(for: feature.accent)
            self.status = feature.status
            self.health = feature.health
            self.tagsInput = feature.tags.joined(separator: ", ")
            self.slugWasManuallyEdited = true
            self.branchWasManuallyEdited = true
        }
    }

    // MARK: - Submit gating

    var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSubmitting
    }

    /// In edit mode the contract only supports status updates.
    /// Non-status fields render with this flag set so the form
    /// grays them out and surfaces a banner explaining why.
    var nonStatusFieldsAreEditable: Bool {
        mode == .create
    }

    // MARK: - Auto-derivation

    func titleChanged(_ newTitle: String) {
        if !slugWasManuallyEdited {
            slug = Self.deriveSlug(from: newTitle)
        }
        if !branchWasManuallyEdited {
            branchName = Self.deriveBranchName(from: newTitle)
        }
    }

    func slugChangedExternally(_ newSlug: String) {
        guard newSlug != Self.deriveSlug(from: title) else { return }
        slugWasManuallyEdited = true
    }

    func branchChangedExternally(_ newBranch: String) {
        guard newBranch != Self.deriveBranchName(from: title) else { return }
        branchWasManuallyEdited = true
    }

    // MARK: - Bodies

    func makeCreateRequest() -> Components.Schemas.CreateFeatureRequest {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSlug = slug.trimmedNilIfEmpty ?? Self.deriveSlug(from: trimmedTitle)
        let resolvedBranch = branchName.trimmedNilIfEmpty ?? Self.deriveBranchName(from: trimmedTitle)
        return Components.Schemas.CreateFeatureRequest(
            branchName: resolvedBranch,
            slug: resolvedSlug,
            title: trimmedTitle,
            vision: vision.trimmedNilIfEmpty,
            descriptionDocKey: nil,
            status: status,
            accent: accent.rawValue,
            milestone: milestone.trimmedNilIfEmpty,
            targetDate: targetDate.trimmedNilIfEmpty,
            health: health.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "on-track" : health.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: parsedTags()
        )
    }

    /// Parse the comma-separated tags input into an array of trimmed,
    /// non-empty values. Order preserved.
    func parsedTags() -> [String] {
        tagsInput
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Submit

    func submit(
        repository: TmuxAgentRepository,
        onSubmitted: @escaping (Components.Schemas.Feature) -> Void
    ) async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        fieldErrors = [:]
        bannerError = nil
        do {
            let result: Components.Schemas.Feature
            if let existing {
                result = try await repository.updateFeatureStatus(
                    id: existing.id,
                    body: Components.Schemas.UpdateFeatureStatusRequest(status: status)
                )
            } else {
                result = try await repository.createFeature(projectIDOrSlug: parentSlug, body: makeCreateRequest())
            }
            onSubmitted(result)
        } catch let RepositoryError.problem(problem) {
            apply(problem: problem)
        } catch let MockRepositoryError.problem(field, _, message) {
            if let mapped = Self.fieldErrorMapper(rawField: field) {
                fieldErrors[mapped] = message
            } else {
                bannerError = message
            }
        } catch {
            bannerError = error.localizedDescription
        }
    }

    func apply(problem: Components.Schemas.ProblemDetails) {
        if let errors = problem.errors, !errors.isEmpty {
            for entry in errors {
                if let field = Self.fieldErrorMapper(rawField: entry.field) {
                    fieldErrors[field] = entry.message
                } else {
                    bannerError = entry.message
                }
            }
            return
        }
        bannerError = problem.detail ?? problem.title ?? "Couldn't save feature."
    }

    // MARK: - Static helpers

    static func deriveSlug(from title: String) -> String {
        let lowered = title.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
        }
        return String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
    }

    /// Branch names use a `feat/<slug>` convention to mirror the
    /// project's `feat/tmx-####-...` ticket-branches without taking
    /// a ticket id.
    static func deriveBranchName(from title: String) -> String {
        let slug = deriveSlug(from: title)
        return slug.isEmpty ? "" : "feat/\(slug)"
    }

    static func fieldErrorMapper(rawField: String) -> Field? {
        let segment = rawField.split(separator: ".", maxSplits: 1).first.map(String.init) ?? rawField
        switch segment {
        case "title":            return .title
        case "slug":             return .slug
        case "branch_name", "branchName":
            return .branchName
        case "vision":           return .vision
        case "milestone":        return .milestone
        case "target_date", "targetDate":
            return .targetDate
        case "accent":           return .accent
        case "status":           return .status
        case "health":           return .health
        case "tags":             return .tags
        default:                 return nil
        }
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
