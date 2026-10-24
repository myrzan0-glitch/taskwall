import SwiftUI
import Shared

/// The Wallist Pro paywall, as a sheet from Wallpaper and Settings: what Pro adds,
/// the plans, and a single button. Pro is the wallpaper fonts; tasks stay free.
struct ProView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected: ProPlan = .yearly
    /// Called once Pro is active, so the font being tried can be kept.
    var onUnlocked: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProFontsTile(size: 72)
                    .padding(.top, 24)

                HStack(spacing: 10) {
                    Text("Wallist")
                    ProBadge()
                }
                .font(.system(size: 30, weight: .bold))
                .padding(.top, 18)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                VStack(spacing: 10) {
                    Text("Matrix font")
                        .font(.custom("DotoRounded-Black", fixedSize: 32))
                    Text("Orbit font")
                        .font(.custom("Michroma-Regular", fixedSize: 21))
                    Text("Grace font")
                        .font(.custom(WallpaperFonts.grace, fixedSize: 34))
                    Text("New fonts as they land. Tasks stay free.")
                        .font(.body)
                        .foregroundStyle(Color.muted)
                        .padding(.top, 4)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 22)
                .padding(.bottom, 16)
                .accessibilityElement(children: .combine)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaBar(edge: .bottom) {
            ProPurchase(selected: $selected) {
                onUnlocked()
                dismiss()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .foregroundStyle(Color.ink)
        .background(Color.sheet.ignoresSafeArea())
        .tint(.ink)
        .presentationBackground(Color.sheet)
        .presentationDragIndicator(.visible)
    }
}

/// The plans, the buy button, and the small print, shared by the sheet and onboarding.
struct ProPurchase: View {
    @Environment(ProStore.self) private var pro
    @Environment(\.openURL) private var openURL
    @Binding var selected: ProPlan
    /// Onboarding's way past the offer; the sheet is pulled down instead.
    var notNow: (() -> Void)? = nil
    let onUnlocked: () -> Void

    private let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacy = URL(string: "https://myrzan0-glitch.github.io/taskwall/privacy.html")!

