import UIKit
import Photos

/// The chosen wallpaper photo, kept in the App Group so shortcuts can use it.
enum PhotoStore {
    /// Longest side kept. Enough for any iPhone screen at full zoom.
    private static let maxPixels: CGFloat = 3000

    static func url(for fileName: String) -> URL {
        AppGroup.containerURL.appendingPathComponent(fileName)
    }

    static func load(_ fileName: String?) -> UIImage? {
        guard let fileName else { return nil }
        return UIImage(contentsOfFile: url(for: fileName).path)
    }

    /// Saves a copy (upright, at most 3000 px) and removes the previous photo.
    static func save(_ image: UIImage, replacing oldFileName: String?) throws -> String {
        let fileName = "wallpaper-\(UUID().uuidString).jpg"
        guard let data = normalized(image).jpegData(compressionQuality: 0.9) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url(for: fileName), options: .atomic)
        if let oldFileName {
            try? FileManager.default.removeItem(at: url(for: oldFileName))
        }
        return fileName
    }

    private static func normalized(_ image: UIImage) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let factor = min(1, maxPixels / max(pixelSize.width, pixelSize.height))
        let target = CGSize(width: (pixelSize.width * factor).rounded(), height: (pixelSize.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

/// Saves the finished wallpaper to Photos with add-only access.
enum PhotoSaver {
    enum Failure: LocalizedError {
        case notAllowed

        var errorDescription: String? {
            "TaskWall isn't allowed to add photos. You can change this in Settings › Privacy › Photos."
        }
    }

    static func save(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw Failure.notAllowed }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}
