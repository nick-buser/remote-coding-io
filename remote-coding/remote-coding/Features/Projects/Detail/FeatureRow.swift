import SwiftUI

/// Row for the Project detail's Features sub-tab.
///
/// Composition (per `docs/feature_plans/30-screens.md` §3):
///
///   [16pt status]   FEAT-018 ◾ milestone                    target date
///                   Title
///                   ████████□□  3/6  ●  2 live
struct FeatureRow: View {
    let feature: Components.Schemas.Feature
    var liveSessionsCount: Int = 0
    var ticketsDone: Int = 0
    var ticketsTotal: Int = 0
    var onTap: () -> Void = {}

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Theme.Spacing.s3) {
                StatusGlyph(role: FeatureStatusStyle.glyphRole(for: feature.status), size: 16)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 6) {
                    metaLine
                    Text(feature.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Text.fg(scheme))
                        .lineLimit(1)
                    progressLine
                }
                Spacer(minLength: 0)
                Chevron()
                    .padding(.top, 6)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var metaLine: some View {
        HStack(spacing: 6) {
            Text(featurePublicID)
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
            Pip(accent: ProjectAccentMapper.color(for: feature.accent), size: 6, radius: 2)
            if let milestone = feature.milestone, !milestone.isEmpty {
                Text(milestone)
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
            }
            Spacer(minLength: 8)
            if let target = feature.targetDate, !target.isEmpty {
                Text(target)
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
            }
        }
    }

    private var progressLine: some View {
        HStack(spacing: 8) {
            ProgressBar(
                value: progressFraction,
                accent: ProjectAccentMapper.color(for: feature.accent)
            )
            .frame(width: 60)
            Text("\(ticketsDone)/\(ticketsTotal)")
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
            if liveSessionsCount > 0 {
                Circle()
                    .fill(Theme.Semantic.green)
                    .frame(width: 6, height: 6)
                Text("\(liveSessionsCount) live")
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
            }
        }
    }

    private var progressFraction: Double {
        guard ticketsTotal > 0 else { return 0 }
        return Double(ticketsDone) / Double(ticketsTotal)
    }

    private var featurePublicID: String {
        "FEAT-\(String(format: "%03d", feature.id))"
    }
}

/// Maps `FeatureStatus` onto the shared `StatusGlyphRole` set.
enum FeatureStatusStyle {
    static func glyphRole(for status: Components.Schemas.FeatureStatus) -> StatusGlyphRole {
        switch status {
        case .inProgress: return .doing
        case .review:     return .review
        case .planned:    return .planned
        case .shipped, .merged: return .shipped
        case .abandoned:  return .todo
        }
    }

    static func label(for status: Components.Schemas.FeatureStatus) -> String {
        switch status {
        case .inProgress: return "In progress"
        case .review:     return "In review"
        case .planned:    return "Planned"
        case .shipped:    return "Shipped"
        case .merged:     return "Merged"
        case .abandoned:  return "Abandoned"
        }
    }
}

#Preview("FeatureRow — light") {
    let feature = Components.Schemas.Feature(
        id: 18,
        projectId: 1,
        branchName: "feat/inbox",
        slug: "inbox-composer",
        title: "Inbox composer with mention groups",
        vision: nil,
        descriptionDocKey: nil,
        status: .inProgress,
        accent: "iris",
        milestone: "M3",
        targetDate: "Jul 12",
        health: "ok",
        tags: [],
        progressCached: 0.5,
        createdAt: Date()
    )
    return RoundedCard {
        FeatureRow(feature: feature, liveSessionsCount: 2, ticketsDone: 3, ticketsTotal: 6)
    }
    .padding()
    .background(Theme.Surface.bg(.light))
}
