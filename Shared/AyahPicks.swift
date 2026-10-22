import Foundation

/// آيات مختارة لـ«آية اليوم»؛ النص يُقرأ من المصحف وليس مكرراً هنا.
enum AyahPicks {
    static let picks: [(s: Int, a: Int)] = [
        (2,255),(2,286),(3,26),(3,185),(13,28),(94,5),(65,3),(2,152),(39,53),(20,25),
        (59,22),(112,1),(55,13),(36,58),(24,35),(2,45),(93,3),(9,51),(8,46),(33,56),
        (3,173),(2,153),(14,7),(17,9),(57,4),(40,60),(2,186),(25,63),(76,9),(103,1)
    ]

    static func today(_ date: Date = Date()) -> (s: Int, a: Int) {
        let d = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return picks[d % picks.count]
    }
}
