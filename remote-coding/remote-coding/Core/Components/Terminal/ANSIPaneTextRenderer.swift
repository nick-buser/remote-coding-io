import Foundation
import SwiftUI

/// ANSI SGR color/style renderer — parses SGR escape sequences from raw pane
/// content and produces a styled `AttributedString`. Plugged in as the default
/// terminal renderer; `PlainPaneTextRenderer` is still available for tests and
/// injected through the same `PaneTextRenderer` boundary.
///
/// Strategy: walk the raw string once as Unicode scalars, collecting styled
/// runs, then assemble the `AttributedString` from runs. This avoids the
/// O(n²) copy overhead of repeated string slicing.
struct ANSIPaneTextRenderer: PaneTextRenderer {
    func render(_ raw: String) -> AttributedString {
        var result = AttributedString()
        var state = SGRState()
        let scalars = Array(raw.unicodeScalars)
        var i = 0
        var runStart = 0

        func flush(upTo end: Int) {
            guard end > runStart else { return }
            let text = String(scalars[runStart..<end])
            result += AttributedString(text, attributes: Self.makeAttributes(for: state))
            runStart = end
        }

        while i < scalars.count {
            let c = scalars[i]
            guard c == "\u{1B}", i + 1 < scalars.count else {
                i += 1
                continue
            }
            let next = scalars[i + 1]
            if next == "[" {
                // CSI sequence
                flush(upTo: i)
                i += 2
                var params = ""
                while i < scalars.count {
                    let v = scalars[i].value
                    if v >= 0x40 && v <= 0x7E {
                        if scalars[i] == "m" {
                            Self.applySGR(params: params, to: &state)
                        }
                        i += 1
                        break
                    }
                    params.unicodeScalars.append(scalars[i])
                    i += 1
                }
                runStart = i
            } else if next == "]" {
                // OSC — consume until BEL or ST
                flush(upTo: i)
                i += 2
                while i < scalars.count {
                    if scalars[i] == "\u{07}" { i += 1; break }
                    if scalars[i] == "\u{1B}", i + 1 < scalars.count, scalars[i + 1] == "\\" {
                        i += 2; break
                    }
                    i += 1
                }
                runStart = i
            } else {
                // Unknown escape — drop both bytes
                flush(upTo: i)
                i += 2
                runStart = i
            }
        }
        flush(upTo: scalars.count)
        return result
    }

    func append(_ chunk: String, to existing: AttributedString) -> AttributedString {
        existing + render(chunk)
    }

    // MARK: - SGR state

    private struct SGRState {
        var bold = false
        var dim = false
        var italic = false
        var underline = false
        var reverse = false
        var fg: Color?
        var bg: Color?
    }

    // MARK: - Attribute assembly

    private static func makeAttributes(for state: SGRState) -> AttributeContainer {
        var container = AttributeContainer()

        var font = Font.system(size: 13, design: .monospaced)
        if state.bold { font = font.bold() }
        if state.italic { font = font.italic() }
        container.font = font

        let baseFg = state.fg ?? Color(white: 0.85)
        let resolvedFg = state.dim ? baseFg.opacity(0.6) : baseFg

        if state.reverse {
            container.foregroundColor = state.bg ?? Color(white: 0.12)
            container.backgroundColor = resolvedFg
        } else {
            container.foregroundColor = resolvedFg
            if let bg = state.bg { container.backgroundColor = bg }
        }

        if state.underline {
            container.underlineStyle = Text.LineStyle(pattern: .solid)
        }

        return container
    }

    // MARK: - SGR parameter parsing

