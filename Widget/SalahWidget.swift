import WidgetKit
import SwiftUI

// الويدجت يحسب الأوقات بنفسه (مدينة الكويت، طريقة الكويت).
// الإقامة هنا بالقيم الافتراضية في Shared/Iqama.swift لأن الحساب المجاني لا يدعم مشاركة الإعدادات بين التطبيق والويدجت.

struct SalahEntry: TimelineEntry {
    let date: Date
    let today: DayTimes
    let next: Prayer
    let nextDate: Date

    static let region = Region.all[0]
    static let calc = CalcSettings()

    static func make(at date: Date) -> SalahEntry {
        let today = PrayerCalc.compute(day: date, region: region, settings: calc)
        let nxt = PrayerCalc.next(after: date, region: region, settings: calc)
        return SalahEntry(date: date, today: today, next: nxt.prayer, nextDate: nxt.date)
    }
}

struct SalahProvider: TimelineProvider {
    func placeholder(in context: Context) -> SalahEntry {
        SalahEntry.make(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SalahEntry) -> Void) {
        completion(SalahEntry.make(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SalahEntry>) -> Void) {
        let now = Date()
        var dates: [Date] = [now]
        for off in 0...1 {
            let day = PrayerCalc.calendar.date(byAdding: .day, value: off, to: now) ?? now
            let dt = PrayerCalc.compute(day: day, region: SalahEntry.region, settings: SalahEntry.calc)
            for p in Prayer.allCases {
                let t = dt[p]
                if t > now { dates.append(t) }
            }
        }
        dates.sort()
        let entries = dates.map { SalahEntry.make(at: $0) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Views

struct SalahWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SalahEntry
    private let fmt = Fmt(use24h: false, arabicDigits: true)

    private var friday: Bool { PrayerCalc.isFriday(entry.nextDate) }

    private var nextName: String {
        (entry.next == .dhuhr && friday) ? "الجمعة" : entry.next.arabicName
    }

    private var nextIqama: Date? {
        if entry.next == .dhuhr && friday { return nil }
        return Iqama.time(entry.next, adhan: entry.nextDate, list: Iqama.defaults)
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                small
            case .systemMedium:
                medium
            case .systemLarge:
                large
            case .accessoryCircular:
                circular
            case .accessoryRectangular:
                rectangular
            case .accessoryInline:
                Text("\(nextName) \(fmt.time(entry.nextDate))")
            default:
                small
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .containerBackground(for: .widget) {
            Theme.gradient(now: entry.date, today: entry.today)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("الصلاة القادمة")
                .font(.caption2)
                .opacity(0.8)
            Text(nextName)
                .font(.system(size: 30, weight: .bold))
            Text(fmt.time(entry.nextDate))
                .font(.headline)
            Spacer(minLength: 2)
            Text(entry.nextDate, style: .timer)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.gold)
            if let iq = nextIqama {
                Text("الإقامة \(fmt.time(iq))")
                    .font(.caption2)
                    .opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(nextName) بعد")
                    .font(.subheadline.weight(.semibold))
                Text(entry.nextDate, style: .timer)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.gold)
                Spacer()
                Text("الكويت")
                    .font(.caption2)
                    .opacity(0.7)
            }
            HStack(spacing: 4) {
                ForEach(Prayer.fivePrayers) { p in
                    column(p)
                }
            }
        }
        .foregroundStyle(.white)
    }

    private var large: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("الصلاة القادمة")
                    .font(.caption)
                    .opacity(0.8)
                Text(nextName)
                    .font(.system(size: 38, weight: .bold))
                Text(fmt.time(entry.nextDate))
                    .font(.title3)
                Text(entry.nextDate, style: .timer)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.gold)
            }
            VStack(spacing: 0) {
                ForEach(Prayer.allCases) { p in
                    largeRow(p)
                }
            }
            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        }
        .foregroundStyle(.white)
    }

    private func largeRow(_ p: Prayer) -> some View {
        let adhan = entry.today[p]
        let isFridayDhuhr = p == .dhuhr && PrayerCalc.isFriday(adhan)
        let isNext = p == entry.next
        return HStack {
            Image(systemName: p.symbol)
                .frame(width: 24)
                .foregroundStyle(isNext ? Theme.gold : Color.white)
            Text(isFridayDhuhr ? "الجمعة" : p.arabicName)
                .font(.subheadline.weight(isNext ? .bold : .regular))
            Spacer()
            Text(fmt.time(adhan))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            if !isFridayDhuhr, let iq = Iqama.time(p, adhan: adhan, list: Iqama.defaults) {
                Text(fmt.time(iq))
                    .font(.caption)
                    .opacity(0.7)
                    .monospacedDigit()
                    .frame(width: 64, alignment: .trailing)
            } else {
                Text("")
                    .frame(width: 64)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isNext ? Color.white.opacity(0.14) : Color.clear)
    }

    private func column(_ p: Prayer) -> some View {
        let isNext = p == entry.next
        let adhan = entry.today[p]
        let isFridayDhuhr = p == .dhuhr && PrayerCalc.isFriday(adhan)
        return VStack(spacing: 4) {
            Image(systemName: p.symbol)
                .font(.caption)
                .foregroundStyle(isNext ? Theme.gold : Color.white)
            Text(isFridayDhuhr ? "الجمعة" : p.arabicName)
                .font(.caption.bold())
            Text(fmt.time(adhan))
                .font(.caption2)
                .monospacedDigit()
            if isFridayDhuhr {
                Text("—").font(.caption2).opacity(0.7)
            } else if let iq = Iqama.time(p, adhan: adhan, list: Iqama.defaults) {
                Text(fmt.time(iq))
                    .font(.caption2)
                    .opacity(0.7)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(isNext ? Color.white.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(nextName)
                    .font(.system(size: 12, weight: .bold))
                Text(fmt.timeShort(entry.nextDate))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(nextName).font(.headline)
            Text(fmt.time(entry.nextDate)).font(.subheadline)
            if let iq = nextIqama {
                Text("الإقامة \(fmt.time(iq))").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget

@main
struct SalahWidgetBundle: WidgetBundle {
    var body: some Widget {
        SalahWidget()
    }
}

struct SalahWidget: Widget {
    let kind = "SalahWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SalahProvider()) { entry in
            SalahWidgetView(entry: entry)
        }
        .configurationDisplayName("أوقات الصلاة")
        .description("الصلاة القادمة مع العد التنازلي ووقت الإقامة")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
