import Foundation
import SwiftUI

// نص القرآن: حزمة quran-json 3.1.2 (رخصة CC-BY-4.0)، النص العثماني من موسوعة القرآن (quranenc.com).
// تم التحقق من عدد السور (١١٤) والآيات (٦٢٣٦) وعدد آيات كل سورة. التعديل الوحيد: استبدال مسافة رفيعة في البقرة ٧٢ بمسافة عادية.

struct Surah: Identifiable, Hashable {
    let n: Int
    let name: String
    let type: String
    let ayahs: [String]

    var id: Int { n }
    var typeArabic: String { type == "meccan" ? "مكية" : "مدنية" }
}

struct AyahRef: Codable, Hashable, Identifiable {
    let s: Int
    let a: Int
    var id: String { "\(s):\(a)" }
}

struct AyahHit: Identifiable {
    let ref: AyahRef
    let surahName: String
    let text: String
    var id: String { ref.id }
}

struct QuranLoadResult {
    let surahs: [Surah]
    let keys: [[String]]
}

enum QuranText {
    /// تطبيع خفيف: بدون تشكيل، وتوحيد الألف والياء والتاء المربوطة (الألف الخنجرية تصبح ألفاً)
    static func normalize(_ s: String) -> String {
        let alef = Unicode.Scalar(UInt32(0x0627))!
        let yeh = Unicode.Scalar(UInt32(0x064A))!
        let heh = Unicode.Scalar(UInt32(0x0647))!
        var out = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            let v = u.value
            if v == 0x0670 { out.append(alef); continue }
            if u.properties.generalCategory == .nonspacingMark { continue }
            if (0x06D6...0x06ED).contains(v) || v == 0x0640 { continue }
            switch v {
            case 0x0671, 0x0623, 0x0625, 0x0622:
                out.append(alef)
            case 0x0649:
                out.append(yeh)
            case 0x0629:
                out.append(heh)
            default:
                out.append(u)
            }
        }
        return String(out)
    }

    /// مفتاح بحث بدون ألفات: يجعل «العالمين» و«العٰلمين» و«ذلك» و«ذٰلك» متطابقة
    static func searchKey(_ s: String) -> String {
        let n = normalize(s)
        let alef = Unicode.Scalar(UInt32(0x0627))!
        var out = String.UnicodeScalarView()
        for u in n.unicodeScalars where u != alef {
            out.append(u)
        }
        let collapsed = String(out).split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        return collapsed
    }

    static func asciiDigits(_ s: String) -> String {
        let map: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9"
        ]
        return String(s.map { map[$0] ?? $0 })
    }
}

enum QuranLoader {
    private struct Raw: Decodable {
        let surahs: [RawSurah]
    }

    private struct RawSurah: Decodable {
        let n: Int
        let name: String
        let type: String
        let a: [String]
    }

    static func load(bundle: Bundle) -> QuranLoadResult? {
        guard let url = bundle.url(forResource: "quran", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode(Raw.self, from: data) else { return nil }
        let surahs = raw.surahs.map { Surah(n: $0.n, name: $0.name, type: $0.type, ayahs: $0.a) }
        let keys = surahs.map { s in s.ayahs.map { QuranText.searchKey($0) } }
        return QuranLoadResult(surahs: surahs, keys: keys)
    }

    static func search(_ query: String, in result: QuranLoadResult, limit: Int) -> [AyahRef] {
        let q = QuranText.searchKey(query)
        guard q.count >= 2 else { return [] }
        var hits: [AyahRef] = []
        for (si, list) in result.keys.enumerated() {
            for (ai, key) in list.enumerated() where key.contains(q) {
                hits.append(AyahRef(s: si + 1, a: ai + 1))
                if hits.count >= limit { return hits }
            }
        }
        return hits
    }
}

struct QuranFont: Identifiable, Hashable {
    let name: String
    let title: String
    var id: String { name }

    static let all: [QuranFont] = [
        QuranFont(name: "Geeza Pro", title: "جيزة"),
        QuranFont(name: "Damascus", title: "دمشق"),
        QuranFont(name: "Al Nile", title: "النيل"),
        QuranFont(name: "Baghdad", title: "بغداد"),
        QuranFont(name: "DecoType Naskh", title: "نسخ"),
        QuranFont(name: "KufiStandardGK", title: "كوفي"),
        QuranFont(name: "system", title: "النظام")
    ]

    static func font(_ name: String, size: Double) -> Font {
        if name == "system" { return .system(size: CGFloat(size), weight: .regular) }
        return .custom(name, size: CGFloat(size))
    }
}

final class QuranStore: ObservableObject {
    @Published private(set) var surahs: [Surah] = []
    @Published private(set) var loadFailed: Bool = false

    @Published var lastRead: AyahRef? {
        didSet { persistLastRead() }
    }
    @Published var favorites: [AyahRef] {
        didSet { persistFavorites() }
    }
    @Published var fontName: String {
        didSet { UserDefaults.standard.set(fontName, forKey: "quran.font") }
    }
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "quran.fontSize") }
    }

    private var loaded: QuranLoadResult?

    init() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: "quran.lastRead"), let r = try? JSONDecoder().decode(AyahRef.self, from: data) {
            lastRead = r
        } else {
            lastRead = nil
        }
        if let data = d.data(forKey: "quran.favorites"), let f = try? JSONDecoder().decode([AyahRef].self, from: data) {
            favorites = f
        } else {
            favorites = []
        }
        fontName = d.string(forKey: "quran.font") ?? "Geeza Pro"
        let size = d.double(forKey: "quran.fontSize")
        fontSize = size >= 18 ? size : 28
        Task { await self.load() }
    }

    func load() async {
        let result = await Task.detached(priority: .userInitiated) { () -> QuranLoadResult? in
            QuranLoader.load(bundle: Bundle.main)
        }.value
        await MainActor.run {
            if let r = result {
                self.loaded = r
                self.surahs = r.surahs
                self.loadFailed = false
            } else {
                self.loadFailed = true
            }
        }
    }

    private func persistLastRead() {
        if let r = lastRead, let data = try? JSONEncoder().encode(r) {
            UserDefaults.standard.set(data, forKey: "quran.lastRead")
        }
    }

    private func persistFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: "quran.favorites")
        }
    }

    func surah(_ n: Int) -> Surah? {
        guard n >= 1, n <= surahs.count else { return nil }
        return surahs[n - 1]
    }

    func ayahText(_ ref: AyahRef) -> String? {
        guard let s = surah(ref.s), ref.a >= 1, ref.a <= s.ayahs.count else { return nil }
        return s.ayahs[ref.a - 1]
    }

    func text(surah n: Int, from: Int, to: Int) -> String? {
        guard let s = surah(n), from >= 1, to <= s.ayahs.count, from <= to else { return nil }
        return s.ayahs[(from - 1)...(to - 1)].joined(separator: " ")
    }

    var bismillah: String? { surahs.first?.ayahs.first }

    func isFavorite(_ r: AyahRef) -> Bool { favorites.contains(r) }

    func toggleFavorite(_ r: AyahRef) {
        if let i = favorites.firstIndex(of: r) { favorites.remove(at: i) } else { favorites.insert(r, at: 0) }
    }

    func search(_ query: String) async -> [AyahHit] {
        guard let data = loaded else { return [] }
        let refs = await Task.detached(priority: .userInitiated) { () -> [AyahRef] in
            QuranLoader.search(query, in: data, limit: 50)
        }.value
        return refs.compactMap { r in
            guard let s = surah(r.s), let t = ayahText(r) else { return nil }
            return AyahHit(ref: r, surahName: s.name, text: t)
        }
    }
}
