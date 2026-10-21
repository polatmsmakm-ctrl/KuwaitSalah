import Foundation

struct Region: Identifiable, Hashable {
    let id: String
    let name: String
    let lat: Double
    let lng: Double

    static let all: [Region] = [
        Region(id: "capital", name: "العاصمة", lat: 29.3759, lng: 47.9774),
        Region(id: "hawalli", name: "حولي", lat: 29.3328, lng: 48.0286),
        Region(id: "farwaniya", name: "الفروانية", lat: 29.2775, lng: 47.9585),
        Region(id: "mubarak", name: "مبارك الكبير", lat: 29.2120, lng: 48.0600),
        Region(id: "ahmadi", name: "الأحمدي", lat: 29.0769, lng: 48.0838),
        Region(id: "jahra", name: "الجهراء", lat: 29.3375, lng: 47.6581)
    ]
}

/// Defaults follow the Kuwait method: Fajr 18 deg, Isha 17.5 deg.
struct CalcSettings: Codable, Equatable {
    var fajrAngle: Double = 18
    var ishaAngle: Double = 17.5
    var hanafiAsr: Bool = false
    /// Minute adjustments indexed by Prayer.rawValue
    var adjust: [Int] = [0, 0, 0, 0, 0, 0]
}

struct DayTimes {
    let times: [Prayer: Date]
    subscript(_ p: Prayer) -> Date { times[p] ?? Date.distantPast }
}

enum PrayerCalc {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Kuwait") ?? TimeZone(secondsFromGMT: 3 * 3600)!
        return c
    }()

    static let tzOffsetHours: Double = 3.0

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
        let comps = calendar.dateComponents([.year, .month, .day], from: day)
        let midnight = calendar.startOfDay(for: day)
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
        for off in 0...2 {
            let day = calendar.date(byAdding: .day, value: off, to: now) ?? now
            let dt = compute(day: day, region: region, settings: settings)
            for p in Prayer.fivePrayers {
                if dt[p] > now { return (p, dt[p]) }
            }
        }
        return (.fajr, now)
    }

    static func isFriday(_ d: Date) -> Bool {
        calendar.component(.weekday, from: d) == 6
    }
}
