import SwiftUI

struct TimetableView: View {
    @EnvironmentObject var store: Store
    @State private var monthOffset: Int = 0

    private var cal: Calendar { PrayerCalc.calendar }

    private func daysOfMonth() -> [Date] {
        let base = cal.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
        let comps = cal.dateComponents([.year, .month], from: base)
        guard let start = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: start) else { return [] }
        return range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: start) }
    }

    var body: some View {
        let fmt = store.fmt
        let days = daysOfMonth()
        let title = days.first.map { fmt.custom($0, "MMMM yyyy") } ?? ""

        ZStack {
            AppBackground(kind: .more)
            VStack(spacing: 10) {
                HStack {
                    Button {
                        monthOffset -= 1
                    } label: {
                        Image(systemName: "chevron.right.circle.fill").font(.title2)
                    }
                    Spacer()
                    Text(title).font(.title3.bold())
                    Spacer()
                    Button {
                        monthOffset += 1
                    } label: {
                        Image(systemName: "chevron.left.circle.fill").font(.title2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                headerRow
                    .padding(.horizontal, 8)

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(days, id: \.self) { d in
                            dayRow(d, fmt: fmt)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 16)
                }
            }
            .foregroundStyle(Theme.ink)
        }
        .navigationTitle("الجدول الشهري")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(["اليوم", "الفجر", "الشروق", "الظهر", "العصر", "المغرب", "العشاء"], id: \.self) { t in
                Text(t)
                    .font(.system(size: 11, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .opacity(0.75)
            }
        }
    }

    private func dayRow(_ d: Date, fmt: Fmt) -> some View {
        let dt = PrayerCalc.compute(day: d, region: store.region, settings: store.calc)
        let isToday = cal.isDateInToday(d)
        let friday = PrayerCalc.isFriday(d)
        let dayNum = fmt.custom(d, "d")
        let wk = fmt.custom(d, "EEE")

        return HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(dayNum).font(.system(size: 13, weight: .bold))
                Text(wk).font(.system(size: 9)).opacity(0.7)
            }
            .frame(maxWidth: .infinity)

            ForEach(Prayer.allCases) { p in
                Text(fmt.timeShort(dt[p]))
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isToday ? AnyShapeStyle(Theme.gold.opacity(0.32))
                              : (friday ? AnyShapeStyle(Color.primary.opacity(0.12)) : AnyShapeStyle(.ultraThinMaterial)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isToday ? Theme.gold : Color.clear, lineWidth: 1.2)
        )
    }
}
