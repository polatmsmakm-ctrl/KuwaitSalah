import XCTest
@testable import KuwaitSalah

final class PrayerCalcTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        PrayerCalc.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testOrderAndRangesAcrossYear() {
        for region in Region.all {
            var day = date(2026, 1, 1)
            for _ in 0..<366 {
                let t = PrayerCalc.compute(day: day, region: region, settings: CalcSettings())
                XCTAssertLessThan(t[.fajr], t[.sunrise])
                XCTAssertLessThan(t[.sunrise], t[.dhuhr])
                XCTAssertLessThan(t[.dhuhr], t[.asr])
                XCTAssertLessThan(t[.asr], t[.maghrib])
                XCTAssertLessThan(t[.maghrib], t[.isha])
                day = PrayerCalc.calendar.date(byAdding: .day, value: 1, to: day)!
            }
        }
    }

    func testDhuhrNearNoonInKuwait() {
        let t = PrayerCalc.compute(day: date(2026, 10, 21), region: Region.all[0], settings: CalcSettings())
        let c = PrayerCalc.calendar.dateComponents([.hour, .minute], from: t[.dhuhr])
        XCTAssertEqual(c.hour, 11)
        XCTAssertTrue((15...45).contains(c.minute ?? 0))
    }

    func testMinuteAdjustmentMovesTimeExactly() {
        var s = CalcSettings()
        let base = PrayerCalc.compute(day: date(2026, 3, 1), region: Region.all[0], settings: s)
        s.adjust[Prayer.asr.rawValue] = 3
        let adj = PrayerCalc.compute(day: date(2026, 3, 1), region: Region.all[0], settings: s)
        XCTAssertEqual(adj[.asr].timeIntervalSince(base[.asr]), 180, accuracy: 0.5)
        XCTAssertEqual(adj[.fajr], base[.fajr])
    }

    func testQiblaFromKuwaitCity() {
        let b = PrayerCalc.qiblaBearing(lat: 29.3759, lng: 47.9774)
        XCTAssertTrue((223.5...225.5).contains(b), "bearing was \(b)")
    }

    func testNearestRegion() {
        XCTAssertEqual(Region.nearest(lat: 29.34, lng: 47.66)?.id, "jahra")
        XCTAssertNil(Region.nearest(lat: 24.7, lng: 46.7)) // الرياض خارج الكويت
    }
}

final class PrefsMigrationTests: XCTestCase {
    func testOldPrefsWithMissingFieldsKeepValues() throws {
        let json = #"{"regionID":"hawalli","use24h":true,"calc":{"fajrAngle":19}}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(Prefs.self, from: json)
        XCTAssertEqual(p.regionID, "hawalli")
        XCTAssertTrue(p.use24h)
        XCTAssertEqual(p.calc.fajrAngle, 19)
        XCTAssertEqual(p.calc.ishaAngle, 17.5)
        XCTAssertEqual(p.iqama, Iqama.defaults)
        XCTAssertEqual(p.appearance, 0)
        XCTAssertFalse(p.statsEnabled)
    }

    func testRoundTrip() throws {
        var p = Prefs()
        p.appearance = 2
        p.iqama[0] = 30
        let back = try JSONDecoder().decode(Prefs.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(p, back)
    }

    func testBadArrayLengthsFallBack() throws {
        let json = #"{"iqama":[1,2],"adhanOn":[true]}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(Prefs.self, from: json)
        XCTAssertEqual(p.iqama, Iqama.defaults)
        XCTAssertEqual(p.adhanOn.count, 5)
    }
}

final class QuranTests: XCTestCase {
    private var data: QuranLoadResult!

    override func setUpWithError() throws {
        data = try XCTUnwrap(QuranLoader.load(bundle: Bundle.main))
    }

    func testCounts() {
        XCTAssertEqual(data.surahs.count, 114)
        XCTAssertEqual(data.surahs.reduce(0) { $0 + $1.ayahs.count }, 6236)
        XCTAssertEqual(data.surahs[0].ayahs.count, 7)
        XCTAssertEqual(data.surahs[1].ayahs.count, 286)
        XCTAssertEqual(data.surahs[113].ayahs.count, 6)
    }

    func testNoEmptyAyahAndNoOddSpaces() {
        for s in data.surahs {
            for a in s.ayahs {
                XCTAssertFalse(a.isEmpty)
                XCTAssertFalse(a.unicodeScalars.contains { $0.value == 0x2009 || $0.value == 0x00A0 })
            }
        }
    }

    func testSearchFindsAyatAlKursi() {
        let hits = QuranLoader.search("الله لا إله إلا هو الحي القيوم", in: data, limit: 50)
        XCTAssertTrue(hits.contains(AyahRef(s: 2, a: 255)))
    }

    func testSearchKeyIgnoresDiacriticsAndAlef() {
        XCTAssertEqual(QuranText.searchKey("ٱلْعَٰلَمِينَ"), QuranText.searchKey("العالمين"))
    }
}
