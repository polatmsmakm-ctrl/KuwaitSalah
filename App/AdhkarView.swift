import SwiftUI

// الأذكار: نصوص مشهورة متفق عليها. الآيات تُقرأ مباشرة من نص القرآن المدمج في التطبيق لضمان سلامتها.
// ننصح بمراجعة كتب الأذكار الموثوقة (كحصن المسلم) للتوسع.

enum DhikrContent {
    case text(String)
    case quran(surah: Int, from: Int, to: Int)
}

struct Dhikr: Identifiable {
    let id: String
    let content: DhikrContent
    let repeats: Int
}

struct DhikrCategory: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let items: [Dhikr]
}

enum AdhkarData {
    static let all: [DhikrCategory] = [
        DhikrCategory(id: "morning", title: "أذكار الصباح", symbol: "sunrise.fill", items: [
            Dhikr(id: "m1", content: .quran(surah: 2, from: 255, to: 255), repeats: 1),
            Dhikr(id: "m2", content: .quran(surah: 112, from: 1, to: 4), repeats: 3),
            Dhikr(id: "m3", content: .quran(surah: 113, from: 1, to: 5), repeats: 3),
            Dhikr(id: "m4", content: .quran(surah: 114, from: 1, to: 6), repeats: 3),
            Dhikr(id: "m5", content: .text("أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ"), repeats: 1),
            Dhikr(id: "m6", content: .text("اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ"), repeats: 1),
            Dhikr(id: "m7", content: .text("بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ"), repeats: 3),
            Dhikr(id: "m8", content: .text("رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ ﷺ نَبِيًّا"), repeats: 3),
            Dhikr(id: "m9", content: .text("سُبْحَانَ اللَّهِ وَبِحَمْدِهِ"), repeats: 100)
        ]),
        DhikrCategory(id: "evening", title: "أذكار المساء", symbol: "sunset.fill", items: [
            Dhikr(id: "e1", content: .quran(surah: 2, from: 255, to: 255), repeats: 1),
            Dhikr(id: "e2", content: .quran(surah: 112, from: 1, to: 4), repeats: 3),
            Dhikr(id: "e3", content: .quran(surah: 113, from: 1, to: 5), repeats: 3),
            Dhikr(id: "e4", content: .quran(surah: 114, from: 1, to: 6), repeats: 3),
            Dhikr(id: "e5", content: .text("أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ"), repeats: 1),
            Dhikr(id: "e6", content: .text("اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ"), repeats: 1),
            Dhikr(id: "e7", content: .text("بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ"), repeats: 3),
            Dhikr(id: "e8", content: .text("أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ"), repeats: 3),
            Dhikr(id: "e9", content: .text("سُبْحَانَ اللَّهِ وَبِحَمْدِهِ"), repeats: 100)
        ]),
        DhikrCategory(id: "afterPrayer", title: "أذكار بعد الصلاة", symbol: "hands.sparkles.fill", items: [
            Dhikr(id: "p1", content: .text("أَسْتَغْفِرُ اللَّهَ"), repeats: 3),
            Dhikr(id: "p2", content: .text("اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ"), repeats: 1),
            Dhikr(id: "p3", content: .text("سُبْحَانَ اللَّهِ"), repeats: 33),
            Dhikr(id: "p4", content: .text("الْحَمْدُ لِلَّهِ"), repeats: 33),
            Dhikr(id: "p5", content: .text("اللَّهُ أَكْبَرُ"), repeats: 33),
            Dhikr(id: "p6", content: .text("لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ"), repeats: 1),
            Dhikr(id: "p7", content: .quran(surah: 2, from: 255, to: 255), repeats: 1)
        ]),
        DhikrCategory(id: "sleep", title: "أذكار النوم", symbol: "moon.zzz.fill", items: [
            Dhikr(id: "s1", content: .quran(surah: 2, from: 255, to: 255), repeats: 1),
            Dhikr(id: "s2", content: .quran(surah: 112, from: 1, to: 4), repeats: 3),
            Dhikr(id: "s3", content: .quran(surah: 113, from: 1, to: 5), repeats: 3),
            Dhikr(id: "s4", content: .quran(surah: 114, from: 1, to: 6), repeats: 3),
            Dhikr(id: "s5", content: .text("بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا"), repeats: 1),
            Dhikr(id: "s6", content: .text("اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ"), repeats: 3)
        ]),
        DhikrCategory(id: "wake", title: "عند الاستيقاظ", symbol: "alarm.fill", items: [
            Dhikr(id: "w1", content: .text("الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ"), repeats: 1)
        ]),
        DhikrCategory(id: "general", title: "أذكار عامة", symbol: "sparkles", items: [
            Dhikr(id: "g1", content: .text("لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ"), repeats: 1),
            Dhikr(id: "g2", content: .text("سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ"), repeats: 1),
            Dhikr(id: "g3", content: .text("أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ"), repeats: 1),
            Dhikr(id: "g4", content: .text("اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ"), repeats: 1),
            Dhikr(id: "g5", content: .text("رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ"), repeats: 1)
        ])
    ]
}

