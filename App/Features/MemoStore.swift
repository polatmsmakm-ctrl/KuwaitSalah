import SwiftUI

/// جزء محفوظ يُراجَع بنظام التكرار المتباعد (صناديق لايتنر)
struct MemoItem: Codable, Identifiable, Hashable {
    let s: Int
    let from: Int
    let to: Int
    var box: Int
    var due: Date
    var lastMistakes: Int
    var attempts: Int
    var id: String { "\(s):\(from)-\(to)" }
}

struct MemoDay: Codable {
    var ayahs: Int = 0
    var mistakes: Int = 0
    var sessions: Int = 0
}

final class MemoStore: ObservableObject {
    /// الفاصل بالأيام لكل صندوق
    static let intervals: [Int] = [1, 3, 7, 14, 30, 60]

    @Published private(set) var items: [MemoItem] = []
    @Published private(set) var days: [String: MemoDay] = [:]
    /// الكلمات التي تخطئ فيها: "سورة|كلمة" ← عدد الأخطاء
    @Published private(set) var weak: [String: Int] = [:]

    init() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: "memo.items"), let v = try? JSONDecoder().decode([MemoItem].self, from: data) { items = v }
        if let data = d.data(forKey: "memo.days"), let v = try? JSONDecoder().decode([String: MemoDay].self, from: data) { days = v }
        if let data = d.data(forKey: "memo.weak"), let v = try? JSONDecoder().decode([String: Int].self, from: data) { weak = v }
    }

    private func save() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(items) { d.set(data, forKey: "memo.items") }
        if let data = try? JSONEncoder().encode(days) { d.set(data, forKey: "memo.days") }
        if let data = try? JSONEncoder().encode(weak) { d.set(data, forKey: "memo.weak") }
    }

    /// تسجيل نتيجة تسميع جزء: بلا أخطاء يرتقي الصندوق، وبأخطاء يهبط
    func record(surah: Int, from: Int, to: Int, mistakes: Int, wrongWords: [String]) {
        guard from >= 1, to >= from else { return }
        let id = "\(surah):\(from)-\(to)"
        let now = Date()
        if let i = items.firstIndex(where: { $0.id == id }) {
            var it = items[i]
            it.attempts += 1
            it.lastMistakes = mistakes
            it.box = mistakes == 0 ? min(Self.intervals.count - 1, it.box + 1) : max(0, it.box - 1)
            it.due = now.addingTimeInterval(Double(Self.intervals[it.box]) * 86400)
            items[i] = it
        } else {
            let box = mistakes == 0 ? 1 : 0
            items.append(MemoItem(s: surah, from: from, to: to, box: box,
                                  due: now.addingTimeInterval(Double(Self.intervals[box]) * 86400),
                                  lastMistakes: mistakes, attempts: 1))
        }
        let key = DayKey.key(now)
        var day = days[key] ?? MemoDay()
        day.ayahs += (to - from + 1)
        day.mistakes += mistakes
        day.sessions += 1
        days[key] = day
        for w in wrongWords where !w.isEmpty {
            weak["\(surah)|\(w)", default: 0] += 1
        }
        save()
    }

    func remove(_ item: MemoItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    var dueItems: [MemoItem] {
        let now = Date()
        return items.filter { $0.due <= now }.sorted { $0.due < $1.due }
    }

    var upcoming: [MemoItem] {
        let now = Date()
        return items.filter { $0.due > now }.sorted { $0.due < $1.due }
    }

    /// أيام متتالية بها تسميع (تنتهي اليوم أو أمس)
    var streak: Int {
        var n = 0
        var d = Date()
        if days[DayKey.key(d)] == nil {
            guard let y = PrayerCalc.calendar.date(byAdding: .day, value: -1, to: d) else { return 0 }
            d = y
        }
        while days[DayKey.key(d)] != nil {
            n += 1
            guard let p = PrayerCalc.calendar.date(byAdding: .day, value: -1, to: d) else { break }
            d = p
        }
        return n
    }

    var totalAyahs: Int { days.values.reduce(0) { $0 + $1.ayahs } }
    var totalMistakes: Int { days.values.reduce(0) { $0 + $1.mistakes } }
    var today: MemoDay { days[DayKey.key(Date())] ?? MemoDay() }

    func topWeak(_ n: Int) -> [(surah: Int, word: String, count: Int)] {
        weak.compactMap { k, v -> (Int, String, Int)? in
            let p = k.split(separator: "|", maxSplits: 1).map(String.init)
            guard p.count == 2, let s = Int(p[0]) else { return nil }
            return (s, p[1], v)
        }
        .sorted { $0.2 > $1.2 }
        .prefix(n)
        .map { (surah: $0.0, word: $0.1, count: $0.2) }
    }

    func clearWeak() {
        weak = [:]
        save()
    }
}
