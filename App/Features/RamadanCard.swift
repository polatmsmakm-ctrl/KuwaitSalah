import SwiftUI

/// بطاقة رمضان: تظهر تلقائياً في الشهر التاسع الهجري، وتعرض العدّ للإمساك والإفطار.
struct RamadanCard: View {
    @EnvironmentObject var store: Store
    let now: Date

    static func isRamadan(_ date: Date, offset: Int) -> Bool {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = TimeZone(identifier: "Asia/Kuwait") ?? .current
        let d = cal.date(byAdding: .day, value: offset, to: date) ?? date
        return cal.component(.month, from: d) == 9
    }

    var body: some View {
        if Self.isRamadan(now, offset: store.prefs.hijriOffset) {
            let fmt = store.fmt
            let t = PrayerCalc.compute(day: now, region: store.region, settings: store.prefs.calc)
            let imsak = t[.fajr]
            let iftar = t[.maghrib]
            let fasting = now >= imsak && now < iftar
            let target: Date = now < imsak ? imsak : (now < iftar ? iftar : (PrayerCalc.calendar.date(byAdding: .day, value: 1, to: now).map { PrayerCalc.compute(day: $0, region: store.region, settings: store.prefs.calc)[.fajr] } ?? iftar))
            VStack(spacing: 8) {
                Label("رمضان كريم", systemImage: "moon.stars.fill")
                    .font(.headline).foregroundStyle(Theme.gold)
                Text(fasting ? "باقي على الإفطار" : "باقي على الإمساك")
                    .font(.caption).opacity(0.8)
                Text(fmt.countdown(target.timeIntervalSince(now)))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                HStack {
                    Text("الإمساك \(fmt.time(imsak))")
                    Spacer()
                    Text("الإفطار \(fmt.time(iftar))")
                }
                .font(.footnote)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .glassCard(18)
        }
    }
}
