import SwiftUI
import Shared

/// Reframe the photo and choose how tasks stay readable on it.
struct PhotoAdjustView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var draft: WallpaperStyle?
    @State private var gestureStart: (zoom: Double, x: Double, y: Double)?

    var body: some View {
        NavigationStack {
            Group {
                if let draft {
                    content(draft)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Adjust Photo")
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
        .preferredColorScheme(.dark)
        .onAppear { draft = model.style }
    }

    private func content(_ style: WallpaperStyle) -> some View {
        VStack(spacing: 18) {
            preview(style)
            VStack(spacing: 10) {
                row("Text", selection: binding(\.textTone) { $0.withTextTone(tone: $1) }) {
                    Text("Auto").tag(ToneSetting.automatic)
                    Text("White").tag(ToneSetting.light)
                    Text("Black").tag(ToneSetting.dark)
                }
                row("Backdrop", selection: binding(\.backdrop) { $0.withBackdrop(backdrop: $1) }) {
                    Text("Auto").tag(BackdropSetting.automatic)
                    Text("None").tag(BackdropSetting.clear)
                    Text("Shade").tag(BackdropSetting.shade)
                    Text("Glass").tag(BackdropSetting.glass)
                }
                row("Position", selection: positionBinding) {
                    Text("Below Clock").tag(TaskPosition.belowClock)
                    Text("Bottom").tag(TaskPosition.bottom)
                }
            }
            Text(style.photoAnalysis?.explanation ?? "Choose a photo to see what Auto picks.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func preview(_ style: WallpaperStyle) -> some View {
        let screen = model.screenSize
        let width: CGFloat = 220
        let height = width * screen.height / screen.width
        return LockScreenPreview(style: style, width: width)
            .overlay(alignment: .bottom) {
                Text("Pinch and drag to reframe")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 12)
            }
            .frame(width: width, height: height)
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

    private var positionBinding: Binding<TaskPosition> {
        Binding {
            draft?.position ?? .belowClock
        } set: { position in
            guard let style = draft else { return }
            // Moving the tasks changes what's behind them, so measure again.
            draft = model.analyzed(style.withPosition(position: position))
        }
    }

    private func binding<T>(_ keyPath: KeyPath<WallpaperStyle, T>, _ apply: @escaping (WallpaperStyle, T) -> WallpaperStyle) -> Binding<T> where T: Hashable {
        Binding {
            draft.map { $0[keyPath: keyPath] } ?? model.style[keyPath: keyPath]
        } set: { value in
            guard let style = draft else { return }
            draft = apply(style, value)
        }
    }

    private func row<T: Hashable, Content: View>(_ title: String, selection: Binding<T>, @ViewBuilder options: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(width: 76, alignment: .leading)
            Picker(title, selection: selection, content: options)
                .pickerStyle(.segmented)
                .labelsHidden()
        }
    }
}
