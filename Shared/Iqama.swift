import Foundation

/// الإقامة = دقائق بعد الأذان، بالترتيب: فجر، ظهر، عصر، مغرب، عشاء
enum Iqama {
    static let defaults: [Int] = [25, 20, 20, 10, 20]

    static func minutes(_ p: Prayer, list: [Int]) -> Int? {
        guard let i = p.iqamaIndex, i < list.count else { return nil }
        return list[i]
    }

    static func time(_ p: Prayer, adhan: Date, list: [Int]) -> Date? {
        guard let m = minutes(p, list: list) else { return nil }
        return adhan.addingTimeInterval(Double(m) * 60.0)
    }
}
