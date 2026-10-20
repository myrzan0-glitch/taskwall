import SwiftUI

// TaskWall's black-and-white look. Applied once at the root (`.tint(.brand)`),
// so no control falls back to the system blue.

extension Color {
    /// Black in light mode, white in dark mode (`Resources/AccentColor`).
    /// Read by name so it works even if the build doesn't register a global accent.
    static let brand = Color("AccentColor")
    /// Text and icons drawn on top of `brand`: white in light mode, black in dark mode.
    static let onBrand = Color(.systemBackground)
}

extension View {
    /// The filled call to action: black glass with white text, inverted in dark mode.
    func prominentButton() -> some View {
        buttonStyle(.glassProminent)
            .tint(.brand)
            .foregroundStyle(Color.onBrand)
    }
}
