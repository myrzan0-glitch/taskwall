import SwiftUI
import PhotosUI
import Shared

/// The Wallpaper sheet, from the left button on Today: the look of the Lock Screen.
struct WallpaperView: View {
    @Environment(AppModel.self) private var model
    @Environment(ProStore.self) private var pro
    @Environment(\.openURL) private var openURL
    @State private var pickedItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showAdjust = false
    @State private var showPro = false
    @State private var message: String?
    /// A Pro font being tried without Pro: shown in the preview, not saved.
    @State private var tryingFont: WallpaperFont?

    var body: some View {
        let style = model.style
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    LockScreenPreview(style: tryingFont.map { style.withFont(font: $0) }, width: 140)
                        .shadow(color: .black.opacity(0.5), radius: 25, y: 20)
                        .padding(.top, 8)

                    ThemeSwatches(
                        selected: style.source == BackgroundSource.photo ? nil : style.theme,
                        photoSelected: style.source == BackgroundSource.photo,
                        onSelect: { model.setStyle(style.withTheme(theme: $0)) },
                        onPhoto: {
                            if style.hasPhoto {
                                model.setStyle(style.withSource(source: .photo))
                            } else {
                                showPhotoPicker = true
                            }
                        }
                    )
                    .padding(.top, 18)

                    FontPicker(selected: tryingFont ?? style.font, isPro: pro.isPro, onSelect: pickFont)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    VStack(spacing: 0) {
                        row("Layout") {
                            Picker("Layout", selection: layoutBinding) {
                                Text("List").tag(WallpaperLayout.list)
                                Text("Table").tag(WallpaperLayout.table)
                            }
                            .accessibilityIdentifier("layoutPicker")
                        }
                        DottedDivider()
                        row("Task list") {
                            Picker("Task list", selection: positionBinding) {
                                Text("Below clock").tag(TaskPosition.belowClock)
                                Text("Bottom").tag(TaskPosition.bottom)
                            }
                            .accessibilityIdentifier("positionPicker")
                        }
                        DottedDivider()
                        Toggle("Progress bar", isOn: progressBinding)
                            .font(.body)
                            .padding(.horizontal, 8)
                            .frame(minHeight: 52)
                        DottedDivider()
                        if style.source == BackgroundSource.photo {
                            Button { showAdjust = true } label: {
                                linkRow("Adjust photo", value: readabilitySummary(style))
                            }
                            .hapticButtonStyle(.plain)
                            .accessibilityIdentifier("adjustPhoto")
                        } else {
                            Button { showPhotoPicker = true } label: {
                                linkRow("Use a photo", icon: "image-01")
                            }
                            .hapticButtonStyle(.plain)
                            .accessibilityIdentifier("usePhoto")
                        }
                        DottedDivider()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .sensoryFeedback(.selection, trigger: style.layout)
                    .sensoryFeedback(.selection, trigger: style.position)
                }
                .padding(.bottom, 24)
            }
            .foregroundStyle(Color.ink)
            .navigationTitle("Wallpaper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Haptic.tap.play()
                        Task { await saveImage() }
                    } label: {
                        Image("download-01").renderingMode(.template)
                    }
                    .accessibilityLabel("Save Image")
                }
            }
            .safeAreaBar(edge: .bottom) {
                Group {
                    if tryingFont != nil {
                        VStack(spacing: 10) {
                            Button { showPro = true } label: {
                                Label {
                                    Text("Unlock with Pro")
                                } icon: {
                                    Image("square-lock-02").renderingMode(.template)
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                            }
                            .hapticButtonStyle(.glassProminent)
                            .buttonBorderShape(.capsule)
                            .controlSize(.large)
                            .tint(Color.peach)
                            .foregroundStyle(Color.ground)
                            .accessibilityIdentifier("unlockPro")
                            Text("Preview any font. Pro puts it on your Lock Screen.")
                                .font(.footnote)
                                .foregroundStyle(Color.muted)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        PrimaryButton("Update Lock Screen") { openURL(ShortcutLinks.runShortcut) }
                            .accessibilityIdentifier("updateNow")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        // Styles set at the app root don't reach sheets.
        .toggleStyle(BrandSwitchStyle())
        .tint(.ink)
        .presentationBackground(Color.sheet)
        .presentationDragIndicator(.visible)
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task { await usePhoto(item) }
        }
        .fullScreenCover(isPresented: $showAdjust) {
            PhotoAdjustView()
        }
        .sheet(isPresented: $showPro) {
            ProView(onUnlocked: keepTriedFont)
        }
        // Pro can also start from a renewal or a purchase on another device.
        .onChange(of: pro.isPro) { _, isPro in
            if isPro { keepTriedFont() }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    /// Free fonts, and every font with Pro, are saved at once; a Pro font
    /// without Pro is only previewed until the person unlocks it.
    private func pickFont(_ font: WallpaperFont) {
        if font.isPro && !pro.isPro {
            tryingFont = font
        } else {
            tryingFont = nil
            model.setStyle(model.style.withFont(font: font))
        }
    }

    private func keepTriedFont() {
        guard let font = tryingFont else { return }
        tryingFont = nil
        model.setStyle(model.style.withFont(font: font))
    }

    private func row<Content: View>(_ title: String, @ViewBuilder control: () -> Content) -> some View {
        HStack {
            Text(title).font(.body)
            Spacer()
            control()
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Color.muted)
        }
        .padding(.leading, 8)
        .frame(minHeight: 52)
    }

    private func linkRow(_ title: String, value: String? = nil, icon: String? = nil) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.body)
            Spacer()
            if let value {
                Text(value).foregroundStyle(Color.muted)
            }
            if let icon {
                Image(icon).renderingMode(.template).resizable().frame(width: 18, height: 18).foregroundStyle(Color.muted)
            }
            Image("arrow-right-01").renderingMode(.template).resizable().frame(width: 16, height: 16).foregroundStyle(Color.muted)
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private var layoutBinding: Binding<WallpaperLayout> {
        Binding { model.style.layout } set: { model.setStyle(model.style.withLayout(layout: $0)) }
    }

    private var positionBinding: Binding<TaskPosition> {
        Binding { model.style.position } set: {
            // On a photo, moving the list changes what's behind it, so measure again.
            model.setStyle(model.analyzed(model.style.withPosition(position: $0)))
        }
    }

    private var progressBinding: Binding<Bool> {
        Binding { model.style.showProgress } set: { model.setStyle(model.style.withShowProgress(show: $0)) }
    }

    private func readabilitySummary(_ style: WallpaperStyle) -> String {
        style.textTone == ToneSetting.automatic && style.backdrop == BackdropSetting.automatic ? "Auto" : "Custom"
    }

    private func usePhoto(_ item: PhotosPickerItem) async {
        defer { pickedItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
            message = "That photo couldn't be opened."
            return
        }
        do {
            try model.choosePhoto(image)
            showAdjust = true
        } catch {
            message = "That photo couldn't be saved."
        }
    }

    private func saveImage() async {
        guard let image = model.renderWallpaper() else {
            message = "The wallpaper couldn't be created."
            return
        }
        do {
            try await PhotoSaver.save(image)
            message = "Saved to Photos."
        } catch {
            message = error.localizedDescription
        }
    }
}

/// The five colour themes as "Aa" circles, then the photo.
struct ThemeSwatches: View {
    @Environment(AppModel.self) private var model
    /// Nil when the photo is the background.
    let selected: WallpaperTheme?
    let photoSelected: Bool
    let onSelect: (WallpaperTheme) -> Void
    let onPhoto: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(WallpaperTheme.companion.picker, id: \.self) { theme in
                Button { onSelect(theme) } label: {
                    Text("Aa")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color(argb: theme.palette.foreground))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color(argb: theme.palette.background)))
                        .modifier(SwatchRing(on: theme == selected))
                }
                .hapticButtonStyle(.plain)
                .accessibilityLabel("\(theme.displayName) theme")
                .accessibilityAddTraits(theme == selected ? .isSelected : [])
            }
            Button(action: onPhoto) {
                Group {
                    if let photo = model.photo {
                        Image(uiImage: photo).resizable().scaledToFill()
                    } else {
                        Image("image-01").renderingMode(.template).resizable().frame(width: 20, height: 20)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.control)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .modifier(SwatchRing(on: photoSelected))
            }
            .hapticButtonStyle(.plain)
            .accessibilityLabel(model.photo == nil ? "Choose a photo" : "Your photo")
            .accessibilityAddTraits(photoSelected ? .isSelected : [])
        }
    }
}

