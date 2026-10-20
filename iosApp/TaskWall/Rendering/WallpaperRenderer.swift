import SwiftUI
import Shared

/// Turns today's tasks into the wallpaper image the shortcut sets.
@MainActor
enum WallpaperRenderer {
    static func image(store: TaskWallStore, today: CalendarDay, photo: UIImage?) -> UIImage? {
        let settings = store.settings
        let size = CGSize(
            width: settings.screen?.widthPoints ?? 393,
            height: settings.screen?.heightPoints ?? 852
        )
        let style = settings.wallpaper
        let canvas = WallpaperCanvas(
            content: store.wallpaperContent(today: today),
            style: style,
            appearance: store.resolvedAppearance(),
            photo: style.source == BackgroundSource.photo ? photo : nil
        )
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: canvas)
        renderer.scale = CGFloat(settings.screen?.scale ?? 3)
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage
    }

    static func pngData(store: TaskWallStore, today: CalendarDay) -> Data? {
        let photo = PhotoStore.load(store.settings.wallpaper.photoFileName)
        return image(store: store, today: today, photo: photo)?.pngData()
    }
}
