import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - آية اليوم

struct AyahEntry: TimelineEntry {
    let date: Date
    let text: String
    let caption: String
}

enum AyahWidgetData {
    private struct Raw: Decodable { let surahs: [S] }
    private struct S: Decodable { let n: Int; let name: String; let a: [String] }

    static func make(at date: Date) -> AyahEntry {
        let t = AyahPicks.today(date)
        guard let url = Bundle.main.url(forResource: "quran", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode(Raw.self, from: data),
              t.s >= 1, t.s <= raw.surahs.count else {
            return AyahEntry(date: date, text: "إِنَّ مَعَ الْعُسْرِ يُسْرًا", caption: "الشرح · ٦")
        }
        let s = raw.surahs[t.s - 1]
        let text = t.a >= 1 && t.a <= s.a.count ? s.a[t.a - 1] : ""
        return AyahEntry(date: date, text: text, caption: "\(s.name) · \(t.a)")
    }
}

struct AyahProvider: TimelineProvider {
    func placeholder(in context: Context) -> AyahEntry { AyahWidgetData.make(at: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (AyahEntry) -> Void) {
        completion(AyahWidgetData.make(at: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AyahEntry>) -> Void) {
        let now = Date()
        let tomorrow = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now)
        completion(Timeline(entries: [AyahWidgetData.make(at: now)], policy: .after(tomorrow)))
    }
}

struct AyahWidgetView: View {
    let entry: AyahEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(spacing: 6) {
            Text(entry.text)
                .font(.custom("Geeza Pro", size: family == .systemSmall ? 14 : 19))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .foregroundStyle(.white)
                .environment(\.layoutDirection, .rightToLeft)
            Text(entry.caption)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.gold)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) { WidgetNebula(name: "wd_pillar") }
    }
}

struct AyahWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AyahWidget", provider: AyahProvider()) { entry in
            AyahWidgetView(entry: entry)
        }
        .configurationDisplayName("آية اليوم")
        .description("آية مختارة تتجدد كل يوم")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Live Activity (الصلاة القادمة على شاشة القفل)

struct PrayerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerActivityAttributes.self) { ctx in
            HStack {
                VStack(alignment: .leading) {
                    Text("الصلاة القادمة").font(.caption).foregroundStyle(.white.opacity(0.7))
                    Text(ctx.state.prayerName).font(.title2.bold()).foregroundStyle(Theme.gold)
                }
                Spacer()
                Text(ctx.state.time, style: .timer)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.white)
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.05, green: 0.06, blue: 0.18))
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text(ctx.state.prayerName).foregroundStyle(Theme.gold) }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(ctx.state.time, style: .timer).monospacedDigit().frame(maxWidth: 80)
                }
            } compactLeading: {
                Text(ctx.state.prayerName).font(.caption2)
            } compactTrailing: {
                Text(ctx.state.time, style: .timer).monospacedDigit().frame(maxWidth: 48).font(.caption2)
            } minimal: {
                Image(systemName: "moon.stars.fill")
            }
        }
    }
}
