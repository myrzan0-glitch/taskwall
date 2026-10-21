import SwiftUI

// TaskWall's black-and-white look. Applied once at the root (`.tint(.brand)`),
// so no control falls back to the system blue.

extension Color {
    /// Black in light mode, white in dark mode (`Resources/AccentColor`).
    /// Read by name so it works even if the build doesn't register a global accent.
    static let brand = Color("AccentColor")
    /// Text and icons drawn on top of `brand`: white in light mode, black in dark mode.
    /// Plain black and white, not `systemBackground`: inside a glass sheet that
    /// one renders see-through, which hid the switch knob on New Task.
    static let onBrand = Color(UIColor { $0.userInterfaceStyle == .dark ? .black : .white })
}

/// The system switch draws a white knob, which vanishes on the white dark-mode
/// accent. This one keeps the knob in the opposite colour of the track
/// (white on black, black on white) and still reads as a switch to VoiceOver.
struct BrandSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        BrandSwitch(configuration: configuration)
    }
}

private struct BrandSwitch: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let isOn = configuration.isOn
        HStack {
            configuration.label
            Spacer(minLength: 12)
            Capsule()
                .fill(isOn ? AnyShapeStyle(Color.brand) : AnyShapeStyle(.quaternary))
                .frame(width: 63, height: 28)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? Color.onBrand : Color.white)
                        .frame(width: 37, height: 24)
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        .padding(2)
                }
                .animation(.snappy(duration: 0.2), value: isOn)
        }
        .opacity(isEnabled ? 1 : 0.4)
        .contentShape(Rectangle())
        .onTapGesture { if isEnabled { configuration.isOn.toggle() } }
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

extension View {
    /// The filled call to action: black glass with white text, inverted in dark mode.
    func prominentButton() -> some View {
        buttonStyle(.glassProminent)
            .tint(.brand)
            .foregroundStyle(Color.onBrand)
    }

    /// A tab's list starts just under its large title, as in Wallet and Settings.
    /// Lists and forms otherwise keep a header-sized gap above the first section.
    func contentBelowLargeTitle() -> some View {
        contentMargins(.top, 8, for: .scrollContent)
    }
}
