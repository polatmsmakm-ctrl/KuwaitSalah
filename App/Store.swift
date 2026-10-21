import SwiftUI
import UserNotifications

struct Prefs: Codable, Equatable {
    var regionID: String = "capital"
    var calc: CalcSettings = CalcSettings()
    var use24h: Bool = false
    var arabicDigits: Bool = true
    var hijriOffset: Int = 0
    /// الإقامة بالدقائق بعد الأذان: فجر، ظهر، عصر، مغرب، عشاء
    var iqama: [Int] = Iqama.defaults
    /// fajr, dhuhr, asr, maghrib, isha
    var adhanOn: [Bool] = [true, true, true, true, true]
    var notifySunrise: Bool = false
    var notifyIqama: Bool = true
    var preMinutes: Int = 0
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
}

final class Store: ObservableObject {
    @Published var prefs: Prefs {
        didSet { save() }
    }

    private let key = "prefs.v2"

    init() {
        if let data = UserDefaults.standard.data(forKey: "prefs.v2"),
           let p = try? JSONDecoder().decode(Prefs.self, from: data) {
            prefs = p
        } else {
            prefs = Prefs()
        }
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    private func save() {
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    var fmt: Fmt { Fmt(use24h: prefs.use24h, arabicDigits: prefs.arabicDigits) }

    var region: Region {
        Region.all.first(where: { $0.id == prefs.regionID }) ?? Region.all[0]
    }

    func refreshNotifications() {
        let region = self.region
        let prefs = self.prefs
        Task {
            await Notifier.reschedule(region: region, prefs: prefs)
        }
    }
}
