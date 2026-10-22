import SwiftUI

enum AyahOfDay {
    static func today(_ date: Date = Date()) -> AyahRef {
        let t = AyahPicks.today(date)
        return AyahRef(s: t.s, a: t.a)
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
