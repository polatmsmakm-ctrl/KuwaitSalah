import Foundation

/// iqama = minutes after the adhan, in this order: fajr, dhuhr, asr, maghrib, isha
struct Mosque: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var area: String
    var iqama: [Int]
    /// true = placeholder values that have not been checked against the real mosque
    var estimated: Bool

    func iqamaMinutes(for p: Prayer) -> Int? {
        guard let i = p.iqamaIndex, i < iqama.count else { return nil }
        return iqama[i]
    }

    func iqamaTime(for p: Prayer, adhan: Date) -> Date? {
        guard let m = iqamaMinutes(for: p) else { return nil }
        return adhan.addingTimeInterval(Double(m) * 60.0)
    }

    // ------------------------------------------------------------------
    // لإضافة مسجد جديد للقائمة (وللويدجت أيضاً) أضف سطراً هنا:
    // Mosque(id: "اسم-فريد", name: "اسم المسجد", area: "المنطقة",
    //        iqama: [فجر, ظهر, عصر, مغرب, عشاء], estimated: false)
    // القيم بالدقائق بعد الأذان.
    // ------------------------------------------------------------------
    static let presets: [Mosque] = [
        Mosque(id: "default", name: "افتراضي", area: "الكويت",
               iqama: [25, 20, 20, 10, 20], estimated: true),
        Mosque(id: "grand", name: "الجامع الكبير", area: "مدينة الكويت",
               iqama: [25, 20, 20, 10, 20], estimated: true)
    ]

    static func blank() -> Mosque {
        Mosque(id: "c-" + UUID().uuidString, name: "", area: "", iqama: [25, 20, 20, 10, 20], estimated: false)
    }
}
