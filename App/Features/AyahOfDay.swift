import SwiftUI

/// آيات مختارة؛ النص يُقرأ من المصحف وليس مكرراً هنا.
enum AyahOfDay {
    static let picks: [AyahRef] = [
        (2,255),(2,286),(3,26),(3,185),(13,28),(94,5),(65,3),(2,152),(39,53),(20,25),
        (59,22),(112,1),(55,13),(36,58),(24,35),(2,45),(93,3),(9,51),(8,46),(33,56),
        (3,173),(2,153),(14,7),(17,9),(57,4),(40,60),(2,186),(25,63),(76,9),(103,1)
    ].map { AyahRef(s: $0.0, a: $0.1) }

    static func today(_ date: Date = Date()) -> AyahRef {
        let d = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return picks[d % picks.count]
    }
}

struct AyahOfDayCard: View {
    @EnvironmentObject var quran: QuranStore
    @EnvironmentObject var store: Store

    var body: some View {
        let ref = AyahOfDay.today()
        if let t = quran.ayahText(ref), let s = quran.surah(ref.s) {
            let caption = "\(s.name) · آية \(store.fmt.number(ref.a))"
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("آية اليوم", systemImage: "sun.max.fill").font(.caption.bold()).foregroundStyle(Theme.accent)
                    Spacer()
                    ShareAyahImageButton(text: t, caption: caption).labelStyle(.iconOnly).font(.callout)
                }
                Text(t)
                    .font(QuranFont.font(quran.fontName, size: max(quran.fontSize - 4, 20)))
                    .lineSpacing(8)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(caption).font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            .padding(14)
            .glassCard(18)
        }
    }
}
