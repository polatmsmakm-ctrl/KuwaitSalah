import XCTest
@testable import KuwaitSalah

final class RecitationAlignerTests: XCTestCase {
    private let ayah = "بسم الله الرحمن الرحيم".split(separator: " ").map(String.init)

    func testExactRecitationIsAllCorrect() {
        let r = RecitationAligner.align(expected: ayah, heard: ayah)
        XCTAssertEqual(r.states, [.correct, .correct, .correct, .correct])
        XCTAssertEqual(r.mistakes, 0)
        XCTAssertEqual(r.progress, 4)
    }

    func testNothingHeardIsAllPending() {
        let r = RecitationAligner.align(expected: ayah, heard: [])
        XCTAssertEqual(r.states, Array(repeating: WordState.pending, count: 4))
    }

    func testPartialRecitationLeavesRestPending() {
        let r = RecitationAligner.align(expected: ayah, heard: ["بسم", "الله"])
        XCTAssertEqual(r.states, [.correct, .correct, .pending, .pending])
        XCTAssertEqual(r.progress, 2)
    }

    func testSkippedWordIsMissed() {
        let r = RecitationAligner.align(expected: ayah, heard: ["بسم", "الرحمن", "الرحيم"])
        XCTAssertEqual(r.states, [.correct, .missed, .correct, .correct])
        XCTAssertEqual(r.mistakes, 1)
    }

    func testWrongWordIsWrongAndKeepsHeardWord() {
        let r = RecitationAligner.align(expected: ayah, heard: ["بسم", "الله", "الكريم", "الرحيم"])
        XCTAssertEqual(r.states, [.correct, .correct, .wrong, .correct])
        XCTAssertEqual(r.heardFor[2], "الكريم")
    }

    func testDiacriticsAndAlefVariantsDoNotCountAsMistakes() {
        let expected = ["ٱلْحَمْدُ", "لِلَّهِ", "رَبِّ", "ٱلْعَٰلَمِينَ"]
        let heard = ["الحمد", "لله", "رب", "العالمين"]
        let r = RecitationAligner.align(expected: expected, heard: heard)
        XCTAssertEqual(r.mistakes, 0)
        XCTAssertEqual(r.correct, 4)
    }
}

final class QuranAPIParsingTests: XCTestCase {
    func testSurahStartPagesAreComplete() {
        XCTAssertEqual(QuranAPI.surahStartPages.count, 114)
        XCTAssertEqual(QuranAPI.startPage(ofSurah: 1), 1)
        XCTAssertEqual(QuranAPI.startPage(ofSurah: 2), 2)
        XCTAssertEqual(QuranAPI.startPage(ofSurah: 18), 293)
        XCTAssertEqual(QuranAPI.startPage(ofSurah: 36), 440)
        XCTAssertEqual(QuranAPI.startPage(ofSurah: 67), 562)
        XCTAssertEqual(QuranAPI.startPage(ofSurah: 114), 604)
        XCTAssertEqual(QuranAPI.surahStartPages, QuranAPI.surahStartPages.sorted())
    }

    func testParsePageWordsAndGroupsByLine() throws {
        let json = """
        {"verses":[{"verse_key":"1:1","words":[
          {"position":1,"text_uthmani":"بِسْمِ","line_number":2,"char_type_name":"word"},
          {"position":2,"text_uthmani":"ٱللَّهِ","line_number":2,"char_type_name":"word"},
          {"position":3,"text_uthmani":"١","line_number":2,"char_type_name":"end"}]},
         {"verse_key":"1:2","words":[
          {"position":1,"text_uthmani":"ٱلْحَمْدُ","line_number":3,"char_type_name":"word"}]}],
         "pagination":{"next_page":null}}
        """.data(using: .utf8)!
        let (words, next) = try QuranAPI.parsePageWords(json)
        XCTAssertEqual(words.count, 4)
        XCTAssertNil(next)
        XCTAssertTrue(words[2].isEnd)
        let page = QuranAPI.group(words: words, page: 1)
        XCTAssertEqual(page.lines.count, 2)
        XCTAssertEqual(page.lines[0].count, 3)
        XCTAssertEqual(page.refs, [AyahRef(s: 1, a: 1), AyahRef(s: 1, a: 2)])
    }

    func testParseChapterAudioTimings() throws {
        let json = """
        {"audio_file":{"audio_url":"https://example.com/1.mp3","timestamps":[
          {"verse_key":"1:1","timestamp_from":0,"timestamp_to":5000,"segments":[[1,0,900],[2,900,1800]]},
          {"verse_key":"1:2","timestamp_from":5000,"timestamp_to":9000,"segments":[]}]}}
        """.data(using: .utf8)!
        let a = try QuranAPI.parseChapterAudio(json, chapter: 1)
        XCTAssertEqual(a.verses.count, 2)
        XCTAssertEqual(a.verses[0].words.count, 2)
        XCTAssertEqual(a.verses[1].from, 5000)
    }

    func testStripHTMLKeepsParagraphs() {
        let s = QuranAPI.stripHTML("<p>الأول &nbsp; نص</p><p>الثاني</p>")
        XCTAssertEqual(s, "الأول نص\n\nالثاني")
    }
}

final class TafsirDisplayTests: XCTestCase {
    func testDisplayStripsBidiControlsAndForcesRTL() {
        let raw = "\u{202D}قال أبو جعفر\u{202C}\n\nتأويل"
        let out = TafsirSheet.display(raw)
        XCTAssertFalse(out.contains("\u{202D}"))
        XCTAssertTrue(out.hasPrefix("\u{200F}قال"))
        XCTAssertTrue(out.contains("\n\n\u{200F}تأويل"))
    }
}
