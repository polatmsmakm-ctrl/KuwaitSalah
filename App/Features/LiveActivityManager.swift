import Foundation
import ActivityKit

@MainActor
enum LiveActivityManager {
    static let key = "liveactivity.on"

    /// يبدأ نشاطاً مباشراً للصلاة القادمة (يُجدَّد كلما فُتح التطبيق).
    static func sync(region: Region, calc: CalcSettings) {
        let on = UserDefaults.standard.object(forKey: key) as? Bool ?? true
        let nxt = PrayerCalc.next(after: Date(), region: region, settings: calc)
        Task { @MainActor in
            for a in Activity<PrayerActivityAttributes>.activities {
                await a.end(nil, dismissalPolicy: .immediate)
            }
            guard on, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            let state = PrayerActivityAttributes.ContentState(prayerName: nxt.prayer.arabicName, time: nxt.date)
            let content = ActivityContent(state: state, staleDate: nxt.date)
            _ = try? Activity.request(attributes: PrayerActivityAttributes(title: "الصلاة القادمة"),
                                      content: content, pushType: nil)
        }
    }
}
