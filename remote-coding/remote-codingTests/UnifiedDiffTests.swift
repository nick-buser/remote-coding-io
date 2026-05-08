import Foundation
import Testing
@testable import remote_coding

struct UnifiedDiffTests {

    @Test func emptyInputsProduceNoLines() async {
        let lines = UnifiedDiff.compute(old: "", new: "")
        #expect(lines.isEmpty)
    }

    @Test func identicalContentProducesContextOnly() async {
        let text = "alpha\nbeta\ngamma"
        let lines = UnifiedDiff.compute(old: text, new: text)
        #expect(lines.count == 3)
        for line in lines {
            #expect(line.kind == .context)
        }
    }

    @Test func insertionProducesAddedLines() async {
        let old = "alpha\ngamma"
        let new = "alpha\nbeta\ngamma"
        let lines = UnifiedDiff.compute(old: old, new: new)

        #expect(lines.map(\.kind) == [.context, .added, .context])
        #expect(lines[1].text == "beta")
    }

    @Test func deletionProducesRemovedLines() async {
        let old = "alpha\nbeta\ngamma"
        let new = "alpha\ngamma"
        let lines = UnifiedDiff.compute(old: old, new: new)

        #expect(lines.map(\.kind) == [.context, .removed, .context])
        #expect(lines[1].text == "beta")
    }

    @Test func replacementProducesRemovedThenAdded() async {
        let old = "alpha\nbeta"
        let new = "alpha\ngamma"
        let lines = UnifiedDiff.compute(old: old, new: new)

        #expect(lines.map(\.kind) == [.context, .removed, .added])
        #expect(lines[1].text == "beta")
        #expect(lines[2].text == "gamma")
    }

    @Test func summaryCountsAdditionsAndDeletions() async {
        let old = "alpha\nbeta\ngamma"
        let new = "alpha\nbeta-prime\ngamma\ndelta"
        let summary = UnifiedDiff.summary(old: old, new: new)

        #expect(summary.dels == 1)
        #expect(summary.adds == 2)
    }

    @Test func trailingNewlineDoesNotCreateBlankEntry() async {
        let old = "alpha\nbeta\n"
        let new = "alpha\nbeta\ngamma\n"
        let lines = UnifiedDiff.compute(old: old, new: new)

        #expect(lines.count == 3)
        #expect(lines.map(\.text) == ["alpha", "beta", "gamma"])
    }
}
