import SwiftUI
import Shared

/// Each story's colours and picture, matched by its id.
struct ReadLook {
    let background: Color
    let foreground: Color
    let secondary: Color
    let button: Color
    let buttonText: Color
    let art: Art

    enum Art { case sunrise, hourglass, fiveDeeds }

    static func of(_ read: Read) -> ReadLook {
        switch read.id {
        case "seneca-short-life":
            ReadLook(background: Color(hex: 0x1E47C8), foreground: Color(hex: 0xF4F2EE), secondary: Color(hex: 0xF4F2EE).opacity(0.66),
                     button: Color(hex: 0xF4F2EE), buttonText: Color(hex: 0x1E47C8), art: .hourglass)
        case "abai-five-things":
            ReadLook(background: Color(hex: 0x0F5257), foreground: Color(hex: 0xF1E7D0), secondary: Color(hex: 0xF1E7D0).opacity(0.66),
                     button: Color(hex: 0xF1E7D0), buttonText: Color(hex: 0x0F5257), art: .fiveDeeds)
        default:
            ReadLook(background: Color.peach, foreground: Color(hex: 0x1A1410), secondary: Color(hex: 0x1A1410).opacity(0.62),
                     button: Color(hex: 0x1A1410), buttonText: Color.peach, art: .sunrise)
        }
    }
}

/// The stories a person has liked, kept on this phone.
enum ReadLikes {
    static let key = "likedReads"

    static func contains(_ id: String, in stored: String) -> Bool {
        stored.split(separator: ",").contains { $0 == id }
    }

    static func toggled(_ id: String, in stored: String) -> String {
        var ids = stored.split(separator: ",").map(String.init)
        if let index = ids.firstIndex(of: id) { ids.remove(at: index) } else { ids.append(id) }
        return ids.joined(separator: ",")
    }
}

// MARK: - Card

/// One story in the feed under Today's tasks: its picture, Read, Like and Share.
struct ReadCard: View {
    let read: Read
    let open: () -> Void
    @AppStorage(ReadLikes.key) private var liked = ""

    var body: some View {
        let look = ReadLook.of(read)
        let isLiked = ReadLikes.contains(read.id, in: liked)
        VStack(alignment: .leading, spacing: 0) {
            Text("\(read.author.uppercased()) · \(read.minutes) MIN")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(look.secondary)
            Text(read.title)
                .font(.system(size: 31, weight: .heavy))
                .padding(.top, 12)
                .accessibilityAddTraits(.isHeader)
            Text(read.subtitle)
                .font(.system(size: 15))
                .foregroundStyle(look.secondary)
                .padding(.top, 10)

            ReadArt(art: look.art, color: look.foreground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 20)
                .accessibilityHidden(true)

            HStack(alignment: .bottom) {
                Button(action: open) {
                    Text("Read")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(look.buttonText)
                        .padding(.horizontal, 30)
                        .frame(height: 54)
                        .background(Capsule().fill(look.button))
                }
                .hapticButtonStyle(.plain)
                .accessibilityLabel("Read \(read.title)")
                .accessibilityIdentifier("readStory")
                Spacer()
                VStack(spacing: 6) {
                    Button {
                        liked = ReadLikes.toggled(read.id, in: liked)
                    } label: {
                        ReadIcon.heart.frame(width: 26, height: 26).frame(width: 44, height: 44)
                            .foregroundStyle(isLiked ? Color.flag : look.foreground)
                            .contentShape(Rectangle())
                    }
                    .hapticButtonStyle(.plain)
                    .accessibilityLabel(isLiked ? "Unlike" : "Like")
                    .accessibilityAddTraits(isLiked ? .isSelected : [])
                    ShareLink(item: read.shareText) {
                        ReadIcon.share(cutout: look.background).frame(width: 26, height: 26).frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .hapticButtonStyle(.plain)
                    .accessibilityLabel("Share")
                }
                .padding(.trailing, -6)
            }
        }
        .foregroundStyle(look.foreground)
        .padding(EdgeInsets(top: 26, leading: 28, bottom: 26, trailing: 22))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 38, style: .continuous).fill(look.background))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("readCard")
    }
}

// MARK: - Story

