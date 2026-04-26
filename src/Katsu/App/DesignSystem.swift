import SwiftUI

/// Centralized design tokens. Prefer these over hand-picked colors so dark
/// mode and dynamic type stay correct.
enum DesignSystem {
    /// Katsu accent — a warm, food-app orange/amber. Defined in code so the
    /// asset catalog stays minimal until final branding lands (FND-006).
    static let accent = Color(red: 0.92, green: 0.45, blue: 0.20)
}
