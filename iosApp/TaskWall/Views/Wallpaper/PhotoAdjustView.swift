import SwiftUI
import PhotosUI
import Shared

/// Reframe the photo and choose how tasks stay readable on it.
struct PhotoAdjustView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var draft: WallpaperStyle?
    @State private var gestureStart: (zoom: Double, x: Double, y: Double)?
    @State private var pickedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Group {
                if let draft {
                    content(draft)
                }
            }
            .background(Color.ground.ignoresSafeArea())
            .foregroundStyle(Color.ink)
            .navigationTitle("Adjust photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        if let draft { model.setStyle(draft) }
                        dismiss()
                    }
                }
            }
        }
        .tint(.ink)
        .onAppear { draft = model.style }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                defer { pickedItem = nil }
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    try? model.choosePhoto(image)
                    draft = model.style
                }
            }
        }
    }

    private func content(_ style: WallpaperStyle) -> some View {
        ScrollView {
            VStack(spacing: 6) {
                preview(style)
                    .padding(.bottom, 8)

                HStack(spacing: 12) {
                    Text("Zoom")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 76, alignment: .leading)
                    Slider(value: zoomBinding, in: 1...3, onEditingChanged: { editing in
                        if !editing, let style = draft { draft = model.analyzed(style) }
                    })
                    .accessibilityLabel("Zoom")
                    .tint(Color.ink)
                    Text(String(format: "%.1f×", style.photoZoom))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Color.muted)
                        .frame(width: 40, alignment: .trailing)
                }
                .frame(minHeight: 40)

                chips("Text", selected: style.textTone, options: [
                    (ToneSetting.automatic, "Auto"), (ToneSetting.light, "White"), (ToneSetting.dark, "Black"),
                ]) { draft = draft?.withTextTone(tone: $0) }
                chips("Backdrop", selected: style.backdrop, options: [
                    (BackdropSetting.automatic, "Auto"), (BackdropSetting.clear, "None"),
                    (BackdropSetting.shade, "Shade"), (BackdropSetting.glass, "Glass"),
                ]) { draft = draft?.withBackdrop(backdrop: $0) }
                chips("Position", selected: style.position, options: [
                    (TaskPosition.belowClock, "Below clock"), (TaskPosition.bottom, "Bottom"),
                ]) { position in
                    // Moving the tasks changes what's behind them, so measure again.
                    if let style = draft { draft = model.analyzed(style.withPosition(position: position)) }
                }

                Text(note(style))
                    .font(.caption)
                    .foregroundStyle(Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Label {
                            Text("Replace photo")
                        } icon: {
                            Image("image-01").renderingMode(.template)
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    Button {
                        guard let style = draft else { return }
                        draft = model.analyzed(
                            style.withFraming(zoom: 1, offsetX: 0, offsetY: 0)
                                .withTextTone(tone: .automatic)
                                .withBackdrop(backdrop: .automatic)
                                .withPosition(position: .belowClock)
                        )
                    } label: {
                        Text("Reset").font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                }
                .controlSize(.large)
                .padding(.top, 10)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func preview(_ style: WallpaperStyle) -> some View {
        let screen = model.screenSize
        let width: CGFloat = 196
        let height = width * screen.height / screen.width
        let region = WallpaperGeometry.shared.analysisRegion(position: style.position)
        return LockScreenPreview(style: style, width: width)
            .overlay { ThirdsGrid().clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous)) }
            .overlay(alignment: .topLeading) {
                // Where the tasks go, so the photo's subject can stay clear of them.
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.peach.opacity(0.95), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .frame(width: width * CGFloat(region.width), height: height * CGFloat(region.height))
                    .overlay(alignment: .top) {
                        Text("Tasks go here")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.ground)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.peach))
                            .offset(y: -9)
                    }
                    .offset(x: width * CGFloat(region.x), y: height * CGFloat(region.y))
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .bottom) {
                Text("Pinch and drag to reframe")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 12)
            }
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.5), radius: 25, y: 20)
            .gesture(reframeGesture(previewSize: CGSize(width: width, height: height)))
            .accessibilityHint("Pinch to zoom and drag to move the photo.")
    }

    private func reframeGesture(previewSize: CGSize) -> some Gesture {
        let drag = DragGesture()
            .onChanged { value in
                guard let style = draft else { return }
                let start = gestureStart ?? (zoom: style.photoZoom, x: style.photoOffsetX, y: style.photoOffsetY)
                gestureStart = start
                update(
                    zoom: style.photoZoom,
                    x: start.x + Double(value.translation.width / previewSize.width),
                    y: start.y + Double(value.translation.height / previewSize.height)
                )
            }
        let pinch = MagnifyGesture()
            .onChanged { value in
                guard let style = draft else { return }
                let start = gestureStart ?? (zoom: style.photoZoom, x: style.photoOffsetX, y: style.photoOffsetY)
                gestureStart = start
                update(zoom: start.zoom * Double(value.magnification), x: style.photoOffsetX, y: style.photoOffsetY)
            }
        return SimultaneousGesture(drag, pinch)
            .onEnded { _ in
                gestureStart = nil
                if let style = draft { draft = model.analyzed(style) }
            }
    }

    /// Keeps the photo covering the whole screen while it moves.
    private func update(zoom: Double, x: Double, y: Double) {
        guard let style = draft else { return }
        let zoom = min(max(zoom, 1), 4)
        let limit = (zoom - 1) / 2
        draft = style.withFraming(zoom: zoom, offsetX: min(max(x, -limit), limit), offsetY: min(max(y, -limit), limit))
    }

    private var zoomBinding: Binding<Double> {
        Binding {
            draft?.photoZoom ?? 1
        } set: { zoom in
            guard let style = draft else { return }
            update(zoom: zoom, x: style.photoOffsetX, y: style.photoOffsetY)
        }
    }

    private func note(_ style: WallpaperStyle) -> String {
        if style.textTone == ToneSetting.automatic && style.backdrop == BackdropSetting.automatic {
            return style.photoAnalysis?.explanation ?? "Choose a photo to see what Auto picks."
        }
        return "Custom readability. Reset goes back to Auto."
    }

    private func chips<T: Hashable>(_ title: String, selected: T, options: [(T, String)], pick: @escaping (T) -> Void) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(width: 76, alignment: .leading)
            HStack(spacing: 6) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Button { pick(option.0) } label: {
                        ChipLabel(title: option.1, selected: option.0 == selected)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(option.0 == selected ? .isSelected : [])
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 40)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

/// The rule-of-thirds lines over the preview.
private struct ThirdsGrid: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            for i in 1...2 {
                let x = size.width * CGFloat(i) / 3
                let y = size.height * CGFloat(i) / 3
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
