import SwiftUI
import CoreText
import Shared

/// The typefaces the task list can use on the wallpaper. iOS draws the clock itself.
///
/// The Pro fonts ship in the app under the SIL Open Font License (see Resources/Fonts):
/// Matrix is Doto with round dots, fixed at its Black weight; Orbit is Michroma.
enum WallpaperFonts {
    private static let names = ["DotoRounded-Black", "Michroma-Regular"]

    private static let registered: Bool = {
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }()

    /// Makes the bundled fonts available to this process. Safe to call more than once.
    static func register() {
        _ = registered
    }
}

/// Where text sits in the wallpaper's task list.
enum WallpaperTextRole {
    case heading, title, detail, more, tableHeading, tableTitle, tableDetail
}

extension WallpaperFont {
    /// The font for one part of the wallpaper, at the 390-pt design scaled by `s`.
    /// Sizes stay within the space `WallpaperGeometry.maxLines` allows for.
    func font(_ role: WallpaperTextRole, s: CGFloat) -> Font {
        if self == .matrix {
            return .custom("DotoRounded-Black", fixedSize: matrixSize(role) * s)
        }
        if self == .orbit {
            return .custom("Michroma-Regular", fixedSize: orbitSize(role) * s)
        }
        return .system(size: classicSize(role) * s, weight: classicWeight(role))
    }

    /// Letter spacing for that part, scaled by `s`.
    func tracking(_ role: WallpaperTextRole, s: CGFloat) -> CGFloat {
        let wide = self == .orbit
        switch role {
        case .heading: return (wide ? 2.4 : 1) * s
        case .tableHeading: return (wide ? 2.4 : 0.6) * s
        case .detail, .tableDetail, .more: return wide ? 1.2 * s : 0
        case .title, .tableTitle: return 0
        }
    }

    private func classicSize(_ role: WallpaperTextRole) -> CGFloat {
        switch role {
        case .heading: 13
        case .tableHeading: 11
        case .title: 20
        case .detail, .more: 15
        case .tableTitle, .tableDetail: 16
        }
    }

    private func classicWeight(_ role: WallpaperTextRole) -> Font.Weight {
        switch role {
        case .heading, .tableHeading: .bold
        case .title, .tableTitle, .more: .semibold
        case .detail, .tableDetail: .medium
        }
    }

    private func matrixSize(_ role: WallpaperTextRole) -> CGFloat {
        switch role {
        case .heading: 14
        case .tableHeading: 12
        case .title: 20
        case .detail, .more: 15
        case .tableTitle, .tableDetail: 16
        }
    }

    private func orbitSize(_ role: WallpaperTextRole) -> CGFloat {
        switch role {
        case .heading, .tableHeading: 10
        case .title: 15
        case .detail, .more: 11
        case .tableTitle, .tableDetail: 13
        }
    }
}
