import Foundation

/// Tiny unified-diff helper used by the Review screen.
///
/// Implements the classic LCS-via-DP table approach: O(n×m) time,
/// O(n×m) space. Adequate for PR-sized diffs (hundreds of lines per
/// file). For larger inputs swap to Myers later — the call site
/// only depends on the `Hunk` / `Line` shape returned here.
enum UnifiedDiff {
    enum Kind: Equatable, Sendable {
        case context
        case added
        case removed
    }

    struct Line: Equatable, Sendable, Identifiable {
        let id: Int
        var kind: Kind
        var text: String
    }

    /// Compute the line-by-line diff between `old` and `new`. Lines
    /// are split on `\n` (the trailing empty string from a final
    /// newline is dropped to avoid spurious blank entries).
    static func compute(old: String, new: String) -> [Line] {
        let oldLines = splitLines(old)
        let newLines = splitLines(new)
        let lcs = longestCommonSubsequence(oldLines, newLines)

        var lines: [Line] = []
        var idCounter = 0
        var i = 0  // index into oldLines
        var j = 0  // index into newLines
        var k = 0  // index into lcs

        while k < lcs.count {
            // Emit removed-only chunks: anything in old that doesn't
            // match the next LCS entry.
            while i < oldLines.count, oldLines[i] != lcs[k] {
                lines.append(.init(id: idCounter, kind: .removed, text: oldLines[i]))
                idCounter += 1
                i += 1
            }
            // Emit added-only chunks: anything in new that doesn't
            // match the next LCS entry.
            while j < newLines.count, newLines[j] != lcs[k] {
                lines.append(.init(id: idCounter, kind: .added, text: newLines[j]))
                idCounter += 1
                j += 1
            }
            // The LCS entry is a context line.
            if i < oldLines.count, j < newLines.count {
                lines.append(.init(id: idCounter, kind: .context, text: lcs[k]))
                idCounter += 1
                i += 1
                j += 1
            }
            k += 1
        }
        // Trailing tails after exhausting the LCS.
        while i < oldLines.count {
            lines.append(.init(id: idCounter, kind: .removed, text: oldLines[i]))
            idCounter += 1
            i += 1
        }
        while j < newLines.count {
            lines.append(.init(id: idCounter, kind: .added, text: newLines[j]))
            idCounter += 1
            j += 1
        }
        return lines
    }

    /// `(adds, dels)` summary for the file header pill.
    static func summary(old: String, new: String) -> (adds: Int, dels: Int) {
        let lines = compute(old: old, new: new)
        var adds = 0
        var dels = 0
        for line in lines {
            switch line.kind {
            case .added:   adds += 1
            case .removed: dels += 1
            case .context: break
            }
        }
        return (adds, dels)
    }

    // MARK: - Internals

    private static func splitLines(_ text: String) -> [String] {
        var parts = text.components(separatedBy: "\n")
        if parts.last == "" {
            parts.removeLast()
        }
        return parts
    }

    private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
        guard !a.isEmpty && !b.isEmpty else { return [] }
        // Classic LCS DP table.
        var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0..<a.count {
            for j in 0..<b.count {
                if a[i] == b[j] {
                    table[i + 1][j + 1] = table[i][j] + 1
                } else {
                    table[i + 1][j + 1] = max(table[i + 1][j], table[i][j + 1])
                }
            }
        }
        // Reconstruct.
        var result: [String] = []
        var i = a.count
        var j = b.count
        while i > 0 && j > 0 {
            if a[i - 1] == b[j - 1] {
                result.append(a[i - 1])
                i -= 1
                j -= 1
            } else if table[i - 1][j] >= table[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        return result.reversed()
    }
}
