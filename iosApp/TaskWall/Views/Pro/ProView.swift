import SwiftUI
import Shared

/// The Wallist Pro paywall, laid out like the tip jar: what Pro adds, one plan
/// at a time, and a single button. Pro is the wallpaper fonts; tasks stay free.
struct ProView: View {
    @Environment(ProStore.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var selected: ProPlan = .yearly
    /// Called once Pro is active, so the font being tried can be kept.
    var onUnlocked: () -> Void = {}

    private let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacy = URL(string: "https://myrzan0-glitch.github.io/taskwall/privacy.html")!

    var body: some View {
        VStack(spacing: 0) {
            Text("Aa")
                .font(.custom("DotoRounded-Black", fixedSize: 46))
                .foregroundStyle(Color.ground)
                .frame(width: 96, height: 96)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(argb: WallpaperTheme.signal.palette.background)))
                .accessibilityHidden(true)
                .padding(.top, 40)

            HStack(spacing: 10) {
                Text("Wallist")
                Text("Pro")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.ground)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Capsule().fill(Color.peach))
            }
            .font(.system(size: 30, weight: .bold))
            .padding(.top, 22)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: 20) {
                Text("Matrix font")
                    .font(.custom("DotoRounded-Black", fixedSize: 34))
                Text("Orbit font")
                    .font(.custom("Michroma-Regular", fixedSize: 22))
                Text("New fonts as they land")
                    .font(.system(size: 26, weight: .semibold))
                Text("Tasks stay free")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.muted)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 36)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                Button(action: nextPlan) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(selected.displayName).font(.title3.weight(.semibold))
                                Image("arrow-right-01")
                                    .renderingMode(.template)
                                    .resizable()
                                    .frame(width: 12, height: 12)
                                    .foregroundStyle(Color.control)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Color.muted))
                            }
                            Text(selected.note)
                                .font(.subheadline)
                                .foregroundStyle(Color.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(pro.price(for: selected) ?? "–")
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 24)
                    .frame(minHeight: 84)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.control))
                    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .hapticButtonStyle(.plain)
                .accessibilityLabel("\(selected.displayName), \(pro.price(for: selected) ?? "")")
                .accessibilityHint("Tap for the other plan.")
                .accessibilityIdentifier("proPlan")

                Button {
                    Task {
                        if pro.price(for: selected) == nil {
                            if await pro.startWithoutProducts() {
                                unlocked()
                                return
                            }
                            guard pro.price(for: selected) != nil else { return }
                        }
                        if await pro.purchase(selected) { unlocked() }
                    }
                } label: {
                    Group {
                        if pro.phase == .purchasing {
                            ProgressView().tint(Color.ground)
                        } else {
                            Text("Start Pro")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .prominentButton()
                .controlSize(.large)
                .disabled(pro.phase == .purchasing)
                .accessibilityIdentifier("startPro")

                if pro.canTestUnlock {
                    Text("TestFlight: Start Pro unlocks Pro for free on this device.")
                        .font(.footnote)
                        .foregroundStyle(Color.peach)
                        .multilineTextAlignment(.center)
                }

                if case .failed(let reason) = pro.phase {
                    Text(reason).font(.footnote).foregroundStyle(Color.flag).multilineTextAlignment(.center)
                }

                Text("Renews automatically · Cancel anytime in Settings")
                    .font(.footnote)
                    .foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center)

                HStack(spacing: 18) {
                    Button("Restore") {
                        Task {
                            if await pro.restore() { unlocked() }
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
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
        .foregroundStyle(Color.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sheet.ignoresSafeArea())
        .tint(.ink)
        .presentationBackground(Color.sheet)
        .presentationDragIndicator(.visible)
        .onDisappear { if pro.phase != .purchasing { pro.phase = .idle } }
    }

    private func nextPlan() {
        selected = selected == .yearly ? .monthly : .yearly
    }

    private func unlocked() {
        onUnlocked()
        dismiss()
    }
}
