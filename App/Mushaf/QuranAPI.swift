import Foundation

// عميل واجهة quran.com المجانية (v4). يُستدعى من الجهاز نفسه، والنتائج تُخزَّن في الكاش.
// الصفحات والتفسير تُخزَّن على القرص فتعمل دون إنترنت بعد أول فتح.

struct MWord: Codable, Hashable, Identifiable {
    let surah: Int
    let ayah: Int
    let position: Int
    let text: String
    let line: Int
    let isEnd: Bool

    var id: String { "\(surah):\(ayah):\(position)\(isEnd ? "e" : "")" }
    var ref: AyahRef { AyahRef(s: surah, a: ayah) }
}

struct MPage: Codable {
    let number: Int
    let lines: [[MWord]]

    var words: [MWord] { lines.flatMap { $0 } }
    var refs: [AyahRef] {
        var seen = Set<AyahRef>()
        var out: [AyahRef] = []
        for w in words where !seen.contains(w.ref) {
            seen.insert(w.ref)
            out.append(w.ref)
        }
        return out
    }
}

struct VerseTiming {
    let surah: Int
    let ayah: Int
    let from: Double   // مللي ثانية داخل ملف السورة
    let to: Double
    let words: [(position: Int, from: Double, to: Double)]
}

struct ChapterAudio {
    let url: URL
    let verses: [VerseTiming]
}

struct TafsirInfo: Identifiable, Hashable {
    let id: Int
    let name: String
    let author: String

    /// اسم عربي للتفسير (المصدر يعطي أسماء إنجليزية لبعضها)
    var displayName: String {
        let n = name.lowercased()
        let map: [(String, String)] = [
            ("muyassar", "التفسير الميسر"), ("wasit", "التفسير الوسيط (الطنطاوي)"), ("tantawi", "التفسير الوسيط (الطنطاوي)"),
            ("ibn kathir", "تفسير ابن كثير"), ("tabari", "تفسير الطبري"), ("qurtubi", "تفسير القرطبي"),
            ("sa'di", "تفسير السعدي"), ("saadi", "تفسير السعدي"), ("sadi", "تفسير السعدي"),
            ("baghawi", "تفسير البغوي"), ("jalalayn", "تفسير الجلالين"), ("tanwir", "التحرير والتنوير"),
            ("zamakhshari", "تفسير الزمخشري"), ("razi", "تفسير الرازي"), ("shawkani", "تفسير الشوكاني"),
            ("nasafi", "تفسير النسفي"), ("baydawi", "تفسير البيضاوي"), ("qushayri", "تفسير القشيري"),
            ("ibn ashur", "التحرير والتنوير"), ("mawardi", "تفسير الماوردي"), ("suyuti", "الدر المنثور (السيوطي)")
        ]
        for (k, v) in map where n.contains(k) { return v }
        return name
    }
}

enum QuranAPIError: Error {
    case badResponse
    case parse
}

enum QuranAPI {
    static let base = "https://api.quran.com/api/v4/"

    /// أول صفحة لكل سورة في مصحف المدينة (١١٤ سورة)
    static let surahStartPages: [Int] = [
        1, 2, 50, 77, 106, 128, 151, 177, 187, 208, 221, 235, 249, 255, 262, 267, 282, 293, 305, 312,
        322, 332, 342, 350, 359, 367, 377, 385, 396, 404, 411, 415, 418, 428, 434, 440, 446, 453, 458, 467,
        477, 483, 489, 496, 499, 502, 507, 511, 515, 518, 520, 523, 526, 528, 531, 534, 537, 542, 545, 549,
        551, 553, 554, 556, 558, 560, 562, 564, 566, 568, 570, 572, 574, 575, 577, 578, 580, 582, 583, 585,
        586, 587, 587, 589, 590, 591, 591, 592, 593, 594, 595, 596, 596, 597, 597, 598, 598, 599, 599, 600,
        600, 601, 601, 601, 602, 602, 602, 603, 603, 603, 604, 604, 604, 604
    ]

    static func startPage(ofSurah n: Int) -> Int {
        guard n >= 1, n <= surahStartPages.count else { return 1 }
        return surahStartPages[n - 1]
    }

