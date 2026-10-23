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

    func testMatrixFlagIsARegularDotGrid() {
        let rows = PriorityFlag.matrixDots
        XCTAssertEqual(Set(rows.map(\.count)).count, 1, "every row has the same number of dots")
        XCTAssertTrue(rows.allSatisfy { $0.first == "1" }, "the pole runs down the left")
    }

    func testOrbitNumbersAreTwoDigits() {
        XCTAssertEqual(WallpaperCanvas.twoDigits(1), "01")
        XCTAssertEqual(WallpaperCanvas.twoDigits(12), "12")
    }

    func testProFontsAreBundledAndLoad() {
        WallpaperFonts.register()
        XCTAssertNotNil(UIFont(name: "DotoRounded-Black", size: 20), "Matrix font file missing from the app")
        XCTAssertNotNil(UIFont(name: "Michroma-Regular", size: 20), "Orbit font file missing from the app")
        XCTAssertNotNil(UIFont(name: "Unbounded-Light", size: 20), "Orbit's Cyrillic font file missing from the app")
    }

    private let cyrillic = "Закончить приложение. Съешь же ещё этих мягких булок. Ўзбек қўғҳ"

    private func hasEveryGlyph(_ font: CTFont, _ text: String) -> Bool {
        let units = Array(text.filter(\.isLetter).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: units.count)
        return CTFontGetGlyphsForCharacters(font, units, &glyphs, units.count)
    }

    func testMatrixDrawsCyrillicInItsOwnDots() throws {
        WallpaperFonts.register()
        let matrix = try XCTUnwrap(UIFont(name: "DotoRounded-Black", size: 20))
        XCTAssertTrue(hasEveryGlyph(matrix as CTFont, cyrillic))
    }

    func testOrbitFallsBackToUnboundedForCyrillic() throws {
        WallpaperFonts.register()
        let orbit = WallpaperFont.orbit(size: 20)
        XCTAssertTrue(hasEveryGlyph(orbit, "Renew passport"), "Latin stays in Michroma")
        let text = "Закончить" as CFString
        let used = CTFontCreateForString(orbit, text, CFRange(location: 0, length: CFStringGetLength(text)))
        XCTAssertEqual(CTFontCopyPostScriptName(used) as String, "Unbounded-Light")
        XCTAssertTrue(hasEveryGlyph(used, cyrillic))
    }

    func testLongTasksStayInsideTheWallpaper() throws {
        // A long Russian title must shorten with an ellipsis, not run past the edge.
        let store = TaskWallStore(file: InMemoryTextFileStore(text: nil))
        store.setScreen(metrics: ScreenMetrics(widthPoints: 390, heightPoints: 844, scale: 1))
        _ = store.addTask(title: "Закончить приложение и отправить его в App Store сегодня вечером", notes: "", priority: .high, dueDay: nil, dueMinutes: nil, showOnWallpaper: true, nowMillis: 1)
        _ = store.addQuickTask(title: "juma namaz", nowMillis: 2)
        for font in WallpaperFont.entries {
            for layout in [WallpaperLayout.list, WallpaperLayout.table] {
                let style = store.settings.wallpaper.withTheme(theme: .navy).withFont(font: font).withLayout(layout: layout)
                store.setWallpaperStyle(style: style)
                let image = try XCTUnwrap(WallpaperRenderer.image(store: store, today: CalendarDay.today, photo: nil))
                XCTAssertEqual(image.size, CGSize(width: 390, height: 844), "\(font) \(layout)")
                XCTAssertEqual(try brightPixels(in: image, fromX: 390 - 16), 0, "\(font) \(layout) draws into the right margin")
            }
        }
    }

    /// Text-coloured pixels at or right of `fromX`; Navy's own background is dark.
    private func brightPixels(in image: UIImage, fromX: Int) throws -> Int {
        try pixels(in: image).filter { $0.x >= fromX && max($0.r, $0.g, $0.b) > 120 }.count
    }

    private func pixels(in image: UIImage) throws -> [(x: Int, r: UInt8, g: UInt8, b: UInt8)] {
        let cg = try XCTUnwrap(image.cgImage)
        let width = cg.width, height = cg.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        XCTAssertTrue(drawn)
        return stride(from: 0, to: bytes.count, by: 4).map { i in
            (x: (i / 4) % width, r: bytes[i], g: bytes[i + 1], b: bytes[i + 2])
        }
    }

    func testRendersInEveryFontAndLayout() throws {
        let store = TaskWallStore(file: InMemoryTextFileStore(text: nil))
        store.setScreen(metrics: ScreenMetrics(widthPoints: 100, heightPoints: 200, scale: 1))
        _ = store.addQuickTask(title: "Buy milk", nowMillis: 1)
        // A Priority task, so each font's own flag is drawn too.
        _ = store.addTask(title: "Call mum", notes: "", priority: .high, dueDay: nil, dueMinutes: nil, showOnWallpaper: true, nowMillis: 2)
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
        try pixels(in: image).filter { max($0.r, $0.g, $0.b) < 12 }.count
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
