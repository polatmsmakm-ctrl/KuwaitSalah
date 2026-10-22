import Foundation
import ActivityKit

struct PrayerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var prayerName: String
        var time: Date
    }
    var title: String
}
