import SwiftUI
import Shared

/// Every ready-made look as a small Lock Screen, plus the person's photo.
struct ThemesView: View {
    @Environment(AppModel.self) private var model

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        let style = model.style
        ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(WallpaperTheme.entries, id: \.self) { theme in
                    card(
                        title: theme.displayName,
                        style: style.withTheme(theme: theme),
                        selected: style.source == BackgroundSource.color && style.theme == theme
                    ) {
                        model.setStyle(style.withTheme(theme: theme))
                    }
                }
                if style.hasPhoto {
                    card(
                        title: "Your Photo",
                        style: style.withSource(source: .photo),
                        selected: style.source == BackgroundSource.photo
                    ) {
                        model.setStyle(style.withSource(source: .photo))
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card(title: String, style: WallpaperStyle, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                GeometryReader { geo in
                    LockScreenPreview(style: style, width: geo.size.width)
                }
                .aspectRatio(model.screenSize.width / model.screenSize.height, contentMode: .fit)
                .padding(3)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.primary, lineWidth: selected ? 2.5 : 0)
                )
                HStack(spacing: 4) {
                    if selected {
                        Image("checkmark-circle-02").renderingMode(.template).resizable().frame(width: 16, height: 16)
                    }
                    Text(title).font(.subheadline.weight(selected ? .semibold : .regular))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) theme")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
