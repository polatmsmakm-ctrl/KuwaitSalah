import Foundation

enum Prayer: Int, CaseIterable, Identifiable, Codable {
    case fajr = 0, sunrise, dhuhr, asr, maghrib, isha

    var id: Int { rawValue }

    var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .sunrise: return "الشروق"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }

    var symbol: String {
        switch self {
        case .fajr: return "sunrise"
        case .sunrise: return "sun.horizon"
        case .dhuhr: return "sun.max"
        case .asr: return "sun.haze"
        case .maghrib: return "sunset"
        case .isha: return "moon.stars"
        }
    }

    var hasIqama: Bool { self != .sunrise }

    /// Index into Iqama.defaults (fajr, dhuhr, asr, maghrib, isha)
    var iqamaIndex: Int? {
        switch self {
        case .fajr: return 0
        case .sunrise: return nil
        case .dhuhr: return 1
        case .asr: return 2
        case .maghrib: return 3
        case .isha: return 4
        }
    }

    static let fivePrayers: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]
}
