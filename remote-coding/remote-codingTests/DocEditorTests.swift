import Foundation
import Testing
@testable import remote_coding

struct DocEditorTests {

    // MARK: - DocMarkdownSerializer

    @Test func serializeHeadings() {
        let blocks: [DocBlock] = [
            .heading(level: 1, runs: [TextRun(text: "Vision", marks: [])]),
            .heading(level: 2, runs: [TextRun(text: "Goals", marks: [])]),
            .heading(level: 3, runs: [TextRun(text: "Details", marks: [])])
        ]
        let md = DocMarkdownSerializer.serialize(blocks)
        #expect(md.contains("# Vision"))
        #expect(md.contains("## Goals"))
        #expect(md.contains("### Details"))
    }

    @Test func serializeParagraphWithMarks() {
        let runs: [TextRun] = [
            TextRun(text: "Hello ", marks: []),
            TextRun(text: "world", marks: [.bold]),
            TextRun(text: " and ", marks: []),
            TextRun(text: "code", marks: [.code])
        ]
        let md = DocMarkdownSerializer.serializeRuns(runs)
        #expect(md == "Hello **world** and `code`")
    }

    @Test func serializeCodeBlock() {
        let block = DocBlock.codeBlock(language: "swift", text: "struct Foo {}")
        let md = DocMarkdownSerializer.serialize([block])
        #expect(md == "```swift\nstruct Foo {}\n```")
    }

    @Test func serializeHorizontalRule() {
        let md = DocMarkdownSerializer.serialize([.horizontalRule])
        #expect(md == "---")
    }

    @Test func serializeTable() {
        let block = DocBlock.table(
            headers: ["Name", "Value"],
            rows: [["alpha", "1"], ["beta", "2"]]
        )
        let md = DocMarkdownSerializer.serialize([block])
        #expect(md.contains("| Name | Value |"))
        #expect(md.contains("| --- | --- |"))
        #expect(md.contains("| alpha | 1 |"))
        #expect(md.contains("| beta | 2 |"))
    }

    @Test func serializeImage() {
        let block = DocBlock.image(src: "https://example.com/img.png", alt: "A picture")
        let md = DocMarkdownSerializer.serialize([block])
        #expect(md == "![A picture](https://example.com/img.png)")
    }

    @Test func serializeTaskList() {
        let items: [TaskItem] = [
            TaskItem(checked: true, blocks: [.paragraph(runs: [TextRun(text: "Done", marks: [])])]),
            TaskItem(checked: false, blocks: [.paragraph(runs: [TextRun(text: "Todo", marks: [])])])
        ]
        let md = DocMarkdownSerializer.serialize([.taskList(items: items)])
        #expect(md.contains("- [x] Done"))
        #expect(md.contains("- [ ] Todo"))
    }

    // MARK: - DocMarkdownParser

    @Test func parseHeading() {
        let blocks = DocMarkdownParser.parse("# Hello\n\n## World")
        #expect(blocks.count == 2)
        if case .heading(let level, let runs) = blocks[0] {
            #expect(level == 1)
            #expect(runs.first?.text == "Hello")
        } else {
            Issue.record("Expected heading")
        }
    }

    @Test func parseCodeBlock() {
        let md = "```swift\nlet x = 1\n```"
        let blocks = DocMarkdownParser.parse(md)
        guard case .codeBlock(let lang, let text) = blocks.first else {
            Issue.record("Expected codeBlock"); return
        }
        #expect(lang == "swift")
        #expect(text == "let x = 1")
    }

    @Test func parseHorizontalRule() {
        let blocks = DocMarkdownParser.parse("---")
        #expect(blocks.first == .horizontalRule)
    }

    @Test func parseTable() {
        let md = """
        | A | B |
        | --- | --- |
        | 1 | 2 |
        """
        let blocks = DocMarkdownParser.parse(md)
        guard case .table(let headers, let rows) = blocks.first else {
            Issue.record("Expected table"); return
        }
        #expect(headers == ["A", "B"])
        #expect(rows == [["1", "2"]])
    }

    @Test func parseImage() {
        let blocks = DocMarkdownParser.parse("![alt text](https://example.com/pic.jpg)")
        guard case .image(let src, let alt) = blocks.first else {
            Issue.record("Expected image"); return
        }
        #expect(src == "https://example.com/pic.jpg")
        #expect(alt == "alt text")
    }

    @Test func parseTaskList() {
        let md = "- [x] Done\n- [ ] Pending"
        let blocks = DocMarkdownParser.parse(md)
        guard case .taskList(let items) = blocks.first else {
            Issue.record("Expected taskList"); return
        }
        #expect(items.count == 2)
        #expect(items[0].checked == true)
        #expect(items[1].checked == false)
    }