    // MARK: الشبكة

    static func get(_ path: String) async throws -> Data {
        guard let url = URL(string: base + path) else { throw QuranAPIError.badResponse }
        var req = URLRequest(url: url)
        req.timeoutInterval = 25
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { throw QuranAPIError.badResponse }
        return data
    }

    private static var cacheDir: URL {
        // مجلد دائم (لا يمسحه النظام) كي تبقى الصفحات والتفاسير والتوقيتات للاستخدام بدون إنترنت
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("mushaf", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    // MARK: صفحة المصحف

    static func page(_ n: Int) async throws -> MPage {
        let file = cacheDir.appendingPathComponent("page-\(n).json")
        if let data = try? Data(contentsOf: file), let p = try? JSONDecoder().decode(MPage.self, from: data), !p.lines.isEmpty {
            return p
        }
        var all: [MWord] = []
        var pageNo = 1
        while pageNo < 6 {
            let q = "verses/by_page/\(n)?words=true&word_fields=text_uthmani&fields=verse_key&per_page=50&page=\(pageNo)"
            let data = try await get(q)
            let (words, next) = try parsePageWords(data)
            all.append(contentsOf: words)
            guard let nx = next, nx > pageNo else { break }
            pageNo = nx
        }
        let result = group(words: all, page: n)
        guard !result.lines.isEmpty else { throw QuranAPIError.parse }
        if let enc = try? JSONEncoder().encode(result) { try? enc.write(to: file, options: .atomic) }
        return result
    }

    /// يحلّل جواب verses/by_page ويعيد الكلمات ورقم الصفحة التالية من الترقيم (إن وُجدت)
    static func parsePageWords(_ data: Data) throws -> ([MWord], Int?) {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let verses = root["verses"] as? [[String: Any]] else { throw QuranAPIError.parse }
        var out: [MWord] = []
        for v in verses {
            guard let key = v["verse_key"] as? String else { continue }
            let parts = key.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2, let words = v["words"] as? [[String: Any]] else { continue }
            for w in words {
                let pos = (w["position"] as? Int) ?? Int("\(w["position"] ?? "")") ?? 0
                let line = (w["line_number"] as? Int) ?? Int("\(w["line_number"] ?? "")") ?? 0
                let type = (w["char_type_name"] as? String) ?? "word"
                let text = (w["text_uthmani"] as? String) ?? (w["text"] as? String) ?? ""
                out.append(MWord(surah: parts[0], ayah: parts[1], position: pos, text: text, line: line, isEnd: type == "end"))
            }
        }
        var next: Int?
        if let pg = root["pagination"] as? [String: Any] {
            next = pg["next_page"] as? Int
        }
        return (out, next)
    }

    /// يجمع الكلمات في أسطر حسب رقم السطر؛ إن غاب رقم السطر نوزعها على أسطر متساوية تقريباً
    static func group(words: [MWord], page: Int) -> MPage {
        guard !words.isEmpty else { return MPage(number: page, lines: []) }
        if words.contains(where: { $0.line > 0 }) {
            var order: [Int] = []
            var map: [Int: [MWord]] = [:]
            for w in words {
                if map[w.line] == nil { order.append(w.line) }
                map[w.line, default: []].append(w)
            }
            let lines = order.sorted().compactMap { map[$0] }
            return MPage(number: page, lines: lines)
        }
        let perLine = 6
        var lines: [[MWord]] = []
        var cur: [MWord] = []
        for w in words {
            cur.append(w)
            if cur.count >= perLine { lines.append(cur); cur = [] }
        }
        if !cur.isEmpty { lines.append(cur) }
        return MPage(number: page, lines: lines)
    }

    /// رقم صفحة آية معيّنة
    static func pageNumber(of ref: AyahRef) async throws -> Int {
        let data = try await get("verses/by_key/\(ref.s):\(ref.a)")
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let verse = root["verse"] as? [String: Any],
              let p = verse["page_number"] as? Int else { throw QuranAPIError.parse }
        return p
    }

    // MARK: الصوت

    static func chapterAudio(reciter: Int, chapter: Int) async throws -> ChapterAudio {
        // التوقيتات لا تتغير: نقرأها من القرص أولاً حتى يعمل التشغيل بدون إنترنت
        let file = cacheDir.appendingPathComponent("audio-\(reciter)-\(chapter).json")
        if let data = try? Data(contentsOf: file), let a = try? parseChapterAudio(data, chapter: chapter), !a.verses.isEmpty {
            return a
        }
        let data = try await get("chapter_recitations/\(reciter)/\(chapter)?segments=true")
        let parsed = try parseChapterAudio(data, chapter: chapter)
        if !parsed.verses.isEmpty { try? data.write(to: file, options: .atomic) }
        return parsed
    }

    /// عدد صفحات المصحف المحفوظة على الجهاز
    static func cachedPageCount() -> Int {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: cacheDir.path)) ?? []
        return files.filter { $0.hasPrefix("page-") && $0.hasSuffix(".json") }.count
    }

