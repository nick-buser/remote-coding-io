import SwiftUI

/// View modifiers matching the v2 type scale from
/// `docs/feature_plans/10-design-system.md`. Each modifier sets size,
/// weight, and tracking; line height stays at the system default unless
/// the design specifies otherwise.
///
/// Mono modifiers fall back to `.monospaced` design (SF Mono) by default;
/// JetBrains Mono can be embedded later as a drop-in upgrade without
/// changing call sites.
extension View {
    /// 34pt large title — Inbox, Projects, Roadmap, Sessions, You.
    func themeTitle() -> some View {
        font(.system(size: 34, weight: .bold))
            .tracking(-0.4)
    }

    /// 34pt project name in detail hero.
    func themeDisplayLarge() -> some View {
        font(.system(size: 34, weight: .semibold))
            .tracking(-0.5)
    }

    /// 28pt feature title in hero.
    func themeDisplayMedium() -> some View {
        font(.system(size: 28, weight: .semibold))
            .tracking(-0.4)
    }

    /// 16pt body text.
    func themeBody() -> some View {
        font(.system(size: 16, weight: .regular))
    }

    /// 13pt caption / list-row sub.
    func themeCaption() -> some View {
        font(.system(size: 13, weight: .regular))
    }

    /// Monospaced text at the given size, medium weight.
    func themeMono(_ size: CGFloat) -> some View {
        font(.system(size: size, weight: .medium, design: .monospaced))
    }

    /// 11pt monospaced — IDs, branch names, eyebrow labels.
    func themeMonoSm() -> some View {
        font(.system(size: 11, weight: .medium, design: .monospaced))
    }
}