/// تقدم الأذكار اليومي: يُصفَّر تلقائياً مع كل يوم جديد
final class AdhkarStore: ObservableObject {
    @Published private(set) var counts: [String: Int]
    private let key = "adhkar.progress.v1"

    init() {
        counts = (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:]
    }

    private func k(_ cat: String, _ item: String, _ day: Date = Date()) -> String {
        "\(DayKey.key(day)):\(cat):\(item)"
    }

    func count(_ cat: String, _ item: String) -> Int { counts[k(cat, item)] ?? 0 }

    func tap(_ cat: String, _ item: Dhikr) {
        let key = k(cat, item.id)
        let c = counts[key] ?? 0
        if c < item.repeats {
            counts[key] = c + 1
            persist()
        }
    }

    func reset(_ cat: DhikrCategory) {
        for i in cat.items { counts.removeValue(forKey: k(cat.id, i.id)) }
        persist()
    }

    func done(_ cat: DhikrCategory) -> Int {
        cat.items.filter { count(cat.id, $0.id) >= $0.repeats }.count
    }

    /// عدد الفئات المكتملة في يوم معين (للإحصائيات)
    func completedCategories(on day: Date) -> Int {
        let prefix = DayKey.key(day)
        return AdhkarData.all.filter { cat in
            cat.items.allSatisfy { (counts["\(prefix):\(cat.id):\($0.id)"] ?? 0) >= $0.repeats }
        }.count
    }

    private func persist() {
        // نحذف ما هو أقدم من ٦٠ يوماً
        let cutoff = DayKey.key(Date().addingTimeInterval(-60 * 86400))
        counts = counts.filter { String($0.key.prefix(10)) >= cutoff }
        UserDefaults.standard.set(counts, forKey: key)
    }
}

struct AdhkarListView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var adhkar: AdhkarStore

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(AdhkarData.all) { cat in
                        NavigationLink(value: cat.id) {
                            HStack(spacing: 12) {
                                Image(systemName: cat.symbol)
                                    .font(.title3)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.title).font(.system(size: 18, weight: .bold))
                                    Text("\(store.fmt.number(adhkar.done(cat))) من \(store.fmt.number(cat.items.count)) اليوم")
                                        .font(.caption)
                                        .foregroundStyle(Theme.inkSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.left").foregroundStyle(Theme.inkSecondary)
                            }
                            .foregroundStyle(Theme.ink)
                            .padding(14)
                            .glassCard(18)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppBackground(kind: .adhkar))
            .navigationDestination(for: String.self) { id in
                if let cat = AdhkarData.all.first(where: { $0.id == id }) {
                    AdhkarCategoryView(category: cat)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct AdhkarCategoryView: View {
    let category: DhikrCategory
    @EnvironmentObject var store: Store
    @EnvironmentObject var adhkar: AdhkarStore
    @EnvironmentObject var quran: QuranStore

    private func text(for d: Dhikr) -> String? {
        switch d.content {
        case .text(let t): return t
        case .quran(let s, let f, let t): return quran.text(surah: s, from: f, to: t)
        }
    }

    var body: some View {
        let fmt = store.fmt
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(category.items) { d in
                    let c = adhkar.count(category.id, d.id)
                    let finished = c >= d.repeats
                    Button {
                        adhkar.tap(category.id, d)
                    } label: {
                        VStack(spacing: 10) {
                            if let t = text(for: d) {
                                Text(t)
                                    .font(.system(size: 21, weight: .medium))
                                    .lineSpacing(8)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("تعذّر تحميل النص").foregroundStyle(Theme.inkSecondary)
                            }
                            HStack {
                                Text(d.repeats > 1 ? "\(fmt.number(c)) / \(fmt.number(d.repeats))" : (finished ? "تم" : "اضغط عند القراءة"))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(finished ? Color.green : Theme.accent)
                                if finished { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.green) }
                            }
                        }
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .glassCard(20)
                        .opacity(finished ? 0.6 : 1)
                    }
                    .buttonStyle(PressStyle())
                    .sensoryFeedback(.impact, trigger: c)
                    .accessibilityHint("اضغط لزيادة العداد")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(AppBackground(kind: .adhkar))
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("إعادة") { adhkar.reset(category) }
            }
        }
    }
}