    static func parseChapterAudio(_ data: Data, chapter: Int) throws -> ChapterAudio {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let file = root["audio_file"] as? [String: Any],
              let urlStr = file["audio_url"] as? String, let url = URL(string: urlStr) else { throw QuranAPIError.parse }
        var verses: [VerseTiming] = []
        if let stamps = file["timestamps"] as? [[String: Any]] {
            for t in stamps {
                guard let key = t["verse_key"] as? String else { continue }
                let parts = key.split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2 else { continue }
                let from = num(t["timestamp_from"]) ?? 0
                let to = num(t["timestamp_to"]) ?? from
                var words: [(position: Int, from: Double, to: Double)] = []
                if let segs = t["segments"] as? [[Any]] {
                    for s in segs where s.count >= 3 {
                        if let p = num(s[0]), let a = num(s[1]), let b = num(s[2]) {
                            words.append((position: Int(p), from: a, to: b))
                        }
                    }
                }
                verses.append(VerseTiming(surah: parts[0], ayah: parts[1], from: from, to: to, words: words))
            }
        }
        return ChapterAudio(url: url, verses: verses)
    }

    private static func num(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let s = any as? String { return Double(s) }
        return nil
    }

    // MARK: التفسير

    static func arabicTafsirs() async throws -> [TafsirInfo] {
        let data = try await get("resources/tafsirs")
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = root["tafsirs"] as? [[String: Any]] else { throw QuranAPIError.parse }
        return list.compactMap { t in
            guard let id = t["id"] as? Int,
                  (t["language_name"] as? String)?.lowercased() == "arabic" else { return nil }
            return TafsirInfo(id: id, name: (t["name"] as? String) ?? "تفسير", author: (t["author_name"] as? String) ?? "")
        }
    }

    static func tafsir(id: Int, ref: AyahRef) async throws -> String {
        let file = cacheDir.appendingPathComponent("tafsir-\(id)-\(ref.s)-\(ref.a).txt")
        if let s = try? String(contentsOf: file, encoding: .utf8), !s.isEmpty { return s }
        let data = try await get("tafsirs/\(id)/by_ayah/\(ref.s):\(ref.a)")
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let t = root["tafsir"] as? [String: Any],
              let html = t["text"] as? String else { throw QuranAPIError.parse }
        let clean = stripHTML(html)
        if !clean.isEmpty { try? clean.write(to: file, atomically: true, encoding: .utf8) }
        return clean
    }

    static func stripHTML(_ s: String) -> String {
        var text = s
        for br in ["</p>", "<br>", "<br/>", "<br />", "</div>"] {
            text = text.replacingOccurrences(of: br, with: "\n\n")
        }
        var out = ""
        var inTag = false
        for ch in text {
            if ch == "<" { inTag = true; continue }
            if ch == ">" { inTag = false; continue }
            if !inTag { out.append(ch) }
        }
        let entities = ["&nbsp;": " ", "&amp;": "&", "&quot;": "\"", "&lt;": "<", "&gt;": ">", "&#39;": "'"]
        for (k, v) in entities { out = out.replacingOccurrences(of: k, with: v) }
        let paragraphs = out.components(separatedBy: "\n").map { line in
            line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
        }
        var result: [String] = []
        for p in paragraphs where !p.isEmpty { result.append(p) }
        return result.joined(separator: "\n\n")
    }
}