/// The three wallpaper fonts as "Aa" cards; the Pro ones carry a badge.
struct FontPicker: View {
    let selected: WallpaperFont
    let isPro: Bool
    let onSelect: (WallpaperFont) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Font")
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Color.muted)
                .padding(.horizontal, 8)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                ForEach(WallpaperFont.entries, id: \.self) { font in
                    Button { onSelect(font) } label: { card(font) }
                        .hapticButtonStyle(.plain)
                        .accessibilityLabel("\(font.displayName) font")
                        .accessibilityValue(font.isPro && !isPro ? String(localized: "Pro") : String())
                        .accessibilityAddTraits(font == selected ? .isSelected : [])
                        .accessibilityIdentifier("font-\(font.displayName.lowercased())")
                }
            }
        }
    }

    private func card(_ font: WallpaperFont) -> some View {
        let on = font == selected
        return VStack(spacing: 6) {
            Text("Aa")
                .font(font.font(.title, s: font == .orbit ? 1.3 : 1.4))
                .frame(height: 30)
            Text(font.displayName)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.chip))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(on ? Color.ink : Color.white.opacity(0.08), lineWidth: on ? 2 : 1)
        )
        .overlay(alignment: .topTrailing) {
            if font.isPro && !isPro {
                Text("PRO")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(Color.ground)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background(Capsule().fill(Color.peach))
                    .padding(8)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct SwatchRing: ViewModifier {
    let on: Bool

    func body(content: Content) -> some View {
        content
            .overlay(Circle().strokeBorder(Color.white.opacity(on ? 0 : 0.14), lineWidth: 1))
            .padding(3)
            .overlay(Circle().strokeBorder(Color.ink, lineWidth: on ? 2 : 0))
    }
}
