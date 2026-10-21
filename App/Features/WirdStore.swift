import SwiftUI
import UserNotifications

/// الختمة والورد اليومي: تتبّع الصفحات المقروءة، هدف يومي، تذكير
struct WirdState: Codable {
    var readPages: [Int] = []
    var khatmat: Int = 0
    var targetDays: Int = 30
    var startDate: Date = Date()
    var today: String = ""
    var todayPages: [Int] = []
    var reminderOn: Bool = false
    var reminderHour: Int = 20
    var reminderMinute: Int = 0
    var lastPage: Int = 1

    init() {}

    enum CodingKeys: String, CodingKey {
        case readPages, khatmat, targetDays, startDate, today, todayPages
        case reminderOn, reminderHour, reminderMinute, lastPage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        readPages = try c.decodeIfPresent([Int].self, forKey: .readPages) ?? []
        khatmat = try c.decodeIfPresent(Int.self, forKey: .khatmat) ?? 0
        targetDays = try c.decodeIfPresent(Int.self, forKey: .targetDays) ?? 30
        startDate = try c.decodeIfPresent(Date.self, forKey: .startDate) ?? Date()
        today = try c.decodeIfPresent(String.self, forKey: .today) ?? ""
        todayPages = try c.decodeIfPresent([Int].self, forKey: .todayPages) ?? []
        reminderOn = try c.decodeIfPresent(Bool.self, forKey: .reminderOn) ?? false
        reminderHour = try c.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 20
        reminderMinute = try c.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0
        lastPage = try c.decodeIfPresent(Int.self, forKey: .lastPage) ?? 1
    }
}

final class WirdStore: ObservableObject {
    static let totalPages = 604
    /// أول صفحة في كل جزء (٣٠ جزءاً) في مصحف المدينة
    static let juzStart: [Int] = [1, 22, 42, 62, 82, 102, 122, 142, 162, 182, 202, 222, 242, 262, 282,
                                  302, 322, 342, 362, 382, 402, 422, 442, 462, 482, 502, 522, 542, 562, 582]
    static let dayOptions = [7, 10, 15, 20, 30, 45, 60, 90]

    @Published var state: WirdState {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "wird.v1"),
           let s = try? JSONDecoder().decode(WirdState.self, from: data) {
            state = s
        } else {
            state = WirdState()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: "wird.v1")
        }
    }

    /// تسجيل زيارة صفحة (تُستدعى بعد بقاء المستخدم فيها بضع ثوانٍ)
    func visit(_ page: Int) {
        guard page >= 1, page <= Self.totalPages else { return }
        let key = DayKey.key(Date())
        if state.today != key {
            state.today = key
            state.todayPages = []
        }
        state.lastPage = page
        if !state.readPages.contains(page) { state.readPages.append(page) }
        if !state.todayPages.contains(page) { state.todayPages.append(page) }
        if state.readPages.count >= Self.totalPages {
            state.khatmat += 1
            state.readPages = []
            state.startDate = Date()
        }
    }

    func reset() {
        state.readPages = []
        state.startDate = Date()
    }

    var readCount: Int { state.readPages.count }
    var remaining: Int { Self.totalPages - readCount }
    var progress: Double { Double(readCount) / Double(Self.totalPages) }

    var dailyGoal: Int {
        let d = Double(max(1, state.targetDays))
        return max(1, Int((Double(Self.totalPages) / d).rounded(.up)))
    }

    var pagesToday: Int {
        state.today == DayKey.key(Date()) ? state.todayPages.count : 0
    }

    /// الصفحة التالية غير المقروءة بعد آخر صفحة
    var nextPage: Int {
        let read = Set(state.readPages)
        if state.lastPage < Self.totalPages {
            for p in (state.lastPage + 1)...Self.totalPages where !read.contains(p) { return p }
        }
        for p in 1...Self.totalPages where !read.contains(p) { return p }
        return 1
    }

    /// الأيام المتبقية للختم بحسب وتيرتك الحالية
    var projectedDaysLeft: Int? {
        guard readCount > 0 else { return nil }
        let elapsed = max(1.0, Date().timeIntervalSince(state.startDate) / 86400.0 + 1.0)
        let pace = Double(readCount) / elapsed
        guard pace > 0 else { return nil }
        return Int((Double(remaining) / pace).rounded(.up))
    }

    func juzProgress(_ j: Int) -> (read: Int, total: Int) {
        let from = Self.juzStart[j]
        let to = j + 1 < Self.juzStart.count ? Self.juzStart[j + 1] - 1 : Self.totalPages
        let set = Set(state.readPages)
        let read = (from...to).filter { set.contains($0) }.count
        return (read, to - from + 1)
    }

    // MARK: التذكير اليومي

    func updateReminder() {
        let on = state.reminderOn
        let h = state.reminderHour, m = state.reminderMinute
        let goal = dailyGoal
        Task {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: ["wird-daily"])
            guard on else { return }
            await Notifier.requestAuth()
            let content = UNMutableNotificationContent()
            content.title = "وردك اليومي"
            content.body = "حان وقت وردك من القرآن. هدفك اليوم \(goal) صفحة."
            content.sound = .default
            var comps = DateComponents()
            comps.hour = h
            comps.minute = m
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: "wird-daily", content: content, trigger: trigger))
        }
    }
}
