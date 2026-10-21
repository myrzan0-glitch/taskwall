import SwiftUI
import Shared

/// The tip jar, laid out like a paywall that sells nothing: what stays free,
/// one tip size at a time, and a single button. No discounts, timers or pressure.
struct TipJarView: View {
    @Environment(TipStore.self) private var tips
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Tip = .flatWhite

    private let promises = ["No ads", "No account", "No tracking"]

    var body: some View {
        NavigationStack {
            Group {
                if case .thanked(let name) = tips.phase {
                    thanks(name)
                } else {
                    picker
                }
            }
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.sheet.ignoresSafeArea())
        }
        .tint(.ink)
        .presentationBackground(Color.sheet)
        // Closed by swiping down, so the thanks don't show again next time.
        .onDisappear { if tips.phase != .purchasing { tips.phase = .idle } }
    }

    private var picker: some View {
        VStack(spacing: 0) {
            Image("wallpaper")
                .renderingMode(.template)
                .resizable()
                .frame(width: 48, height: 48)
                .foregroundStyle(Color.peach)
                .frame(width: 96, height: 96)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.ground))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
                .accessibilityHidden(true)
                .padding(.top, 24)

            VStack(spacing: 22) {
                ForEach(promises, id: \.self) { Text($0) }
                HStack(spacing: 10) {
                    Text("Free forever")
                    Text("Tip jar")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.ground)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(Capsule().fill(Color.peach))
                }
                Text("Made by one person").foregroundStyle(Color.muted)
            }
            .font(.system(size: 30, weight: .semibold))
            .multilineTextAlignment(.center)
            .padding(.top, 48)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                Button(action: nextTip) {
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
                            Text(note(for: selected))
                                .font(.subheadline)
                                .foregroundStyle(Color.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(tips.price(for: selected) ?? "–")
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 24)
                    .frame(minHeight: 84)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.control))
                    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(selected.displayName), \(tips.price(for: selected) ?? "")")
                .accessibilityHint("Tap for another tip size.")
                .accessibilityIdentifier("tipSize")

                Button {
                    Task { await tips.purchase(selected) }
                } label: {
                    Group {
                        if tips.phase == .purchasing {
                            ProgressView().tint(Color.ground)
                        } else {
                            Text("Tip \(tips.price(for: selected) ?? "")")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .prominentButton()
                .controlSize(.large)
                .disabled(tips.phase == .purchasing || tips.price(for: selected) == nil)
                .accessibilityIdentifier("tipButton")

                if case .failed(let reason) = tips.phase {
                    Text(reason).font(.footnote).foregroundStyle(Color.flag).multilineTextAlignment(.center)
                }

                Text("One-time, through the App Store · Unlocks nothing")
                    .font(.footnote)
                    .foregroundStyle(Color.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
    }

    private func nextTip() {
        let all = Tip.entries
        guard let index = all.firstIndex(of: selected) else { return }
        selected = all[(index + 1) % all.count]
    }

    private func note(for tip: Tip) -> String {
        switch tip {
        case .espresso: "A small thank-you"
        case .flatWhite: "Keeps the updates coming"
        default: "You made my week"
        }
    }

    private func close() {
        tips.phase = .idle
        dismiss()
    }

    private func thanks(_ name: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image("coffee-02").renderingMode(.template).resizable().frame(width: 44, height: 44).foregroundStyle(Color.peach)
            Text("Thank you").font(.system(size: 34, weight: .bold))
            Text("Your \(name.lowercased()) keeps Task on Wallpaper free for everyone. It really means a lot.")
                .font(.subheadline)
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
            Spacer()
            PrimaryButton("Done", action: close)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
    }
}
