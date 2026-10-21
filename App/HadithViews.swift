import SwiftUI
import UIKit

struct HadithChapterTarget: Hashable {
    let book: Int
    let chapter: Int
}

struct HadithHomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var hadith: HadithStore
    @State private var query = ""
    @State private var hits: [HadithItem] = []
    @State private var mode = 0

    private var isSearching: Bool {
        QuranText.searchKey(query.trimmingCharacters(in: .whitespaces)).count >= 2
    }

    var body: some View {
        ZStack {
            AppBackground(kind: .quran)
            if hadith.failed {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                    Text("تعذّر تحميل الأحاديث").font(.headline)
                }
                .foregroundStyle(Theme.ink)
            } else if hadith.books.contains(where: { $0 == nil }) {
                ProgressView("جارٍ تحميل الكتب…").tint(Theme.accent).foregroundStyle(Theme.ink)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if isSearching {
                            searchResults
                        } else {
                            Picker("", selection: $mode) {
                                Text("الكتب").tag(0)
                                Text("المفضلة").tag(1)
                            }
                            .pickerStyle(.segmented)
                            if mode == 0 { bookCards } else { favoritesList }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("الأحاديث")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "ابحث في البخاري ومسلم")
        .navigationDestination(for: HadithChapterTarget.self) { t in
            HadithChapterView(target: t)
        }
        .navigationDestination(for: HadithItem.self) { h in
            HadithDetailView(item: h)
        }
        .task { await hadith.loadIfNeeded() }
        .task(id: query) {
            let q = query.trimmingCharacters(in: .whitespaces)
            guard QuranText.searchKey(q).count >= 2 else { hits = []; return }
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            let r = await hadith.search(q)
            if !Task.isCancelled { hits = r }
        }
    }

    @ViewBuilder
    private var bookCards: some View {
        ForEach(0..<2, id: \.self) { i in
            if let b = hadith.books[i] {
                NavigationLink(value: HadithChapterTarget(book: i, chapter: -1)) {
                    HStack(spacing: 12) {
                        Image(systemName: "books.vertical.fill").font(.title2).foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(b.name).font(.system(size: 20, weight: .bold))
                            Text("\(store.fmt.number(b.chapters.count)) كتاباً · \(store.fmt.number(b.items.count)) حديثاً")
                                .font(.caption).foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.left").foregroundStyle(Theme.inkSecondary)
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(16)
                    .glassCard(18)
                }
                .buttonStyle(.plain)
            }
        }
        Text("الترقيم حسب موقع sunnah.com، وقد يختلف عن ترقيم النسخ المطبوعة. للتوسع في الشرح والدرجة راجع كتب الشروح.")
            .font(.caption)
            .foregroundStyle(Theme.inkSecondary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }

    @ViewBuilder
    private var searchResults: some View {
        if hadith.searching && hits.isEmpty {
            ProgressView().tint(Theme.accent).padding(.top, 30)
        } else if hits.isEmpty {
            Text("لا توجد نتائج").foregroundStyle(Theme.inkSecondary).padding(.top, 30)
        } else {
            Text("النتائج (أول ٦٠ من كل كتاب)")
                .font(.footnote).foregroundStyle(Theme.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(hits) { h in
                NavigationLink(value: h) { HadithCard(item: h, lines: 4) }.buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var favoritesList: some View {
        let items = hadith.favorites.compactMap { hadith.item($0) }
        if items.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "star").font(.largeTitle).foregroundStyle(Theme.accent)
                Text("لا توجد أحاديث مفضلة بعد").font(.headline)
                Text("افتح أي حديث واضغط النجمة لإضافته.").font(.footnote).foregroundStyle(Theme.inkSecondary)
            }
            .foregroundStyle(Theme.ink)
            .padding(.top, 40)
        } else {
            ForEach(items) { h in
                NavigationLink(value: h) { HadithCard(item: h, lines: 4) }.buttonStyle(.plain)
            }
        }
    }
}

struct HadithCard: View {
    let item: HadithItem
    var lines: Int? = nil
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(HadithStore.bookNames[item.book]) · حديث \(store.fmt.number(item.number))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text(item.text)
                .font(.system(size: 18))
                .lineSpacing(6)
                .lineLimit(lines)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(18)
    }
}

/// قائمة كتب المصنَّف (chapter == -1) أو أحاديث كتاب محدد
struct HadithChapterView: View {
    let target: HadithChapterTarget
    @EnvironmentObject var store: Store
    @EnvironmentObject var hadith: HadithStore

    var body: some View {
        ZStack {
            AppBackground(kind: .quran)
            if let book = hadith.books[target.book] {
                if target.chapter < 0 {
                    chapterList(book)
                } else {
                    hadithList(book)
                }
            } else {
                ProgressView().tint(Theme.accent)
            }
        }
        .navigationTitle(target.chapter < 0
            ? HadithStore.bookNames[target.book]
            : (hadith.books[target.book]?.chapters[target.chapter] ?? ""))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chapterList(_ book: HadithBook) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(book.chapters.enumerated()), id: \.offset) { i, title in
                    NavigationLink(value: HadithChapterTarget(book: target.book, chapter: i)) {
                        HStack {
                            Text(title).font(.system(size: 18, weight: .semibold)).multilineTextAlignment(.leading)
                            Spacer()
                            Text(store.fmt.number(i < book.ranges.count ? book.ranges[i].count : 0))
                                .font(.caption).foregroundStyle(Theme.inkSecondary)
                            Image(systemName: "chevron.left").foregroundStyle(Theme.inkSecondary)
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(14)
                        .glassCard(16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func hadithList(_ book: HadithBook) -> some View {
        let items = book.items.filter { $0.chapter == target.chapter }
        return ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(items) { h in
                    NavigationLink(value: h) { HadithCard(item: h, lines: 6) }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

struct HadithDetailView: View {
    let item: HadithItem
    @EnvironmentObject var store: Store
    @EnvironmentObject var hadith: HadithStore

    private var shareText: String {
        "\(item.text)\n\n— \(HadithStore.bookNames[item.book])، حديث رقم \(item.number) (ترقيم sunnah.com)"
    }

    var body: some View {
        let fav = hadith.isFavorite(item)
        ZStack {
            AppBackground(kind: .quran)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("\(HadithStore.bookNames[item.book]) · حديث \(store.fmt.number(item.number))")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(item.text)
                        .font(.system(size: 24))
                        .lineSpacing(12)
                        .foregroundStyle(Theme.ink)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .glassCard(20)
                .padding(16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button { hadith.toggleFavorite(item) } label: {
                    Image(systemName: fav ? "star.fill" : "star")
                }
                .accessibilityLabel(fav ? "إزالة من المفضلة" : "إضافة للمفضلة")
                Button { UIPasteboard.general.string = shareText } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel("نسخ")
                ShareLink(item: shareText) { Image(systemName: "square.and.arrow.up") }
            }
        }
    }
}
