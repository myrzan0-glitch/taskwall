import SwiftUI
import UIKit

// Wallist's look: iOS 27, dark. Warm white type on a near-black ground,
// one peach marker for today and one red flag for priority. Liquid Glass stays on
// the control layer (the bottom bar, bar buttons, sheets); content is flat lists
// with dotted separators. The app always runs in dark mode (see TaskWallApp).

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// The screen behind everything.
    static let ground = Color(hex: 0x0C0C0D)
    /// Large sheets: Settings, Wallpaper, the tip jar.
    static let sheet = Color(hex: 0x151517)
    /// The selected day in the week strip and quiet pills.
    static let raised = Color(hex: 0x1C1C1E)
    /// Small filled controls inside sheets.
    static let control = Color(hex: 0x2A2A2D)
    /// Chips in the task composer.
    static let chip = Color(hex: 0x222225)
    /// Text and icons: a warm white.
    static let ink = Color(hex: 0xF4F2EE)
    /// Secondary text, 5.3:1 on the ground.
    static let muted = Color(hex: 0x8E8E93)
    /// Today, and the one accent.
    static let peach = Color(hex: 0xFFBE98)
    /// Priority and overdue.
    static let flag = Color(hex: 0xFF5F57)
    /// Dotted separators.
    static let separator = Color.white.opacity(0.2)
}

/// The switch from the design: 64 × 28 with a capsule knob, peach when on.
/// The system switch can't take a custom on-colour and knob, so this draws it
/// and still reads as a switch to VoiceOver.
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
                .fill(isOn ? AnyShapeStyle(Color.peach) : AnyShapeStyle(Color(red: 120 / 255, green: 120 / 255, blue: 128 / 255).opacity(0.32)))
                .frame(width: 64, height: 28)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(.white)
                        .frame(width: 38, height: 24)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                        .padding(2)
                }
                .animation(.snappy(duration: 0.2), value: isOn)
        }
        .opacity(isEnabled ? 1 : 0.4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEnabled else { return }
            Haptic.tap.play()
            configuration.isOn.toggle()
        }
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

extension View {
    /// The one main action on a screen: warm white glass with dark text, as a capsule.
    func prominentButton(_ haptic: Haptic = .tap) -> some View {
        hapticButtonStyle(.glassProminent, haptic)
            .buttonBorderShape(.capsule)
            .tint(Color.ink)
            .foregroundStyle(Color.ground)
    }

    /// `style`, plus a haptic each time the button fires: a light tap unless told otherwise.
    func hapticButtonStyle<S: PrimitiveButtonStyle>(_ style: S, _ haptic: Haptic? = .tap) -> some View {
        buttonStyle(HapticButtonStyle(base: style, haptic: haptic))
    }

    /// Regular Liquid Glass around a round or capsule control that floats over content.
    func glassControl<S: Shape>(in shape: S) -> some View {
        glassEffect(.regular.interactive(), in: shape)
    }
}

/// Sizes a sheet to its content, so it floats as a short glass card.
private struct FittedSheet: ViewModifier {
    let grabber: Bool
    @State private var height: CGFloat = 320

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .presentationDetents([.height(height)])
            .presentationDragIndicator(grabber ? .visible : .hidden)
    }
}

extension View {
    /// Sheets have no close button, so the grab bar shows they can be swiped away.
    func fittedSheet(grabber: Bool = true) -> some View {
        modifier(FittedSheet(grabber: grabber))
    }
}

/// The full-width call to action at the bottom of a screen (50 pt capsule).
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var isEnabled = true
    var haptic: Haptic = .tap
    let action: () -> Void

    init(_ title: LocalizedStringKey, isEnabled: Bool = true, haptic: Haptic = .tap, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.haptic = haptic
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .prominentButton(haptic)
        .controlSize(.large)
        .disabled(!isEnabled)
    }
}

/// A 34 pt capsule chip: the composer's Priority, date and time, and suggestions.
struct ChipLabel: View {
    let title: String
    var icon: String? = nil
    var iconColor: Color = .ink
    var selected = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(selected ? Color.ground : iconColor)
            }
            Text(title)
                .font(.footnote.weight(selected ? .semibold : .medium))
                .lineLimit(1)
        }
        .foregroundStyle(selected ? Color.ground : Color.ink)
        .padding(.leading, icon == nil ? 12 : 10)
        .padding(.trailing, 12)
        .frame(height: 34)
        .background(Capsule().fill(selected ? Color.ink : Color.chip))
        .overlay(Capsule().strokeBorder(selected ? Color.ink : Color.white.opacity(0.1), lineWidth: 1))
        .contentShape(Capsule())
    }
}

/// The dotted line between rows.
struct DottedDivider: View {
    var body: some View {
        Line()
            .stroke(Color.separator, style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [0.5, 4]))
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.midY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}

/// Lays chips out in rows and wraps them, like text.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Haptics

/// The feel of a press: a light tap for most buttons, the double tap of a success
/// for finishing something (ticking a task off, adding one).
enum Haptic {
    case tap, success

    @MainActor func play() {
        switch self {
        case .tap: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

/// Wraps any button style so the button plays a haptic as it fires, looking just as before.
struct HapticButtonStyle<Base: PrimitiveButtonStyle>: PrimitiveButtonStyle {
    let base: Base
    let haptic: Haptic?

    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role) {
            haptic?.play()
            configuration.trigger()
        } label: {
            configuration.label
        }
        .buttonStyle(base)
    }
}
