import Foundation

/// Encodes a `[DocBlock]` tree back to the TipTap JSON string expected by
/// the API's `body_blocks` field. This is the inverse of `DocBlockDecoder`.
enum DocTipTapEncoder {

    static func encode(_ blocks: [DocBlock]) -> String {
        let array = blocks.map(encodeBlock)
        guard let data = try? JSONSerialization.data(withJSONObject: array),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    // MARK: - Blocks

    private static func encodeBlock(_ block: DocBlock) -> [String: Any] {
        switch block {
        case .heading(let level, let runs):
            return [
                "type": "heading",
                "attrs": ["level": level],
                "content": encodeRuns(runs)
            ]

        case .paragraph(let runs):
            return [
                "type": "paragraph",
                "content": encodeRuns(runs)
            ]

        case .bulletList(let items):
            return [
                "type": "bulletList",
                "content": items.map { blocks -> [String: Any] in
                    ["type": "listItem", "content": blocks.map(encodeBlock)]
                }
            ]

        case .orderedList(let items):
            return [
                "type": "orderedList",
                "content": items.map { blocks -> [String: Any] in
                    ["type": "listItem", "content": blocks.map(encodeBlock)]
                }
            ]

        case .codeBlock(let language, let text):
            var attrs: [String: Any] = [:]
            if let language { attrs["language"] = language }
            return [
                "type": "codeBlock",
                "attrs": attrs,
                "content": [["type": "text", "text": text]]
            ]

        case .blockquote(let blocks):
            return [
                "type": "blockquote",
                "content": blocks.map(encodeBlock)
            ]

        case .taskList(let items):
            return [
                "type": "taskList",
                "content": items.map { item -> [String: Any] in
                    [
                        "type": "taskItem",
                        "attrs": ["checked": item.checked],
                        "content": item.blocks.map(encodeBlock)
                    ]
                }
            ]

        case .table(let headers, let rows):
            var tableRows: [[String: Any]] = []
            if !headers.isEmpty {
                let headerCells: [[String: Any]] = headers.map { h in
                    ["type": "tableHeader",
                     "content": [["type": "paragraph",
                                  "content": [["type": "text", "text": h]]]]]
                }
                tableRows.append(["type": "tableRow", "content": headerCells])
            }
            for row in rows {
                let cells: [[String: Any]] = row.map { cell in
                    ["type": "tableCell",
                     "content": [["type": "paragraph",
                                  "content": [["type": "text", "text": cell]]]]]
                }
                tableRows.append(["type": "tableRow", "content": cells])
            }
            return ["type": "table", "content": tableRows]

        case .horizontalRule:
            return ["type": "horizontalRule"]

        case .image(let src, let alt):
            var attrs: [String: Any] = ["src": src]
            if let alt { attrs["alt"] = alt }
            return ["type": "image", "attrs": attrs]

        case .unsupported(let type):
            return ["type": type]
        }
    }

    // MARK: - Inline runs

    private static func encodeRuns(_ runs: [TextRun]) -> [[String: Any]] {
        runs.map { run in
            var node: [String: Any] = ["type": "text", "text": run.text]
            if !run.marks.isEmpty {
                node["marks"] = run.marks.sorted(by: { $0.rawValue < $1.rawValue }).map { mark -> [String: Any] in
                    ["type": mark.rawValue]
                }
            }
            return node
        }
    }
}
