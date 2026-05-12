import Foundation

/// Read-only representation of a TipTap document block.
///
/// The contract carries `Doc.body_blocks` as opaque TipTap JSON. The
/// renderer here understands a small but useful subset; anything
/// unrecognised falls through to `.unsupported(type:)` so previews
/// and tests stay deterministic.
enum DocBlock: Equatable, Sendable {
    case heading(level: Int, runs: [TextRun])
    case paragraph(runs: [TextRun])
    case bulletList(items: [[DocBlock]])
    case orderedList(items: [[DocBlock]])
    case codeBlock(language: String?, text: String)
    case blockquote(blocks: [DocBlock])
    case taskList(items: [TaskItem])
    case table(headers: [String], rows: [[String]])
    case horizontalRule
    case image(src: String, alt: String?)
    case unsupported(type: String)
}

/// A run of text inside a paragraph / heading / list-item with the
/// marks that should style it (bold / italic / inline code).
struct TextRun: Equatable, Sendable {
    var text: String
    var marks: Set<TextMark>
}

enum TextMark: String, Hashable, Sendable {
    case bold
    case italic
    case code
    case underline
    case strike
}

/// One entry in a `taskList` — a `checked` flag plus the nested
/// blocks (typically a single paragraph).
struct TaskItem: Equatable, Sendable {
    var checked: Bool
    var blocks: [DocBlock]
}

/// Pure helper that walks the raw TipTap JSON and produces a flat
/// `[DocBlock]`. Implemented with `JSONSerialization` so unknown
/// fields are tolerated and the decoder never crashes on novel
/// content.
enum DocBlockDecoder {
    /// Parse a TipTap `body_blocks` JSON string. Returns
    /// `[.unsupported]` placeholders when the input isn't a valid
    /// JSON array of objects, so the renderer always has something
    /// to render.
    static func decode(_ bodyBlocks: String) -> [DocBlock] {
        guard
            let data = bodyBlocks.data(using: .utf8),
            let parsed = try? JSONSerialization.jsonObject(with: data),
            let array = parsed as? [[String: Any]]
        else {
            // Empty or malformed input — return an empty list rather
            // than crash. The renderer falls back to its empty state.
            return []
        }
        return array.map(decodeBlock)
    }

    static func decodeBlock(_ dict: [String: Any]) -> DocBlock {
        guard let type = dict["type"] as? String else {
            return .unsupported(type: "(missing type)")
        }
        let attrs = dict["attrs"] as? [String: Any]
        let content = dict["content"] as? [[String: Any]] ?? []

        switch type {
        case "paragraph":
            return .paragraph(runs: textRuns(from: content))
        case "heading":
            let level = (attrs?["level"] as? Int) ?? 1
            return .heading(level: max(1, min(3, level)), runs: textRuns(from: content))
        case "bulletList":
            return .bulletList(items: listItems(from: content))
        case "orderedList":
            return .orderedList(items: listItems(from: content))
        case "codeBlock":
            let language = attrs?["language"] as? String
            let text = content.compactMap { $0["text"] as? String }.joined()
            return .codeBlock(language: language, text: text)
        case "blockquote":
            return .blockquote(blocks: content.map(decodeBlock))
        case "taskList":
            return .taskList(items: content.compactMap(decodeTaskItem))
        case "table":
            return decodeTable(rows: content)
        case "horizontalRule":
            return .horizontalRule
        case "image":
            let src = (attrs?["src"] as? String) ?? ""
            let alt = attrs?["alt"] as? String
            return .image(src: src, alt: alt?.isEmpty == false ? alt : nil)
        default:
            return .unsupported(type: type)
        }
    }

    private static func decodeTable(rows tableRows: [[String: Any]]) -> DocBlock {
        var headers: [String] = []
        var rows: [[String]] = []
        for row in tableRows {
            guard row["type"] as? String == "tableRow" else { continue }
            let cells = row["content"] as? [[String: Any]] ?? []
            let isHeader = cells.first?["type"] as? String == "tableHeader"
            let texts = cells.map { cell -> String in
                let inner = cell["content"] as? [[String: Any]] ?? []
                return inner.flatMap { node -> [String] in
                    textRuns(from: node["content"] as? [[String: Any]] ?? []).map(\.text)
                }.joined(separator: " ")
            }
            if isHeader {
                headers = texts
            } else {
                rows.append(texts)
            }
        }
        return .table(headers: headers, rows: rows)
    }

    /// Flatten an array of inline `text` nodes into `TextRun`s.
    /// Whitespace-only marks (e.g. unknown mark types) are dropped.
    static func textRuns(from content: [[String: Any]]) -> [TextRun] {
        var runs: [TextRun] = []
        for node in content {
            guard node["type"] as? String == "text",
                  let text = node["text"] as? String,
                  !text.isEmpty
            else { continue }
            let marks = (node["marks"] as? [[String: Any]])?
                .compactMap { mark in (mark["type"] as? String).flatMap(TextMark.init(rawValue:)) }
            runs.append(TextRun(text: text, marks: Set(marks ?? [])))
        }
        return runs
    }

    /// Walk a list's `content` array of `listItem`s into the nested
    /// blocks each item carries.
    static func listItems(from content: [[String: Any]]) -> [[DocBlock]] {
        content.compactMap { item in
            guard item["type"] as? String == "listItem" else { return nil }
            let inner = item["content"] as? [[String: Any]] ?? []
            return inner.map(decodeBlock)
        }
    }

    static func decodeTaskItem(_ dict: [String: Any]) -> TaskItem? {
        guard dict["type"] as? String == "taskItem" else { return nil }
        let attrs = dict["attrs"] as? [String: Any]
        let checked = (attrs?["checked"] as? Bool) ?? false
        let inner = dict["content"] as? [[String: Any]] ?? []
        return TaskItem(checked: checked, blocks: inner.map(decodeBlock))
    }
}
