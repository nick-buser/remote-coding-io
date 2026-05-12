import SwiftUI
import Runestone

// MARK: - Theme preset

enum RunestoneTheme {
    /// Terminal buffer: mono 13pt, no line numbers, no soft-wrap, black bg.
    case terminalDark
    /// Document editor: UI font 14pt, soft-wrap on, no line numbers.
    case docLight
}

// MARK: - View

/// SwiftUI wrapper around Runestone's `TextView`. Exposes a minimal API used
/// by both the terminal buffer and the doc editor. Do not import Runestone
/// from view code — this is the sole touch point.
struct RunestoneTextSurface: UIViewRepresentable {
    var attributedText: AttributedString
    var isEditable: Bool = false
    var onCommit: ((String) -> Void)? = nil
    var onChange: ((String) -> Void)? = nil
    var theme: RunestoneTheme = .terminalDark

    func makeUIView(context: Context) -> TextView {
        let textView = TextView()
        applyTheme(to: textView)
        textView.isEditable = isEditable
        textView.isScrollEnabled = true
        textView.editorDelegate = context.coordinator
        return textView
    }

    func updateUIView(_ textView: TextView, context: Context) {
        // Runestone's content pipeline is plain-text with its own highlighter.
        // We feed the plain string extracted from the attributed string; ANSI
        // colour overlays will be layered on top once ANSIPaneTextRenderer lands.
        let plain = String(attributedText.characters)
        if textView.text != plain {
            textView.setState(TextViewState(text: plain))
        }
        if textView.isEditable != isEditable {
            textView.isEditable = isEditable
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCommit: onCommit, onChange: onChange)
    }

    // MARK: - Theme

    private func applyTheme(to textView: TextView) {
        switch theme {
        case .terminalDark:
            textView.backgroundColor = UIColor(Theme.Surface.terminalBg)
            textView.theme = RunestoneSurfaceTheme(
                font: .monospacedSystemFont(ofSize: 13, weight: .regular),
                textColor: UIColor(Theme.Text.fg(.dark))
            )
            textView.textContainerInset = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
            textView.showLineNumbers = false
            textView.isLineWrappingEnabled = false
        case .docLight:
            textView.backgroundColor = UIColor(Theme.Surface.bg(.light))
            textView.theme = RunestoneSurfaceTheme(
                font: .systemFont(ofSize: 14),
                textColor: UIColor(Theme.Text.fg(.light))
            )
            textView.textContainerInset = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
            textView.showLineNumbers = false
            textView.isLineWrappingEnabled = true
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, TextViewDelegate {
        var onCommit: ((String) -> Void)?
        var onChange: ((String) -> Void)?

        init(onCommit: ((String) -> Void)?, onChange: ((String) -> Void)?) {
            self.onCommit = onCommit
            self.onChange = onChange
        }

        func textViewDidReturn(_ textView: TextView) {
            onCommit?(textView.text)
        }

        func textViewDidChange(_ textView: TextView) {
            onChange?(textView.text)
        }
    }
}

// MARK: - Runestone theme adapter

/// Conforms to Runestone's `Theme` protocol while delegating most properties
/// to `DefaultTheme`. We only customize `font` and `textColor` for our
/// terminal/doc presets — the rest (gutter, page guide, marked text) keep
/// Runestone defaults since we don't render them.
final class RunestoneSurfaceTheme: Runestone.Theme {
    private let base = DefaultTheme()

    let font: UIFont
    let textColor: UIColor

    init(font: UIFont, textColor: UIColor) {
        self.font = font
        self.textColor = textColor
    }

    var gutterBackgroundColor: UIColor { base.gutterBackgroundColor }
    var gutterHairlineColor: UIColor { base.gutterHairlineColor }
    var lineNumberColor: UIColor { base.lineNumberColor }
    var lineNumberFont: UIFont { base.lineNumberFont }
    var selectedLineBackgroundColor: UIColor { base.selectedLineBackgroundColor }
    var selectedLinesLineNumberColor: UIColor { base.selectedLinesLineNumberColor }
    var selectedLinesGutterBackgroundColor: UIColor { base.selectedLinesGutterBackgroundColor }
    var invisibleCharactersColor: UIColor { base.invisibleCharactersColor }
    var pageGuideHairlineColor: UIColor { base.pageGuideHairlineColor }
    var pageGuideBackgroundColor: UIColor { base.pageGuideBackgroundColor }
    var markedTextBackgroundColor: UIColor { base.markedTextBackgroundColor }

    func textColor(for highlightName: String) -> UIColor? { base.textColor(for: highlightName) }
}

// MARK: - Previews

#Preview("RunestoneTextSurface — terminal dark") {
    let sample = AttributedString("$ ls -la\ntotal 48\ndrwxr-xr-x  12 user  staff   384 May  8 10:00 .\n-rw-r--r--   1 user  staff  2048 May  8 09:58 Package.swift")
    RunestoneTextSurface(attributedText: sample, isEditable: false, theme: .terminalDark)
        .ignoresSafeArea()
        .background(Color.black)
        .preferredColorScheme(.dark)
}

#Preview("RunestoneTextSurface — doc light") {
    let sample = AttributedString("# Feature PRD\n\nReal-time terminal streaming via WebSocket.\n\n## Goals\n\n- Low latency\n- Reconnect on drop")
    RunestoneTextSurface(attributedText: sample, isEditable: true, theme: .docLight)
        .ignoresSafeArea()
}
