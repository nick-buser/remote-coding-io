import Foundation

/// Parses a Markdown string (as produced by `DocMarkdownSerializer`) into a
/// `[DocBlock]` tree. Handles the same subset that the serializer emits so
/// that the edit round-trip is lossless for all supported block types.
enum DocMarkdownParser {

    static func parse(_ markdown: String) -> [DocBlock] {
        var blocks: [DocBlock] = []
        let lines = markdown.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // ── Fenced code block ──────────────────────────────────────────
            if line.hasPrefix("```") {
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                i += 1
                var code: [String] = []
                while i < lines.count && !lines[i].hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 }
                blocks.append(.codeBlock(
                    language: lang.isEmpty ? nil : lang,
                    text: code.joined(separator: "\n")
                ))
                continue
            }

            // ── Heading ────────────────────────────────────────────────────
            if let h = parseHeading(line) {
                blocks.append(h)
                i += 1
                continue
            }

            // ── Horizontal rule ────────────────────────────────────────────
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if (trimmed == "---" || trimmed == "***" || trimmed == "___") ||
               (trimmed.count >= 3 && !trimmed.hasPrefix("|") && trimmed.allSatisfy({ $0 == "-" })) {
                blocks.append(.horizontalRule)
                i += 1
                continue
            }

            // ── Table ──────────────────────────────────────────────────────
            if line.hasPrefix("|") {
                var tableLines: [String] = []
                while i < lines.count && lines[i].hasPrefix("|") {
                    tableLines.append(lines[i])
                    i += 1
                }
                if let table = parseTable(tableLines) {
                    blocks.append(table)
                }
                continue
            }

            // ── Blockquote ─────────────────────────────────────────────────
            if line.hasPrefix("> ") {
                var quoteLines: [String] = []
                while i < lines.count && lines[i].hasPrefix("> ") {
                    quoteLines.append(String(lines[i].dropFirst(2)))
                    i += 1
                }
                blocks.append(.blockquote(blocks: parse(quoteLines.joined(separator: "\n"))))
                continue
            }

            // ── Task list ──────────────────────────────────────────────────
            if isTaskItem(line) {
                var items: [TaskItem] = []
                while i < lines.count && isTaskItem(lines[i]) {
                    let l = lines[i]
                    let checked = l.hasPrefix("- [x] ") || l.hasPrefix("- [X] ")
                    let text = String(l.dropFirst(6))
                    items.append(TaskItem(checked: checked, blocks: [.paragraph(runs: parseInline(text))]))
                    i += 1
                }
                blocks.append(.taskList(items: items))
                continue
            }

