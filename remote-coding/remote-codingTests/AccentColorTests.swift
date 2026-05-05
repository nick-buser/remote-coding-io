import Foundation
import SwiftUI
import Testing
@testable import remote_coding

struct AccentColorTests {

    /// Every accent must produce a finite, in-gamut sRGB triple in both
    /// light and dark schemes. This catches regressions if the oklch
    /// matrices ever drift, or if a new accent gets added with values
    /// that fall outside `[0, 1]` after gamma encoding.
    @Test func everyAccentProducesValidSRGBInBothSchemes() {
        for accent in AccentColor.allCases {
            for scheme in [ColorScheme.light, .dark] {
                let triple = accent.oklchTriple(for: scheme)
                let rgb = OKLCH.toSRGB(triple)

                #expect(rgb.r.isFinite)
                #expect(rgb.g.isFinite)
                #expect(rgb.b.isFinite)
                #expect((0.0...1.0).contains(rgb.r))
                #expect((0.0...1.0).contains(rgb.g))
                #expect((0.0...1.0).contains(rgb.b))
            }
        }
    }

    /// Slate is intentionally neutral: same oklch in light and dark, so
    /// the resolved sRGB must match. This pins the
    /// `(.slate, _) → (L: 0.58, C: 0.02, h: 260)` case in `Accent.swift`.
    @Test func slateMatchesAcrossSchemes() {
        let light = OKLCH.toSRGB(AccentColor.slate.oklchTriple(for: .light))
        let dark = OKLCH.toSRGB(AccentColor.slate.oklchTriple(for: .dark))

        #expect(light == dark)
    }

    /// Iris light should land in the purple region. A loose sanity check
    /// that the matrix and gamma encode haven't been swapped or inverted
    /// — green should be the smallest channel for a purple accent.
    @Test func irisLightLandsInPurpleRegion() {
        let rgb = OKLCH.toSRGB(AccentColor.iris.oklchTriple(for: .light))

        #expect(rgb.g < rgb.r)
        #expect(rgb.g < rgb.b)
    }

    /// `value(for:)` must round-trip without crashing for every case in
    /// every scheme. This is the call the views actually make.
    @Test func valueForSchemeReturnsColorForEveryCase() {
        for accent in AccentColor.allCases {
            _ = accent.value(for: .light)
            _ = accent.value(for: .dark)
        }
    }
}
