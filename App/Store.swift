import SwiftUI
import UserNotifications

struct Prefs: Codable, Equatable {
    var regionID: String = "capital"
    var calc: CalcSettings = CalcSettings()
    var use24h: Bool = false
    var arabicDigits: Bool = true
    var hijriOffset: Int = 0
    var selectedMosqueID: String = "default"
    var customMosques: [Mosque] = []
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

    private let key = "prefs.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: "prefs.v1"),
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

    var allMosques: [Mosque] { Mosque.presets + prefs.customMosques }

    var selectedMosque: Mosque {
        allMosques.first(where: { $0.id == prefs.selectedMosqueID }) ?? Mosque.presets[0]
    }

    func isCustom(_ m: Mosque) -> Bool {
        prefs.customMosques.contains(where: { $0.id == m.id })
    }

    func upsert(_ m: Mosque) {
        if let i = prefs.customMosques.firstIndex(where: { $0.id == m.id }) {
            prefs.customMosques[i] = m
        } else {
            prefs.customMosques.append(m)
            prefs.selectedMosqueID = m.id
        }
    }

    func delete(_ m: Mosque) {
        prefs.customMosques.removeAll(where: { $0.id == m.id })
        if prefs.selectedMosqueID == m.id {
            prefs.selectedMosqueID = Mosque.presets[0].id
        }
    }

    func duplicate(_ m: Mosque) -> Mosque {
        var c = m
        c.id = "c-" + UUID().uuidString
        c.name = m.name + " (نسخة)"
        c.estimated = false
        return c
    }

    func refreshNotifications() {
        let region = self.region
        let prefs = self.prefs
        let mosque = self.selectedMosque
        Task {
            await Notifier.reschedule(region: region, prefs: prefs, mosque: mosque)
        }
    }
}
