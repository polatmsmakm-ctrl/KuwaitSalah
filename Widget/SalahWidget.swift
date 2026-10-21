import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration (اختيار المسجد من تعديل الويدجت)

struct MosqueEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "المسجد"
    static let defaultQuery = MosqueQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(_ m: Mosque) {
        self.id = m.id
        self.name = m.name
    }
}

struct MosqueQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [MosqueEntity] {
        Mosque.presets.filter { identifiers.contains($0.id) }.map { MosqueEntity($0) }
    }

    func suggestedEntities() async throws -> [MosqueEntity] {
        Mosque.presets.map { MosqueEntity($0) }
    }

    func defaultResult() async -> MosqueEntity? {
        Mosque.presets.first.map { MosqueEntity($0) }
    }
}

struct SelectMosqueIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "اختيار المسجد"
    static let description = IntentDescription("اختر المسجد لعرض وقت الإقامة")

    @Parameter(title: "المسجد")
    var mosque: MosqueEntity?
}

// MARK: - Timeline

struct SalahEntry: TimelineEntry {
    let date: Date
    let mosque: Mosque
    let today: DayTimes
    let next: Prayer
    let nextDate: Date

    static let region = Region.all[0]
    static let calc = CalcSettings()

    static func make(at date: Date, mosque: Mosque) -> SalahEntry {
        let today = PrayerCalc.compute(day: date, region: region, settings: calc)
        let nxt = PrayerCalc.next(after: date, region: region, settings: calc)
        return SalahEntry(date: date, mosque: mosque, today: today, next: nxt.prayer, nextDate: nxt.date)
    }
}

struct SalahProvider: AppIntentTimelineProvider {
    typealias Entry = SalahEntry
    typealias Intent = SelectMosqueIntent

    private func mosque(for config: SelectMosqueIntent) -> Mosque {
        if let id = config.mosque?.id, let m = Mosque.presets.first(where: { $0.id == id }) {
            return m
        }
        return Mosque.presets[0]
    }

    func placeholder(in context: Context) -> SalahEntry {
        SalahEntry.make(at: Date(), mosque: Mosque.presets[0])
    }

    func snapshot(for configuration: SelectMosqueIntent, in context: Context) async -> SalahEntry {
        SalahEntry.make(at: Date(), mosque: mosque(for: configuration))
    }

    func timeline(for configuration: SelectMosqueIntent, in context: Context) async -> Timeline<SalahEntry> {
        let m = mosque(for: configuration)
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
        let entries = dates.map { SalahEntry.make(at: $0, mosque: m) }
        return Timeline(entries: entries, policy: .atEnd)
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
        return entry.mosque.iqamaTime(for: entry.next, adhan: entry.nextDate)
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                small
            case .systemMedium:
                medium
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
            LinearGradient(colors: [Color(red: 0.05, green: 0.40, blue: 0.32),
                                    Color(red: 0.03, green: 0.20, blue: 0.28)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("الصلاة القادمة")
                .font(.caption2)
                .opacity(0.8)
            Text(nextName)
                .font(.title.bold())
            Text(fmt.time(entry.nextDate))
                .font(.headline)
            Spacer(minLength: 2)
            Text(entry.nextDate, style: .timer)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
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
        VStack(spacing: 6) {
            HStack {
                Text(entry.mosque.name)
                    .font(.caption.bold())
                Spacer()
                Text("\(nextName) بعد")
                    .font(.caption)
                Text(entry.nextDate, style: .timer)
                    .font(.caption.bold())
                    .monospacedDigit()
            }
            HStack(spacing: 4) {
                ForEach(Prayer.fivePrayers) { p in
                    column(p)
                }
            }
        }
        .foregroundStyle(.white)
    }

    private func column(_ p: Prayer) -> some View {
        let isNext = p == entry.next
        let adhan = entry.today[p]
        let isFridayDhuhr = p == .dhuhr && PrayerCalc.isFriday(adhan)
        return VStack(spacing: 4) {
            Image(systemName: p.symbol).font(.caption)
            Text(isFridayDhuhr ? "الجمعة" : p.arabicName).font(.caption.bold())
            Text(fmt.time(adhan)).font(.caption2).monospacedDigit()
            if isFridayDhuhr {
                Text("—").font(.caption2).opacity(0.7)
            } else if let iq = entry.mosque.iqamaTime(for: p, adhan: adhan) {
                Text(fmt.time(iq)).font(.caption2).opacity(0.75).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(isNext ? Color.white.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
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
        AppIntentConfiguration(kind: kind, intent: SelectMosqueIntent.self, provider: SalahProvider()) { entry in
            SalahWidgetView(entry: entry)
        }
        .configurationDisplayName("أوقات الصلاة")
        .description("الصلاة القادمة مع وقت الإقامة للمسجد المختار")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}
