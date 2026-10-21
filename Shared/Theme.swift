import SwiftUI
import UIKit

enum Theme {
    // الهوية: أخضر زمردي داكن، أخضر ليلي، عاجي، ولمسات ذهبية
    static let gold = Color(red: 0.96, green: 0.80, blue: 0.46)
    static let emerald = Color(red: 0.05, green: 0.42, blue: 0.34)
    static let emeraldDeep = Color(red: 0.02, green: 0.20, blue: 0.18)
    static let ivory = Color(red: 0.98, green: 0.96, blue: 0.90)

    // ألوان تتكيف مع الوضع الفاتح والداكن (للشاشات غير الرئيسية)
    static let ink = Color(UIColor { (t: UITraitCollection) -> UIColor in
        t.userInterfaceStyle == .dark ? UIColor.white : UIColor(red: 0.04, green: 0.20, blue: 0.17, alpha: 1)
    })
    static let inkSecondary = Color(UIColor { (t: UITraitCollection) -> UIColor in
        t.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.65)
            : UIColor(red: 0.04, green: 0.20, blue: 0.17, alpha: 0.65)
    })
    static let accent = Color(UIColor { (t: UITraitCollection) -> UIColor in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.96, green: 0.80, blue: 0.46, alpha: 1)
            : UIColor(red: 0.05, green: 0.42, blue: 0.34, alpha: 1)
    })

    // سماء الصفحة الرئيسية حسب وقت اليوم (بنَفَس زمردي)
    static let night: [Color] = [Color(red: 0.01, green: 0.08, blue: 0.09), Color(red: 0.03, green: 0.19, blue: 0.18)]
    static let dawn: [Color] = [Color(red: 0.05, green: 0.20, blue: 0.25), Color(red: 0.78, green: 0.58, blue: 0.42)]
    static let day: [Color] = [Color(red: 0.02, green: 0.36, blue: 0.34), Color(red: 0.30, green: 0.66, blue: 0.58)]
    static let afternoon: [Color] = [Color(red: 0.05, green: 0.34, blue: 0.34), Color(red: 0.86, green: 0.64, blue: 0.34)]
    static let dusk: [Color] = [Color(red: 0.10, green: 0.18, blue: 0.28), Color(red: 0.72, green: 0.40, blue: 0.30)]

    /// ألوان الخلفية حسب وقت اليوم
    static func colors(now: Date, today: DayTimes) -> [Color] {
        if now < today[.fajr] { return night }
        if now < today[.sunrise] { return dawn }
        if now < today[.asr] { return day }
        if now < today[.maghrib] { return afternoon }
        if now < today[.isha] { return dusk }
        return night
    }

    static func isNight(now: Date, today: DayTimes) -> Bool {
        now < today[.fajr] || now >= today[.isha]
    }

    /// شدة النجوم: ليل كامل ١، فجر/غروب نصف
    static func starIntensity(now: Date, today: DayTimes) -> Double {
        if isNight(now: now, today: today) { return 1.0 }
        if now < today[.sunrise] { return 0.45 }
        if now >= today[.maghrib] { return 0.5 }
        return 0.0
    }

    static func gradient(now: Date, today: DayTimes) -> LinearGradient {
        LinearGradient(colors: colors(now: now, today: today), startPoint: .top, endPoint: .bottom)
    }
}

/// زخرفة خفيفة للويدجت: توهج شمس/قمر ونجوم ثابتة
struct SkyDecoration: View {
    let night: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Theme.gold.opacity(night ? 0.18 : 0.40), Color.clear],
                                     center: .center, startRadius: 0, endRadius: 90))
                .frame(width: 180, height: 180)
                .offset(x: 70, y: -60)
            if night {
                ForEach(0..<14, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: i % 3 == 0 ? 2.5 : 1.5, height: i % 3 == 0 ? 2.5 : 1.5)
                        .offset(x: CGFloat((i * 53) % 160) - 80, y: CGFloat((i * 37) % 120) - 60)
                }
            }
        }
    }
}
