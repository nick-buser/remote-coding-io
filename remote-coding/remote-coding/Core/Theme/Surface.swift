import SwiftUI

extension Theme {
    /// Surface tokens — backgrounds, separators, chips, and the chrome
    /// surrounding the terminal. Every accessor takes an explicit
    /// `ColorScheme` so callers (notably the terminal) can opt out of the
    /// system appearance.
    enum Surface {
        static func bg(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Theme.srgb(0, 0, 0)
                : Theme.srgb(245/255, 245/255, 240/255)
        }

        static func card(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Theme.srgb(22/255, 22/255, 23/255)
                : Theme.srgb(1, 1, 1)
        }

        static func sep(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Theme.srgb(1, 1, 1, opacity: 0.07)
                : Theme.srgb(60/255, 60/255, 67/255, opacity: 0.10)
        }

        static func chip(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Theme.srgb(120/255, 120/255, 128/255, opacity: 0.22)
                : Theme.srgb(120/255, 120/255, 128/255, opacity: 0.12)
        }

        /// Tinted overlay for the tab bar background. Pair with a
        /// `.background(.regularMaterial)` layer to approximate the
        /// `backdrop-filter: blur(40px) saturate(180%)` effect from the
        /// design — SwiftUI does not expose a direct backdrop filter, so
        /// the tint sits on top of the system material.
        static func tabBg(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Theme.srgb(20/255, 20/255, 22/255, opacity: 0.78)
                : Theme.srgb(245/255, 245/255, 240/255, opacity: 0.86)
        }

        static func tabBd(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Theme.srgb(1, 1, 1, opacity: 0.08)
                : Theme.srgb(60/255, 60/255, 67/255, opacity: 0.14)
        }

        static func homeBar(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Theme.srgb(1, 1, 1, opacity: 0.55)
                : Theme.srgb(0, 0, 0, opacity: 0.4)
        }

        /// Terminal surfaces are always dark — the design ships a single
        /// dark variant. Exposed as constants rather than scheme-keyed
        /// functions to make the always-dark contract obvious at the call
        /// site.
        static let terminalBg = Theme.srgb(0, 0, 0)
        static let terminalChrome = Theme.srgb(28/255, 28/255, 30/255)
        static let terminalInput = Theme.srgb(44/255, 44/255, 46/255)
    }
}
