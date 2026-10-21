import Foundation
import UserNotifications

enum Notifier {
    static func requestAuth() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private static func request(id: String, title: String, body: String, fire: Date, now: Date) -> (Date, UNNotificationRequest)? {
        let interval = fire.timeIntervalSince(now)
        guard interval > 2 else { return nil }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        return (fire, UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func reschedule(region: Region, prefs: Prefs) async {
        let center = UNUserNotificationCenter.current()
        let st = await center.notificationSettings().authorizationStatus
        guard st == .authorized || st == .provisional else { return }

        // نحذف إشعارات الصلاة فقط (لا نمس تذكير الورد وغيره)
        let pending = await center.pendingNotificationRequests()
        let mine = pending.map { $0.identifier }.filter { $0.hasPrefix("adhan-") || $0.hasPrefix("pre-") || $0.hasPrefix("iqama-") }
        center.removePendingNotificationRequests(withIdentifiers: mine)

        let now = Date()
        var items: [(Date, UNNotificationRequest)] = []

        for off in 0..<7 {
            guard let day = PrayerCalc.calendar.date(byAdding: .day, value: off, to: now) else { continue }
            let dt = PrayerCalc.compute(day: day, region: region, settings: prefs.calc)
            let friday = PrayerCalc.isFriday(day)

            for p in Prayer.allCases {
                let enabled: Bool
                if let idx = p.iqamaIndex {
                    enabled = idx < prefs.adhanOn.count ? prefs.adhanOn[idx] : true
                } else {
                    enabled = prefs.notifySunrise
                }
                if !enabled { continue }

                let t = dt[p]
                let name = (p == .dhuhr && friday) ? "الجمعة" : p.arabicName
                let tag = "\(off)-\(p.rawValue)"

                if prefs.preMinutes > 0 && p != .sunrise {
                    if let r = request(id: "pre-\(tag)",
                                       title: "اقترب أذان \(name)",
                                       body: "بعد \(prefs.preMinutes) دقيقة",
                                       fire: t.addingTimeInterval(-Double(prefs.preMinutes) * 60.0),
                                       now: now) {
                        items.append(r)
                    }
                }

                let adhanTitle = p == .sunrise ? "الشروق" : "حان الآن أذان \(name)"
                if let r = request(id: "adhan-\(tag)", title: adhanTitle, body: "الكويت", fire: t, now: now) {
                    items.append(r)
                }

                if prefs.notifyIqama && p.hasIqama && !(friday && p == .dhuhr) {
                    if let iq = Iqama.time(p, adhan: t, list: prefs.iqama),
                       let r = request(id: "iqama-\(tag)",
                                       title: "إقامة صلاة \(name)",
                                       body: "حان وقت الإقامة",
                                       fire: iq,
                                       now: now) {
                        items.append(r)
                    }
                }
            }
        }

        items.sort { $0.0 < $1.0 }
        for (_, req) in items.prefix(60) {
            try? await center.add(req)
        }
    }
}
