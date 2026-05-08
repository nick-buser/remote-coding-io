import Foundation
import Observation

/// View model behind `CreateProjectSheet`. Owns form state, drives
/// the slug auto-derivation logic, and maps server-side
/// `ProblemDetails.errors` onto local form fields via
/// `FieldErrorMapper`.
///
/// The same view model also powers the edit flow — pass an existing
/// `Project` to `init(existing:)` and the form pre-fills, the
/// submit button reads "Save changes", and `submit(...)` routes to
/// `updateProject` instead of `createProject`.
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

    /// When non-nil the form is editing an existing project. The
    /// `slug` carried here keeps `submit(...)` routed to the right
    /// `updateProject(idOrSlug:)` even after the user edits it.
    let existing: Components.Schemas.Project?

    var mode: Mode { existing == nil ? .create : .edit }

    enum Mode: Hashable, Sendable {
        case create
        case edit
    }

    init(existing: Components.Schemas.Project? = nil) {
        self.existing = existing
        if let project = existing {
            self.name = project.name
            self.slug = project.slug
            self.gitRepoUrl = project.gitRepoUrl ?? ""
            self.localRepoPath = project.localRepoPath
            self.tagline = project.tagline ?? ""
            self.description = project.description ?? ""
            self.accent = AccentColor(rawValue: project.accent ?? "") ?? .iris
            self.icon = project.icon ?? ""
            self.status = project.status
            self.pinned = project.pinned
            // Treat the pre-filled slug as user-supplied so name
            // edits don't silently rewrite it.
            self.slugWasManuallyEdited = true
        }
    }

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

    /// Build the request body for create-mode submissions. Trims
    /// whitespace and treats empty strings as nil for optional
    /// fields.
    func makeCreateRequest() -> Components.Schemas.CreateProjectRequest {
        let (trimmedName, resolvedSlug, resolvedIcon, trimmedPath) = sanitisedCore()
        return Components.Schemas.CreateProjectRequest(
            name: trimmedName,
            slug: resolvedSlug,
            gitRepoUrl: gitRepoUrl.trimmedNilIfEmpty,
            localRepoPath: trimmedPath,
            tagline: tagline.trimmedNilIfEmpty,
            description: description.trimmedNilIfEmpty,
            accent: accent.rawValue,
            icon: resolvedIcon,
            status: status,
            pinned: pinned
        )
    }

    /// Build the PUT-shaped update body for edit-mode submissions.
    func makeUpdateRequest() -> Components.Schemas.UpdateProjectRequest {
        let (trimmedName, resolvedSlug, resolvedIcon, trimmedPath) = sanitisedCore()
        return Components.Schemas.UpdateProjectRequest(
            name: trimmedName,
            slug: resolvedSlug,
            gitRepoUrl: gitRepoUrl.trimmedNilIfEmpty,
            localRepoPath: trimmedPath,
            tagline: tagline.trimmedNilIfEmpty,
            description: description.trimmedNilIfEmpty,
            accent: accent.rawValue,
            icon: resolvedIcon,
            status: status,
            pinned: pinned
        )
    }

    /// Shared field sanitisation between create / update bodies.
    private func sanitisedCore() -> (name: String, slug: String, icon: String, path: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSlug = trimmedSlug.isEmpty ? Self.deriveSlug(from: trimmedName) : trimmedSlug
        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedIcon = trimmedIcon.isEmpty ? Self.deriveIcon(from: trimmedName) : trimmedIcon
        let trimmedPath = localRepoPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmedName, resolvedSlug, resolvedIcon, trimmedPath)
    }

    // MARK: - Submit

    /// Submits the form, routing through `createProject` (when
    /// `existing == nil`) or `updateProject` (otherwise) and
    /// dispatching the resulting project through `onSubmitted`. On
    /// error, populates `fieldErrors` (when a `ProblemDetails`
    /// carries `errors[]`) or `bannerError` (otherwise).
    func submit(
        repository: TmuxAgentRepository,
        onSubmitted: @escaping (Components.Schemas.Project) -> Void
    ) async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        fieldErrors = [:]
        bannerError = nil
        do {
            let project: Components.Schemas.Project
            if let existing {
                project = try await repository.updateProject(
                    idOrSlug: existing.slug,
                    body: makeUpdateRequest()
                )
            } else {
                project = try await repository.createProject(makeCreateRequest())
            }
            onSubmitted(project)
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
