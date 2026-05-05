import CoreGraphics

extension Theme {
    /// Radius scale from `docs/feature_plans/10-design-system.md`.
    /// `r1` is for the smallest pip; `r8` is the phone screen interior.
    enum Radius {
        static let r1: CGFloat = 6
        static let r2: CGFloat = 9
        static let r3: CGFloat = 12
        static let r4: CGFloat = 14
        static let r5: CGFloat = 18
        static let r6: CGFloat = 22
        static let r7: CGFloat = 26
        static let r8: CGFloat = 44
    }
}