            // ── Bullet list ────────────────────────────────────────────────
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                var items: [[DocBlock]] = []
                while i < lines.count && (lines[i].hasPrefix("- ") || lines[i].hasPrefix("* ")) {
                    let text = String(lines[i].dropFirst(2))
                    items.append([.paragraph(runs: parseInline(text))])
                    i += 1
                }
                blocks.append(.bulletList(items: items))
                continue
            }

            // ── Ordered list ───────────────────────────────────────────────
            if line.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                var items: [[DocBlock]] = []
                while i < lines.count,
                      lines[i].range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                    let text = lines[i].replacingOccurrences(
                        of: #"^\d+\. "#, with: "", options: .regularExpression)
                    items.append([.paragraph(runs: parseInline(text))])
                    i += 1
                }
                blocks.append(.orderedList(items: items))
                continue
            }

            // ── Image ──────────────────────────────────────────────────────
            if line.hasPrefix("!["), let img = parseImage(line) {
                blocks.append(img)
                i += 1
                continue
            }

            // ── Empty line ─────────────────────────────────────────────────
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // ── Paragraph ──────────────────────────────────────────────────
            blocks.append(.paragraph(runs: parseInline(line)))
            i += 1
        }

        return blocks
    }

    // MARK: - Block helpers

    private static func isTaskItem(_ line: String) -> Bool {
        line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ")
    }

    private static func parseHeading(_ line: String) -> DocBlock? {
        var level = 0
        for ch in line {
            if ch == "#" { level += 1 } else { break }
        }
        guard level >= 1, level <= 6 else { return nil }
        let rest = String(line.dropFirst(level))
        guard rest.hasPrefix(" ") else { return nil }
        return .heading(level: min(3, level), runs: parseInline(String(rest.dropFirst())))
    }

    private static func parseTable(_ lines: [String]) -> DocBlock? {
        guard lines.count >= 2 else { return nil }
        let parseRow: (String) -> [String] = { line in
            line.split(separator: "|", omittingEmptySubsequences: false)
                .dropFirst()
                .dropLast()
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }
        let headers = parseRow(lines[0])
        let rows = lines.dropFirst(2).map(parseRow)
        return .table(headers: headers, rows: Array(rows))
    }

    private static func parseImage(_ line: String) -> DocBlock? {
        let pattern = #"^!\[([^\]]*)\]\(([^)]+)\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let altRange = Range(match.range(at: 1), in: line),
              let srcRange = Range(match.range(at: 2), in: line)
        else { return nil }
        let alt = String(line[altRange])
        let src = String(line[srcRange])
        return .image(src: src, alt: alt.isEmpty ? nil : alt)
    }

    // MARK: - Inline parser

    /// Parse inline marks from a Markdown text fragment into `[TextRun]`.
    ///
    /// The parser is greedy and left-to-right. It handles the patterns emitted
    /// by `DocMarkdownSerializer`: `**bold**`, `~~strike~~`, `<u>underline</u>`,
    /// `*italic*`, `` `code` ``. Swift `Substring` indices are shared with the
    /// parent `String`, so ranges returned by `range(of:)` on a substring are
    /// directly usable as indices into the original string.
    static func parseInline(_ text: String) -> [TextRun] {
        var runs: [TextRun] = []
        var remaining = text

        while !remaining.isEmpty {
            // Bold: **text**
            if remaining.hasPrefix("**"),
               let end = remaining.dropFirst(2).range(of: "**") {
                let inner = remaining[remaining.index(remaining.startIndex, offsetBy: 2)..<end.lowerBound]
                runs.append(TextRun(text: String(inner), marks: [.bold]))
                remaining = String(remaining[end.upperBound...])
                continue
            }

            // Strike: ~~text~~
            if remaining.hasPrefix("~~"),
               let end = remaining.dropFirst(2).range(of: "~~") {
                let inner = remaining[remaining.index(remaining.startIndex, offsetBy: 2)..<end.lowerBound]
                runs.append(TextRun(text: String(inner), marks: [.strike]))
                remaining = String(remaining[end.upperBound...])
                continue
            }

            // Underline: <u>text</u>
            if remaining.hasPrefix("<u>"),
               let close = remaining.range(of: "</u>") {
                let inner = remaining[remaining.index(remaining.startIndex, offsetBy: 3)..<close.lowerBound]
                runs.append(TextRun(text: String(inner), marks: [.underline]))
                remaining = String(remaining[close.upperBound...])
                continue
            }

            // Italic: *text* (must not be **)
            if remaining.hasPrefix("*") && !remaining.hasPrefix("**"),
               let end = remaining.dropFirst(1).range(of: "*") {
                let inner = remaining[remaining.index(after: remaining.startIndex)..<end.lowerBound]
                runs.append(TextRun(text: String(inner), marks: [.italic]))
                remaining = String(remaining[end.upperBound...])
                continue
            }

            // Code: `text`
            if remaining.hasPrefix("`"),
               let end = remaining.dropFirst(1).range(of: "`") {
                let inner = remaining[remaining.index(after: remaining.startIndex)..<end.lowerBound]
                runs.append(TextRun(text: String(inner), marks: [.code]))
                remaining = String(remaining[end.upperBound...])
                continue
            }

            // Accumulate plain chars until the next potential marker
            var plain = ""
            var idx = remaining.startIndex
            while idx < remaining.endIndex {
                let ch = remaining[idx]
                if ch == "*" || ch == "`" || ch == "~" ||
                   (ch == "<" && remaining[idx...].hasPrefix("<u>")) {
                    break
                }
                plain.append(ch)
                idx = remaining.index(after: idx)
            }
            if plain.isEmpty {
                // Unmatched marker — consume one char as plain text to avoid looping.
                plain = String(remaining.prefix(1))
                remaining = String(remaining.dropFirst())
            } else {
                remaining = String(remaining[idx...])
            }
            runs.append(TextRun(text: plain, marks: []))
        }

        return runs.filter { !$0.text.isEmpty }
    }
}
