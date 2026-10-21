import SwiftUI
import UIKit

struct ReaderTarget: Hashable {
    let surah: Int
    let ayah: Int
}

/// شارة رقم السورة: نجمة ثمانية من مربعين متقاطعين
struct StarBadge: View {
    let number: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .stroke(Theme.accent, lineWidth: 1.5)
                .frame(width: 26, height: 26)
            RoundedRectangle(cornerRadius: 5)
                .stroke(Theme.accent.opacity(0.6), lineWidth: 1.5)
                .frame(width: 26, height: 26)
                .rotationEffect(.degrees(45))
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
        }
        .frame(width: 42, height: 42)
    }
}

struct QuranHomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var quran: QuranStore
    @State private var query: String = ""
    @State private var hits: [AyahHit] = []
    @State private var mode: Int = 0
    @AppStorage("mushaf.lastPage") private var mushafLastPage = 1
    @State private var showMemorize = false

    private var filteredSurahs: [Surah] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return quran.surahs }
        let ascii = QuranText.asciiDigits(q)
        if let num = Int(ascii) {
            return quran.surahs.filter { $0.n == num }
        }
        let key = QuranText.searchKey(q)
        return quran.surahs.filter { QuranText.searchKey($0.name).contains(key) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(kind: .quran)
                content
            }
            .navigationTitle("القرآن الكريم")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ReaderTarget.self) { t in
                SurahReaderView(target: t)
            }
            .navigationDestination(for: MushafTarget.self) { t in
                MushafView(target: t)
            }
            .searchable(text: $query, prompt: "ابحث عن سورة أو آية")
            .task(id: query) {
                let q = query.trimmingCharacters(in: .whitespaces)
                if q.count < 3 || Int(QuranText.asciiDigits(q)) != nil {
                    hits = []
                    return
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
                if Task.isCancelled { return }
                let r = await quran.search(q)
                if !Task.isCancelled { hits = r }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if quran.loadFailed {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                Text("تعذّر تحميل نص القرآن").font(.headline)
                Text("أعد تثبيت التطبيق إذا استمرت المشكلة.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .foregroundStyle(Theme.ink)
        } else if quran.surahs.isEmpty {
            ProgressView().tint(Theme.accent)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    Picker("", selection: $mode) {
                        Text("السور").tag(0)
                        Text("المفضلة").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 4)

                    if mode == 0 && query.isEmpty {
                        mushafCards
                    }

                    if mode == 0 {
                        surahList
                    } else {
                        favoritesList
                    }
                    DevCredit()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private var mushafCards: some View {
        NavigationLink(value: MushafTarget(page: mushafLastPage, focus: nil)) {
            HStack(spacing: 12) {
                Image(systemName: "book.pages.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("المصحف الشريف").font(.system(size: 18, weight: .bold))
                    Text("٦٠٤ صفحات · استماع بتظليل الكلمات · تفسير")
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

        Button {
            showMemorize = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mic.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("الحفظ والتسميع").font(.system(size: 18, weight: .bold))
                    Text("اقرأ بصوتك والتطبيق يكشف الأخطاء")
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
        .sheet(isPresented: $showMemorize) {
            MemorizeView(start: quran.lastRead ?? AyahRef(s: 1, a: 1))
        }
    }

    @ViewBuilder
    private var surahList: some View {
        let fmt = store.fmt
        if query.isEmpty, let lr = quran.lastRead, let s = quran.surah(lr.s) {
            NavigationLink(value: ReaderTarget(surah: lr.s, ayah: lr.a)) {
                HStack(spacing: 12) {
                    Image(systemName: "bookmark.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("تابع القراءة").font(.caption).foregroundStyle(Theme.inkSecondary)
                        Text("سورة \(s.name) · آية \(fmt.number(lr.a))")
                            .font(.system(size: 18, weight: .bold))
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

        if !hits.isEmpty {
            Text("نتائج في الآيات")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
            ForEach(hits) { h in
                NavigationLink(value: ReaderTarget(surah: h.ref.s, ayah: h.ref.a)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("سورة \(h.surahName) · آية \(fmt.number(h.ref.a))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                        Text(h.text)
                            .font(QuranFont.font(quran.fontName, size: 20))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .glassCard(18)
                }
                .buttonStyle(.plain)
            }
        }

        if filteredSurahs.isEmpty && hits.isEmpty && !query.isEmpty {
            Text("لا توجد نتائج")
                .foregroundStyle(Theme.inkSecondary)
                .padding(.top, 20)
        }

        ForEach(filteredSurahs) { s in
            NavigationLink(value: ReaderTarget(surah: s.n, ayah: 1)) {
                HStack(spacing: 12) {
                    StarBadge(number: fmt.number(s.n))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.name).font(.system(size: 20, weight: .bold))
                        Text("\(s.typeArabic) · \(fmt.number(s.ayahs.count)) آية")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.left").foregroundStyle(Theme.inkSecondary)
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassCard(18)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var favoritesList: some View {
        let fmt = store.fmt
        if quran.favorites.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "star").font(.largeTitle).foregroundStyle(Theme.accent)
                Text("لا توجد آيات مفضلة بعد").font(.headline)
                Text("افتح أي سورة واضغط على زر ⋯ بجانب الآية ثم «إضافة للمفضلة».")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Theme.ink)
            .padding(.top, 40)
        } else {
            ForEach(quran.favorites) { ref in
                if let s = quran.surah(ref.s), let t = quran.ayahText(ref) {
                    HStack(alignment: .top, spacing: 8) {
                        NavigationLink(value: ReaderTarget(surah: ref.s, ayah: ref.a)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("سورة \(s.name) · آية \(fmt.number(ref.a))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                                Text(t)
                                    .font(QuranFont.font(quran.fontName, size: 20))
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            }
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        Button {
                            quran.toggleFavorite(ref)
                        } label: {
                            Image(systemName: "trash").foregroundStyle(Theme.inkSecondary)
                        }
                        .accessibilityLabel("إزالة من المفضلة")
                    }
                    .padding(14)
                    .glassCard(18)
                }
            }
        }
    }
}

struct SurahReaderView: View {
    let target: ReaderTarget
    @EnvironmentObject var store: Store
    @EnvironmentObject var quran: QuranStore
    @Environment(\.scenePhase) private var phase
    @State private var topCandidate: Int = Int.max

    var body: some View {
        if let s = quran.surah(target.surah) {
            reader(s)
        } else {
            ZStack {
                AppBackground(kind: .quran)
                ProgressView().tint(Theme.accent)
            }
        }
    }

    private func reader(_ s: Surah) -> some View {
        let fmt = store.fmt
        let total = s.ayahs.count
        return ZStack {
            AppBackground(kind: .quran)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        header(s, fmt: fmt)
                        ForEach(Array(1...max(1, total)), id: \.self) { n in
                            AyahRow(surah: s.n, number: n, text: s.ayahs[n - 1],
                                    onAppear: { noteAppear(n) },
                                    onDisappear: { noteDisappear(n) })
                                .id(n)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                .onAppear {
                    if target.ayah > 1 {
                        DispatchQueue.main.async {
                            proxy.scrollTo(target.ayah, anchor: .top)
                        }
                    }
                }
            }
        }
        .navigationTitle("سورة \(s.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("الخط", selection: $quran.fontName) {
                        ForEach(QuranFont.all) { f in
                            Text(f.title).tag(f.name)
                        }
                    }
                    Button {
                        quran.fontSize = min(48, quran.fontSize + 2)
                    } label: {
                        Label("تكبير الخط", systemImage: "textformat.size.larger")
                    }
                    Button {
                        quran.fontSize = max(18, quran.fontSize - 2)
                    } label: {
                        Label("تصغير الخط", systemImage: "textformat.size.smaller")
                    }
                } label: {
                    Image(systemName: "textformat.size")
                }
                .accessibilityLabel("خيارات الخط")
            }
        }
        .onDisappear { commit(total: total, surah: s.n) }
        .onChange(of: phase) { _, newPhase in
            if newPhase != .active { commit(total: total, surah: s.n) }
        }
    }

    @ViewBuilder
    private func header(_ s: Surah, fmt: Fmt) -> some View {
        VStack(spacing: 10) {
            Text("سورة \(s.name)")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("\(s.typeArabic) · \(fmt.number(s.ayahs.count)) آية")
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)
            if s.n != 1 && s.n != 9, let b = quran.bismillah {
                Text(b)
                    .font(QuranFont.font(quran.fontName, size: quran.fontSize))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .glassCard(20)
        .padding(.vertical, 10)
    }

    private func noteAppear(_ n: Int) {
        if n < topCandidate { topCandidate = n }
    }

    private func noteDisappear(_ n: Int) {
        if n == topCandidate { topCandidate = n + 1 }
    }

    private func commit(total: Int, surah: Int) {
        guard topCandidate != Int.max else { return }
        let a = min(max(1, topCandidate), total)
        quran.lastRead = AyahRef(s: surah, a: a)
    }
}

struct AyahRow: View {
    let surah: Int
    let number: Int
    let text: String
    let onAppear: () -> Void
    let onDisappear: () -> Void
    @EnvironmentObject var store: Store
    @EnvironmentObject var quran: QuranStore
    private let player = RecitationPlayer.shared
    @State private var tafsirRef: AyahRef?
    @State private var memoRef: AyahRef?

    var body: some View {
        let fmt = store.fmt
        let ref = AyahRef(s: surah, a: number)
        let isFav = quran.isFavorite(ref)
        let isMarked = quran.lastRead == ref

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    Button {
                        quran.toggleFavorite(ref)
                    } label: {
                        Label(isFav ? "إزالة من المفضلة" : "إضافة للمفضلة", systemImage: isFav ? "star.slash" : "star")
                    }
                    Button {
                        quran.lastRead = ref
                    } label: {
                        Label("علّم هنا كموضع قراءة", systemImage: "bookmark")
                    }
                    Button {
                        player.play(surah: surah, ayah: number)
                    } label: {
                        Label("استماع", systemImage: "play.circle")
                    }
                    Button {
                        tafsirRef = ref
                    } label: {
                        Label("تفسير", systemImage: "text.book.closed")
                    }
                    Button {
                        memoRef = ref
                    } label: {
                        Label("حفظ وتسميع", systemImage: "mic")
                    }
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Label("نسخ الآية", systemImage: "doc.on.doc")
                    }
                    ShareLink(item: text) {
                        Label("مشاركة", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Theme.inkSecondary)
                }
                .accessibilityLabel("خيارات الآية \(fmt.number(number))")

                if isMarked {
                    Image(systemName: "bookmark.fill").foregroundStyle(Theme.accent)
                }
                if isFav {
                    Image(systemName: "star.fill").foregroundStyle(Theme.accent)
                }
                Spacer()
            }
            .font(.callout)

            Text("\(text) \u{FD3F}\(fmt.number(number))\u{FD3E}")
                .font(QuranFont.font(quran.fontName, size: quran.fontSize))
                .lineSpacing(quran.fontSize * 0.45)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)

            Divider().overlay(Theme.inkSecondary.opacity(0.25))
        }
        .padding(.vertical, 8)
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .sheet(item: $tafsirRef) { r in TafsirSheet(ref: r) }
        .sheet(item: $memoRef) { r in MemorizeView(start: r) }
    }
}
