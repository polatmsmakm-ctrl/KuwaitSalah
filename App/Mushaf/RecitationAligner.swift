import Foundation

// مقارنة ما سمعه التطبيق بنص الآيات، كلمةً كلمة (منطق صرف يمكن اختباره بلا صوت).

enum WordState: Equatable {
    case pending   // لم تُقرأ بعد
    case correct
    case wrong     // قُرئت بشكل مختلف
    case missed    // تُركت وقُرئ ما بعدها
}

struct AlignResult: Equatable {
    let states: [WordState]
    let heardFor: [Int: String]   // الكلمة المسموعة مقابل كل كلمة خاطئة
    let progress: Int             // عدد الكلمات المتوقعة التي بلغها القارئ

    var mistakes: Int { states.filter { $0 == .wrong || $0 == .missed }.count }
    var correct: Int { states.filter { $0 == .correct }.count }
}

enum RecitationAligner {
    /// مفتاح مقارنة: بلا تشكيل ولا ألفات، وبتوحيد الياء والهاء والهمزات
    static func key(_ s: String) -> String {
        let k = QuranText.searchKey(s).replacingOccurrences(of: " ", with: "")
        if !k.isEmpty { return k }
        return QuranText.normalize(s).replacingOccurrences(of: " ", with: "")
    }

    /// المسافة بين كلمتين من 0 (متطابقتان) إلى 1 (مختلفتان تماماً)
    static func distance(_ a: String, _ b: String) -> Double {
        let x = Array(a), y = Array(b)
        if x.isEmpty && y.isEmpty { return 0 }
        if x.isEmpty || y.isEmpty { return 1 }
        var prev = Array(0...y.count)
        var cur = Array(repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            cur[0] = i
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &cur)
        }
        return Double(prev[y.count]) / Double(max(x.count, y.count))
    }

    static let matchThreshold = 0.34

    /// expected: كلمات الآيات، heard: ما سمعه التعرّف الصوتي حتى الآن
    static func align(expected: [String], heard: [String]) -> AlignResult {
        let e = expected.map { key($0) }
        let h = heard.map { key($0) }.filter { !$0.isEmpty }
        let n = e.count, m = h.count
        if n == 0 { return AlignResult(states: [], heardFor: [:], progress: 0) }
        if m == 0 { return AlignResult(states: Array(repeating: .pending, count: n), heardFor: [:], progress: 0) }

        // cost[i][j]: أقل كلفة لمحاذاة أول i كلمة مسموعة مع أول j كلمة متوقعة
        var cost = Array(repeating: Array(repeating: 0.0, count: n + 1), count: m + 1)
        for j in 0...n { cost[0][j] = Double(j) }
        for i in 1...m { cost[i][0] = Double(i) }
        for i in 1...m {
            for j in 1...n {
                let d = distance(h[i - 1], e[j - 1])
                let sub = d <= matchThreshold ? d : 1.0
                cost[i][j] = min(cost[i - 1][j - 1] + sub,     // مطابقة أو استبدال
                                 cost[i][j - 1] + 1.0,         // كلمة متوقعة متروكة
                                 cost[i - 1][j] + 1.0)         // كلمة زائدة مسموعة
            }
        }
        // آخر كلمة بلغها القارئ: أقل كلفة، وعند التساوي نأخذ الأبعد
        var bestJ = 0
        var bestCost = Double.greatestFiniteMagnitude
        for j in 0...n where cost[m][j] <= bestCost {
            bestCost = cost[m][j]
            bestJ = j
        }

        var states = Array(repeating: WordState.pending, count: n)
        var heardFor: [Int: String] = [:]
        var i = m, j = bestJ
        while j > 0 {
            if i > 0 {
                let d = distance(h[i - 1], e[j - 1])
                let sub = d <= matchThreshold ? d : 1.0
                if abs(cost[i][j] - (cost[i - 1][j - 1] + sub)) < 1e-9 {
                    if d <= matchThreshold {
                        states[j - 1] = .correct
                    } else {
                        states[j - 1] = .wrong
                        heardFor[j - 1] = heard.filter { !key($0).isEmpty }[i - 1]
                    }
                    i -= 1; j -= 1
                    continue
                }
                if abs(cost[i][j] - (cost[i][j - 1] + 1.0)) < 1e-9 {
                    states[j - 1] = .missed
                    j -= 1
                    continue
                }
                i -= 1   // كلمة زائدة مسموعة
            } else {
                states[j - 1] = .missed
                j -= 1
            }
        }
        return AlignResult(states: states, heardFor: heardFor, progress: bestJ)
    }
}