    var body: some View {
        VStack(spacing: 12) {
            ProPlanList(selected: $selected)
                .padding(.top, 10)

            Button(action: buy) {
                Group {
                    if pro.phase == .purchasing {
                        ProgressView().tint(Color.ground)
                    } else {
                        Text(selected == .lifetime ? "Buy Lifetime" : "Start Pro")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .prominentButton()
            .controlSize(.large)
            .disabled(pro.phase == .purchasing)
            .accessibilityIdentifier("startPro")

            if let notNow {
                Button("Not now", action: notNow)
                    .font(.headline)
                    .hapticButtonStyle(.plain)
                    .frame(minHeight: 36)
                    .disabled(pro.phase == .purchasing)
                    .accessibilityIdentifier("notNow")
            }

            if pro.canTestUnlock {
                Text("TestFlight: Start Pro unlocks Pro for free on this device.")
                    .font(.footnote)
                    .foregroundStyle(Color.peach)
                    .multilineTextAlignment(.center)
            }

            if case .failed(let reason) = pro.phase {
                Text(reason).font(.footnote).foregroundStyle(Color.flag).multilineTextAlignment(.center)
            }

            Text(selected.isSubscription ? "Renews automatically · Cancel anytime in Settings" : "One payment · Yours to keep")
                .font(.footnote)
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)

            HStack(spacing: 18) {
                Button("Restore") {
                    Task {
                        if await pro.restore() { onUnlocked() }
                    }
                }
                .accessibilityIdentifier("restorePro")
                Button("Terms") { openURL(terms) }
                Button("Privacy") { openURL(privacy) }
            }
            .font(.footnote)
            .hapticButtonStyle(.plain)
            .foregroundStyle(Color.muted)
            .disabled(pro.phase == .purchasing)
        }
        .padding(.bottom, 8)
        .onAppear {
            if !pro.plans.contains(selected), let first = pro.plans.first { selected = first }
        }
        .onDisappear { if pro.phase != .purchasing { pro.phase = .idle } }
    }

    private func buy() {
        Task {
            if pro.price(for: selected) == nil {
                if await pro.startWithoutProducts() {
                    onUnlocked()
                    return
                }
                guard pro.price(for: selected) != nil else { return }
            }
            if await pro.purchase(selected) { onUnlocked() }
        }
    }
}

/// Yearly, Lifetime and Monthly as rows to choose from, the billed price on the right.
struct ProPlanList: View {
    @Environment(ProStore.self) private var pro
    @Binding var selected: ProPlan

    var body: some View {
        VStack(spacing: 6) {
            ForEach(pro.plans, id: \.self) { plan in
                Button { selected = plan } label: { row(plan) }
                    .hapticButtonStyle(.plain)
                    .accessibilityLabel("\(plan.displayName), \(pro.price(for: plan) ?? "")")
                    .accessibilityValue(pro.note(for: plan))
                    .accessibilityAddTraits(plan == selected ? .isSelected : [])
                    .accessibilityIdentifier("plan-\(plan.displayName.lowercased())")
            }
        }
    }

    private func row(_ plan: ProPlan) -> some View {
        let on = plan == selected
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return HStack(spacing: 14) {
            Circle()
                .strokeBorder(on ? Color.ink : Color.muted, lineWidth: 2)
                .overlay(Circle().fill(on ? Color.ink : .clear).padding(6))
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.displayName).font(.body.weight(.semibold))
                Text(pro.note(for: plan))
                    .font(.footnote)
                    .foregroundStyle(Color.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(pro.price(for: plan) ?? "–")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .frame(minHeight: 56)
        .background(shape.fill(Color.raised))
        .overlay(shape.strokeBorder(on ? Color.ink : Color.white.opacity(0.1), lineWidth: on ? 2 : 1))
        .overlay(alignment: .topTrailing) {
            if plan == .yearly {
                Text("Best value")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.ground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.peach))
                    .offset(y: -9)
                    .padding(.trailing, 16)
            }
        }
        .contentShape(shape)
    }
}

/// "Pro" in a peach capsule, after "Wallist".
struct ProBadge: View {
    var body: some View {
        Text("Pro")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.ground)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule().fill(Color.peach))
    }
}

/// The blinking "Aa" on Signal red, the Pro icon.
struct ProFontsTile: View {
    var size: CGFloat = 96

    var body: some View {
        ProFontsIcon(scale: size / 96)
            .foregroundStyle(Color.ground)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 28 * size / 96, style: .continuous)
                    .fill(Color(argb: WallpaperTheme.signal.palette.background))
            )
            .accessibilityHidden(true)
    }
}

/// "Aa" that blinks through each Pro font in turn, so the icon shows them all.
struct ProFontsIcon: View {
    /// 1 fills the paywall's 96-pt tile.
    var scale: CGFloat = 1
    @State private var index = 0
    @State private var visible = true

    private let fonts = WallpaperFont.entries.filter(\.isPro)

    var body: some View {
        Text("Aa")
            .font(sample(fonts[index]))
            .opacity(visible ? 1 : 0)
            .accessibilityHidden(true)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1.4))
                    withAnimation(.easeIn(duration: 0.12)) { visible = false }
                    try? await Task.sleep(for: .seconds(0.14))
                    index = (index + 1) % fonts.count
                    withAnimation(.easeOut(duration: 0.18)) { visible = true }
                }
            }
    }

    /// Each face at the size where its "Aa" looks the same height.
    private func sample(_ font: WallpaperFont) -> Font {
        if font == .orbit { return Font(WallpaperFont.orbit(size: 30 * scale)) }
        if font == .grace { return .custom(WallpaperFonts.grace, fixedSize: 60 * scale) }
        return .custom("DotoRounded-Black", fixedSize: 46 * scale)
    }
}