/// A story, full screen: its picture and title, then the text with the quote in Grace.
struct ReadArticleView: View {
    let read: Read
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let look = ReadLook.of(read)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    ReadArt(art: look.art, color: look.foreground)
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 18)
                        .accessibilityHidden(true)
                    Text("\(read.author.uppercased()) · \(read.minutes) MIN READ")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(look.secondary)
                    Text(read.title)
                        .font(.system(size: 34, weight: .heavy))
                        .padding(.top, 12)
                        .accessibilityAddTraits(.isHeader)
                    Text(read.subtitle)
                        .font(.system(size: 16))
                        .foregroundStyle(look.secondary)
                        .padding(.top, 10)
                }
                .foregroundStyle(look.foreground)
                .padding(EdgeInsets(top: 116, leading: 28, bottom: 30, trailing: 28))
                .background(
                    UnevenRoundedRectangle(bottomLeadingRadius: 34, bottomTrailingRadius: 34, style: .continuous)
                        .fill(look.background)
                        .ignoresSafeArea(edges: .top)
                )

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(read.opening, id: \.self) { paragraph($0) }
                    quote
                    ForEach(read.closing, id: \.self) { paragraph($0) }
                }
                .padding(EdgeInsets(top: 30, leading: 28, bottom: 72, trailing: 28))
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.ground.ignoresSafeArea())
        .foregroundStyle(Color.ink)
        .overlay(alignment: .top) {
            HStack {
                Button { dismiss() } label: {
                    Image("arrow-left-01")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 22, height: 22)
                        .frame(width: 48, height: 48)
                        .contentShape(Circle())
                }
                .hapticButtonStyle(.plain)
                .glassControl(in: Circle())
                .accessibilityLabel("Back")
                .accessibilityIdentifier("closeStory")
                Spacer()
                ShareLink(item: read.shareText) {
                    ReadIcon.share(cutout: Color(hex: 0x2C2C2E))
                        .frame(width: 22, height: 22)
                        .frame(width: 48, height: 48)
                        .contentShape(Circle())
                }
                .hapticButtonStyle(.plain)
                .glassControl(in: Circle())
                .accessibilityLabel("Share")
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 16)
        }
        .accessibilityIdentifier("readArticle")
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17))
            .lineSpacing(6)
            .foregroundStyle(Color(hex: 0xD8D6D2))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var quote: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let original = read.quoteOriginal {
                Text(original)
                    .font(.custom(WallpaperFonts.grace, fixedSize: 24))
                    .foregroundStyle(Color.ink)
            }
            Text("\u{201C}\(read.quote)\u{201D}")
                .font(.custom(WallpaperFonts.grace, fixedSize: 27))
                .foregroundStyle(Color.peach)
            Text(read.source.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.muted)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 6)
    }
}

// MARK: - Drawing

/// Filled icons drawn like the app's own: a heart, and a tray with an arrow out of it.
enum ReadIcon {
    static var heart: some View {
        Canvas { context, size in
            let u = size.width / 24
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * u, y: y * u) }
            var path = Path()
            path.move(to: p(12, 21))
            path.addCurve(to: p(10.9, 20.6), control1: p(11.6, 21), control2: p(11.2, 20.86))
            path.addCurve(to: p(2.5, 8.9), control1: p(7, 17.4), control2: p(2.5, 13.8))
            path.addCurve(to: p(7.6, 3.5), control1: p(2.5, 5.9), control2: p(4.8, 3.5))
            path.addCurve(to: p(12, 5.9), control1: p(9.4, 3.5), control2: p(10.9, 4.4))
            path.addCurve(to: p(16.4, 3.5), control1: p(13.1, 4.4), control2: p(14.6, 3.5))
            path.addCurve(to: p(21.5, 8.9), control1: p(19.2, 3.5), control2: p(21.5, 5.9))
            path.addCurve(to: p(13.1, 20.6), control1: p(21.5, 13.8), control2: p(17, 17.4))
            path.addCurve(to: p(12, 21), control1: p(12.8, 20.86), control2: p(12.4, 21))
            path.closeSubpath()
            context.fill(path, with: .foreground)
        }
    }

    /// `cutout` is the colour behind the icon, for the arrow where it crosses the tray.
    static func share(cutout: Color) -> some View {
        Canvas { context, size in
            let u = size.width / 24
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * u, y: y * u) }
            let line = StrokeStyle(lineWidth: 2.2 * u, lineCap: .round, lineJoin: .round)
            let tray = Path(roundedRect: CGRect(x: 3.5 * u, y: 9.5 * u, width: 17 * u, height: 12 * u), cornerRadius: 3.5 * u)
            context.fill(tray, with: .foreground)
            var above = Path()
            above.move(to: p(12, 2.8))
            above.addLine(to: p(12, 9.5))
            above.move(to: p(8.2, 6.3))
            above.addLine(to: p(12, 2.6))
            above.addLine(to: p(15.8, 6.3))
            context.stroke(above, with: .foreground, style: line)
            var inside = Path()
            inside.move(to: p(12, 9.5))
            inside.addLine(to: p(12, 14.5))
            context.stroke(inside, with: .color(cutout), style: line)
        }
    }
}

/// Each story's picture, drawn in its text colour on a 220 × 190 design.
struct ReadArt: View {
    let art: ReadLook.Art
    let color: Color

