import Foundation

struct Fmt {
    var use24h: Bool = false
    var arabicDigits: Bool = true

    private var locale: Locale {
        Locale(identifier: arabicDigits ? "ar@numbers=arab" : "ar@numbers=latn")
    }

    private func formatter(_ pattern: String, calendar: Calendar? = nil) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = PrayerCalc.calendar.timeZone
        if let calendar = calendar { f.calendar = calendar }
        f.dateFormat = pattern
        return f
    }

    func time(_ d: Date) -> String {
        formatter(use24h ? "HH:mm" : "h:mm a").string(from: d)
    }

    /// وقت بدون ص/م للجداول
    func timeShort(_ d: Date) -> String {
        formatter(use24h ? "HH:mm" : "h:mm").string(from: d)
    }

    func custom(_ d: Date, _ pattern: String) -> String {
        formatter(pattern).string(from: d)
    }

    func digits(_ s: String) -> String {
        guard arabicDigits else { return s }
        let map: [Character: Character] = [
            "0": "٠", "1": "١", "2": "٢", "3": "٣", "4": "٤",
            "5": "٥", "6": "٦", "7": "٧", "8": "٨", "9": "٩"
        ]
        return String(s.map { map[$0] ?? $0 })
    }

    func number(_ n: Int) -> String { digits(String(n)) }

    func countdown(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval))
        return digits(String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60))
    }

    func gregorian(_ d: Date) -> String {
        formatter("EEEE d MMMM yyyy").string(from: d)
    }

    func hijri(_ d: Date, offset: Int) -> String {
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.timeZone = PrayerCalc.calendar.timeZone
        let shifted = PrayerCalc.calendar.date(byAdding: .day, value: offset, to: d) ?? d
        return formatter("d MMMM yyyy", calendar: c).string(from: shifted)
    }
}
