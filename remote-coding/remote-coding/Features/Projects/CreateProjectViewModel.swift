import Foundation
import Observation

/// View model behind `CreateProjectSheet`. Owns form state, drives
/// the slug auto-derivation logic, and maps server-side
/// `ProblemDetails.errors` onto local form fields via
/// `FieldErrorMapper`.
@MainActor
@Observable
final class CreateProjectViewModel {
    var name: String = ""
    var slug: String = ""
    var gitRepoUrl: String = ""
    var localRepoPath: String = ""
    var tagline: String = ""
    var description: String = ""
    var accent: AccentColor = .iris
    var icon: String = ""
    var status: Components.Schemas.ProjectStatus = .active
    var pinned: Bool = false

    /// Once the user types into the slug field directly, stop
    /// auto-deriving from `name`.
    var slugWasManuallyEdited: Bool = false

    var isSubmitting: Bool = false
    /// Field-level errors keyed by form field. Cleared on every
    /// submit attempt and any field mutation.
    var fieldErrors: [Field: String] = [:]
    /// Generic banner error (network / undocumented status / etc.)
    var bannerError: String?

    enum Field: String, Hashable, Sendable {
        case name
        case slug
        case localRepoPath
        case gitRepoUrl
        case tagline
        case description
        case accent
        case icon
        case status
        case pinned
    }

    // MARK: - Validation / submit eligibility

    var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !localRepoPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSubmitting
    }

    /// Update `slug` automatically when the user is still letting
    /// the form derive it. Call this from `name`'s `onChange`.
    func nameChanged(_ newName: String) {
        if !slugWasManuallyEdited {
            slug = Self.deriveSlug(from: newName)
        }
    }

    func slugEdited(_ newSlug: String) {
        slugWasManuallyEdited = true
        slug = newSlug
    }

    /// Build the request body from the current form state. Trims
    /// whitespace and treats empty strings as nil for optional fields.
    func makeRequest() -> Components.Schemas.CreateProjectRequest {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSlug = trimmedSlug.isEmpty ? Self.deriveSlug(from: trimmedName) : trimmedSlug
        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        return Components.Schemas.CreateProjectRequest(
            name: trimmedName,
            slug: resolvedSlug,
            gitRepoUrl: gitRepoUrl.trimmedNilIfEmpty,
            localRepoPath: localRepoPath.trimmingCharacters(in: .whitespacesAndNewlines),
            tagline: tagline.trimmedNilIfEmpty,
            description: description.trimmedNilIfEmpty,
            accent: accent.rawValue,
            icon: trimmedIcon.isEmpty ? Self.deriveIcon(from: trimmedName) : trimmedIcon,
            status: status,
            pinned: pinned
        )
    }

    // MARK: - Submit

    /// Submits the form, dispatching the result through `onCreated` on
    /// success. On error, populates `fieldErrors` (when a
    /// `ProblemDetails` carries `errors[]`) or `bannerError`
    /// (otherwise).
    func submit(
        repository: TmuxAgentRepository,
        onCreated: @escaping (Components.Schemas.Project) -> Void
    ) async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        fieldErrors = [:]
        bannerError = nil
        do {
            let project = try await repository.createProject(makeRequest())
            onCreated(project)
        } catch let RepositoryError.problem(problem) {
            apply(problem: problem)
        } catch let MockRepositoryError.problem(field, _, message) {
            // Mock parity: a single FieldError surfaced as
            // RepositoryError isn't reachable in mock-backed
            // previews, so the mock throws its own typed error
            // and we map it the same way.
            if let mapped = Self.fieldErrorMapper(rawField: field) {
                fieldErrors[mapped] = message
            } else {
                bannerError = message
            }
        } catch {
            bannerError = error.localizedDescription
        }
    }

    /// Pull the optional `errors[]` array off `ProblemDetails`,
    /// route each `FieldError` to a known form `Field`, and stash
    /// any leftover detail on `bannerError`.
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
        bannerError = problem.detail ?? problem.title ?? "Couldn't create project."
    }

    // MARK: - Static helpers

    /// `name` → kebab-case slug. Lowercases, replaces runs of
    /// non-alphanumeric chars with `-`, strips leading/trailing
    /// `-`. Returns an empty string when the input has no
    /// alphanumerics.
    static func deriveSlug(from name: String) -> String {
        let lowered = name.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return "-"
        }
        return String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
    }

    /// First grapheme cluster from the trimmed name, or empty when
    /// the name is empty.
    static func deriveIcon(from name: String) -> String {
        guard let first = name.first else { return "" }
        return String(first)
    }

    /// Maps the contract's JSON path field to a local form field.
    /// Unknown paths return nil so the caller routes them to the
    /// banner error.
    static func fieldErrorMapper(rawField: String) -> Field? {
        // Match the leading segment before `.` so nested errors
        // (e.g. `slug.format`) still find the right form field.
        let segment = rawField.split(separator: ".", maxSplits: 1).first.map(String.init) ?? rawField
        switch segment {
        case "name":            return .name
        case "slug":            return .slug
        case "local_repo_path", "localRepoPath", "path":
            return .localRepoPath
        case "git_repo_url", "gitRepoUrl", "url":
            return .gitRepoUrl
        case "tagline":         return .tagline
        case "description":     return .description
        case "accent":          return .accent
        case "icon":            return .icon
        case "status":          return .status
        case "pinned":          return .pinned
        default:                return nil
        }
    }
}

private extension String {
    /// Trim and return nil for empty strings — used on optional
    /// request fields so the live backend doesn't see "".
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