    @Test func parseBulletList() {
        let blocks = DocMarkdownParser.parse("- Alpha\n- Beta\n- Gamma")
        guard case .bulletList(let items) = blocks.first else {
            Issue.record("Expected bulletList"); return
        }
        #expect(items.count == 3)
    }

    @Test func parseOrderedList() {
        let blocks = DocMarkdownParser.parse("1. First\n2. Second")
        guard case .orderedList(let items) = blocks.first else {
            Issue.record("Expected orderedList"); return
        }
        #expect(items.count == 2)
    }

    @Test func parseInlineBold() {
        let runs = DocMarkdownParser.parseInline("Hello **world**")
        #expect(runs.count == 2)
        #expect(runs[0].text == "Hello ")
        #expect(runs[1].marks.contains(.bold))
    }

    @Test func parseInlineCode() {
        let runs = DocMarkdownParser.parseInline("`snippet`")
        #expect(runs.count == 1)
        #expect(runs[0].marks.contains(.code))
    }

    @Test func parseInlineStrike() {
        let runs = DocMarkdownParser.parseInline("~~struck~~")
        #expect(runs.count == 1)
        #expect(runs[0].marks.contains(.strike))
    }

    // MARK: - DocTipTapEncoder

    @Test func encodeParagraph() {
        let blocks: [DocBlock] = [.paragraph(runs: [TextRun(text: "Hello", marks: [])])]
        let json = DocTipTapEncoder.encode(blocks)
        #expect(json.contains("\"paragraph\""))
        #expect(json.contains("Hello"))
    }

    @Test func encodeHeading() {
        let blocks: [DocBlock] = [.heading(level: 2, runs: [TextRun(text: "Title", marks: [])])]
        let json = DocTipTapEncoder.encode(blocks)
        #expect(json.contains("\"heading\""))
        #expect(json.contains("\"level\""))
    }

    @Test func encodeHorizontalRule() {
        let json = DocTipTapEncoder.encode([.horizontalRule])
        #expect(json.contains("\"horizontalRule\""))
    }

    @Test func encodeTable() {
        let block = DocBlock.table(headers: ["Col"], rows: [["Val"]])
        let json = DocTipTapEncoder.encode([block])
        #expect(json.contains("\"table\""))
        #expect(json.contains("tableHeader"))
        #expect(json.contains("tableCell"))
    }

    // MARK: - Round-trip: serialize → parse → encode → decode

    @Test func roundTripHeadingAndParagraph() {
        let original: [DocBlock] = [
            .heading(level: 1, runs: [TextRun(text: "Plan", marks: [])]),
            .paragraph(runs: [TextRun(text: "Some detail.", marks: [])])
        ]
        let md = DocMarkdownSerializer.serialize(original)
        let reparsed = DocMarkdownParser.parse(md)
        let encoded = DocTipTapEncoder.encode(reparsed)
        let decoded = DocBlockDecoder.decode(encoded)
        #expect(decoded == original)
    }

    @Test func roundTripCodeBlock() {
        let original: [DocBlock] = [
            .codeBlock(language: "swift", text: "let x = 42")
        ]
        let md = DocMarkdownSerializer.serialize(original)
        let reparsed = DocMarkdownParser.parse(md)
        let encoded = DocTipTapEncoder.encode(reparsed)
        let decoded = DocBlockDecoder.decode(encoded)
        #expect(decoded == original)
    }

    @Test func roundTripHorizontalRule() {
        let original: [DocBlock] = [.horizontalRule]
        let md = DocMarkdownSerializer.serialize(original)
        let reparsed = DocMarkdownParser.parse(md)
        let encoded = DocTipTapEncoder.encode(reparsed)
        let decoded = DocBlockDecoder.decode(encoded)
        #expect(decoded == original)
    }

    @Test func roundTripTable() {
        let original: [DocBlock] = [
            .table(headers: ["Name", "Score"], rows: [["Alice", "95"], ["Bob", "88"]])
        ]
        let md = DocMarkdownSerializer.serialize(original)
        let reparsed = DocMarkdownParser.parse(md)
        let encoded = DocTipTapEncoder.encode(reparsed)
        let decoded = DocBlockDecoder.decode(encoded)
        #expect(decoded == original)
    }

    @Test func roundTripBulletList() {
        let original: [DocBlock] = [
            .bulletList(items: [
                [.paragraph(runs: [TextRun(text: "Alpha", marks: [])])],
                [.paragraph(runs: [TextRun(text: "Beta", marks: [])])]
            ])
        ]
        let md = DocMarkdownSerializer.serialize(original)
        let reparsed = DocMarkdownParser.parse(md)
        let encoded = DocTipTapEncoder.encode(reparsed)
        let decoded = DocBlockDecoder.decode(encoded)
        #expect(decoded == original)
    }
}
