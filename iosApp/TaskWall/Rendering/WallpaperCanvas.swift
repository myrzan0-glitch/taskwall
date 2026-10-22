import SwiftUI
import Shared

/// Draws the TaskWall wallpaper. The same view is used for previews and, via
/// `WallpaperRenderer`, for the image the shortcut sets as the Lock Screen.
/// Measurements follow the 390-pt-wide design and scale with the canvas.
struct WallpaperCanvas: View {
    static let space = "wallpaper"

    let content: WallpaperContent
    let style: WallpaperStyle
    let appearance: ResolvedAppearance
    let photo: UIImage?
    /// Previews only: draws iOS's own clock and buttons. Never part of the image.
    var showsSystemUI = false

    private var palette: WallpaperPalette { appearance.palette }
    private var typeface: WallpaperFont { style.font }
    private var isGlass: Bool { appearance.isPhoto && appearance.backdrop == Backdrop.glass && photo != nil }
    private var isShade: Bool { appearance.isPhoto && appearance.backdrop == Backdrop.shade }
    private var textShadow: Color {
        guard appearance.isPhoto, !isGlass else { return .clear }
        return appearance.tone == TextTone.light ? .black.opacity(0.45) : .white.opacity(0.35)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let s = size.width / 390
            ZStack(alignment: .topLeading) {
                Color(argb: palette.background)
                if appearance.isPhoto, let photo {
                    PhotoLayer(photo: photo, style: style, size: size)
                }
                if isShade {
                    shadeBand(size: size)
                }
                if showsSystemUI {
                    SystemClock(color: Color(argb: palette.foreground), shadow: textShadow, s: s)
                        .frame(width: size.width)
                        .offset(y: 70 * s)
                }
                taskBlock(size: size, s: s)
                if showsSystemUI {
                    SystemControls(color: Color(argb: palette.foreground), s: s)
                        .frame(width: size.width, height: size.height, alignment: .bottom)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .coordinateSpace(.named(Self.space))
            .clipped()
        }
    }

    // MARK: Layers

    private func shadeBand(size: CGSize) -> some View {
        let belowClock = style.position == TaskPosition.belowClock
        let top = size.height * (belowClock ? 226 : 400) / 844
        let height = size.height * (belowClock ? 440 : 444) / 844
        let shade = Color(argb: palette.shade)
        return LinearGradient(
            stops: [
                .init(color: shade.opacity(0), location: 0),
                .init(color: shade, location: 0.16),
                .init(color: shade, location: 0.84),
                .init(color: shade.opacity(0), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: size.width, height: height)
        .offset(y: top)
    }

    private func taskBlock(size: CGSize, s: CGFloat) -> some View {
        let belowClock = style.position == TaskPosition.belowClock
        return VStack(spacing: 0) {
            if !belowClock { Spacer(minLength: 0) }
            panel(size: size, s: s)
            if belowClock { Spacer(minLength: 0) }
        }
        .padding(.horizontal, 24 * s)
        .padding(.top, belowClock ? size.height * CGFloat(WallpaperGeometry.shared.TASKS_TOP) : 0)
        .padding(.bottom, belowClock ? 0 : 116 * s)
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    private func panel(size: CGSize, s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14 * s) {
            header(s: s)
            if style.layout == WallpaperLayout.table {
                table(s: s)
            } else {
                list(s: s)
            }
            if content.hiddenCount > 0 {
                Text("+\(content.hiddenCount) more")
                    .font(typeface.font(.more, s: s))
                    .tracking(typeface.tracking(.more, s: s))
                    .foregroundStyle(Color(argb: palette.muted))
            }
        }
        // Text without a colour of its own takes the wallpaper's, never the system's:
        // the rendered image draws in light mode, where that would be black.
        .foregroundStyle(Color(argb: palette.foreground))
        .padding(isGlass ? EdgeInsets(top: 18 * s, leading: 18 * s, bottom: 20 * s, trailing: 18 * s) : EdgeInsets())
        .background {
            if isGlass, let photo {
                FrostedBackdrop(
                    photo: photo,
                    style: style,
                    canvas: size,
                    tint: Color(argb: palette.panelTint),
                    radius: 30 * s,
                    blur: 22 * s
                )
            }
        }
        .shadow(color: textShadow, radius: 1.5 * s, x: 0, y: 1 * s)
    }

    @ViewBuilder
    private func header(s: CGFloat) -> some View {
        if typeface == .matrix {
            matrixHeader(s: s)
        } else if typeface == .orbit {
            orbitHeader(s: s)
        } else {
            standardHeader(s: s)
        }
    }

    /// "01", "02" … "10": Orbit counts like an instrument readout.
    static func twoDigits(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }

    /// Orbit's accent: peach on dark backgrounds, the text colour on light ones.
    private var orbitAccent: Color {
        appearance.tone == TextTone.light ? Color.peach : Color(argb: palette.foreground)
    }

    /// Orbit, an instrument panel: spaced capitals, then progress as a hairline
    /// with a dot where it ends.
    private func orbitHeader(s: CGFloat) -> some View {
        let done = "\(Self.twoDigits(Int(content.doneCount))) / \(Self.twoDigits(Int(content.totalCount))) DONE"
        return VStack(alignment: .leading, spacing: 10 * s) {
            HStack(alignment: .firstTextBaseline) {
                Text(content.heading.uppercased())
                    .tracking(typeface.tracking(.heading, s: s))
                Spacer()
                Text(done)
                    .tracking(1.32 * s)
                    .accessibilityLabel(content.progressLabel)
            }
            .font(typeface.font(.heading, s: s))
            .foregroundStyle(Color(argb: palette.muted))
            if style.showProgress {
                GeometryReader { g in
                    let end = g.size.width * CGFloat(content.progress)
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color(argb: palette.line)).frame(height: 2 * s)
                        Rectangle().fill(orbitAccent).frame(width: end, height: 2 * s)
                        Circle().fill(orbitAccent)
                            .frame(width: 8 * s, height: 8 * s)
                            .offset(x: end - 4 * s)
                    }
                    .frame(height: 8 * s)
                }
                .frame(height: 8 * s)
                .accessibilityHidden(true)
            }
        }
    }

    /// Matrix, after a dot-matrix watch face: the day on the left, a big
    /// done/total count on the right, and progress as a row of dots.
    private func matrixHeader(s: CGFloat) -> some View {
        let muted = Color(argb: palette.muted)
        return VStack(alignment: .leading, spacing: 16 * s) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2 * s) {
                    Text(content.heading.uppercased())
                        .tracking(typeface.tracking(.heading, s: s))
                    Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day()).uppercased())
                        .foregroundStyle(muted)
                }
                .font(typeface.font(.heading, s: s))
                Spacer(minLength: 8 * s)
                HStack(alignment: .firstTextBaseline, spacing: 4 * s) {
                    Text("\(content.doneCount)")
                        .font(.custom("DotoRounded-Black", fixedSize: 64 * s))
                    Text("/\(content.totalCount)")
                        .font(.custom("DotoRounded-Black", fixedSize: 22 * s))
                        .foregroundStyle(muted)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(content.progressLabel)
            }
            if style.showProgress {
                let dots = 25
                let filled = Int((content.progress * Double(dots)).rounded())
                HStack(spacing: 4 * s) {
                    ForEach(0..<dots, id: \.self) { i in
                        Circle()
                            .fill(Color(argb: i < filled ? palette.foreground : palette.line))
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityHidden(true)
            }
        }
    }

    private func standardHeader(s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8 * s) {
            HStack(alignment: .firstTextBaseline) {
                Text(content.heading.uppercased())
                    .font(typeface.font(.heading, s: s))
                    .tracking(typeface.tracking(.heading, s: s))
                Spacer()
                Text(typeface == .orbit ? content.progressLabel.uppercased() : content.progressLabel)
                    .font(typeface.font(.heading, s: s))
                    .tracking(typeface.tracking(.heading, s: s))
            }
            .foregroundStyle(Color(argb: palette.muted))
            if style.showProgress {
                Capsule()
                    .fill(Color(argb: palette.line))
                    .overlay(alignment: .leading) {
                        GeometryReader { g in
                            Capsule()
                                .fill(Color(argb: palette.foreground))
                                .frame(width: g.size.width * CGFloat(content.progress))
                        }
                    }
                    .frame(height: 4 * s)
            }
        }
    }

    @ViewBuilder
    private func list(s: CGFloat) -> some View {
        if typeface == .orbit {
            orbitList(s: s)
        } else {
            standardList(s: s)
        }
    }

    /// Orbit's rows: a two-digit number instead of a circle, hairlines between
    /// rows, and the due time in spaced capitals (red when overdue).
    private func orbitList(s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(content.lines.enumerated()), id: \.element.id) { index, line in
                HStack(alignment: .top, spacing: 14 * s) {
                    Text(Self.twoDigits(index + 1))
                        .font(.custom("Michroma-Regular", fixedSize: 10 * s))
                        .tracking(1 * s)
                        .foregroundStyle(Color(argb: palette.muted).opacity(line.isDone ? 0.55 : 1))
                        .frame(width: 22 * s, alignment: .leading)
                        .padding(.top, 4 * s)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5 * s) {
                        Text(line.title)
                            .font(typeface.font(.title, s: s))
                            .foregroundStyle(Color(argb: line.isDone ? palette.muted : palette.foreground))
                            .strikethrough(line.isDone, color: Color(argb: palette.muted))
                            .lineLimit(2)
                        if let detail = line.detail, !line.isDone {
                            Text(detail.uppercased().replacingOccurrences(of: ", ", with: " · "))
                                .font(typeface.font(.detail, s: s))
                                .tracking(typeface.tracking(.detail, s: s))
                                .foregroundStyle(Color(argb: line.isOverdue ? palette.flag : palette.muted))
                        }
                    }
                    Spacer(minLength: 0)
                    if line.isFlagged && !line.isDone {
                        priorityFlag(size: 16 * s)
                            .padding(.top, 2 * s)
                    }
                }
                .padding(.vertical, 13 * s)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color(argb: palette.line)).frame(height: 1)
                }
            }
        }
    }

    private func standardList(s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: (typeface == .matrix ? 12 : 15) * s) {
            ForEach(content.lines, id: \.id) { line in
                HStack(alignment: .top, spacing: 12 * s) {
                    checkMark(done: line.isDone, s: s)
                        .padding(.top, 2 * s)
                    VStack(alignment: .leading, spacing: 1 * s) {
                        Text(line.title)
                            .font(typeface.font(.title, s: s))
                            .foregroundStyle(Color(argb: line.isDone ? palette.muted : palette.foreground))
                            .strikethrough(line.isDone, color: Color(argb: palette.muted))
                            .lineLimit(2)
                        if let detail = line.detail {
                            Text(detail)
                                .font(typeface.font(.detail, s: s))
                                .tracking(typeface.tracking(.detail, s: s))
                                .foregroundStyle(Color(argb: palette.muted))
                        }
                    }
                    Spacer(minLength: 0)
                    if line.isFlagged && !line.isDone {
                        priorityFlag(size: 18 * s)
                            .padding(.top, 3 * s)
                    }
                }
            }
        }
    }

    private func table(s: CGFloat) -> some View {
        let line = Color(argb: palette.line)
        return VStack(spacing: 0) {
            HStack {
                Text("TASK")
                Spacer()
                Text("DUE")
            }
            .font(typeface.font(.tableHeading, s: s))
            .tracking(typeface.tracking(.tableHeading, s: s))
            .foregroundStyle(Color(argb: palette.muted))
            .padding(.bottom, 8 * s)
            line.frame(height: 1)
            ForEach(content.lines, id: \.id) { row in
                HStack(spacing: 8 * s) {
                    Circle()
                        .strokeBorder(Color(argb: row.isDone ? palette.muted : palette.foreground), lineWidth: 1.5 * s)
                        .background(Circle().fill(row.isDone ? Color(argb: palette.muted) : .clear))
                        .frame(width: 9 * s, height: 9 * s)
                    Text(row.title)
                        .font(typeface.font(.tableTitle, s: s))
                        .foregroundStyle(Color(argb: row.isDone ? palette.muted : palette.foreground))
                        .strikethrough(row.isDone, color: Color(argb: palette.muted))
                        .lineLimit(1)
                    if row.isFlagged && !row.isDone {
                        priorityFlag(size: 14 * s)
                    }
                    Spacer(minLength: 8 * s)
                    Text(row.isOverdue ? "Overdue" : (row.detail ?? "Today"))
                        .font(typeface.font(.tableDetail, s: s))
                        .tracking(typeface.tracking(.tableDetail, s: s))
                        .foregroundStyle(Color(argb: palette.muted))
                }
                .padding(.vertical, 12 * s)
                line.frame(height: 1)
            }
        }
    }

    /// The Priority flag, drawn in the typeface's style: Classic uses the app's own
    /// flag, Matrix builds it from dots and Orbit draws it as a line pennant.
    private func priorityFlag(size: CGFloat) -> some View {
        PriorityFlag(typeface: typeface, color: Color(argb: palette.flag))
            .frame(width: size, height: size)
            .accessibilityLabel("Priority")
    }

    @ViewBuilder
    private func checkMark(done: Bool, s: CGFloat) -> some View {
        if done {
            Circle()
                .fill(Color(argb: palette.muted))
                .overlay {
                    Image("tick-02")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 14 * s, height: 14 * s)
                        .foregroundStyle(Color(argb: appearance.isPhoto ? palette.onForeground : palette.background))
                }
                .frame(width: 21 * s, height: 21 * s)
        } else if typeface == .matrix {
            // A ring of dots, to match the type.
            Circle()
                .strokeBorder(
                    Color(argb: palette.foreground),
                    style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round, dash: [0, 4.2 * s])
                )
                .frame(width: 21 * s, height: 21 * s)
        } else {
            Circle()
                .strokeBorder(Color(argb: palette.foreground), lineWidth: 2 * s)
                .frame(width: 21 * s, height: 21 * s)
        }
    }
}

