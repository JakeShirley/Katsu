import SwiftUI

/// Centralized design tokens for Katsu. Prefer these over hand-picked colors,
/// fonts, or magic numbers so dark mode, Dynamic Type, and accessibility
/// behavior stay correct across the app (see `AGENTS.md`).
///
/// Tokens are grouped by concern:
/// - `DesignSystem.Palette` — raw brand color references.
/// - `DesignSystem.Colors` — semantic role colors that adapt to color scheme.
/// - `DesignSystem.Spacing` — 4pt rhythm.
/// - `DesignSystem.Radius` — corner radii.
/// - `DesignSystem.HitTarget` — minimum tappable size (44pt baseline).
/// - `DesignSystem.Animation` — motion presets that respect Reduce Motion.
enum DesignSystem {
    // MARK: - Brand palette
    //
    // Katsu's identity color is a warm, food-app orange/amber pulled from the
    // app icon (≈ #EB7333). Keep these raw values in one place; views should
    // reach for `Colors` or the convenience accessors below instead.

    enum Palette {
        /// Primary Katsu orange (≈ #EB7333). Matches `Assets.xcassets/AccentColor`.
        static let katsuOrange = Color(red: 0.922, green: 0.451, blue: 0.200)
        /// Slightly deeper variant for pressed / emphasis states.
        static let katsuOrangeDeep = Color(red: 0.804, green: 0.361, blue: 0.149)
        /// Soft, low-chroma orange for tinted surfaces (e.g. badge backgrounds).
        static let katsuOrangeSoft = Color(red: 0.984, green: 0.890, blue: 0.808)
        /// Companion warm-cream for hero surfaces.
        static let katsuCream = Color(red: 0.988, green: 0.957, blue: 0.910)
    }

    // MARK: - Semantic colors
    //
    // Wrap system colors so we get automatic light/dark adaptation and high-
    // contrast support for free. Avoid `Color(red:green:blue:)` in views.

    enum Colors {
        /// Brand accent. Matches the asset catalog `AccentColor` and is what
        /// `KatsuApp` applies via `.tint(...)`.
        static let accent = Palette.katsuOrange
        /// Pressed / emphasized accent.
        static let accentDeep = Palette.katsuOrangeDeep
        /// Tinted accent surface for chips, badges, and selection backgrounds.
        static let accentSoft = Palette.katsuOrangeSoft

        /// Primary text — adapts to color scheme.
        static let textPrimary = Color.primary
        /// Secondary / supporting text.
        static let textSecondary = Color.secondary

        /// Default screen background (matches grouped table backgrounds).
        static let background = Color(.systemGroupedBackground)
        /// Card / row surface that sits on top of `background`.
        static let surface = Color(.secondarySystemGroupedBackground)
        /// Hairline separator color.
        static let separator = Color(.separator)

        /// Destructive / error actions and copy.
        static let destructive = Color(.systemRed)
        /// Success state (e.g. shopping list checked).
        static let success = Color(.systemGreen)
        /// Warning state (e.g. token expiring soon).
        static let warning = Color(.systemOrange)
    }

    // MARK: - Spacing
    //
    // Use a 4pt rhythm. Stick to these constants instead of literal `8`,
    // `12`, etc. so layouts stay consistent and easy to tune globally.

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner radii

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 16
        static let pill: CGFloat = 999
    }

    // MARK: - Hit targets
    //
    // Apple's HIG (and our accessibility baseline in AGENTS.md) require any
    // interactive control to be at least 44x44pt.

    enum HitTarget {
        static let minimum: CGFloat = 44
    }

    // MARK: - Motion
    //
    // Views should still gate spring/parallax animations on
    // `@Environment(\.accessibilityReduceMotion)` per the FND-007 baseline.
    // These presets are the defaults to use when motion is allowed.

    enum Motion {
        static let standard: Animation = .easeInOut(duration: 0.2)
        static let emphasized: Animation = .spring(response: 0.45, dampingFraction: 0.85)
    }

    // MARK: - Convenience back-compat
    //
    // Older call sites use `DesignSystem.accent` directly. Keep that working
    // so we don't have to churn views in this changeset.
    static let accent = Colors.accent
}
