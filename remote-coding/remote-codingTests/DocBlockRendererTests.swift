import Foundation
import Testing
@testable import remote_coding

struct DocBlockDecoderTests {

    // MARK: - Decoder shapes

    @Test func decodesParagraphAndHeadingFromMockSeed() async {
        let json = """
        [{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Vision"}]},\
        {"type":"paragraph","content":[{"type":"text","text":"Stream pane output."}]}]
        """

        let blocks = DocBlockDecoder.decode(json)

        #expect(blocks.count == 2)
        if case .heading(let level, let runs) = blocks[0] {
            #expect(level == 2)
            #expect(runs.first?.text == "Vision")
        } else {
            Issue.record("first block should be a heading")
        }
        if case .paragraph(let runs) = blocks[1] {
            #expect(runs.first?.text == "Stream pane output.")
        } else {
            Issue.record("second block should be a paragraph")
        }
    }

    @Test func headingLevelClampsToValidRange() async {
        let json = """
        [{"type":"heading","attrs":{"level":7},"content":[{"type":"text","text":"Too deep"}]}]
        """

        let blocks = DocBlockDecoder.decode(json)

        if case .heading(let level, _) = blocks.first {
            #expect(level == 3)
        } else {
            Issue.record("expected a clamped heading")
        }
    }

    @Test func decodesBulletListWithListItemContent() async {
        let json = """
        [{"type":"bulletList","content":[\
        {"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"First"}]}]},\
        {"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"Second"}]}]}]}]
        """

        let blocks = DocBlockDecoder.decode(json)

        if case .bulletList(let items) = blocks.first {
            #expect(items.count == 2)
            if case .paragraph(let runs) = items.first?.first {
                #expect(runs.first?.text == "First")
            } else {
                Issue.record("expected a paragraph inside the first bullet")
            }
        } else {
            Issue.record("expected a bulletList block")
        }
    }

    @Test func decodesCodeBlockWithLanguageAttr() async {
        let json = """
        [{"type":"codeBlock","attrs":{"language":"swift"},"content":[{"type":"text","text":"struct A {}"}]}]
        """

        let blocks = DocBlockDecoder.decode(json)

        if case .codeBlock(let language, let text) = blocks.first {
            #expect(language == "swift")
            #expect(text == "struct A {}")
        } else {
            Issue.record("expected a codeBlock")
        }
    }

    @Test func decodesTaskListWithCheckedAttrs() async {
        let json = """
        [{"type":"taskList","content":[\
        {"type":"taskItem","attrs":{"checked":true},"content":[{"type":"paragraph","content":[{"type":"text","text":"Done"}]}]},\
        {"type":"taskItem","attrs":{"checked":false},"content":[{"type":"paragraph","content":[{"type":"text","text":"Open"}]}]}]}]
        """

        let blocks = DocBlockDecoder.decode(json)

        if case .taskList(let items) = blocks.first {
            #expect(items.count == 2)
            #expect(items[0].checked)
            #expect(!items[1].checked)
        } else {
            Issue.record("expected a taskList")
        }
    }

    @Test func unknownNodeFallsBackToUnsupportedPlaceholder() async {
        let json = """
        [{"type":"horizontalRule"}]
        """

        let blocks = DocBlockDecoder.decode(json)

        if case .unsupported(let type) = blocks.first {
            #expect(type == "horizontalRule")
        } else {
            Issue.record("expected an unsupported placeholder")
        }
    }

    @Test func malformedInputReturnsEmptyArray() async {
        #expect(DocBlockDecoder.decode("").isEmpty)
        #expect(DocBlockDecoder.decode("not json").isEmpty)
        #expect(DocBlockDecoder.decode("{\"not\":\"an array\"}").isEmpty)
    }

    // MARK: - Marks

    @Test func textRunsCarryRecognisedMarks() async {
        let json = """
        [{"type":"paragraph","content":[\
        {"type":"text","text":"plain "},\
        {"type":"text","text":"bold","marks":[{"type":"bold"}]},\
        {"type":"text","text":" italic","marks":[{"type":"italic"}]},\
        {"type":"text","text":" code","marks":[{"type":"code"}]}]}]
        """

        let blocks = DocBlockDecoder.decode(json)

        if case .paragraph(let runs) = blocks.first {
            #expect(runs.count == 4)
            #expect(runs[0].marks.isEmpty)
            #expect(runs[1].marks == [.bold])
            #expect(runs[2].marks == [.italic])
            #expect(runs[3].marks == [.code])
        } else {
            Issue.record("expected a paragraph")
        }
    }

    @Test func unknownMarksAreDropped() async {
        let json = """
        [{"type":"paragraph","content":[\
        {"type":"text","text":"odd","marks":[{"type":"glitter"}]}]}]
        """

        let blocks = DocBlockDecoder.decode(json)

        if case .paragraph(let runs) = blocks.first, let run = runs.first {
            #expect(run.text == "odd")
            #expect(run.marks.isEmpty)
        } else {
            Issue.record("expected a paragraph with a single run")
        }
    }
}
