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

    private func arcInfo(today: DayTimes, fmt: Fmt) -> (progress: Double, isDay: Bool, left: String, right: String) {
        let region = store.region
        let calc = store.prefs.calc
        let cal = PrayerCalc.calendar

        if now >= today[.sunrise] && now < today[.maghrib] {
            let total = today[.maghrib].timeIntervalSince(today[.sunrise])
            let p = total > 0 ? now.timeIntervalSince(today[.sunrise]) / total : 0
            return (p, true, "الشروق \(fmt.time(today[.sunrise]))", "المغرب \(fmt.time(today[.maghrib]))")
        }

        let start: Date
        let end: Date
        if now >= today[.maghrib] {
            let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
            let tt = PrayerCalc.compute(day: tomorrow, region: region, settings: calc)
            start = today[.maghrib]
            end = tt[.sunrise]
        } else {
            let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
            let yt = PrayerCalc.compute(day: yesterday, region: region, settings: calc)
            start = yt[.maghrib]
            end = today[.sunrise]
        }
        let total = end.timeIntervalSince(start)
        let p = total > 0 ? now.timeIntervalSince(start) / total : 0
        return (p, false, "المغرب \(fmt.time(start))", "الشروق \(fmt.time(end))")
    }

    var body: some View {
        let region = store.region
        let calc = store.prefs.calc
        let fmt = store.fmt
        let today = PrayerCalc.compute(day: now, region: region, settings: calc)
        let nxt = PrayerCalc.next(after: now, region: region, settings: calc)
        let prv = PrayerCalc.previous(before: now, region: region, settings: calc)
        let arc = arcInfo(today: today, fmt: fmt)

        ZStack {
            SkyBackground(now: now, today: today)
            ScrollView {
                VStack(spacing: 16) {
                    HeaderView(now: now, regionName: region.name)
                    SkyArc(progress: arc.progress, isDay: arc.isDay, leftLabel: arc.left, rightLabel: arc.right)
                    HeroView(now: now, nxt: nxt, prv: prv)
                    PrayerListView(now: now, today: today, nxt: nxt)
                    DhikrCard(now: now)
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
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                    Text("الكويت · \(regionName)")
                }
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15), in: Capsule())

                if PrayerCalc.isFriday(now) {
                    Text("جمعة مباركة")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.black.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.gold, in: Capsule())
                }
            }

            Text(fmt.hijri(now, offset: store.prefs.hijriOffset))
                .font(.system(size: 30, weight: .bold))
                .shadow(color: Color.black.opacity(0.25), radius: 6)
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
        let remaining = nxt.date.timeIntervalSince(now)
        let glow: Double = remaining < 300 ? 12.0 + 8.0 * sin(now.timeIntervalSinceReferenceDate * 3.0) : 10.0
        let countdown = fmt.countdown(remaining)

        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .padding(14)

                ForEach(0..<60, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(i % 5 == 0 ? 0.45 : 0.18))
                        .frame(width: i % 5 == 0 ? 2 : 1, height: i % 5 == 0 ? 8 : 4)
                        .offset(y: -128)
                        .rotationEffect(.degrees(Double(i) * 6.0))
                }

                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 8)
                    .padding(22)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: [Theme.gold.opacity(0.6), Color.orange, Theme.gold],
                                        center: .center, startAngle: .degrees(0), endAngle: .degrees(360)),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(22)
                    .shadow(color: Theme.gold.opacity(0.7), radius: glow)

                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: Theme.gold, radius: 8)
                    .offset(y: -113)
                    .rotationEffect(.degrees(progress * 360.0))

                VStack(spacing: 4) {
                    Text("الصلاة القادمة")
                        .font(.footnote)
                        .opacity(0.8)
                    Text(nextFriday ? "الجمعة" : nxt.prayer.arabicName)
                        .font(.system(size: 46, weight: .bold))
                        .shadow(color: Color.black.opacity(0.25), radius: 6)
                    Text(fmt.time(nxt.date))
                        .font(.title3)
                        .opacity(0.9)
                    Text(countdown)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.gold)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.easeInOut(duration: 0.25), value: countdown)
                }
            }
            .frame(width: 290, height: 290)

            iqamaLine(fmt: fmt, nextFriday: nextFriday)
        }
    }

    @ViewBuilder
    private func iqamaLine(fmt: Fmt, nextFriday: Bool) -> some View {
        let list = store.prefs.iqama
        let prevFriday = prv.prayer == .dhuhr && PrayerCalc.isFriday(prv.date)
        if !prevFriday, let t = Iqama.time(prv.prayer, adhan: prv.date, list: list), t > now {
            pill("إقامة \(prv.prayer.arabicName) بعد \(fmt.countdown(t.timeIntervalSince(now)))", icon: "timer")
        } else if !nextFriday, let t = Iqama.time(nxt.prayer, adhan: nxt.date, list: list) {
            pill("إقامة \(nxt.prayer.arabicName) الساعة \(fmt.time(t))", icon: "bell.fill")
        }
    }

    private func pill(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Theme.gold)
            Text(text).monospacedDigit()
        }
        .font(.callout.weight(.medium))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .glassCard(30)
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

        VStack(spacing: 8) {
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
                    isNext: p == nxt.prayer && PrayerCalc.calendar.isDate(nxt.date, inSameDayAs: adhan),
                    small: p == .sunrise
                )
            }
        }
    }
}

struct PrayerRow: View {
    let name: String
    let symbol: String
    let adhan: String
    let iqama: String
    let passed: Bool
    let isNext: Bool
    let small: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isNext ? AnyShapeStyle(Theme.gold) : AnyShapeStyle(Color.white.opacity(0.14)))
                    .frame(width: 38, height: 38)
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isNext ? Color.black.opacity(0.8) : Color.white)
            }
            Text(name)
                .font(.system(size: small ? 16 : 19, weight: isNext ? .bold : .medium))
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(adhan)
                    .font(.system(size: small ? 16 : 19, weight: .semibold))
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
        .padding(.horizontal, 14)
        .padding(.vertical, small ? 8 : 11)
        .opacity(passed ? 0.6 : 1.0)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isNext ? AnyShapeStyle(LinearGradient(colors: [Theme.gold.opacity(0.35), Color.orange.opacity(0.18)],
                                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                             : AnyShapeStyle(.ultraThinMaterial))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isNext ? Theme.gold.opacity(0.85) : Color.white.opacity(0.08), lineWidth: isNext ? 1.5 : 1)
        )
        .shadow(color: isNext ? Theme.gold.opacity(0.35) : Color.clear, radius: 10)
    }
}

struct DhikrCard: View {
    let now: Date

    private let items: [String] = [
        "سبحان الله وبحمده، سبحان الله العظيم",
        "لا حول ولا قوة إلا بالله",
        "أستغفر الله وأتوب إليه",
        "اللهم صلِّ وسلِّم على نبينا محمد",
        "حسبي الله لا إله إلا هو عليه توكلت وهو رب العرش العظيم",
        "رب اشرح لي صدري ويسر لي أمري",
        "لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير"
    ]

    var body: some View {
        let idx = PrayerCalc.calendar.ordinality(of: .day, in: .year, for: now) ?? 0
        VStack(spacing: 8) {
            Label("ذكر اليوم", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.gold)
            Text(items[idx % items.count])
                .font(.system(size: 20, weight: .medium))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .glassCard()
    }
}
