import SwiftUI

/// Renders a parsed `[DocBlock]` tree using native SwiftUI views.
///
/// Headings, paragraphs, lists, code blocks, blockquotes, and
/// task lists are all handled. Unknown block types render a muted
/// "Unsupported block" placeholder so the page still scrolls
/// cleanly when the contract introduces new TipTap node types.
struct DocBlockRenderer: View {
    let blocks: [DocBlock]

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s3) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: DocBlock) -> some View {
        switch block {
        case .heading(let level, let runs):
            heading(level: level, runs: runs)
        case .paragraph(let runs):
            paragraph(runs: runs)
        case .bulletList(let items):
            bulletList(items: items, ordered: false)
        case .orderedList(let items):
            bulletList(items: items, ordered: true)
        case .codeBlock(let language, let text):
            codeBlock(language: language, text: text)
        case .blockquote(let inner):
            blockquote(blocks: inner)
        case .taskList(let items):
            taskList(items: items)
        case .unsupported(let type):
            unsupported(type: type)
        }
    }

    // MARK: - Heading / paragraph

    private func heading(level: Int, runs: [TextRun]) -> some View {
        Text(attributed(runs))
            .font(.system(size: headingSize(for: level), weight: .bold))
            .foregroundStyle(Theme.Text.fg(scheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, level == 1 ? Theme.Spacing.s2 : 0)
    }

    private func paragraph(runs: [TextRun]) -> some View {
        Text(attributed(runs))
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Theme.Text.fg(scheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func headingSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return 22
        case 2: return 18
        default: return 16
        }
    }

    // MARK: - Lists

    private func bulletList(items: [[DocBlock]], ordered: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, blocks in
                HStack(alignment: .top, spacing: 8) {
                    Text(ordered ? "\(index + 1)." : "•")
                        .font(.system(size: 15, weight: ordered ? .semibold : .regular, design: ordered ? .monospaced : .default))
                        .foregroundStyle(Theme.Text.fg2(scheme))
                        .frame(width: ordered ? 22 : 14, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                            renderBlock(block)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Code

    private func codeBlock(language: String?, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let language, !language.isEmpty {
                Text(language.uppercased())
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .themeMono(13)
                    .foregroundStyle(Theme.Text.fg(scheme))
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
        .padding(Theme.Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.r2, style: .continuous)
                .fill(Theme.Surface.chip(scheme))
        )
    }

    // MARK: - Blockquote

    private func blockquote(blocks: [DocBlock]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Theme.Text.fg3(scheme))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    renderBlock(block)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Task list

    private func taskList(items: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(item.checked ? Theme.Semantic.green : .clear)
                            .frame(width: 18, height: 18)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(item.checked ? Theme.Semantic.green : Theme.Text.fg3(scheme), lineWidth: 1.5)
                            .frame(width: 18, height: 18)
                        if item.checked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(item.blocks.enumerated()), id: \.offset) { _, block in
                            renderBlock(block)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Unsupported

    private func unsupported(type: String) -> some View {
        Text("Unsupported block: \(type)")
            .themeCaption()
            .foregroundStyle(Theme.Text.fg2(scheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.r2, style: .continuous)
                    .stroke(Theme.Text.fg3(scheme), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            )
    }

    // MARK: - AttributedString

    /// Build a SwiftUI `Text`-friendly `AttributedString` from a runs
    /// array. Each mark applies the matching attribute; unknown marks
    /// are ignored.
    private func attributed(_ runs: [TextRun]) -> AttributedString {
        var result = AttributedString()
        for run in runs {
            var piece = AttributedString(run.text)
            for mark in run.marks {
                switch mark {
                case .bold:
                    piece.font = .system(size: 15, weight: .semibold)
                case .italic:
                    piece.font = (piece.font ?? .system(size: 15)).italic()
                case .code:
                    piece.font = .system(size: 14, design: .monospaced)
                    piece.backgroundColor = Theme.Surface.chip(scheme)
                case .underline:
                    piece.underlineStyle = .single
                case .strike:
                    piece.strikethroughStyle = .single
                }
            }
            result.append(piece)
        }
        return result
    }
}

#Preview("DocBlockRenderer — light") {
    let json = """
    [{"type":"heading","attrs":{"level":1},"content":[{"type":"text","text":"Vision"}]},\
    {"type":"paragraph","content":[{"type":"text","text":"Stream pane output over WebSocket."}]},\
    {"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Notes"}]},\
    {"type":"bulletList","content":[\
    {"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"Use Runestone for the text surface."}]}]},\
    {"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"Don't conflate raw tmux Sessions with AgentSessions."}]}]}]}]
    """
    return ScrollView {
        DocBlockRenderer(blocks: DocBlockDecoder.decode(json))
            .padding()
    }
    .background(Theme.Surface.bg(.light))
}

#Preview("DocBlockRenderer — dark") {
    let json = """
    [{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Code"}]},\
    {"type":"codeBlock","attrs":{"language":"swift"},"content":[{"type":"text","text":"struct Foo {}"}]},\
    {"type":"taskList","content":[\
    {"type":"taskItem","attrs":{"checked":true},"content":[{"type":"paragraph","content":[{"type":"text","text":"First done"}]}]},\
    {"type":"taskItem","attrs":{"checked":false},"content":[{"type":"paragraph","content":[{"type":"text","text":"Still todo"}]}]}]}]
    """
    return ScrollView {
        DocBlockRenderer(blocks: DocBlockDecoder.decode(json))
            .padding()
    }
    .background(Theme.Surface.bg(.dark))
    .preferredColorScheme(.dark)
}