    var body: some View {
        Canvas { context, size in
            let s = min(size.width / 220, size.height / 190)
            context.translateBy(x: (size.width - 220 * s) / 2, y: (size.height - 190 * s) / 2)
            context.scaleBy(x: s, y: s)
            switch art {
            case .sunrise: sunrise(context)
            case .hourglass: hourglass(context)
            case .fiveDeeds: fiveDeeds(context)
            }
        }
    }

    private func stroke(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }

    private func sunrise(_ context: GraphicsContext) {
        var horizon = Path()
        horizon.move(to: CGPoint(x: 30, y: 150))
        horizon.addLine(to: CGPoint(x: 190, y: 150))
        context.stroke(horizon, with: .color(color), style: stroke(4))
        var sun = Path()
        sun.addArc(center: CGPoint(x: 110, y: 150), radius: 60, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        sun.closeSubpath()
        context.fill(sun, with: .color(color))
        var rays = Path()
        for (from, to) in [((110, 70), (110, 44)), ((66, 86), (48, 68)), ((154, 86), (172, 68)), ((38, 124), (14, 124)), ((182, 124), (206, 124))] {
            rays.move(to: CGPoint(x: from.0, y: from.1))
            rays.addLine(to: CGPoint(x: to.0, y: to.1))
        }
        context.stroke(rays, with: .color(color), style: stroke(5))
        var ground = Path()
        ground.move(to: CGPoint(x: 60, y: 168))
        ground.addLine(to: CGPoint(x: 160, y: 168))
        ground.move(to: CGPoint(x: 82, y: 182))
        ground.addLine(to: CGPoint(x: 138, y: 182))
        context.stroke(ground, with: .color(color.opacity(0.45)), style: stroke(4))
    }

    private func hourglass(_ context: GraphicsContext) {
        let sand = Color.peach
        var frame = Path()
        frame.move(to: CGPoint(x: 54, y: 6))
        frame.addLine(to: CGPoint(x: 166, y: 6))
        frame.move(to: CGPoint(x: 54, y: 184))
        frame.addLine(to: CGPoint(x: 166, y: 184))
        context.stroke(frame, with: .color(color), style: stroke(6))
        var glass = Path()
        glass.move(to: CGPoint(x: 66, y: 6))
        glass.addCurve(to: CGPoint(x: 110, y: 95), control1: CGPoint(x: 66, y: 50), control2: CGPoint(x: 110, y: 72))
        glass.addCurve(to: CGPoint(x: 66, y: 184), control1: CGPoint(x: 110, y: 118), control2: CGPoint(x: 66, y: 140))
        glass.move(to: CGPoint(x: 154, y: 6))
        glass.addCurve(to: CGPoint(x: 110, y: 95), control1: CGPoint(x: 154, y: 50), control2: CGPoint(x: 110, y: 72))
        glass.addCurve(to: CGPoint(x: 154, y: 184), control1: CGPoint(x: 110, y: 118), control2: CGPoint(x: 154, y: 140))
        context.stroke(glass, with: .color(color), style: stroke(5))
        var top = Path()
        top.move(to: CGPoint(x: 80, y: 38))
        top.addLine(to: CGPoint(x: 140, y: 38))
        top.addCurve(to: CGPoint(x: 110, y: 76), control1: CGPoint(x: 134, y: 58), control2: CGPoint(x: 116, y: 68))
        top.addCurve(to: CGPoint(x: 80, y: 38), control1: CGPoint(x: 104, y: 68), control2: CGPoint(x: 86, y: 58))
        context.fill(top, with: .color(sand))
        var stream = Path()
        stream.move(to: CGPoint(x: 110, y: 100))
        stream.addLine(to: CGPoint(x: 110, y: 150))
        context.stroke(stream, with: .color(sand), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 7]))
        var heap = Path()
        heap.move(to: CGPoint(x: 76, y: 178))
        heap.addCurve(to: CGPoint(x: 110, y: 150), control1: CGPoint(x: 82, y: 160), control2: CGPoint(x: 96, y: 152))
        heap.addCurve(to: CGPoint(x: 144, y: 178), control1: CGPoint(x: 124, y: 152), control2: CGPoint(x: 138, y: 160))
        heap.closeSubpath()
        context.fill(heap, with: .color(sand))
    }

    /// Abai's five precious deeds, filled, over the five enemies, left empty.
    private func fiveDeeds(_ context: GraphicsContext) {
        let gold = Color(hex: 0xF6C27A)
        for i in 0..<5 {
            let x = 22 + CGFloat(i) * 44
            context.fill(Path(ellipseIn: CGRect(x: x - 16, y: 50, width: 32, height: 32)), with: .color(gold))
            context.stroke(
                Path(ellipseIn: CGRect(x: x - 14, y: 118, width: 28, height: 28)),
                with: .color(color.opacity(0.45)),
                style: stroke(3)
            )
        }
    }
}
