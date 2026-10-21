import SwiftUI

struct HomeView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            HomeContent(now: ctx.date)
        }
    }
}

struct HomeContent: View {
    @EnvironmentObject var store: Store
    let now: Date

    var body: some View {
        let region = store.region
        let calc = store.prefs.calc
        let today = PrayerCalc.compute(day: now, region: region, settings: calc)
        let nxt = PrayerCalc.next(after: now, region: region, settings: calc)
        let prv = PrayerCalc.previous(before: now, region: region, settings: calc)

        ZStack {
            Theme.gradient(now: now, today: today)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    HeaderView(now: now, regionName: region.name)
                    HeroView(now: now, nxt: nxt, prv: prv)
                    PrayerListView(now: now, today: today, nxt: nxt)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .foregroundStyle(.white)
    }
}

struct HeaderView: View {
    @EnvironmentObject var store: Store
    let now: Date
    let regionName: String

    var body: some View {
        let fmt = store.fmt
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                Text("الكويت · \(regionName)")
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.15), in: Capsule())

            Text(fmt.hijri(now, offset: store.prefs.hijriOffset))
                .font(.system(size: 28, weight: .bold))
            Text(fmt.gregorian(now))
                .font(.subheadline)
                .opacity(0.8)
        }
        .padding(.top, 8)
    }
}

struct HeroView: View {
    @EnvironmentObject var store: Store
    let now: Date
    let nxt: (prayer: Prayer, date: Date)
    let prv: (prayer: Prayer, date: Date)

    private var progress: Double {
        let total = nxt.date.timeIntervalSince(prv.date)
        guard total > 0 else { return 0 }
        return min(1.0, max(0.0, now.timeIntervalSince(prv.date) / total))
    }

    var body: some View {
        let fmt = store.fmt
        let nextFriday = nxt.prayer == .dhuhr && PrayerCalc.isFriday(nxt.date)

        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.gold, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Text("الصلاة القادمة")
                        .font(.footnote)
                        .opacity(0.8)
                    Text(nextFriday ? "الجمعة" : nxt.prayer.arabicName)
                        .font(.system(size: 44, weight: .bold))
                    Text(fmt.time(nxt.date))
                        .font(.title3)
                    Text(fmt.countdown(nxt.date.timeIntervalSince(now)))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
            }
            .frame(width: 270, height: 270)
            .padding(.top, 8)

            iqamaLine(fmt: fmt, nextFriday: nextFriday)
        }
    }

    @ViewBuilder
    private func iqamaLine(fmt: Fmt, nextFriday: Bool) -> some View {
        let list = store.prefs.iqama
        let prevFriday = prv.prayer == .dhuhr && PrayerCalc.isFriday(prv.date)
        if !prevFriday, let t = Iqama.time(prv.prayer, adhan: prv.date, list: list), t > now {
            pill("إقامة \(prv.prayer.arabicName) بعد \(fmt.countdown(t.timeIntervalSince(now)))")
        } else if !nextFriday, let t = Iqama.time(nxt.prayer, adhan: nxt.date, list: list) {
            pill("إقامة \(nxt.prayer.arabicName) الساعة \(fmt.time(t))")
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.callout.weight(.medium))
            .monospacedDigit()
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.16), in: Capsule())
    }
}

struct PrayerListView: View {
    @EnvironmentObject var store: Store
    let now: Date
    let today: DayTimes
    let nxt: (prayer: Prayer, date: Date)

    var body: some View {
        let fmt = store.fmt
        let friday = PrayerCalc.isFriday(now)
        let list = store.prefs.iqama

        VStack(spacing: 0) {
            ForEach(Prayer.allCases) { p in
                let adhan = today[p]
                let isFridayDhuhr = p == .dhuhr && friday
                let iq: String = {
                    if isFridayDhuhr { return "" }
                    if let t = Iqama.time(p, adhan: adhan, list: list) { return fmt.time(t) }
                    return ""
                }()
                PrayerRow(
                    name: isFridayDhuhr ? "الجمعة" : p.arabicName,
                    symbol: p.symbol,
                    adhan: fmt.time(adhan),
                    iqama: iq,
                    passed: adhan <= now,
                    isNext: p == nxt.prayer && PrayerCalc.calendar.isDate(nxt.date, inSameDayAs: adhan)
                )
                if p != .isha {
                    Divider().overlay(Color.white.opacity(0.12))
                }
            }
        }
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct PrayerRow: View {
    let name: String
    let symbol: String
    let adhan: String
    let iqama: String
    let passed: Bool
    let isNext: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 28)
                .foregroundStyle(isNext ? Theme.gold : Color.white)
            Text(name)
                .font(.system(size: 18, weight: isNext ? .bold : .medium))
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(adhan)
                    .font(.system(size: 18, weight: .semibold))
                    .monospacedDigit()
                if !iqama.isEmpty {
                    Text("إقامة \(iqama)")
                        .font(.caption2)
                        .opacity(0.7)
                        .monospacedDigit()
                }
            }
            if passed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green.opacity(0.85))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .opacity(passed ? 0.6 : 1.0)
        .background(isNext ? Color.white.opacity(0.14) : Color.clear)
    }
}
