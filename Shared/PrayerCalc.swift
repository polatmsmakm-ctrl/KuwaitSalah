import Foundation

struct Region: Identifiable, Hashable {
    let id: String
    let name: String
    let lat: Double
    let lng: Double
    var tzID: String = "Asia/Kuwait"

    /// الاسم المعروض: محافظات الكويت تُسبق بـ«الكويت»
    var label: String { Region.all.contains(where: { $0.id == id }) ? "الكويت · \(name)" : name }

    var timeZone: TimeZone { TimeZone(identifier: tzID) ?? TimeZone(secondsFromGMT: 3 * 3600)! }

    /// مدن جاهزة للاختيار اليدوي
    static let cities: [Region] = [
        Region(id: "c-makkah", name: "مكة المكرمة", lat: 21.4225, lng: 39.8262, tzID: "Asia/Riyadh"),
        Region(id: "c-madinah", name: "المدينة المنورة", lat: 24.4672, lng: 39.6111, tzID: "Asia/Riyadh"),
        Region(id: "c-riyadh", name: "الرياض", lat: 24.7136, lng: 46.6753, tzID: "Asia/Riyadh"),
        Region(id: "c-jeddah", name: "جدة", lat: 21.5433, lng: 39.1728, tzID: "Asia/Riyadh"),
        Region(id: "c-dammam", name: "الدمام", lat: 26.4207, lng: 50.0888, tzID: "Asia/Riyadh"),
        Region(id: "c-beirut", name: "بيروت", lat: 33.8938, lng: 35.5018, tzID: "Asia/Beirut"),
        Region(id: "c-tripoli", name: "طرابلس (لبنان)", lat: 34.4367, lng: 35.8497, tzID: "Asia/Beirut"),
        Region(id: "c-saida", name: "صيدا", lat: 33.5630, lng: 35.3688, tzID: "Asia/Beirut"),
        Region(id: "c-amman", name: "عمّان", lat: 31.9454, lng: 35.9284, tzID: "Asia/Amman"),
        Region(id: "c-cairo", name: "القاهرة", lat: 30.0444, lng: 31.2357, tzID: "Africa/Cairo"),
        Region(id: "c-dubai", name: "دبي", lat: 25.2048, lng: 55.2708, tzID: "Asia/Dubai"),
        Region(id: "c-doha", name: "الدوحة", lat: 25.2854, lng: 51.5310, tzID: "Asia/Qatar"),
        Region(id: "c-manama", name: "المنامة", lat: 26.2285, lng: 50.5860, tzID: "Asia/Bahrain"),
        Region(id: "c-muscat", name: "مسقط", lat: 23.5880, lng: 58.3829, tzID: "Asia/Muscat"),
        Region(id: "c-baghdad", name: "بغداد", lat: 33.3152, lng: 44.3661, tzID: "Asia/Baghdad")
    ]

    static let all: [Region] = [
        Region(id: "capital", name: "العاصمة", lat: 29.3759, lng: 47.9774),
        Region(id: "hawalli", name: "حولي", lat: 29.3328, lng: 48.0286),
        Region(id: "farwaniya", name: "الفروانية", lat: 29.2775, lng: 47.9585),
        Region(id: "mubarak", name: "مبارك الكبير", lat: 29.2120, lng: 48.0600),
        Region(id: "ahmadi", name: "الأحمدي", lat: 29.0769, lng: 48.0838),
        Region(id: "jahra", name: "الجهراء", lat: 29.3375, lng: 47.6581)
    ]

    /// المسافة بالكيلومتر (هافرساين)
    static func distanceKm(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> Double {
        let r = 6371.0
        let p1 = lat1 * Double.pi / 180.0
        let p2 = lat2 * Double.pi / 180.0
        let dp = (lat2 - lat1) * Double.pi / 180.0
        let dl = (lng2 - lng1) * Double.pi / 180.0
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * r * asin(min(1.0, sqrt(a)))
    }

    /// أقرب محافظة، أو nil إذا كان الموقع بعيداً عن الكويت (أكثر من ١٢٠ كم)
    static func nearest(lat: Double, lng: Double) -> Region? {
        var best: Region?
        var bestD = Double.greatestFiniteMagnitude
        for r in all {
            let d = distanceKm(lat, lng, r.lat, r.lng)
            if d < bestD {
                bestD = d
                best = r
            }
        }
        return bestD <= 120 ? best : nil
    }
}

/// Defaults follow the Kuwait method: Fajr 18 deg, Isha 17.5 deg.
struct CalcSettings: Codable, Equatable {
    var fajrAngle: Double = 18
    var ishaAngle: Double = 17.5
    var hanafiAsr: Bool = false
    /// إن كانت > 0 فالعشاء = المغرب + هذه الدقائق (أم القرى)
    var ishaMinutes: Double = 0
    /// Minute adjustments indexed by Prayer.rawValue
    var adjust: [Int] = [0, 0, 0, 0, 0, 0]

