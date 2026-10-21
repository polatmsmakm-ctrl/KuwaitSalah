import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var adhkar: AdhkarStore
    @AppStorage("tasbih.total") private var tasbihTotal: Int = 0

    private var days: [Date] {
        (0..<7).reversed().compactMap { PrayerCalc.calendar.date(byAdding: .day, value: -$0, to: Date()) }
    }

    private func prayedCount(_ d: Date) -> Int {
        Prayer.fivePrayers.filter { store.isPrayed(d, $0) }.count
    }

    /// أيام متتالية اكتملت فيها الصلوات الخمس (اليوم لا يكسر السلسلة إن لم يكتمل بعد)
    private var streak: Int {
        var n = 0
        var d = Date()
        if prayedCount(d) < 5 { d = PrayerCalc.calendar.date(byAdding: .day, value: -1, to: d) ?? d }
        while prayedCount(d) == 5 && n < 3650 {
            n += 1
            d = PrayerCalc.calendar.date(byAdding: .day, value: -1, to: d) ?? d
        }
        return n
    }

    var body: some View {
        let fmt = store.fmt
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 14) {
                    if !store.prefs.statsEnabled {
                        VStack(spacing: 10) {
                            Image(systemName: "chart.bar.fill").font(.largeTitle).foregroundStyle(Theme.accent)
                            Text("تتبّع صلواتك وأذكارك").font(.headline)
                            Text("اختياري، وتبقى البيانات على جهازك فقط. عند التفعيل تظهر علامة ✓ بجانب كل صلاة في الصفحة الرئيسية لتعلّم ما أديته.")
                                .font(.footnote)
                                .foregroundStyle(Theme.inkSecondary)
                                .multilineTextAlignment(.center)
                            Button("تفعيل الإحصائيات") { store.prefs.statsEnabled = true }
                                .buttonStyle(.borderedProminent)
                        }
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .glassCard()
                    } else {
                        HStack(spacing: 12) {
                            stat("سلسلة الأيام", fmt.number(streak), "flame.fill")
                            stat("أذكار اليوم", fmt.number(adhkar.completedCategories(on: Date())), "sparkles")
                            stat("تسبيح", fmt.number(tasbihTotal), "circle.hexagongrid.fill")
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("آخر ٧ أيام").font(.headline)
                            ForEach(days, id: \.self) { d in
                                HStack {
                                    Text(fmt.custom(d, "EEEE d MMM"))
                                        .font(.footnote)
                                        .frame(width: 110, alignment: .leading)
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.primary.opacity(0.1))
                                            Capsule().fill(Theme.accent)
                                                .frame(width: geo.size.width * CGFloat(prayedCount(d)) / 5.0)
                                        }
                                    }
                                    .frame(height: 8)
                                    Text("\(fmt.number(prayedCount(d)))/\(fmt.number(5))")
                                        .font(.footnote.monospacedDigit())
                                        .frame(width: 40)
                                }
                            }
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(16)
                        .glassCard()

                        Button(role: .destructive) {
                            store.prayed = []
                        } label: {
                            Text("مسح سجل الصلوات")
                        }
                        .font(.footnote)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("الإحصائيات")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(Theme.accent)
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(Theme.inkSecondary)
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassCard(18)
    }
}
