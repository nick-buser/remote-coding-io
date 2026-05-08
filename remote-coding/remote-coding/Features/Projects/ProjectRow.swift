import SwiftUI

/// Project list row.
///
/// Composition (per `docs/feature_plans/30-screens.md` §2):
///
///   [38pt accent square w/ icon]   Title  ★               Tagline
///                                  ● Active · 4 live · 3/5 features    >
///
/// Counts (`live`, feature `active/total`) are passed in from the
/// parent so this row is pure visual — it does no repository fetches.
struct ProjectRow: View {
    let project: Components.Schemas.Project
    var liveCount: Int?
    var featureCount: ProjectListViewModel.FeatureCount?
    var onTap: () -> Void = {}

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Theme.Spacing.s3) {
                accentTile
                VStack(alignment: .leading, spacing: 4) {
                    titleLine
                    if let tagline = project.tagline, !tagline.isEmpty {
                        Text(tagline)
                            .themeCaption()
                            .foregroundStyle(Theme.Text.fg2(scheme))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    metaPills
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
                Chevron()
                    .padding(.top, 12)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pieces

    private var accentTile: some View {
        let resolved = ProjectAccentMapper.color(for: project.accent ?? "")
        return RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(resolved.value(for: scheme))
            .frame(width: 38, height: 38)
            .overlay {
                ProjectIconGlyph(rawIcon: project.icon)
                    .foregroundStyle(.white)
            }
    }

    private var titleLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(project.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Text.fg(scheme))
                .lineLimit(1)
            if project.pinned {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Semantic.yellow)
            }
        }
    }

    private var metaPills: some View {
        HStack(spacing: 10) {
            MetaPill(
                icon: "dot",
                iconColor: ProjectStatusStyle.color(for: project.status),
                label: ProjectStatusStyle.label(for: project.status)
            )
            if let liveCount, liveCount > 0 {
                MetaPill(icon: nil, iconColor: nil, label: "\(liveCount) live")
            }
            if let featureCount {
                MetaPill(icon: nil, iconColor: nil, label: "\(featureCount.active)/\(featureCount.total) features")
            }
        }
    }
}

/// Maps the freeform `Project.icon` string from the contract onto an
/// SF Symbol when the value matches one of the design's known names,
/// or renders the literal glyph when the value is a single Unicode
/// character (the v2 design uses `◇`, `⌗`, `✺`, `∎`). Otherwise falls
/// back to a generic folder symbol.
struct ProjectIconGlyph: View {
    let rawIcon: String?

    private static let knownSymbols: Set<String> = [
        "terminal", "iphone", "doc.text", "shippingbox", "folder",
        "globe", "command", "hammer", "wrench", "cube", "wand.and.stars"
    ]

    var body: some View {
        if let raw = rawIcon, !raw.isEmpty {
            if Self.knownSymbols.contains(raw) {
                Image(systemName: raw)
                    .font(.system(size: 18, weight: .semibold))
            } else if raw.unicodeScalars.count == 1 {
                Text(raw)
                    .font(.system(size: 18, weight: .semibold))
            } else {
                Image(systemName: "folder")
                    .font(.system(size: 18, weight: .semibold))
            }
        } else {
            Image(systemName: "folder")
                .font(.system(size: 18, weight: .semibold))
        }
    }
}

/// Maps `ProjectStatus` to its design color and label.
enum ProjectStatusStyle {
    static func color(for status: Components.Schemas.ProjectStatus) -> Color {
        switch status {
        case .active:      return Theme.Semantic.green
        case .maintenance: return Theme.Semantic.orange
        case .paused:      return .gray
        }
    }

    static func label(for status: Components.Schemas.ProjectStatus) -> String {
        switch status {
        case .active:      return "Active"
        case .maintenance: return "Maint."
        case .paused:      return "Paused"
        }
    }
}

/// Maps a project's free-form accent string onto the v2 `AccentColor`
/// set. The mock fixtures still use legacy web-hub values
/// ("indigo", "teal"); this mapping bridges them until
/// `service-mock-rich-seed` migrates the seed.
enum ProjectAccentMapper {
    static func color(for raw: String) -> AccentColor {
        if let direct = AccentColor(rawValue: raw) { return direct }
        switch raw {
        case "indigo", "blue", "purple": return .iris
        case "teal", "green":             return .mint
        case "orange", "yellow":          return .amber
        case "red", "pink":               return .rose
        case "gray", "grey":              return .slate
        default:                          return .iris
        }
    }
}

#Preview("ProjectRow — pinned, light") {
    RoundedCard {
        ProjectRow(
            project: ProjectRow.previewProject(name: "tmux server (coding app)", pinned: true, accent: "indigo", icon: "terminal"),
            liveCount: 4,
            featureCount: .init(active: 3, total: 5)
        )
    }
    .padding()
    .background(Theme.Surface.bg(.light))
}

#Preview("ProjectRow — unpinned, dark") {
    RoundedCard {
        ProjectRow(
            project: ProjectRow.previewProject(name: "remote coding iOS", pinned: false, accent: "teal", icon: "iphone"),
            liveCount: nil,
            featureCount: .init(active: 1, total: 4)
        )
    }
    .padding()
    .background(Theme.Surface.bg(.dark))
    .preferredColorScheme(.dark)
}

extension ProjectRow {
    static func previewProject(
        name: String,
        pinned: Bool,
        accent: String,
        icon: String,
        status: Components.Schemas.ProjectStatus = .active
    ) -> Components.Schemas.Project {
        Components.Schemas.Project(
            id: 1,
            name: name,
            slug: name.replacingOccurrences(of: " ", with: "-").lowercased(),
            gitRepoUrl: nil,
            localRepoPath: "/tmp/preview",
            tagline: "Preview tagline",
            description: nil,
            accent: accent,
            icon: icon,
            status: status,
            pinned: pinned,
            lastTouchedAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
