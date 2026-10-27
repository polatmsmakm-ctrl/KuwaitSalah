import SwiftUI
import UserNotifications

struct Place: Codable, Equatable {
    var name: String
    var lat: Double
    var lng: Double
    var tz: String
}

struct Prefs: Codable, Equatable {
    /// 0 تلقائي حسب موقعك، 1 محافظة كويتية، 2 مدينة من القائمة
    var locMode: Int = 0
    var place: Place? = nil
    var cityID: String = "c-makkah"
    /// طريقة الحساب تلقائية حسب الدولة (وإلا تُستخدم الزوايا اليدوية)
    var calcAuto: Bool = true
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
    /// 0 تلقائي، 1 فاتح، 2 داكن
    var appearance: Int = 0
    /// الإحصائيات اختيارية (تتبع الصلوات والأذكار)
    var statsEnabled: Bool = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case locMode, place, cityID, calcAuto
        case regionID, calc, use24h, arabicDigits, hijriOffset, iqama
        case adhanOn, notifySunrise, notifyIqama, preMinutes, appearance, statsEnabled
    }

    /// فك تشفير متسامح: أي حقل مفقود (من نسخة سابقة) يأخذ قيمته الافتراضية ولا تُمسح الإعدادات
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        regionID = try c.decodeIfPresent(String.self, forKey: .regionID) ?? "capital"
        calc = try c.decodeIfPresent(CalcSettings.self, forKey: .calc) ?? CalcSettings()
        locMode = try c.decodeIfPresent(Int.self, forKey: .locMode) ?? 0
        place = try c.decodeIfPresent(Place.self, forKey: .place)
        cityID = try c.decodeIfPresent(String.self, forKey: .cityID) ?? "c-makkah"
        // من عدّل الزوايا يدوياً في نسخة سابقة يبقى على إعداده
        let customized = calc.fajrAngle != 18 || calc.ishaAngle != 17.5
        calcAuto = try c.decodeIfPresent(Bool.self, forKey: .calcAuto) ?? !customized
        use24h = try c.decodeIfPresent(Bool.self, forKey: .use24h) ?? false
        arabicDigits = try c.decodeIfPresent(Bool.self, forKey: .arabicDigits) ?? true
        hijriOffset = try c.decodeIfPresent(Int.self, forKey: .hijriOffset) ?? 0
        iqama = try c.decodeIfPresent([Int].self, forKey: .iqama) ?? Iqama.defaults
        adhanOn = try c.decodeIfPresent([Bool].self, forKey: .adhanOn) ?? [true, true, true, true, true]
        notifySunrise = try c.decodeIfPresent(Bool.self, forKey: .notifySunrise) ?? false
        notifyIqama = try c.decodeIfPresent(Bool.self, forKey: .notifyIqama) ?? true
        preMinutes = try c.decodeIfPresent(Int.self, forKey: .preMinutes) ?? 0
        appearance = try c.decodeIfPresent(Int.self, forKey: .appearance) ?? 0
        statsEnabled = try c.decodeIfPresent(Bool.self, forKey: .statsEnabled) ?? false
        if iqama.count != 5 { iqama = Iqama.defaults }
        if adhanOn.count != 5 { adhanOn = [true, true, true, true, true] }
    }
}

enum DayKey {
    static func key(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = PrayerCalc.calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
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
        didSet {
            save()
            PrayerCalc.timeZone = region.timeZone
        }
    }
    /// التبويب المحدد (للاختصارات)
    @Published var selectedTab: Int = 0
    /// 0 أذكار، 1 مسبحة
    @Published var adhkarMode: Int = 0
    /// الصلوات التي علّمها المستخدم أنه أدّاها: "yyyy-MM-dd:rawValue"
    @Published var prayed: Set<String> {
        didSet { savePrayed() }
    }

    private let key = "prefs.v2"
    private let prayedKey = "prayed.v1"
    private var refreshTask: Task<Void, Never>?

    init() {
        if let data = UserDefaults.standard.data(forKey: "prefs.v2"),
           let p = try? JSONDecoder().decode(Prefs.self, from: data) {
            prefs = p
        } else {
            prefs = Prefs()
        }
        let saved = UserDefaults.standard.stringArray(forKey: "prayed.v1") ?? []
        prayed = Set(saved)
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        PrayerCalc.timeZone = region.timeZone
    }

    private func save() {
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func savePrayed() {
        UserDefaults.standard.set(Array(prayed), forKey: prayedKey)
    }

    var fmt: Fmt { Fmt(use24h: prefs.use24h, arabicDigits: prefs.arabicDigits) }

    var region: Region {
        let kuwait = Region.all.first(where: { $0.id == prefs.regionID }) ?? Region.all[0]
        switch prefs.locMode {
        case 2:
            return Region.cities.first(where: { $0.id == prefs.cityID }) ?? kuwait
        case 0:
            if let p = prefs.place {
                return Region(id: "gps", name: p.name, lat: p.lat, lng: p.lng, tzID: p.tz)
            }
            return kuwait
        default:
            return kuwait
        }
    }

    /// إعدادات الحساب الفعلية (حسب دولة المستخدم ما لم يختر الزوايا يدوياً)
    var calc: CalcSettings {
        prefs.calcAuto ? prefs.calc.withMethod(of: region.tzID) : prefs.calc
    }

    var colorScheme: ColorScheme? {
        // الخلفيات فضائية داكنة، فالتطبيق داكن دائماً
        return .dark
    }

    // MARK: - تعليم الصلوات

    func prayedKey(_ d: Date, _ p: Prayer) -> String {
        "\(DayKey.key(d)):\(p.rawValue)"
    }

    func isPrayed(_ d: Date, _ p: Prayer) -> Bool {
        prayed.contains(prayedKey(d, p))
    }

    func togglePrayed(_ d: Date, _ p: Prayer) {
        let k = prayedKey(d, p)
        if prayed.contains(k) { prayed.remove(k) } else { prayed.insert(k) }
    }

    // MARK: - الإشعارات (مع تأخير بسيط لتجنب إعادة الجدولة مع كل نقرة)

    func refreshNotifications() {
        refreshTask?.cancel()
        let region = self.region
        var prefs = self.prefs
        prefs.calc = self.calc
        refreshTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
            await Notifier.reschedule(region: region, prefs: prefs)
        }
    }
}