    init() {}

    enum CodingKeys: String, CodingKey {
        case fajrAngle, ishaAngle, hanafiAsr, adjust, ishaMinutes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fajrAngle = try c.decodeIfPresent(Double.self, forKey: .fajrAngle) ?? 18
        ishaAngle = try c.decodeIfPresent(Double.self, forKey: .ishaAngle) ?? 17.5
        hanafiAsr = try c.decodeIfPresent(Bool.self, forKey: .hanafiAsr) ?? false
        ishaMinutes = try c.decodeIfPresent(Double.self, forKey: .ishaMinutes) ?? 0
        adjust = try c.decodeIfPresent([Int].self, forKey: .adjust) ?? [0, 0, 0, 0, 0, 0]
        if adjust.count != 6 { adjust = [0, 0, 0, 0, 0, 0] }
    }
}

extension CalcSettings {
    /// الطريقة المعتمدة حسب المنطقة الزمنية (تقابل دولة المستخدم)
    static func method(forTZ tz: String) -> CalcSettings {
        var c = CalcSettings()
        switch tz {
        case "Asia/Kuwait":
            c.fajrAngle = 18; c.ishaAngle = 17.5
        case "Asia/Riyadh", "Asia/Qatar", "Asia/Bahrain", "Asia/Aden":
            c.fajrAngle = 18.5; c.ishaMinutes = 90      // أم القرى
        case "Asia/Dubai":
            c.fajrAngle = 18.2; c.ishaAngle = 18.2
        case "Asia/Muscat":
            c.fajrAngle = 18; c.ishaAngle = 18
        case "Africa/Cairo", "Africa/Khartoum", "Africa/Tripoli":
            c.fajrAngle = 19.5; c.ishaAngle = 17.5      // الهيئة المصرية
        default:
            c.fajrAngle = 18; c.ishaAngle = 17          // رابطة العالم الإسلامي
        }
        return c
    }

    /// يدمج طريقة المنطقة مع تفضيلات المستخدم (العصر والتعديلات اليدوية)
    func withMethod(of tz: String) -> CalcSettings {
        var m = CalcSettings.method(forTZ: tz)
        m.hanafiAsr = hanafiAsr
        m.adjust = adjust
        return m
    }
}

struct DayTimes {
    let times: [Prayer: Date]
    subscript(_ p: Prayer) -> Date { times[p] ?? Date.distantPast }
}

enum PrayerCalc {
    /// المنطقة الزمنية الحالية للتطبيق (يضبطها Store بحسب موقع المستخدم؛ الافتراضي الكويت)
    static var timeZone: TimeZone = TimeZone(identifier: "Asia/Kuwait") ?? TimeZone(secondsFromGMT: 3 * 3600)!

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        return c
    }

    static func calendarFor(_ tz: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        return c
    }

    // MARK: - Math helpers

    private static func rad(_ d: Double) -> Double { d * Double.pi / 180.0 }
    private static func deg(_ r: Double) -> Double { r * 180.0 / Double.pi }
    private static func sinD(_ d: Double) -> Double { sin(rad(d)) }
    private static func cosD(_ d: Double) -> Double { cos(rad(d)) }
    private static func fixAngle(_ a: Double) -> Double { a - 360.0 * floor(a / 360.0) }
    private static func fixHour(_ a: Double) -> Double { a - 24.0 * floor(a / 24.0) }

    private static func julian(_ year: Int, _ month: Int, _ day: Int) -> Double {
        var y = year
        var m = month
        if m <= 2 {
            y -= 1
            m += 12
        }
        let a = floor(Double(y) / 100.0)
        let b = 2.0 - a + floor(a / 4.0)
        return floor(365.25 * Double(y + 4716)) + floor(30.6001 * Double(m + 1)) + Double(day) + b - 1524.5
    }

    private static func sunPosition(_ jd: Double) -> (decl: Double, eqt: Double) {
        let d = jd - 2451545.0
        let g = fixAngle(357.529 + 0.98560028 * d)
        let q = fixAngle(280.459 + 0.98564736 * d)
        let l = fixAngle(q + 1.915 * sinD(g) + 0.020 * sinD(2 * g))
        let e = 23.439 - 0.00000036 * d
        let ra = fixHour(deg(atan2(cosD(e) * sinD(l), cosD(l))) / 15.0)
        let eqt = q / 15.0 - ra
        let decl = deg(asin(sinD(e) * sinD(l)))
        return (decl, eqt)
    }

    // MARK: - Public API

