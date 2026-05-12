import SwiftUI

/// Ticket review screen mounted on the `.ticketDetail` route.
///
/// Composition: `QuietHeader` + ticket meta hero + `SegmentedControl`
/// (Diff / Checklist <done>/<total> / Files) + body, with a sticky
/// safe-area footer carrying `Approve & merge` / `Request changes`.
struct TicketReviewView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(RootCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var viewModel: TicketReviewViewModel
    @State private var section: String = ReviewSection.diff.rawValue
    @State private var showRequestChangesSheet = false
    @State private var requestChangesComment: String = ""

    init(publicID: String) {
        _viewModel = State(initialValue: TicketReviewViewModel(publicID: publicID))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                topBar
                hero
                SegmentedControl(items: ReviewSection.allLabels(checklistDone: viewModel.checklistDone, checklistTotal: viewModel.checklistTotal), selection: $section)
                    .padding(.horizontal, Theme.Spacing.s4)
                sectionBody
            }
            .padding(.bottom, Theme.Spacing.s5)
        }
        .background(Theme.Surface.bg(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
        .task {
            await viewModel.load(repository: appModel.repository)
        }
        .refreshable {
            await viewModel.load(repository: appModel.repository)
        }
        .onChange(of: viewModel.didFinishAction) { _, finished in
            if finished {
                dismiss()
            }
        }
        .sheet(isPresented: $showRequestChangesSheet) {
            requestChangesSheet
        }
    }

    // MARK: - Header / hero

    private var topBar: some View {
        QuietHeader(label: viewModel.publicID) {
            BackChevron(label: "Back", accent: appModel.accent) { dismiss() }
        } trailing: {
            Menu {
                Button("Send back to doing") {
                    Task { await viewModel.sendBack(comment: nil, repository: appModel.repository) }
                }
                Button("Mark in review") { /* no-op — already in review */ }
                    .disabled(true)
                Button("Edit ticket") { /* edit sheet — follow-up */ }
                    .disabled(true)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Text.fg(scheme))
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Review actions")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(viewModel.publicID)
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
                StatusPill(role: viewModel.statusRole, label: viewModel.statusLabel)
            }
            Text(viewModel.ticket?.title ?? "Loading…")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.Text.fg(scheme))
                .lineLimit(3)
            metaLine
        }
        .padding(.horizontal, Theme.Spacing.s4)
    }

    private var metaLine: some View {
        let stats = viewModel.diffStats
        let parts: [String] = [
            viewModel.diff.map { "branch \($0.branch)" },
            stats.fileCount > 0 ? "+\(stats.adds) / −\(stats.dels) · \(stats.fileCount) file\(stats.fileCount == 1 ? "" : "s")" : nil
        ].compactMap { $0 }
        return Text(parts.joined(separator: " · "))
            .themeMonoSm()
            .foregroundStyle(Theme.Text.fg2(scheme))
    }

    // MARK: - Body

    @ViewBuilder
    private var sectionBody: some View {
        if viewModel.isLoading && viewModel.ticket == nil {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.s4)
        } else if let errorMessage = viewModel.errorMessage, viewModel.ticket == nil {
            VStack(spacing: Theme.Spacing.s4) {
                EmptyState(systemImage: "wifi.exclamationmark", title: "Couldn't load review", message: errorMessage)
                Button("Retry") {
                    Task { await viewModel.load(repository: appModel.repository) }
                }
                .buttonStyle(.bordered)
            }
        } else {
            switch ReviewSection.from(label: section) {
            case .diff:      diffBody
            case .checklist: checklistBody
            case .files:     filesBody
            }
        }
    }

    private var diffBody: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
            ForEach((viewModel.diff?.files ?? []).indexed(), id: \.index) { _, file in
                DiffFileCard(file: file)
                    .padding(.horizontal, Theme.Spacing.s4)
            }
            if (viewModel.diff?.files ?? []).isEmpty {
                EmptyState(
                    systemImage: "doc.text.magnifyingglass",
                    title: "No diff",
                    message: "The ticket has no associated changes."
                )
            }
        }
    }

    private var checklistBody: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
            Text("ACCEPTANCE CRITERIA")
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
                .padding(.horizontal, Theme.Spacing.s4)
            RoundedCard {
                VStack(spacing: 12) {
                    ForEach(viewModel.criteria.indexed(), id: \.element.id) { index, criterion in
                        if index > 0 {
                            Divider().background(Theme.Surface.sep(scheme))
                        }
                        criteriaRow(for: criterion)
                    }
                    if viewModel.criteria.isEmpty {
                        Text("No criteria defined.")
                            .themeCaption()
                            .foregroundStyle(Theme.Text.fg2(scheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }

    private func criteriaRow(for criterion: Components.Schemas.AcceptanceCriterion) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s3) {
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
            .padding(.top, 2)
            Text(criterion.text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(criterion.done ? Theme.Text.fg2(scheme) : Theme.Text.fg(scheme))
                .strikethrough(criterion.done, color: Theme.Text.fg2(scheme))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var filesBody: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
            ForEach(viewModel.filesByChange(), id: \.label) { group in
                VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
                    Text(group.label.uppercased())
                        .themeMonoSm()
                        .foregroundStyle(Theme.Text.fg2(scheme))
                        .padding(.horizontal, Theme.Spacing.s4)
                    RoundedCard {
                        VStack(spacing: 8) {
                            ForEach(group.files.indexed(), id: \.index) { index, file in
                                if index > 0 {
                                    Divider().background(Theme.Surface.sep(scheme))
                                }
                                Text(file.path)
                                    .themeMono(13)
                                    .foregroundStyle(Theme.Text.fg(scheme))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.s4)
                }
            }
            if viewModel.filesByChange().isEmpty {
                EmptyState(systemImage: "doc", title: "No files", message: "This review has no file changes.")
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            PillButton(title: "Request changes", role: .secondary, accent: appModel.accent, wide: true) {
                requestChangesComment = ""
                showRequestChangesSheet = true
            }
            PillButton(title: "Approve & merge", role: .primary, accent: appModel.accent, wide: true) {
                Task { await viewModel.approve(repository: appModel.repository) }
            }
        }
        .padding(.horizontal, Theme.Spacing.s4)
        .padding(.vertical, Theme.Spacing.s3)
        .background(.ultraThinMaterial)
    }

    private var requestChangesSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                Text("Optional comment")
                    .themeCaption()
                    .foregroundStyle(Theme.Text.fg2(scheme))
                    .padding(.horizontal, Theme.Spacing.s4)
                    .padding(.top, Theme.Spacing.s4)
                TextEditor(text: $requestChangesComment)
                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                    .padding(.horizontal, Theme.Spacing.s4)
                    .frame(minHeight: 160)
                Spacer()
            }
            .background(Theme.Surface.bg(scheme))
            .navigationTitle("Request changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showRequestChangesSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        let trimmed = requestChangesComment.trimmingCharacters(in: .whitespacesAndNewlines)
                        let comment: String? = trimmed.isEmpty ? nil : trimmed
                        showRequestChangesSheet = false
                        Task { await viewModel.requestChanges(comment: comment, repository: appModel.repository) }
                    }
                }
            }
        }
    }
}

