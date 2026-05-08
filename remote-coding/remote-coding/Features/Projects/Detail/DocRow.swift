import SwiftUI

/// Doc row used inside the Project detail Docs sub-tab and the
/// Feature detail PRD sub-tab. The project-scope variant prefixes the
/// parent feature title via `featureLabel`.
struct DocRow: View {
    let doc: Components.Schemas.Doc
    var featureLabel: String? = nil
    var onTap: () -> Void = {}

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Theme.Spacing.s3) {
                Image(systemName: kindSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Text.fg2(scheme))
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(kindLabel)
                            .themeMonoSm()
                            .foregroundStyle(Theme.Text.fg2(scheme))
                        if let featureLabel {
                            Text("·")
                                .themeMonoSm()
                                .foregroundStyle(Theme.Text.fg2(scheme))
                            Text(featureLabel)
                                .themeMonoSm()
                                .foregroundStyle(Theme.Text.fg2(scheme))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Text("\(doc.wordCount) words")
                            .themeMonoSm()
                            .foregroundStyle(Theme.Text.fg2(scheme))
                    }
                    Text(doc.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Text.fg(scheme))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Chevron()
                    .padding(.top, 2)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var kindSymbol: String {
        switch doc.kind {
        case .vision: return "sparkles"
        case .prd:    return "doc.text"
        case .design: return "ruler"
        case .notes:  return "list.bullet.rectangle"
        case .log:    return "clock.arrow.circlepath"
        case .custom: return "doc"
        }
    }

    private var kindLabel: String {
        switch doc.kind {
        case .vision: return "VISION"
        case .prd:    return "PRD"
        case .design: return "DESIGN"
        case .notes:  return "NOTES"
        case .log:    return "LOG"
        case .custom: return "DOC"
        }
    }
}
