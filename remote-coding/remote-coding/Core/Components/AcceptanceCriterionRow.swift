import SwiftUI

/// A toggleable acceptance criterion row. Tapping the checkbox fires
/// `onToggle`; the caller is responsible for the async update.
struct AcceptanceCriterionRow: View {
    let criterion: Components.Schemas.AcceptanceCriterion
    var onToggle: () -> Void = {}

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: Theme.Spacing.s3) {
                checkbox
                    .padding(.top, 2)
                Text(criterion.text)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(criterion.done ? Theme.Text.fg2(scheme) : Theme.Text.fg(scheme))
                    .strikethrough(criterion.done, color: Theme.Text.fg2(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var checkbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(criterion.done ? Theme.Semantic.green : Color.clear)
                .frame(width: 18, height: 18)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(criterion.done ? Theme.Semantic.green : Theme.Text.fg3(scheme), lineWidth: 1.5)
                .frame(width: 18, height: 18)
            if criterion.done {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
