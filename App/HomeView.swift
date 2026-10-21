import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                content(now: ctx.date)
            }
            .navigationTitle("أوقات الصلاة")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let fmt = store.fmt
        let region = store.region
        let mosque = store.selectedMosque
        let calc = store.prefs.calc
        let today = PrayerCalc.compute(day: now, region: region, settings: calc)
        let nxt = PrayerCalc.next(after: now, region: region, settings: calc)
        let friday = PrayerCalc.isFriday(now)

        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text(fmt.hijri(now, offset: store.prefs.hijriOffset))
                        .font(.title3.bold())
                    Text(fmt.gregorian(now))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(region.name) · \(mosque.name)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                nextCard(nxt: nxt, now: now, fmt: fmt, mosque: mosque, friday: friday)

                VStack(spacing: 0) {
                    HStack {
                        Text("").frame(maxWidth: .infinity, alignment: .leading)
                        Text("الأذان").frame(width: 90)
                        Text("الإقامة").frame(width: 90)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    ForEach(Prayer.allCases) { p in
                        row(p: p, today: today, nxt: nxt, fmt: fmt, mosque: mosque, friday: friday)
                        if p != .isha { Divider().padding(.horizontal) }
                    }
                }
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                if mosque.estimated {
                    Text("أوقات الإقامة لهذا المسجد تقديرية. افتح تبويب المساجد وعدّلها.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
    }

    private func nextCard(nxt: (prayer: Prayer, date: Date), now: Date, fmt: Fmt, mosque: Mosque, friday: Bool) -> some View {
        let name = (nxt.prayer == .dhuhr && friday && PrayerCalc.isFriday(nxt.date)) ? "الجمعة" : nxt.prayer.arabicName
        return VStack(spacing: 6) {
            Text("الصلاة القادمة")
                .font(.footnote)
                .opacity(0.85)
            Text(name)
                .font(.system(size: 38, weight: .bold))
            Text(fmt.time(nxt.date))
                .font(.title2.weight(.medium))
            Text(fmt.countdown(nxt.date.timeIntervalSince(now)))
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if let iq = mosque.iqamaTime(for: nxt.prayer, adhan: nxt.date),
               !(nxt.prayer == .dhuhr && PrayerCalc.isFriday(nxt.date)) {
                Text("الإقامة \(fmt.time(iq))")
                    .font(.footnote)
                    .opacity(0.9)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            LinearGradient(colors: [Color(red: 0.05, green: 0.40, blue: 0.32),
                                    Color(red: 0.03, green: 0.22, blue: 0.30)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
    }

    private func row(p: Prayer, today: DayTimes, nxt: (prayer: Prayer, date: Date), fmt: Fmt, mosque: Mosque, friday: Bool) -> some View {
        let isNext = p == nxt.prayer && PrayerCalc.calendar.isDate(nxt.date, inSameDayAs: today[p])
        let isFridayDhuhr = p == .dhuhr && friday
        let iqama: String = {
            if isFridayDhuhr { return "—" }
            if let t = mosque.iqamaTime(for: p, adhan: today[p]) { return fmt.time(t) }
            return "—"
        }()
        return HStack {
            Label(isFridayDhuhr ? "الجمعة" : p.arabicName, systemImage: p.symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.body.weight(isNext ? .bold : .regular))
            Text(fmt.time(today[p]))
                .frame(width: 90)
                .monospacedDigit()
            Text(iqama)
                .frame(width: 90)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(isNext ? Color.accentColor.opacity(0.15) : Color.clear)
    }
}
