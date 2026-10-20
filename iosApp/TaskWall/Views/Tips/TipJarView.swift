import SwiftUI
import Shared

/// "Keep TaskWall free": a full-screen tip jar in the style of the best paywalls,
/// without discounts, timers or pressure.
struct TipJarView: View {
    @Environment(TipStore.self) private var tips
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Tip = .flatWhite

    private let perks = ["Free for everyone, forever", "New themes and photo styles", "Fixes for every iOS update"]

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            hero

            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 250)
                    if case .thanked(let name) = tips.phase {
                        thanks(name)
                    } else {
                        picker
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                tips.phase = .idle
                dismiss()
            } label: {
                Image("cancel-01").renderingMode(.template).resizable()
                    .frame(width: 18, height: 18)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Close")
            .padding(.trailing, 16)
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    private var hero: some View {
        Image("CoffeeHero")
            .resizable()
            .scaledToFill()
            .grayscale(1)
            .frame(height: 400)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.35), location: 0),
                        .init(color: .black.opacity(0), location: 0.22),
                        .init(color: .black.opacity(0), location: 0.45),
                        .init(color: .black.opacity(0.75), location: 0.78),
                        .init(color: .black, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .ignoresSafeArea(edges: .top)
            .accessibilityHidden(true)
    }

    private var picker: some View {
        VStack(spacing: 0) {
            Text("FREE FOREVER")
                .font(.footnote.weight(.bold))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.72))
            Text("Keep TaskWall free")
                .font(.system(size: 34, weight: .heavy))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            Text("Made by one person. No ads, no tracking, no subscription. A coffee keeps it that way.")
                .font(.subheadline)
                .foregroundStyle(Color(white: 0.68))
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(perks, id: \.self) { perk in
                    Label {
                        Text(perk).font(.subheadline.weight(.medium))
                    } icon: {
                        Image("checkmark-circle-02").renderingMode(.template).resizable().frame(width: 20, height: 20)
                    }
                }
            }
            .padding(.top, 22)

            HStack(spacing: 10) {
                ForEach(Tip.entries, id: \.self) { tip in
                    tipCard(tip)
                }
            }
            .padding(.top, 28)

            Button {
                Task { await tips.purchase(selected) }
            } label: {
                Group {
                    if tips.phase == .purchasing {
                        ProgressView().tint(.black)
                    } else {
                        Text("Tip \(tips.price(for: selected) ?? "")")
                    }
                }
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
            .disabled(tips.phase == .purchasing || tips.price(for: selected) == nil)
            .padding(.top, 20)

            if case .failed(let reason) = tips.phase {
                Text(reason).font(.footnote).foregroundStyle(.red).padding(.top, 10)
            }

            Text("One-time tip through the App Store. It doesn't unlock anything.")
                .font(.caption)
                .foregroundStyle(Color(white: 0.56))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
        }
    }

    private func tipCard(_ tip: Tip) -> some View {
        let isSelected = tip == selected
        return Button {
            selected = tip
        } label: {
            VStack(spacing: 4) {
                Text(tip.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : Color(white: 0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(tips.price(for: tip) ?? "–")
                    .font(.title3.bold())
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? Color(white: 0.17) : Color(white: 0.11))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.14), lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .top) {
                if tip.isPopular {
                    Text("Most popular")
                        .font(.caption2.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.white))
                        .offset(y: -10)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tip.displayName), \(tips.price(for: tip) ?? "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func thanks(_ name: String) -> some View {
        VStack(spacing: 16) {
            Image("favourite").renderingMode(.template).resizable().frame(width: 44, height: 44)
            Text("Thank you").font(.system(size: 34, weight: .heavy))
            Text("Your \(name.lowercased()) keeps TaskWall free for everyone. It really means a lot.")
                .font(.subheadline)
                .foregroundStyle(Color(white: 0.68))
                .multilineTextAlignment(.center)
            Button {
                tips.phase = .idle
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
        }
        .padding(.top, 40)
    }
}