/// The Priority flag in each typeface's style, filling its frame.
struct PriorityFlag: View {
    let typeface: WallpaperFont
    let color: Color

    /// Matrix's flag on a dot grid: a swallowtail cloth on a pole.
    static let matrixDots = [
        "111111",
        "111110",
        "111110",
        "111111",
        "100000",
        "100000",
        "100000",
        "100000",
    ]

    var body: some View {
        if typeface == .matrix {
            Canvas { context, size in
                let rows = Self.matrixDots
                let pitch = size.height / CGFloat(rows.count)
                let dot = pitch * 0.82
                let left = (size.width - pitch * CGFloat(rows[0].count)) / 2
                for (r, row) in rows.enumerated() {
                    for (c, cell) in row.enumerated() where cell == "1" {
                        let rect = CGRect(
                            x: left + CGFloat(c) * pitch + (pitch - dot) / 2,
                            y: CGFloat(r) * pitch + (pitch - dot) / 2,
                            width: dot, height: dot
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }
            }
        } else if typeface == .orbit {
            // A pennant in outline on a thin pole, like a marker on an instrument dial.
            Canvas { context, size in
                let u = size.width / 24
                var pole = Path()
                pole.move(to: CGPoint(x: 5 * u, y: 3 * u))
                pole.addLine(to: CGPoint(x: 5 * u, y: 21 * u))
                var pennant = Path()
                pennant.move(to: CGPoint(x: 5 * u, y: 3.5 * u))
                pennant.addLine(to: CGPoint(x: 20 * u, y: 8.5 * u))
                pennant.addLine(to: CGPoint(x: 5 * u, y: 13.5 * u))
                let line = StrokeStyle(lineWidth: 2 * u, lineCap: .round, lineJoin: .round)
                context.stroke(pole, with: .color(color), style: line)
                context.stroke(pennant, with: .color(color), style: line)
            }
        } else {
            // The same red Priority flag as the app's task rows.
            Image("flag-02")
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(color)
        }
    }
}

/// The photo, filling the screen with the person's zoom and offset.
struct PhotoLayer: View {
    let photo: UIImage
    let style: WallpaperStyle
    let size: CGSize

    var body: some View {
        Image(uiImage: photo)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .scaleEffect(CGFloat(style.photoZoom))
            .offset(x: CGFloat(style.photoOffsetX) * size.width, y: CGFloat(style.photoOffsetY) * size.height)
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}

/// A frosted panel baked into the image: the photo behind it, blurred and tinted.
/// (A live material can't be rendered into a wallpaper image.)
private struct FrostedBackdrop: View {
    let photo: UIImage
    let style: WallpaperStyle
    let canvas: CGSize
    let tint: Color
    let radius: CGFloat
    let blur: CGFloat

    var body: some View {
        GeometryReader { g in
            let frame = g.frame(in: .named(WallpaperCanvas.space))
            ZStack(alignment: .topLeading) {
                PhotoLayer(photo: photo, style: style, size: canvas)
                    .offset(x: -frame.minX, y: -frame.minY)
                    .blur(radius: blur)
                tint
            }
            .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
        )
    }
}

/// Stand-in for iOS's Lock Screen date and clock, shown in previews only.
private struct SystemClock: View {
    let color: Color
    let shadow: Color
    let s: CGFloat

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 0) {
                Text(context.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 21 * s, weight: .semibold))
                    .opacity(0.92)
                Text(context.date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()))
                    .font(.system(size: 112 * s, weight: .bold))
                    .tracking(-3 * s)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .foregroundStyle(color)
            .shadow(color: shadow, radius: 1.5 * s, y: 1 * s)
        }
    }
}