    private static func applySGR(params: String, to state: inout SGRState) {
        let codes: [Int]
        if params.isEmpty {
            codes = [0]
        } else {
            codes = params.split(separator: ";", omittingEmptySubsequences: false)
                .map { Int($0) ?? 0 }
        }
        var i = 0
        while i < codes.count {
            switch codes[i] {
            case 0:
                state = SGRState()
            case 1:
                state.bold = true
            case 2:
                state.dim = true
            case 3:
                state.italic = true
            case 4:
                state.underline = true
            case 7:
                state.reverse = true
            case 22:
                state.bold = false; state.dim = false
            case 23:
                state.italic = false
            case 24:
                state.underline = false
            case 27:
                state.reverse = false
            case 30...37:
                state.fg = ansi16[codes[i] - 30]
            case 38:
                if i + 2 < codes.count, codes[i + 1] == 5 {
                    state.fg = ansi256[clamp(codes[i + 2])]
                    i += 2
                } else if i + 4 < codes.count, codes[i + 1] == 2 {
                    state.fg = Color(red: Double(codes[i + 2]) / 255,
                                     green: Double(codes[i + 3]) / 255,
                                     blue: Double(codes[i + 4]) / 255)
                    i += 4
                }
            case 39:
                state.fg = nil
            case 40...47:
                state.bg = ansi16[codes[i] - 40]
            case 48:
                if i + 2 < codes.count, codes[i + 1] == 5 {
                    state.bg = ansi256[clamp(codes[i + 2])]
                    i += 2
                } else if i + 4 < codes.count, codes[i + 1] == 2 {
                    state.bg = Color(red: Double(codes[i + 2]) / 255,
                                     green: Double(codes[i + 3]) / 255,
                                     blue: Double(codes[i + 4]) / 255)
                    i += 4
                }
            case 49:
                state.bg = nil
            case 90...97:
                state.fg = ansi16[codes[i] - 82]  // 90-82 = 8..15
            case 100...107:
                state.bg = ansi16[codes[i] - 92]  // 100-92 = 8..15
            default:
                break
            }
            i += 1
        }
    }

    private static func clamp(_ n: Int) -> Int {
        min(max(n, 0), 255)
    }

    // MARK: - Color palettes

    // Perceptually balanced 16-color palette (macOS Terminal "Pro" style).
    // Avoids pure red/green; uses muted hues that read well on dark backgrounds.
    static let ansi16: [Color] = [
        // Standard 0–7
        Color(red: 0.000, green: 0.000, blue: 0.000), // 0  Black
        Color(red: 0.600, green: 0.000, blue: 0.000), // 1  Red
        Color(red: 0.000, green: 0.647, blue: 0.000), // 2  Green
        Color(red: 0.600, green: 0.600, blue: 0.000), // 3  Yellow
        Color(red: 0.000, green: 0.000, blue: 0.698), // 4  Blue
        Color(red: 0.698, green: 0.000, blue: 0.698), // 5  Magenta
        Color(red: 0.000, green: 0.647, blue: 0.698), // 6  Cyan
        Color(red: 0.749, green: 0.749, blue: 0.749), // 7  White
        // Bright 8–15
        Color(red: 0.400, green: 0.400, blue: 0.400), // 8  Bright black (gray)
        Color(red: 0.898, green: 0.000, blue: 0.000), // 9  Bright red
        Color(red: 0.000, green: 0.851, blue: 0.000), // 10 Bright green
        Color(red: 0.898, green: 0.898, blue: 0.000), // 11 Bright yellow
        Color(red: 0.000, green: 0.000, blue: 1.000), // 12 Bright blue
        Color(red: 0.898, green: 0.000, blue: 0.898), // 13 Bright magenta
        Color(red: 0.000, green: 0.898, blue: 0.898), // 14 Bright cyan
        Color(red: 0.898, green: 0.898, blue: 0.898), // 15 Bright white
    ]

    // Full 256-color table: 0–15 base colors, 16–231 6×6×6 RGB cube,
    // 232–255 24-step grayscale ramp.
    static let ansi256: [Color] = {
        var table = [Color](repeating: .clear, count: 256)
        for i in 0..<16 { table[i] = ansi16[i] }
        for i in 16...231 {
            let idx = i - 16
            func comp(_ level: Int) -> Double {
                level == 0 ? 0.0 : (55.0 + Double(level) * 40.0) / 255.0
            }
            table[i] = Color(red: comp(idx / 36), green: comp((idx % 36) / 6), blue: comp(idx % 6))
        }
        for i in 232...255 {
            let v = (8.0 + Double(i - 232) * 10.0) / 255.0
            table[i] = Color(white: v)
        }
        return table
    }()
}
