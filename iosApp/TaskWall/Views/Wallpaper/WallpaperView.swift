import SwiftUI
import PhotosUI
import Shared

struct WallpaperView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var showPhotoPicker = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var showAdjust = false
    @State private var message: String?

    var body: some View {
        let style = model.style
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 16) {
                        LockScreenPreview(width: 139)
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Background", selection: sourceBinding) {
                                Text("Color").tag(BackgroundSource.color)
                                Text("Photo").tag(BackgroundSource.photo)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            if style.source == BackgroundSource.photo {
                                Text("Your photo").font(.footnote).foregroundStyle(.secondary)
                                Button {
                                    showPhotoPicker = true
                                } label: {
                                    Label("Choose Photo", image: "image-01")
                                }
                                .buttonStyle(.glass)
                            } else {
                                Text(style.theme.displayName).font(.footnote).foregroundStyle(.secondary)
                                ThemeSwatches(selected: style.theme) { model.setStyle(style.withTheme(theme: $0)) }
                            }

                            Spacer(minLength: 0)
                            Picker("Layout", selection: layoutBinding) {
                                Text("List").tag(WallpaperLayout.list)
                                Text("Table").tag(WallpaperLayout.table)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                    .padding(.vertical, 4)
                }

                if style.source == BackgroundSource.photo {
                    Section {
                        Button {
                            showAdjust = true
                        } label: {
                            LabeledContent("Adjust Photo", value: readabilitySummary(style))
                        }
                        .foregroundStyle(.primary)
                    }
                }

                Section {
                    Toggle("Show Progress", isOn: progressBinding)
                        .tint(.accentColor)
                    NavigationLink {
                        AutomationSettingsView()
                    } label: {
                        LabeledContent("Automatic Updates", value: model.automation.isSetUp ? "On" : "Off")
                    }
                }

                Section {
                    HStack(spacing: 10) {
                        Button {
                            Task { await saveImage() }
                        } label: {
                            Label("Save Image", image: "download-01").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)

                        Button {
                            openURL(ShortcutLinks.runShortcut)
                        } label: {
                            Label("Update Now", image: "refresh").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                    }
                    .controlSize(.large)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Wallpaper")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ThemesView()
                    } label: {
                        Image("grid-view")
                    }
                    .accessibilityLabel("Themes")
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task { await usePhoto(item) }
            }
            .fullScreenCover(isPresented: $showAdjust) {
                PhotoAdjustView()
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var sourceBinding: Binding<BackgroundSource> {
        Binding {
            model.style.source
        } set: { source in
            if source == BackgroundSource.photo && !model.style.hasPhoto {
                showPhotoPicker = true
            } else {
                model.setStyle(model.style.withSource(source: source))
            }
        }
    }

    private var layoutBinding: Binding<WallpaperLayout> {
        Binding { model.style.layout } set: { model.setStyle(model.style.withLayout(layout: $0)) }
    }

    private var progressBinding: Binding<Bool> {
        Binding { model.style.showProgress } set: { model.setStyle(model.style.withShowProgress(show: $0)) }
    }

    private func readabilitySummary(_ style: WallpaperStyle) -> String {
        if style.textTone == ToneSetting.auto && style.backdrop == BackdropSetting.auto { return "Auto" }
        return "Custom"
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

struct ThemeSwatches: View {
    let selected: WallpaperTheme
    let onSelect: (WallpaperTheme) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 12), count: 3), alignment: .leading, spacing: 12) {
            ForEach(WallpaperTheme.entries, id: \.self) { theme in
                Button {
                    onSelect(theme)
                } label: {
                    Text("Aa")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color(argb: theme.palette.foreground))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color(argb: theme.palette.background)))
                        .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 0.5))
                        .padding(3)
                        .overlay(Circle().strokeBorder(.primary, lineWidth: theme == selected ? 2.5 : 0))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(theme.displayName) theme")
                .accessibilityAddTraits(theme == selected ? .isSelected : [])
            }
        }
    }
}
