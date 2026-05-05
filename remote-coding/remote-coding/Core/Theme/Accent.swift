import Foundation
import SwiftUI

/// Five named accents from the v2 design. Each accent has a light- and
/// dark-mode variant in oklch; the variant exists to compensate contrast
/// against the screen background, not to express different states.
///
/// `slate` is intentionally neutral and uses the same oklch value in both
/// modes (per `docs/feature_plans/10-design-system.md`).
enum AccentColor: String, CaseIterable, Hashable, Codable, Sendable {
    case iris
    case amber
    case mint
    case rose
    case slate
}

extension AccentColor {
    /// Resolve this accent to a SwiftUI `Color` for the given scheme.
    /// Internally converts the design's oklch values through OKLab to
    /// linear sRGB, then gamma-encodes to non-linear sRGB.
    func value(for scheme: ColorScheme) -> Color {
        let triple = oklchTriple(for: scheme)
        let rgb = OKLCH.toSRGB(triple)
        return Theme.srgb(rgb.r, rgb.g, rgb.b)
    }

    /// The raw `(L, C, h)` triple this accent uses in the given scheme.
    /// Exposed for tests so the conversion path can be exercised
    /// independent of `Color` (which has no equality usable across
    /// `ColorScheme` values).
    func oklchTriple(for scheme: ColorScheme) -> OKLCH.Triple {
        switch (self, scheme) {
        case (.iris, .light):  return OKLCH.Triple(L: 0.58, C: 0.18, h: 280)
        case (.iris, .dark):   return OKLCH.Triple(L: 0.72, C: 0.16, h: 280)
        case (.amber, .light): return OKLCH.Triple(L: 0.65, C: 0.16, h: 60)
        case (.amber, .dark):  return OKLCH.Triple(L: 0.78, C: 0.15, h: 60)
        case (.mint, .light):  return OKLCH.Triple(L: 0.60, C: 0.13, h: 165)
        case (.mint, .dark):   return OKLCH.Triple(L: 0.74, C: 0.13, h: 165)
        case (.rose, .light):  return OKLCH.Triple(L: 0.60, C: 0.18, h: 15)
        case (.rose, .dark):   return OKLCH.Triple(L: 0.74, C: 0.17, h: 15)
        case (.slate, _):      return OKLCH.Triple(L: 0.58, C: 0.02, h: 260)
        @unknown default:      return OKLCH.Triple(L: 0.58, C: 0.18, h: 280)
        }
    }
}

/// oklch → sRGB conversion. Reference: Björn Ottosson, "A perceptual color
/// space for image processing" (2020). The matrices below are the published
/// OKLab ↔ linear sRGB coefficients; gamma encoding follows the IEC 61966-2-1
/// piecewise sRGB curve.
enum OKLCH {
    struct Triple: Equatable, Sendable {
        var L: Double
        var C: Double
        var h: Double
    }

    struct SRGB: Equatable, Sendable {
        var r: Double
        var g: Double
        var b: Double
    }

    static func toSRGB(_ triple: Triple) -> SRGB {
        let hRad = triple.h * .pi / 180.0
        let a = triple.C * cos(hRad)
        let b = triple.C * sin(hRad)

        let lPrime = triple.L + 0.3963377774 * a + 0.2158037573 * b
        let mPrime = triple.L - 0.1055613458 * a - 0.0638541728 * b
        let sPrime = triple.L - 0.0894841775 * a - 1.2914855480 * b

        let l = lPrime * lPrime * lPrime
        let m = mPrime * mPrime * mPrime
        let s = sPrime * sPrime * sPrime

        let rLin =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let gLin = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let bLin = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        return SRGB(
            r: gammaEncode(rLin),
            g: gammaEncode(gLin),
            b: gammaEncode(bLin)
        )
    }

    private static func gammaEncode(_ x: Double) -> Double {
        let clamped = max(0.0, min(1.0, x))
        if clamped <= 0.0031308 {
            return clamped * 12.92
        } else {
            return 1.055 * pow(clamped, 1.0 / 2.4) - 0.055
        }
    }
}

// MARK: - Environment

private struct AccentColorKey: EnvironmentKey {
    static let defaultValue: AccentColor = .iris
}

extension EnvironmentValues {
    /// Active accent for the current view subtree. The root coordinator
    /// sets this from the user's stored preference; per-screen contexts
    /// (project / feature) override it locally where the design calls
    /// for a scoped accent.
    var accent: AccentColor {
        get { self[AccentColorKey.self] }
        set { self[AccentColorKey.self] = newValue }
    }
}
