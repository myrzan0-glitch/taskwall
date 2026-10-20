import UIKit
import Shared

/// Samples the part of the photo that sits behind the task list and hands the
/// pixels to the shared `LegibilityAnalyzer`, which decides text colour and backdrop.
enum PhotoAnalyzer {
    private static let sampleSize = 64

    static func analyze(_ photo: UIImage, style: WallpaperStyle, canvas: CGSize) -> LegibilityResult? {
        guard canvas.width > 0, canvas.height > 0, photo.size.width > 0, photo.size.height > 0 else { return nil }
        let region = WallpaperGeometry.shared.analysisRegion(position: style.position)
        let regionRect = CGRect(
            x: CGFloat(region.x) * canvas.width,
            y: CGFloat(region.y) * canvas.height,
            width: CGFloat(region.width) * canvas.width,
            height: CGFloat(region.height) * canvas.height
        )

        // Where the photo sits on the screen: aspect-fill, then the person's zoom and offset.
        let fill = max(canvas.width / photo.size.width, canvas.height / photo.size.height)
        let zoom = CGFloat(style.photoZoom)
        let drawn = CGSize(width: photo.size.width * fill * zoom, height: photo.size.height * fill * zoom)
        let photoRect = CGRect(
            x: (canvas.width - drawn.width) / 2 + CGFloat(style.photoOffsetX) * canvas.width,
            y: (canvas.height - drawn.height) / 2 + CGFloat(style.photoOffsetY) * canvas.height,
            width: drawn.width,
            height: drawn.height
        )

        // Draw just the region into a tiny bitmap.
        let side = sampleSize
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drewPixels: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            // Smooth downsampling, so a few bright pixels (e.g. city lights) don't dominate.
            context.interpolationQuality = .high
            UIGraphicsPushContext(context)
            // Flip to UIKit coordinates and map the region onto the bitmap.
            context.translateBy(x: 0, y: CGFloat(side))
            context.scaleBy(x: CGFloat(side) / regionRect.width, y: -CGFloat(side) / regionRect.height)
            context.translateBy(x: -regionRect.minX, y: -regionRect.minY)
            photo.draw(in: photoRect)
            UIGraphicsPopContext()
            return true
        }
        guard drewPixels else { return nil }

        let bytes = KotlinByteArray(size: Int32(pixels.count))
        for (index, value) in pixels.enumerated() {
            bytes.set(index: Int32(index), value: Int8(bitPattern: value))
        }
        return LegibilityAnalyzer.shared.analyzeRgba(rgba: bytes)
    }
}
