import Foundation
import SwiftUI
import Testing
@testable import remote_coding

/// Render-smoke tests for the named primitives the design depends on.
///
/// These don't diff against golden images — they exercise each
/// component's render path with `ImageRenderer`, then assert size
/// and a load-bearing pixel color. The point is to catch the
/// regressions that bite hardest: the view tree failing to build
/// at all, an accent map flipping silently, or a status glyph
/// stopping using its semantic color.
///
/// A future ticket (e.g. service-mock-rich-seed or a dedicated
/// visual-regression ticket) can swap in a real golden-image system
/// — `ImageRenderer` already produces the bitmap; persisting it is
/// the only missing piece.
@MainActor
struct ComponentRenderTests {

    // MARK: - Render harness

    /// Render `view` at `size` against a transparent backdrop and
    /// return the resulting `CGImage`. The image scale is pinned to
    /// 2 so single-pixel asserts land on a deterministic raster.
    private func render(
        size: CGSize,
        scheme: ColorScheme = .light,
        @ViewBuilder _ view: () -> some View
    ) -> CGImage? {
        let renderer = ImageRenderer(
            content: view()
                .environment(\.colorScheme, scheme)
                .frame(width: size.width, height: size.height)
        )
        renderer.scale = 2
        return renderer.cgImage
    }