// MARK: - Per-file diff card

private struct DiffFileCard: View {
    let file: Components.Schemas.FileDiff

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        RoundedCard {
            VStack(alignment: .leading, spacing: 8) {
                header
                Divider().background(Theme.Surface.sep(scheme))
                if file.binary == true {
                    Text("[binary file]")
                        .themeMono(12)
                        .foregroundStyle(Theme.Text.fg2(scheme))
                } else {
                    body(for: UnifiedDiff.compute(old: file.oldContent ?? "", new: file.newContent ?? ""))
                }
            }
        }
    }

    private var header: some View {
        let summary = UnifiedDiff.summary(old: file.oldContent ?? "", new: file.newContent ?? "")
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(displayPath)
                    .themeMono(12)
                    .foregroundStyle(Theme.Text.fg2(scheme))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                changeBadge
            }
            HStack(spacing: 6) {
                Text("+\(summary.adds)")
                    .themeMonoSm()
                    .foregroundStyle(Theme.Semantic.green)
                Text("/")
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
                Text("−\(summary.dels)")
                    .themeMonoSm()
                    .foregroundStyle(Theme.Semantic.red)
            }
        }
    }

    private var changeBadge: some View {
        let label: String
        switch file.change {
        case .added:    label = "Added"
        case .modified: label = "Modified"
        case .deleted:  label = "Deleted"
        case .renamed:  label = "Renamed"
        }
        return Text(label.uppercased())
            .themeMonoSm()
            .foregroundStyle(Theme.Text.fg2(scheme))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.Surface.chip(scheme)))
    }

    private var displayPath: String {
        if file.change == .renamed, let old = file.oldPath, !old.isEmpty {
            return "\(old) → \(file.path)"
        }
        return file.path
    }

    @ViewBuilder
    private func body(for lines: [UnifiedDiff.Line]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(lines) { line in
                    diffLine(line)
                }
            }
        }
    }

    private func diffLine(_ line: UnifiedDiff.Line) -> some View {
        HStack(spacing: 8) {
            Text(prefix(for: line.kind))
                .themeMono(12)
                .foregroundStyle(color(for: line.kind))
                .frame(width: 12, alignment: .leading)
            Text(line.text.isEmpty ? " " : line.text)
                .themeMono(12)
                .foregroundStyle(color(for: line.kind))
                .fixedSize(horizontal: true, vertical: true)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(background(for: line.kind))
    }

    private func prefix(for kind: UnifiedDiff.Kind) -> String {
        switch kind {
        case .added:   return "+"
        case .removed: return "-"
        case .context: return " "
        }
    }

    private func color(for kind: UnifiedDiff.Kind) -> Color {
        switch kind {
        case .added:   return Theme.Semantic.green
        case .removed: return Theme.Semantic.red
        case .context: return Theme.Text.fg(scheme)
        }
    }

    private func background(for kind: UnifiedDiff.Kind) -> Color {
        switch kind {
        case .added:   return Theme.Semantic.green.opacity(0.12)
        case .removed: return Theme.Semantic.red.opacity(0.12)
        case .context: return .clear
        }
    }
}

