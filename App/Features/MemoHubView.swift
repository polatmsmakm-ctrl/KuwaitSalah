import SwiftUI

struct MemoHubView: View {
    @EnvironmentObject var memo: MemoStore
    @EnvironmentObject var quran: QuranStore
    @EnvironmentObject var store: Store
    @State private var review: MemoItem?

    private func title(_ it: MemoItem, _ fmt: Fmt) -> String {
        let name = quran.surah(it.s)?.name ?? ""
        if it.from == it.to { return "سورة \(name) · آية \(fmt.number(it.from))" }
        return "سورة \(name) · آيات \(fmt.number(it.from))–\(fmt.number(it.to))"
    }

    var body: some View {
        let fmt = store.fmt
        ZStack {
            AppBackground(kind: .quran, dim: 0.55)
            ScrollView {
                VStack(spacing: 14) {
                    stats(fmt)
                    dueSection(fmt)
                    upcomingSection(fmt)
                    weakSection(fmt)
                }
                .padding(16)
            }
        }
        .navigationTitle("مراجعة المحفوظ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $review) { it in
            MemorizeView(start: AyahRef(s: it.s, a: it.from), count: it.to - it.from + 1)
        }
    }

    private func stats(_ fmt: Fmt) -> some View {
        HStack(spacing: 10) {
            stat("flame.fill", fmt.number(memo.streak), "أيام متتالية")
            stat("text.book.closed.fill", fmt.number(memo.totalAyahs), "آية سُمّعت")
            stat("xmark.circle.fill", fmt.number(memo.totalMistakes), "خطأ")
        }
    }

    private func stat(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(Theme.gold)
            Text(value).font(.system(size: 24, weight: .black)).foregroundStyle(Theme.ink)
            Text(label).font(.caption2).foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard(16)
    }

    @ViewBuilder
    private func dueSection(_ fmt: Fmt) -> some View {
        let due = memo.dueItems
        VStack(alignment: .leading, spacing: 10) {
            Text("للمراجعة الآن").font(.headline).foregroundStyle(Theme.ink)
            if due.isEmpty {
                Text(memo.items.isEmpty
                     ? "سمّع أي آية من «الحفظ والتسميع» وتُضاف هنا تلقائياً، وتعود لك للمراجعة في الوقت المناسب."
                     : "لا شيء للمراجعة الآن، أحسنت.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
            ForEach(due) { it in
                Button { review = it } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title(it, fmt)).font(.system(size: 16, weight: .bold))
                            Text(it.lastMistakes == 0 ? "آخر مرة بلا أخطاء" : "آخر مرة: \(fmt.number(it.lastMistakes)) أخطاء")
                                .font(.caption)
                                .foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer()
                        Text("راجع").font(.footnote.weight(.bold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Theme.gold, in: Capsule())
                            .foregroundStyle(Color.black.opacity(0.85))
                    }
                    .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(18)
    }

    @ViewBuilder
    private func upcomingSection(_ fmt: Fmt) -> some View {
        let up = memo.upcoming
        if !up.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("قادم").font(.headline).foregroundStyle(Theme.ink)
                ForEach(up.prefix(12)) { it in
                    HStack {
                        Text(title(it, fmt)).font(.subheadline)
                        Spacer()
                        Text(it.due, style: .relative).font(.caption).foregroundStyle(Theme.inkSecondary)
                        Button { memo.remove(it) } label: {
                            Image(systemName: "trash").font(.caption).foregroundStyle(Theme.inkSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(Theme.ink)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .glassCard(18)
        }
    }

    @ViewBuilder
    private func weakSection(_ fmt: Fmt) -> some View {
        let top = memo.topWeak(10)
        if !top.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("كلمات تخطئ فيها كثيراً").font(.headline).foregroundStyle(Theme.ink)
                    Spacer()
                    Button("مسح") { memo.clearWeak() }.font(.caption)
                }
                ForEach(Array(top.enumerated()), id: \.offset) { _, w in
                    HStack {
                        Text(w.word).font(QuranFont.font(quran.fontName, size: 22)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(quran.surah(w.surah)?.name ?? "").font(.caption).foregroundStyle(Theme.inkSecondary)
                        Text("×\(fmt.number(w.count))").font(.caption.weight(.bold)).foregroundStyle(Color.orange)
                    }
                }
            }
            .padding(14)
            .glassCard(18)
        }
    }
}
