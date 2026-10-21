import AVFoundation
import Foundation

struct WordKey: Equatable {
    let surah: Int
    let ayah: Int
    let position: Int
}

/// مشغّل التلاوة: ملف صوتي لكل سورة مع توقيت الآيات والكلمات من quran.com
final class RecitationPlayer: ObservableObject {
    static let shared = RecitationPlayer()

    static let reciters: [(id: Int, name: String)] = [
        (7, "مشاري العفاسي"),
        (3, "عبدالرحمن السديس"),
        (10, "سعود الشريم"),
        (6, "محمود خليل الحصري"),
        (9, "محمد صديق المنشاوي"),
        (2, "عبدالباسط عبدالصمد")
    ]

    @Published private(set) var isPlaying = false
    @Published private(set) var loading = false
    @Published private(set) var currentWord: WordKey?
    @Published private(set) var currentAyah: AyahRef?
    @Published var error: String?
    @Published var reciterID: Int {
        didSet { UserDefaults.standard.set(reciterID, forKey: "mushaf.reciter") }
    }

    private var player: AVPlayer?
    private var observer: Any?
    private var endObserver: NSObjectProtocol?
    private var audio: ChapterAudio?
    private var chapter = 0
    private var generation = 0
    private var lastRequested: AyahRef?
    private var currentReciter = 0
    private var stopAfter: Int?
    private var onFinish: (() -> Void)?

    init() {
        let saved = UserDefaults.standard.integer(forKey: "mushaf.reciter")
        reciterID = Self.reciters.contains(where: { $0.id == saved }) ? saved : 7
    }

    /// تغيير القارئ: إن كانت التلاوة شغّالة تنتقل فوراً للقارئ الجديد من نفس الآية
    func setReciter(_ id: Int) {
        guard id != reciterID else { return }
        let resume = currentAyah ?? lastRequested
        let wasActive = isPlaying || loading
        reciterID = id
        if wasActive, let r = resume { play(surah: r.s, ayah: r.a) }
    }

    var reciterName: String {
        Self.reciters.first(where: { $0.id == reciterID })?.name ?? ""
    }

    func play(surah: Int, ayah: Int) {
        stop()
        generation += 1
        let gen = generation
        chapter = surah
        lastRequested = AyahRef(s: surah, a: ayah)
        loading = true
        error = nil
        let reciter = reciterID
        currentReciter = reciter
        Task {
            do {
                let audio = try await QuranAPI.chapterAudio(reciter: reciter, chapter: surah)
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
                try AVAudioSession.sharedInstance().setActive(true)
                await MainActor.run {
                    guard gen == self.generation else { return }
                    self.start(audio: audio, ayah: ayah, gen: gen)
                }
            } catch {
                await MainActor.run {
                    guard gen == self.generation else { return }
                    self.loading = false
                    self.error = "تعذّر تحميل التلاوة. تأكد من الإنترنت وحاول مرة ثانية."
                    self.onFinish = nil
                }
            }
        }
    }

    private func start(audio: ChapterAudio, ayah: Int, gen: Int) {
        self.audio = audio
        // الملف المنزَّل (إن وُجد) أولى من الشبكة
        let item = AVPlayerItem(url: OfflineAudio.localURL(reciter: currentReciter, chapter: chapter) ?? audio.url)
        let p = AVPlayer(playerItem: item)
        player = p
        let startMs = audio.verses.first(where: { $0.ayah == ayah })?.from ?? 0
        observer = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
                                             queue: .main) { [weak self] t in
            self?.tick(t.seconds * 1000)
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            if self.onFinish != nil { self.finishRange(); return }
            if self.chapter < 114 {
                self.play(surah: self.chapter + 1, ayah: 1)
            } else {
                self.stop()
            }
        }
        if startMs > 0 {
            p.seek(to: CMTime(seconds: startMs / 1000, preferredTimescale: 1000),
                   toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                guard let self = self, gen == self.generation else { return }
                p.play()
                self.isPlaying = true
                self.loading = false
            }
        } else {
            p.play()
            isPlaying = true
            loading = false
        }
    }

    /// يقرأ الشيخ من آية إلى آية ثم يتوقف ويستدعي completion (لوضع: الشيخ يقرأ ثم أقرأ بعده)
    func playRange(surah: Int, from: Int, through: Int, completion: @escaping () -> Void) {
        play(surah: surah, ayah: from)
        stopAfter = through
        onFinish = completion
    }

    private func finishRange() {
        let cb = onFinish
        stop()
        cb?()
    }

    func toggle() {
        guard let p = player else { return }
        if isPlaying { p.pause(); isPlaying = false } else { p.play(); isPlaying = true }
    }

    func stop() {
        generation += 1
        if let o = observer { player?.removeTimeObserver(o) }
        observer = nil
        if let e = endObserver { NotificationCenter.default.removeObserver(e) }
        endObserver = nil
        player?.pause()
        player = nil
        audio = nil
        stopAfter = nil
        onFinish = nil
        isPlaying = false
        loading = false
        currentWord = nil
        currentAyah = nil
    }

    private func tick(_ ms: Double) {
        guard let audio = audio else { return }
        if let last = stopAfter, let end = audio.verses.first(where: { $0.ayah == last })?.to, ms >= end {
            finishRange()
            return
        }
        guard let v = audio.verses.last(where: { $0.from <= ms }) else { return }
        let ref = AyahRef(s: v.surah, a: v.ayah)
        if currentAyah != ref { currentAyah = ref }
        var pos = 0
        for w in v.words where w.from <= ms { pos = w.position }
        let key = pos > 0 ? WordKey(surah: v.surah, ayah: v.ayah, position: pos) : nil
        if currentWord != key { currentWord = key }
    }
}