    static func compute(day: Date, region: Region, settings: CalcSettings) -> DayTimes {
        let tz = region.timeZone
        let cal = calendarFor(tz)
        let comps = cal.dateComponents([.year, .month, .day], from: day)
        let midnight = cal.startOfDay(for: day)
        let tzOffsetHours = Double(tz.secondsFromGMT(for: midnight.addingTimeInterval(12 * 3600))) / 3600.0
        let lat = region.lat
        let lng = region.lng
        let jd = julian(comps.year ?? 2026, comps.month ?? 1, comps.day ?? 1) - lng / (15.0 * 24.0)

        func midDay(_ t: Double) -> Double {
            let eqt = sunPosition(jd + t).eqt
            return fixHour(12.0 - eqt)
        }

        func angleTime(_ angle: Double, _ t: Double, ccw: Bool) -> Double {
            let decl = sunPosition(jd + t).decl
            let noon = midDay(t)
            let inner = (-sinD(angle) - sinD(decl) * sinD(lat)) / (cosD(decl) * cosD(lat))
            let clamped = min(1.0, max(-1.0, inner))
            let tt = deg(acos(clamped)) / 15.0
            return noon + (ccw ? -tt : tt)
        }

        func asrTime(_ factor: Double, _ t: Double) -> Double {
            let decl = sunPosition(jd + t).decl
            let angle = -deg(atan(1.0 / (factor + tan(rad(abs(lat - decl))))))
            return angleTime(angle, t, ccw: false)
        }

        // fajr, sunrise, dhuhr, asr, maghrib, isha (hours, local time guesses)
        var res: [Double] = [5, 6, 12, 13, 18, 18]
        let shift = tzOffsetHours - lng / 15.0

        for _ in 0..<2 {
            let t = res.map { $0 / 24.0 }
            var r = [Double](repeating: 0, count: 6)
            r[0] = angleTime(settings.fajrAngle, t[0], ccw: true)
            r[1] = angleTime(0.833, t[1], ccw: true)
            r[2] = midDay(t[2])
            r[3] = asrTime(settings.hanafiAsr ? 2.0 : 1.0, t[3])
            r[4] = angleTime(0.833, t[4], ccw: false)
            r[5] = angleTime(settings.ishaAngle, t[5], ccw: false)
            res = r.map { $0 + shift }
            if settings.ishaMinutes > 0 {
                var mins = settings.ishaMinutes
                var hj = Calendar(identifier: .islamicUmmAlQura)
                hj.timeZone = tz
                if mins == 90 && hj.component(.month, from: day) == 9 { mins = 120 }
                res[5] = res[4] + mins / 60.0
            }
        }

        var out: [Prayer: Date] = [:]
        for p in Prayer.allCases {
            let i = p.rawValue
            let adj = i < settings.adjust.count ? settings.adjust[i] : 0
            let minutes = Int((res[i] * 60.0).rounded()) + adj
            out[p] = midnight.addingTimeInterval(Double(minutes) * 60.0)
        }
        return DayTimes(times: out)
    }

    /// Next of the five prayers strictly after `now`.
    static func next(after now: Date, region: Region, settings: CalcSettings) -> (prayer: Prayer, date: Date) {
        let cal = calendarFor(region.timeZone)
        for off in 0...2 {
            let day = cal.date(byAdding: .day, value: off, to: now) ?? now
            let dt = compute(day: day, region: region, settings: settings)
            for p in Prayer.fivePrayers {
                if dt[p] > now { return (p, dt[p]) }
            }
        }
        return (.fajr, now)
    }

    /// Latest of the five prayers at or before `now`.
    static func previous(before now: Date, region: Region, settings: CalcSettings) -> (prayer: Prayer, date: Date) {
        let cal = calendarFor(region.timeZone)
        for off in [0, -1, -2] {
            let day = cal.date(byAdding: .day, value: off, to: now) ?? now
            let dt = compute(day: day, region: region, settings: settings)
            for p in Prayer.fivePrayers.reversed() {
                if dt[p] <= now { return (p, dt[p]) }
            }
        }
        return (.isha, now)
    }

    /// اتجاه القبلة بالدرجات من الشمال الحقيقي
    static func qiblaBearing(lat: Double, lng: Double) -> Double {
        let kaabaLat = 21.4225 * Double.pi / 180.0
        let kaabaLng = 39.8262
        let p1 = lat * Double.pi / 180.0
        let dl = (kaabaLng - lng) * Double.pi / 180.0
        let y = sin(dl) * cos(kaabaLat)
        let x = cos(p1) * sin(kaabaLat) - sin(p1) * cos(kaabaLat) * cos(dl)
        let deg = atan2(y, x) * 180.0 / Double.pi
        return (deg + 360.0).truncatingRemainder(dividingBy: 360.0)
    }

    static func isFriday(_ d: Date) -> Bool {
        calendar.component(.weekday, from: d) == 6
    }
}
