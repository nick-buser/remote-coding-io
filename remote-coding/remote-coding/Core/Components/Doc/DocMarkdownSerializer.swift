import Foundation

/// Converts a `[DocBlock]` tree into a Markdown string suitable for display
/// in the Runestone doc editor. The output is round-trippable through
/// `DocMarkdownParser` + `DocTipTapEncoder` back to TipTap JSON.
enum DocMarkdownSerializer {

    static func serialize(_ blocks: [DocBlock]) -> String {
        blocks
            .map(serializeBlock)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    // MARK: - Blocks

    private static func serializeBlock(_ block: DocBlock) -> String {
        switch block {
        case .heading(let level, let runs):
            return String(repeating: "#", count: level) + " " + serializeRuns(runs)

        case .paragraph(let runs):
            return serializeRuns(runs)

        case .bulletList(let items):
            return items.map { blocks in
                "- " + blocks.map(serializeBlock).joined(separator: "\n  ")
            }.joined(separator: "\n")

        case .orderedList(let items):
            return items.enumerated().map { index, blocks in
                "\(index + 1). " + blocks.map(serializeBlock).joined(separator: "\n   ")
            }.joined(separator: "\n")

        case .codeBlock(let language, let text):
            let lang = language ?? ""
            return "```\(lang)\n\(text)\n```"

        case .blockquote(let blocks):
            let inner = serialize(blocks)
            return inner
                .components(separatedBy: "\n")
                .map { "> \($0)" }
                .joined(separator: "\n")

        case .taskList(let items):
            return items.map { item in
                let mark = item.checked ? "[x]" : "[ ]"
                let text = item.blocks.map(serializeBlock).joined(separator: "\n  ")
                return "- \(mark) \(text)"
            }.joined(separator: "\n")

        case .table(let headers, let rows):
            var lines: [String] = []
            if !headers.isEmpty {
                lines.append("| " + headers.joined(separator: " | ") + " |")
                lines.append("| " + headers.map { _ in "---" }.joined(separator: " | ") + " |")
            }
            for row in rows {
                lines.append("| " + row.joined(separator: " | ") + " |")
            }
            return lines.joined(separator: "\n")

        case .horizontalRule:
            return "---"

        case .image(let src, let alt):
            return "![\(alt ?? "")](\(src))"

        case .unsupported:
            return ""
        }
    }

    // MARK: - Inline marks

    static func serializeRuns(_ runs: [TextRun]) -> String {
        runs.map { run in
            var text = run.text
            // Apply innermost marks first so delimiters nest correctly.
            if run.marks.contains(.code) { text = "`\(text)`" }
            if run.marks.contains(.strike) { text = "~~\(text)~~" }
            if run.marks.contains(.underline) { text = "<u>\(text)</u>" }
            if run.marks.contains(.italic) { text = "*\(text)*" }
            if run.marks.contains(.bold) { text = "**\(text)**" }
            return text
        }.joined()
    }
}
