import SwiftUI
import Shared

/// Wallist Pro: what it adds, Lifetime or Monthly, and one button.
/// Opens from Settings and from any Pro choice (a Pro theme, a photo,
/// the table layout, the progress bar). No timers, trials or pressure.
struct PaywallView: View {
    @Environment(ProStore.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @State private var selected: ProPlan = .lifetime

    private let perks = [
        "Any photo as your wallpaper",
        "All five colour themes",
        "Table layout and progress bar",
        "Every new Pro feature",
    ]
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyURL = URL(string: "https://myrzan0-glitch.github.io/taskwall/privacy.html")!

    var body: some View {
        NavigationStack {
            Group {
                if pro.phase == .unlocked {
                    unlocked
                } else {
                    picker
                }
            }
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.sheet.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: close) {
                        Image("cancel-01").renderingMode(.template)
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("closePaywall")
                }
            }
        }
        .tint(.ink)
        .presentationBackground(Color.sheet)
        .presentationDragIndicator(.visible)
        // Swiped away: don't show the thank-you or an old error next time.
        .onDisappear { if pro.phase != .purchasing { pro.phase = .idle } }
    }

    // MARK: Choosing

    private var picker: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image("wallpaper")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 42, height: 42)
                    .foregroundStyle(Color.peach)
                    .frame(width: 84, height: 84)
                    .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color.ground))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
                    .accessibilityHidden(true)

                HStack(spacing: 10) {
                    Text("Wallist")
                    ProBadge(size: .large)
                }
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.5)
                .padding(.top, 18)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Wallist Pro")
                .accessibilityAddTraits(.isHeader)

                Text("Tasks and your wallpaper stay free. Pro adds:")
                    .font(.subheadline)
                    .foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(perks, id: \.self) { perk in
                        HStack(spacing: 12) {
                            Image("checkmark-circle-02")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 22, height: 22)
                                .foregroundStyle(Color.peach)
                                .accessibilityHidden(true)
                            Text(perk).font(.body.weight(.medium))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 18)

                VStack(spacing: 10) {
                    planCard(.lifetime)
                    planCard(.monthly)
                }
                .padding(.top, 22)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaBar(edge: .bottom) { purchaseBar }
    }

    private func planCard(_ plan: ProPlan) -> some View {
        let on = plan == selected
        let current = plan == pro.plan
        return Button { selected = plan } label: {
            HStack(spacing: 14) {
                ZStack {
                    if on {
                        Circle().fill(Color.ink)
                        Circle().fill(Color.ground).frame(width: 10, height: 10)
                    } else {
                        Circle().strokeBorder(Color(hex: 0x5A5A5E), lineWidth: 1.5)
                    }
                }
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(plan.displayName).font(.headline)
                        if plan == .lifetime {
                            Text("Best value")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.ground)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.peach))
                        }
                    }
                    Text(current ? "Your current plan" : note(for: plan))
                        .font(.footnote)
                        .foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(pro.price(for: plan) ?? "–")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Text(plan == .lifetime ? "one time" : "per month")
                        .font(.footnote)
                        .foregroundStyle(Color.muted)
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 18)
            .frame(minHeight: 76)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(on ? Color.control : Color.raised))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(on ? Color.ink : Color.white.opacity(0.1), lineWidth: on ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(current)
        .opacity(current ? 0.5 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(plan == .lifetime ? "planLifetime" : "planMonthly")
    }

    private func note(for plan: ProPlan) -> String {
        plan == .lifetime ? "Pay once, keep it forever" : "Cancel anytime"
    }

    private var purchaseBar: some View {
        let price = pro.price(for: selected)
        return VStack(spacing: 10) {
            Button {
                Task { await pro.purchase(selected) }
            } label: {
                Group {
                    if pro.phase == .purchasing {
                        ProgressView().tint(Color.ground)
                    } else if selected == .lifetime {
                        Text("Get Lifetime for \(price ?? "")")
                    } else {
                        Text("Subscribe for \(price ?? "") a month")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .prominentButton()
            .controlSize(.large)
            .disabled(pro.phase == .purchasing || price == nil || selected == pro.plan)
            .accessibilityIdentifier("buyPro")

            if case .failed(let reason) = pro.phase {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(Color.flag)
                    .multilineTextAlignment(.center)
            }

            Text(legal(price))
                .font(.caption)
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Button("Restore Purchases") { Task { await pro.restore() } }
                    .accessibilityIdentifier("restorePurchases")
                Text("·").accessibilityHidden(true)
                Link("Terms", destination: termsURL)
                Text("·").accessibilityHidden(true)
                Link("Privacy", destination: privacyURL)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.muted)
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .disabled(pro.phase == .purchasing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    /// App Review asks for the price, the length and how to cancel next to the button.
    private func legal(_ price: String?) -> String {
        if selected == .lifetime {
            return "One-time purchase through the App Store. It stays yours on every device with the same Apple Account."
        }
        return "\(price ?? "The price") a month, renews automatically until you cancel. Cancel anytime in Settings › Apple Account › Subscriptions."
    }

    // MARK: Unlocked

    private var unlocked: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("checkmark-circle-02")
                .renderingMode(.template)
                .resizable()
                .frame(width: 56, height: 56)
                .foregroundStyle(Color.peach)
                .accessibilityHidden(true)
            Text("You're Pro")
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.5)
                .accessibilityAddTraits(.isHeader)
            Text(pro.plan == .lifetime
                 ? "Lifetime is yours. Photos, every theme and the table layout are unlocked, now and in every update."
                 : "Your subscription is on. Photos, every theme and the table layout are unlocked.")
                .font(.subheadline)
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
            Spacer()
            PrimaryButton("Done", action: close)
                .accessibilityIdentifier("proDone")
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
    }

    private func close() {
        pro.phase = .idle
        dismiss()
    }
}

/// The peach "Pro" capsule: on the paywall's title, and on Pro choices without Pro.
struct ProBadge: View {
    enum Size { case small, large }
    var size: Size = .small

    var body: some View {
        Text("Pro")
            .font(size == .large ? .headline.weight(.bold) : .caption2.weight(.bold))
            .tracking(0)
            .foregroundStyle(Color.ground)
            .padding(.horizontal, size == .large ? 12 : 6)
            .frame(height: size == .large ? 32 : 18)
            .background(Capsule().fill(Color.peach))
            .accessibilityLabel("Pro")
    }
}
