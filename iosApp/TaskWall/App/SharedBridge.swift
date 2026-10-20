import SwiftUI
import Shared

// Small conversions between Swift types and the shared Kotlin types.

extension CalendarDay {
    static func from(_ date: Date, calendar: Calendar = .current) -> CalendarDay {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return CalendarDay(year: Int32(c.year ?? 1970), month: Int32(c.month ?? 1), day: Int32(c.day ?? 1))
    }

    static var today: CalendarDay { from(Date()) }

    func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: Int(year), month: Int(month), day: Int(day))) ?? Date()
    }
}

extension Date {
    var millis: Int64 { Int64(timeIntervalSince1970 * 1000) }

    init(millis: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(millis) / 1000)
    }

    /// Minutes after midnight in the current calendar.
    var minutesAfterMidnight: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Today at the given minutes after midnight.
    static func at(minutesAfterMidnight minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }
}

extension Color {
    /// From a 0xAARRGGBB value used by the shared palettes.
    init(argb: Int64) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }
}

func kotlinInt(_ value: Int?) -> KotlinInt? {
    value.map { KotlinInt(int: Int32($0)) }
}

extension SectionKind {
    var title: String {
        switch self {
        case .overdue: "Overdue"
        case .today: "Today"
        case .anytime: "Anytime"
        default: "Upcoming"
        }
    }
}

extension Priority {
    var title: String {
        switch self {
        case .high: "High"
        case .medium: "Med"
        case .low: "Low"
        default: "None"
        }
    }

    static var pickerOrder: [Priority] { [.noPriority, .low, .medium, .high] }
}

extension LegibilityResult {
    /// The sentence shown under Adjust Photo, e.g. "Auto picks black text with no backdrop…".
    var explanation: String {
        let text = tone == TextTone.light ? "white" : "black"
        let ratio = { (value: Double) in String(format: "%.1f:1", value) }
        switch backdrop {
        case .clear:
            let best = tone == TextTone.light ? whiteContrast : blackContrast
            return "Auto picks \(text) text with no backdrop. \(text.capitalized) already reaches \(ratio(best)) here."
        case .shade:
            let best = tone == TextTone.light ? whiteContrast : blackContrast
            return "Auto picks \(text) text with a soft shade. \(text.capitalized) alone only reaches \(ratio(best))."
        default:
            return "Auto picks \(text) text on frosted glass. Neither colour is readable on this photo alone (\(ratio(max(whiteContrast, blackContrast))) at best)."
        }
    }
}