/// Stand-in for the flashlight and camera buttons, shown in previews only.
private struct SystemControls: View {
    let color: Color
    let s: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                control("flashlight")
                Spacer()
                control("camera-01")
            }
            .padding(.horizontal, 46 * s)
            .padding(.bottom, 32 * s)
            Capsule()
                .fill(color.opacity(0.85))
                .frame(width: 140 * s, height: 5 * s)
                .padding(.bottom, 8 * s)
        }
    }

    private func control(_ icon: String) -> some View {
        Image(icon)
            .resizable()
            .renderingMode(.template)
            .frame(width: 24 * s, height: 24 * s)
            .foregroundStyle(color)
            .frame(width: 50 * s, height: 50 * s)
            // A plain translucent circle: live glass rendered as solid discs at preview size.
            .background(Circle().fill(color.opacity(0.15)))
    }
}

/// A small Lock Screen preview at the phone's real proportions.
struct LockScreenPreview: View {
    @Environment(AppModel.self) private var model
    var style: WallpaperStyle? = nil
    var content: WallpaperContent? = nil
    let width: CGFloat

    var body: some View {
        let style = style ?? model.style
        let screen = model.screenSize
        let scale = width / screen.width
        WallpaperCanvas(
            content: content ?? model.wallpaperContent(for: style),
            style: style,
            appearance: model.appearance(for: style),
            photo: model.photo,
            showsSystemUI: true
        )
        // The preview is one element; its tiny task titles shouldn't be read or found on their own.
        .accessibilityHidden(true)
        .frame(width: screen.width, height: screen.height)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: width, height: screen.height * scale, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 55 * scale, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 55 * scale, style: .continuous)
                .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lock Screen preview")
    }
}