// MARK: - Section enum

enum ReviewSection: String, CaseIterable {
    case diff = "Diff"
    case checklist = "Checklist"
    case files = "Files"

    static func allLabels(checklistDone: Int, checklistTotal: Int) -> [String] {
        ["Diff", "Checklist \(checklistDone)/\(checklistTotal)", "Files"]
    }

    static func from(label: String) -> ReviewSection {
        if label.hasPrefix("Diff") { return .diff }
        if label.hasPrefix("Checklist") { return .checklist }
        if label.hasPrefix("Files") { return .files }
        return .diff
    }
}

// MARK: - Index helper

extension Array {
    /// Yields `(index, element)` tuples; cleaner than
    /// `Array(.enumerated())` at the call site for SwiftUI's
    /// `ForEach` plus `.id` helpers.
    func indexed() -> [(index: Int, element: Element)] {
        zip(indices, self).map { (index: $0.0, element: $0.1) }
    }
}

// MARK: - Previews

#Preview("TicketReview — light") {
    NavigationStack {
        TicketReviewView(publicID: "TMX-0050")
    }
    .environment(AppModel(repository: MockTmuxAgentRepository()))
    .environment(RootCoordinator())
}

#Preview("TicketReview — dark") {
    NavigationStack {
        TicketReviewView(publicID: "TMX-0050")
    }
    .environment(AppModel(repository: MockTmuxAgentRepository()))
    .environment(RootCoordinator())
    .preferredColorScheme(.dark)
}
