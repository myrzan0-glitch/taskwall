import XCTest
import UIKit
import Shared
@testable import TaskWall

/// The wallpaper image, the photo analysis and the photo file.
@MainActor
final class RenderingTests: XCTestCase {

    private func image(size: CGSize, draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(context.cgContext)
        }
    }

    private func solid(_ color: UIColor, size: CGSize = CGSize(width: 390, height: 844)) -> UIImage {
        image(size: size) { cg in
            cg.setFillColor(color.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
        }
    }

    private let canvas = CGSize(width: 390, height: 844)
    private let photoStyle = WallpaperStyle.companion.defaultStyle.withPhoto(fileName: "p.jpg")

    func testRendersTheWallpaperAtTheSavedScreenSize() throws {
        let store = TaskWallStore(file: InMemoryTextFileStore(text: nil))
        store.setScreen(metrics: ScreenMetrics(widthPoints: 100, heightPoints: 200, scale: 1))
        _ = store.addQuickTask(title: "Buy milk", nowMillis: 1)
        let image = try XCTUnwrap(WallpaperRenderer.image(store: store, today: CalendarDay.today, photo: nil))
        XCTAssertEqual(image.size.width, 100, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 200, accuracy: 0.5)
        XCTAssertNotNil(WallpaperRenderer.pngData(store: store, today: CalendarDay.today))
    }

    func testOrbitNumbersAreTwoDigits() {
        XCTAssertEqual(WallpaperCanvas.twoDigits(1), "01")
        XCTAssertEqual(WallpaperCanvas.twoDigits(12), "12")
    }

    func testProFontsAreBundledAndLoad() {
        WallpaperFonts.register()
        XCTAssertNotNil(UIFont(name: "DotoRounded-Black", size: 20), "Matrix font file missing from the app")
        XCTAssertNotNil(UIFont(name: "Michroma-Regular", size: 20), "Orbit font file missing from the app")
    }

    func testRendersInEveryFontAndLayout() throws {
        let store = TaskWallStore(file: InMemoryTextFileStore(text: nil))
        store.setScreen(metrics: ScreenMetrics(widthPoints: 100, heightPoints: 200, scale: 1))
        _ = store.addQuickTask(title: "Buy milk", nowMillis: 1)
        for font in WallpaperFont.entries {
            for layout in [WallpaperLayout.list, WallpaperLayout.table] {
                store.setWallpaperStyle(style: store.settings.wallpaper.withFont(font: font).withLayout(layout: layout))
                XCTAssertNotNil(WallpaperRenderer.image(store: store, today: CalendarDay.today, photo: nil), "\(font) \(layout)")
            }
        }
    }

    func testEveryFontDrawsTextInTheWallpaperColour() throws {
        // Navy has no black in it, so a black pixel is text that fell back to the system colour.
        let store = TaskWallStore(file: InMemoryTextFileStore(text: nil))
        store.setScreen(metrics: ScreenMetrics(widthPoints: 390, heightPoints: 844, scale: 1))
        _ = store.addQuickTask(title: "Buy milk", nowMillis: 1)
        for font in WallpaperFont.entries {
            store.setWallpaperStyle(style: store.settings.wallpaper.withTheme(theme: .navy).withFont(font: font))
            let image = try XCTUnwrap(WallpaperRenderer.image(store: store, today: CalendarDay.today, photo: nil))
            XCTAssertEqual(try nearBlackPixels(in: image), 0, "\(font)")
        }
    }

    private func nearBlackPixels(in image: UIImage) throws -> Int {
        let cg = try XCTUnwrap(image.cgImage)
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        XCTAssertTrue(drawn)
        var count = 0
        for i in stride(from: 0, to: pixels.count, by: 4) where max(pixels[i], pixels[i + 1], pixels[i + 2]) < 12 {
            count += 1
        }
        return count
    }

    func testRendersWithAPhotoAndEveryBackdrop() throws {
        let store = TaskWallStore(file: InMemoryTextFileStore(text: nil))
        store.setScreen(metrics: ScreenMetrics(widthPoints: 100, heightPoints: 200, scale: 1))
        _ = store.addQuickTask(title: "Buy milk", nowMillis: 1)
        let photo = solid(.gray)
        for backdrop in [BackdropSetting.clear, BackdropSetting.shade, BackdropSetting.glass] {
            store.setWallpaperStyle(style: photoStyle.withBackdrop(backdrop: backdrop))
            XCTAssertNotNil(WallpaperRenderer.image(store: store, today: CalendarDay.today, photo: photo), "\(backdrop)")
        }
    }

    func testDarkPhotoGetsWhiteTextWithNoBackdrop() throws {
        let result = try XCTUnwrap(PhotoAnalyzer.analyze(solid(.black), style: photoStyle, canvas: canvas))
        XCTAssertEqual(result.tone, TextTone.light)
        XCTAssertEqual(result.backdrop, Backdrop.clear)
        XCTAssertGreaterThan(result.whiteContrast, 20)
    }

    func testBrightPhotoGetsBlackTextWithNoBackdrop() throws {
        let result = try XCTUnwrap(PhotoAnalyzer.analyze(solid(.white), style: photoStyle, canvas: canvas))
        XCTAssertEqual(result.tone, TextTone.dark)
        XCTAssertEqual(result.backdrop, Backdrop.clear)
    }

    func testMixedPhotoGetsGlass() throws {
        // Black above the middle, white below: whatever the text colour, part of the list is unreadable.
        let mixed = image(size: canvas) { cg in
            cg.setFillColor(UIColor.black.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height / 2))
            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(CGRect(x: 0, y: canvas.height / 2, width: canvas.width, height: canvas.height / 2))
        }
        let result = try XCTUnwrap(PhotoAnalyzer.analyze(mixed, style: photoStyle, canvas: canvas))
        XCTAssertEqual(result.backdrop, Backdrop.glass)
        XCTAssertLessThan(result.whiteContrast, 3)
        XCTAssertLessThan(result.blackContrast, 3)
    }

    func testMovingTheListChangesWhatIsMeasured() throws {
        // Black where "below the clock" sits, white at the bottom.
        let split = image(size: canvas) { cg in
            cg.setFillColor(UIColor.black.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height * 0.72))
            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(CGRect(x: 0, y: canvas.height * 0.72, width: canvas.width, height: canvas.height * 0.28))
        }
        let belowClock = try XCTUnwrap(PhotoAnalyzer.analyze(split, style: photoStyle, canvas: canvas))
        XCTAssertEqual(belowClock.tone, TextTone.light)
        let bottom = try XCTUnwrap(PhotoAnalyzer.analyze(split, style: photoStyle.withPosition(position: .bottom), canvas: canvas))
        XCTAssertNotEqual(bottom.backdrop, Backdrop.clear, "the bottom band straddles the edge, so it needs help")
    }

    func testAnalyzerRejectsEmptySizes() {
        XCTAssertNil(PhotoAnalyzer.analyze(solid(.black), style: photoStyle, canvas: .zero))
    }

    func testPhotoStoreSavesUprightCopiesAndRemovesTheOldOne() throws {
        let first = try PhotoStore.save(solid(.red, size: CGSize(width: 40, height: 20)), replacing: nil)
        defer { try? FileManager.default.removeItem(at: PhotoStore.url(for: first)) }
        let loaded = try XCTUnwrap(PhotoStore.load(first))
        XCTAssertEqual(loaded.size.width / loaded.size.height, 2, accuracy: 0.01)

        let second = try PhotoStore.save(solid(.blue, size: CGSize(width: 4000, height: 2000)), replacing: first)
        defer { try? FileManager.default.removeItem(at: PhotoStore.url(for: second)) }
        XCTAssertNil(PhotoStore.load(first), "the old photo is gone")
        let big = try XCTUnwrap(PhotoStore.load(second))
        XCTAssertEqual(max(big.size.width, big.size.height) * big.scale, 3000, accuracy: 1, "photos are capped at 3000 px")
        XCTAssertNil(PhotoStore.load(nil))
        XCTAssertNil(PhotoStore.load("missing.jpg"))
    }

    func testChoosingAPhotoUpdatesTheModel() throws {
        let model = AppModel(store: TaskWallStore(file: InMemoryTextFileStore(text: nil)))
        try model.choosePhoto(solid(.black))
        defer {
            if let name = model.style.photoFileName {
                try? FileManager.default.removeItem(at: PhotoStore.url(for: name))
            }
        }
        XCTAssertEqual(model.style.source, BackgroundSource.photo)
        XCTAssertNotNil(model.photo)
        XCTAssertEqual(model.style.photoAnalysis?.tone, TextTone.light)
        XCTAssertTrue(model.appearance().isPhoto)
        XCTAssertEqual(model.appearance().backdrop, Backdrop.clear)

        let reframed = model.analyzed(model.style.withFraming(zoom: 2, offsetX: 0.2, offsetY: 0))
        XCTAssertEqual(reframed.photoZoom, 2)
        XCTAssertNotNil(reframed.photoAnalysis)
    }
}
