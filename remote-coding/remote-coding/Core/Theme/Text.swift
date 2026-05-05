import SwiftUI

extension Theme {
    /// Three text levels matching the design's `fg` / `fg2` / `fg3`
    /// (primary / secondary / tertiary). Resolves through `ColorScheme`.
    enum Text {
        static func fg(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Theme.srgb(245/255, 245/255, 247/255)
                : Theme.srgb(10/255, 10/255, 9/255)
        }

        static func fg2(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Theme.srgb(235/255, 235/255, 245/255, opacity: 0.6)
                : Theme.srgb(60/255, 60/255, 67/255, opacity: 0.62)
        }

        static func fg3(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Theme.srgb(235/255, 235/255, 245/255, opacity: 0.28)
                : Theme.srgb(60/255, 60/255, 67/255, opacity: 0.32)
        }
    }
}