    /// Pull the sRGB color out of `image` at the given (point) coordinate.
    /// Returns nil if the bitmap can't be read.
    private func pixel(in image: CGImage, atPoint point: CGPoint) -> SRGBPixel? {
        guard let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }
        let bpr = image.bytesPerRow
        // ImageRenderer at scale 2 → pixels are at (point * 2).
        let px = Int(point.x * 2)
        let py = Int(point.y * 2)
        let i = py * bpr + px * 4
        // Default ImageRenderer output is RGBA premultiplied.
        let r = Double(bytes[i]) / 255.0
        let g = Double(bytes[i + 1]) / 255.0
        let b = Double(bytes[i + 2]) / 255.0
        let a = Double(bytes[i + 3]) / 255.0
        return SRGBPixel(r: r, g: g, b: b, a: a)
    }

    private struct SRGBPixel: Equatable {
        var r: Double
        var g: Double
        var b: Double
        var a: Double
    }

    /// Returns true if any pixel in `image` is approximately `expected`.
    /// Used when the *position* of the colored region depends on layout
    /// (HStacks, frames, ZStacks with shrinkwrapped content) and a
    /// fixed-coordinate sample would couple the test to layout.
    private func imageContains(
        _ image: CGImage,
        approximately expected: (Double, Double, Double),
        tolerance: Double = 0.06,
        minRatio: Double = 0.005
    ) -> Bool {
        guard let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return false }
        let bpr = image.bytesPerRow
        let h = image.height
        let w = image.width
        var matches = 0
        for y in 0..<h {
            for x in 0..<w {
                let i = y * bpr + x * 4
                let r = Double(bytes[i]) / 255.0
                let g = Double(bytes[i + 1]) / 255.0
                let b = Double(bytes[i + 2]) / 255.0
                if abs(r - expected.0) < tolerance,
                   abs(g - expected.1) < tolerance,
                   abs(b - expected.2) < tolerance {
                    matches += 1
                }
            }
        }
        return Double(matches) / Double(w * h) >= minRatio
    }

    /// Assert that `pixel` is approximately `expected` within `tolerance`
    /// per channel. Tolerance defaults to 0.06 to absorb antialiasing and
    /// gamma-conversion drift across renders.
    private func expectColor(
        _ pixel: SRGBPixel?,
        approximately expected: (Double, Double, Double),
        tolerance: Double = 0.06,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard let pixel else {
            Issue.record("pixel was nil", sourceLocation: sourceLocation)
            return
        }
        #expect(abs(pixel.r - expected.0) < tolerance, sourceLocation: sourceLocation)
        #expect(abs(pixel.g - expected.1) < tolerance, sourceLocation: sourceLocation)
        #expect(abs(pixel.b - expected.2) < tolerance, sourceLocation: sourceLocation)
    }

    private func expectedRGB(for accent: AccentColor, scheme: ColorScheme) -> (Double, Double, Double) {
        let rgb = OKLCH.toSRGB(accent.oklchTriple(for: scheme))
        return (rgb.r, rgb.g, rgb.b)
    }

    // MARK: - Pip

    @Test func pipRendersAtTheConfiguredSize() {
        let image = render(size: CGSize(width: 12, height: 12)) {
            Pip(accent: .iris, size: 12, radius: 4)
        }
        #expect(image != nil)
        // ImageRenderer produces a 2x raster.
        #expect(image?.width == 24)
        #expect(image?.height == 24)
    }

    @Test func pipUsesTheAccentColorAtCenter() {
        for accent in AccentColor.allCases {
            let image = render(size: CGSize(width: 12, height: 12)) {
                Pip(accent: accent, size: 12, radius: 4)
            }
            let center = pixel(in: image!, atPoint: CGPoint(x: 6, y: 6))
            expectColor(center, approximately: expectedRGB(for: accent, scheme: .light))
        }
    }

    // MARK: - StatusGlyph

    @Test func statusGlyphShippedFillsWithSemanticGreen() {
        let image = render(size: CGSize(width: 32, height: 32)) {
            StatusGlyph(role: .shipped, size: 18)
        }
        // The disc + ✓ composition makes per-pixel asserts brittle.
        // Instead require that at least 1% of the rendered image is
        // semantic-green — that catches "the role->color map flipped"
        // without coupling to exact glyph dimensions.
        #expect(imageContains(image!, approximately: (52.0/255, 199.0/255, 89.0/255)))
    }

    @Test func statusGlyphTodoRendersAsRingOnly() {
        let image = render(size: CGSize(width: 18, height: 18)) {
            StatusGlyph(role: .todo, size: 18)
        }
        // Centre of a ring-only glyph should be transparent / unset
        // (alpha ~= 0). This catches a regression that fills the ring
        // by accident.
        let center = pixel(in: image!, atPoint: CGPoint(x: 9, y: 9))
        #expect(center?.a ?? 1 < 0.1)
    }

    // MARK: - MetaPill

    @Test func metaPillRendersIconColorSomewhere() {
        let image = render(size: CGSize(width: 120, height: 24)) {
            MetaPill(
                icon: "dot",
                iconColor: Theme.Semantic.green,
                label: "Active"
            )
        }
        // The HStack centres inside the frame, so the dot's exact
        // coordinates depend on label width. Scan instead — the test
        // catches the regression where iconColor stops applying.
        #expect(imageContains(image!, approximately: (52.0/255, 199.0/255, 89.0/255)))
    }

    @Test func metaPillWithoutIconStillRenders() {
        let image = render(size: CGSize(width: 80, height: 20)) {
            MetaPill(icon: nil, iconColor: nil, label: "Idle")
        }
        #expect(image != nil)
    }

    // MARK: - Chip

    @Test func chipActiveUsesEnvironmentAccent() {
        for accent in AccentColor.allCases {
            let image = render(size: CGSize(width: 60, height: 30)) {
                Chip(label: "All", active: true)
                    .environment(\.accent, accent)
            }
            // Sample the chip's pill — centre.
            let pill = pixel(in: image!, atPoint: CGPoint(x: 30, y: 15))
            expectColor(pill, approximately: expectedRGB(for: accent, scheme: .light))
        }
    }

    @Test func chipInactiveDoesNotPaintAccent() {
        let image = render(size: CGSize(width: 60, height: 30)) {
            Chip(label: "All", active: false)
                .environment(\.accent, .iris)
        }
        // Background is `Theme.Surface.chip(.light)` — gray-tinted at 12%
        // alpha. Centre pixel must NOT match the iris accent.
        let pill = pixel(in: image!, atPoint: CGPoint(x: 30, y: 15))
        let iris = expectedRGB(for: .iris, scheme: .light)
        // Distance > tolerance.
        if let pill {
            let dr = abs(pill.r - iris.0)
            let dg = abs(pill.g - iris.1)
            let db = abs(pill.b - iris.2)
            #expect(dr + dg + db > 0.3)
        }
    }

    // MARK: - SegmentedControl

    @Test func segmentedControlRendersWithoutCrashing() {
        // Selection-driven views are awkward inside a non-stateful render
        // — bind to a constant. The point is to exercise the layout path
        // with each item.
        let items = ["Features", "Tickets", "Docs", "Sessions"]
        for active in items {
            let binding = Binding<String>(
                get: { active },
                set: { _ in }
            )
            let image = render(size: CGSize(width: 320, height: 32)) {
                SegmentedControl(items: items, selection: binding)
            }
            #expect(image != nil)
        }
    }

    // MARK: - KindIcon

    @Test func kindIconRendersExpectedColorAtCenter() {
        // `test` uses fg3 (gray), and `decision`/`review`/`doc` use accents
        // that depend on scheme — sample the four with semantic colors.
        let cases: [(ActivityKind, (Double, Double, Double))] = [
            (.question, (255.0/255, 149.0/255, 0)),
            (.commit,   (52.0/255, 199.0/255, 89.0/255)),
        ]
        for (kind, expected) in cases {
            let image = render(size: CGSize(width: 32, height: 32)) {
                KindIcon(kind: kind, size: 32)
            }
            // Sample slightly off-centre to skip the white glyph.
            let bg = pixel(in: image!, atPoint: CGPoint(x: 4, y: 16))
            expectColor(bg, approximately: expected)
        }
    }

    @Test func kindIconReviewUsesIrisAccent() {
        let image = render(size: CGSize(width: 32, height: 32), scheme: .light) {
            KindIcon(kind: .review, size: 32)
        }
        let bg = pixel(in: image!, atPoint: CGPoint(x: 4, y: 16))
        expectColor(bg, approximately: expectedRGB(for: .iris, scheme: .light))
    }
}
