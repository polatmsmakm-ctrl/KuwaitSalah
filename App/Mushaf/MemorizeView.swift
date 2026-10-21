import SwiftUI

/// الحفظ والتسميع: تقرأ آية أو أكثر بصوتك، والتطبيق يقارن ما سمعه بالنص ويلوّن الكلمات.
struct MemorizeView: View {
    @State var start: AyahRef
    @EnvironmentObject var quran: QuranStore
    @EnvironmentObject var store: Store
    @EnvironmentObject var player: RecitationPlayer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var listener = RecitationListener()
    @State private var count = 1
    @State private var hideWords = true
    @State private var finished = false
    @State private var advancing = false
    @State private var alerted = Set<Int>()
    @State private var originStart: AyahRef
    @State private var originCount = 1
    @State private var advanced = false

    init(start: AyahRef) {
        _start = State(initialValue: start)
        _originStart = State(initialValue: start)
    }

    private var surah: Surah? { quran.surah(start.s) }

    private var maxCount: Int {
        guard let s = surah else { return 1 }
        return max(1, min(10, s.ayahs.count - start.a + 1))
    }

    /// كلمات الآيات كما تُعرض (بلا الرموز التي لا تُنطق وحدها)
    private var tokens: [String] {
        guard let s = surah else { return [] }
        let to = min(s.ayahs.count, start.a + count - 1)
        guard start.a >= 1, start.a <= to else { return [] }
        return s.ayahs[(start.a - 1)...(to - 1)]
            .joined(separator: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\n" })
            .map(String.init)
            .filter { !RecitationAligner.key($0).isEmpty }
    }

    private var result: AlignResult {
        RecitationAligner.align(expected: tokens, heard: listener.heard)
    }

    var body: some View {
        let toks = tokens
        let res = result
        return NavigationStack {
            ZStack {
                AppBackground(kind: .quran, dim: 0.6)
                ScrollView {
                    VStack(spacing: 14) {
                        controls
                        wordsCard(toks, res)
                        if !listener.isListening && finished && res.progress > 0 {
                            summary(toks, res)
                        }
                        if let e = listener.error {
                            Text(e).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                        }
                        micButton
                    }
                    .padding(16)
                }
            }
            .navigationTitle("التسميع")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("إغلاق") {
                        listener.stop()
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: listener.isListening) { _, on in
            if !on && !listener.heard.isEmpty && !advancing { finished = true }
        }
        .onChange(of: res.mistakes) { _, _ in
            guard listener.isListening else { return }
            var fresh = false
            for (i, st) in res.states.enumerated() where st == .wrong && !alerted.contains(i) {
                alerted.insert(i)
                fresh = true
            }
            if fresh { MistakeAlert.shared.fire() }
        }
        .onChange(of: res.progress) { _, p in
            // أكمل الآية/الآيات المطلوبة: انتقل تلقائياً للتي بعدها واستمر بالاستماع
            guard listener.isListening, !toks.isEmpty, p >= toks.count else { return }
            advanceToNext()
        }
        .onDisappear { listener.stop() }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                Text("سورة \(surah?.name ?? "") · من آية \(store.fmt.number(start.a))")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            Stepper(value: $count, in: 1...maxCount) {
                Text("عدد الآيات: \(store.fmt.number(count))")
                    .foregroundStyle(Theme.ink)
            }
            .disabled(listener.isListening)
            Toggle("إخفاء الكلمات حتى تقرأها", isOn: $hideWords)
                .foregroundStyle(Theme.ink)
            HStack(spacing: 10) {
                Button {
                    player.play(surah: start.s, ayah: start.a)
                } label: {
                    Label("استمع للآية", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                if player.isPlaying || player.loading {
                    Button {
                        player.stop()
                    } label: {
                        Label("إيقاف", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
        }
        .padding(14)
        .glassCard(20)
        .onChange(of: count) { _, _ in resetAttempt() }
    }

    /// ينتقل للآيات التالية ويعيد الاستماع (الجلسة الصوتية من أبل تُقطع بعد وقت قصير، فنبدأ جلسة جديدة لكل آية)
    private func advanceToNext() {
        guard let s = surah else { return }
        let next = start.a + count
        advancing = true
        advanced = true
        listener.stop()
        if next > s.ayahs.count {
            // نهاية السورة
            advancing = false
            finished = true
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            alerted = []
            start = AyahRef(s: start.s, a: next)
            count = min(count, max(1, s.ayahs.count - next + 1))
            finished = false
            listener.start()
            advancing = false
        }
    }

    private func resetAttempt() {
        listener.stop()
        finished = false
    }

    @ViewBuilder
    private func wordsCard(_ toks: [String], _ res: AlignResult) -> some View {
        FlowLayout(spacing: 10, lineSpacing: 14, rtl: true) {
            ForEach(Array(toks.enumerated()), id: \.offset) { i, w in
                chip(w, state: i < res.states.count ? res.states[i] : .pending)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCard(20)
        .environment(\.layoutDirection, .rightToLeft)
    }

    @ViewBuilder
    private func chip(_ word: String, state: WordState) -> some View {
        let font = QuranFont.font(quran.fontName, size: 26)
        if hideWords && state == .pending {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.inkSecondary.opacity(0.25))
                .frame(width: max(24, CGFloat(RecitationAligner.key(word).count) * 11), height: 22)
                .padding(.vertical, 6)
        } else {
            Text(word)
                .font(font)
                .foregroundStyle(color(state))
                .padding(.horizontal, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(background(state))
                )
        }
    }

    private func color(_ s: WordState) -> Color {
        switch s {
        case .pending: return Theme.ink
        case .correct: return Color(red: 0.25, green: 0.75, blue: 0.42)
        case .wrong: return Color(red: 0.95, green: 0.35, blue: 0.32)
        case .missed: return Color(red: 0.98, green: 0.62, blue: 0.20)
        }
    }

    private func background(_ s: WordState) -> Color {
        switch s {
        case .wrong: return Color.red.opacity(0.15)
        case .missed: return Color.orange.opacity(0.15)
        default: return Color.clear
        }
    }

    private func summary(_ toks: [String], _ res: AlignResult) -> some View {
        let finishedAll = res.progress >= toks.count
        return VStack(alignment: .leading, spacing: 10) {
            Text(res.mistakes == 0 && finishedAll ? "ما شاء الله، قراءة صحيحة بلا أخطاء" : "النتيجة")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            HStack(spacing: 16) {
                Label("\(store.fmt.number(res.correct)) صحيحة", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color(red: 0.25, green: 0.75, blue: 0.42))
                Label("\(store.fmt.number(res.mistakes)) أخطاء", systemImage: "xmark.circle.fill")
                    .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.32))
            }
            .font(.subheadline.weight(.semibold))
            if !finishedAll {
                Text("توقفت عند الكلمة \(store.fmt.number(res.progress)) من \(store.fmt.number(toks.count)).")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
            ForEach(Array(toks.enumerated()), id: \.offset) { i, w in
                if i < res.states.count, res.states[i] == .wrong || res.states[i] == .missed {
                    HStack {
                        Text(w).font(QuranFont.font(quran.fontName, size: 22)).foregroundStyle(Theme.ink)
                        Spacer()
                        if res.states[i] == .missed {
                            Text("تُركت").font(.caption).foregroundStyle(Color.orange)
                        } else {
                            Text("سُمعت: \(res.heardFor[i] ?? "؟")")
                                .font(.caption)
                                .foregroundStyle(Theme.inkSecondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(20)
    }

    private var micButton: some View {
        Button {
            if listener.isListening {
                listener.stop()
                finished = true
            } else {
                player.stop()
                if advanced {
                    // إعادة التسميع ترجع لأول آية بدأت منها
                    start = originStart
                    count = originCount
                    advanced = false
                } else {
                    originStart = start
                    originCount = count
                }
                finished = false
                alerted = []
                listener.start()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: listener.isListening ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 30))
                Text(listener.isListening ? "إنهاء التسميع" : (finished ? "إعادة التسميع" : "ابدأ التسميع"))
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(listener.isListening ? Color.red : Theme.emerald, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
