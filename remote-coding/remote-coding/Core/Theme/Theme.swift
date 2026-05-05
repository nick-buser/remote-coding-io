import SwiftUI

/// Single namespace for the design tokens.
///
/// Token values are sourced from the v2 design canvas
/// (`claude_design_references/.../ios-screens-zen.jsx`) and the design
/// system plan (`docs/feature_plans/10-design-system.md`). Each member
/// type is defined in its own file under `Core/Theme/`; this file is
/// only the shared namespace and a few cross-cutting conveniences.
enum Theme {
    typealias Accent = AccentColor
}

extension Theme {
    /// Resolve a 0–1 RGB triple plus opacity into a SwiftUI `Color`.
    ///
    /// Centralised so every other theme file uses the same constructor and
    /// stays inside the sRGB color space. SwiftUI defaults to sRGB anyway,
    /// but pinning it here avoids surprises if Apple ever changes that.
    static func srgb(
        _ red: Double,
        _ green: Double,
        _ blue: Double,
        opacity: Double = 1.0
    ) -> Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
