import Foundation
import SwiftUI

// صحيح البخاري وصحيح مسلم: نصوص عربية من قاعدة hadith-json (مأخوذة من موقع sunnah.com).
// الترقيم هو ترقيم الموقع (تسلسلي)، وقد يختلف عن ترقيم محمد فؤاد عبد الباقي المطبوع.

struct HadithItem: Identifiable, Hashable {
    let book: Int      // 0 البخاري، 1 مسلم
    let number: Int
    let chapter: Int   // فهرس الكتاب (الباب الرئيسي) داخل المصنَّف
    let text: String

    var id: String { "\(book):\(number)" }
}

struct HadithBook {
    let name: String
    let chapters: [String]
    let items: [HadithItem]
    /// مفاتيح البحث (بدون تشكيل)، تُحسب عند أول بحث
    var keys: [String] = []
    /// بداية ونهاية كل كتاب داخل items
    let ranges: [Range<Int>]
}

enum HadithLoader {
    private struct Raw: Decodable {
        let name: String
        let chapters: [String]
        let h: [Row]
    }

    private struct Row: Decodable {
        let n: Int
        let c: Int
        let t: String

        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            n = try c.decode(Int.self)
            self.c = try c.decode(Int.self)
            t = try c.decode(String.self)
        }
    }

    static let files = ["bukhari", "muslim"]

    static func load(index: Int, bundle: Bundle) -> HadithBook? {
        guard index >= 0, index < files.count,
              let url = bundle.url(forResource: files[index], withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode(Raw.self, from: data) else { return nil }
        let items = raw.h.map { HadithItem(book: index, number: $0.n, chapter: $0.c, text: $0.t) }
        var ranges: [Range<Int>] = []
        var start = 0
        for i in 1...max(1, items.count) {
            if i == items.count || items[i].chapter != items[start].chapter {
                ranges.append(start..<min(i, items.count))
                start = i
            }
        }
        return HadithBook(name: raw.name, chapters: raw.chapters, items: items, ranges: ranges)
    }

    /// بحث: كل كلمات الاستعلام يجب أن تظهر (بدون تشكيل أو ألفات)
    static func search(_ query: String, keys: [String], limit: Int, in range: Range<Int>? = nil) -> [Int] {
        let words = QuranText.searchKey(query).split(separator: " ").map(String.init)
        guard !words.isEmpty, words.joined().count >= 2 else { return [] }
        var out: [Int] = []
        for (i, k) in keys.enumerated() where (range?.contains(i) ?? true) && words.allSatisfy({ k.contains($0) }) {
            out.append(i)
            if out.count >= limit { break }
        }
        return out
    }
}

@MainActor
final class HadithStore: ObservableObject {
    @Published private(set) var books: [HadithBook?] = [nil, nil]
    @Published private(set) var failed = false
    @Published private(set) var searching = false
    @Published var favorites: [String] {
        didSet { UserDefaults.standard.set(favorites, forKey: "hadith.favorites") }
    }

    private var keysReady = false

    init() {
        favorites = UserDefaults.standard.stringArray(forKey: "hadith.favorites") ?? []
    }

    func loadIfNeeded() async {
        guard books[0] == nil || books[1] == nil else { return }
        let loaded = await Task.detached(priority: .userInitiated) { () -> [HadithBook?] in
            [HadithLoader.load(index: 0, bundle: .main), HadithLoader.load(index: 1, bundle: .main)]
        }.value
        books = loaded
        failed = loaded.contains(where: { $0 == nil })
    }

    private func buildKeysIfNeeded() async {
        guard !keysReady else { return }
        let snapshot = books
        let keys = await Task.detached(priority: .userInitiated) { () -> [[String]] in
            snapshot.map { b in (b?.items ?? []).map { QuranText.searchKey($0.text) } }
        }.value
        for i in 0..<books.count {
            books[i]?.keys = keys[i]
        }
        keysReady = true
    }

    func search(_ query: String, limit: Int = 60, book only: Int? = nil, chapter: Int? = nil) async -> [HadithItem] {
        await loadIfNeeded()
        searching = true
        defer { searching = false }
        await buildKeysIfNeeded()
        let snapshot = books
        let hits = await Task.detached(priority: .userInitiated) { () -> [HadithItem] in
            var all: [HadithItem] = []
            for (bi, b) in snapshot.enumerated() {
                guard let b = b else { continue }
                if let only = only, only != bi { continue }
                var range: Range<Int>? = nil
                if let c = chapter, c >= 0, c < b.ranges.count { range = b.ranges[c] }
                let idx = HadithLoader.search(query, keys: b.keys, limit: limit, in: range)
                all.append(contentsOf: idx.map { b.items[$0] })
            }
            return all
        }.value
        return hits
    }

    func item(_ id: String) -> HadithItem? {
        let p = id.split(separator: ":")
        guard p.count == 2, let b = Int(p[0]), let n = Int(p[1]),
              b >= 0, b < books.count, let book = books[b] else { return nil }
        // الأرقام تسلسلية من ١، فالفهرس n-1
        let i = n - 1
        guard i >= 0, i < book.items.count, book.items[i].number == n else { return nil }
        return book.items[i]
    }

    func isFavorite(_ h: HadithItem) -> Bool { favorites.contains(h.id) }

    func toggleFavorite(_ h: HadithItem) {
        if let i = favorites.firstIndex(of: h.id) { favorites.remove(at: i) } else { favorites.insert(h.id, at: 0) }
    }

    static let bookNames = ["صحيح البخاري", "صحيح مسلم"]
}

extension HadithBook: Equatable {
    static func == (l: HadithBook, r: HadithBook) -> Bool { l.name == r.name && l.items.count == r.items.count }
}
