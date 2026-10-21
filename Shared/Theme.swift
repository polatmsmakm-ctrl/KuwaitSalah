import SwiftUI

enum Theme {
    static let gold = Color(red: 0.96, green: 0.80, blue: 0.46)

    static let night: [Color] = [Color(red: 0.03, green: 0.05, blue: 0.15), Color(red: 0.09, green: 0.15, blue: 0.34)]
    static let dawn: [Color] = [Color(red: 0.13, green: 0.17, blue: 0.40), Color(red: 0.80, green: 0.50, blue: 0.48)]
    static let day: [Color] = [Color(red: 0.08, green: 0.36, blue: 0.62), Color(red: 0.32, green: 0.66, blue: 0.82)]
    static let afternoon: [Color] = [Color(red: 0.16, green: 0.38, blue: 0.62), Color(red: 0.88, green: 0.62, blue: 0.34)]
    static let dusk: [Color] = [Color(red: 0.26, green: 0.14, blue: 0.38), Color(red: 0.78, green: 0.38, blue: 0.36)]

    /// ألوان الخلفية حسب وقت اليوم
    static func colors(now: Date, today: DayTimes) -> [Color] {
        if now < today[.fajr] { return night }
        if now < today[.sunrise] { return dawn }
        if now < today[.asr] { return day }
        if now < today[.maghrib] { return afternoon }
        if now < today[.isha] { return dusk }
        return night
    }

    static func gradient(now: Date, today: DayTimes) -> LinearGradient {
        LinearGradient(colors: colors(now: now, today: today), startPoint: .top, endPoint: .bottom)
    }
}
