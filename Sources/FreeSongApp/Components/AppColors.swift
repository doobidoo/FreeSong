import SwiftUI

// MARK: - Accent Color Support

/// Adds `.accent` as a ShapeStyle so `.foregroundStyle(.accent)` works
/// in SPM library targets that don't have an asset catalog.
extension ShapeStyle where Self == Color {
    /// The app's accent color, resolves to the system accent color.
    static var accent: Color { .accentColor }
}
