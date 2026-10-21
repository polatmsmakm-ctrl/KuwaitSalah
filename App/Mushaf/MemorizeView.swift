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
    @AppStorage("memorize.hideWords") private var hideWords = true
    @State private var finished = false
    @State private var advancing = false
    @AppStorage("memorize.listenFirst") private var listenFirst = false
    private enum Phase { case idle, sheikh, you }
    @State private var phase: Phase = .idle
    @State private var note: String?
    @State private var carry: [String] = []
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
        RecitationAligner.align(expected: tokens, heard: carry + listener.heard)
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
            if !on && !listener.heard.isEmpty && !advancing {
                finished = true
                carry += listener.heard
                listener.clearHeard()
            }
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
            advanceToNext(retry: listenFirst && res.mistakes > 0)
        }
        .onChange(of: player.error) { _, e in
            // تعذّر تشغيل الشيخ: ندخل دورك مباشرة
            if e != nil && phase == .sheikh {
                phase = .you
                listener.start()
            }
        }
        .onDisappear { listener.stop(); player.stop() }
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
            Picker("طريقة التسميع", selection: $hideWords) {
                Text("من الحفظ (مخفية)").tag(true)
                Text("مع رؤية الآية").tag(false)
            }
            .pickerStyle(.segmented)
            Toggle("الشيخ يقرأ أولاً ثم أقرأ بعده", isOn: $listenFirst)
                .foregroundStyle(Theme.ink)
                .disabled(listener.isListening || phase == .sheikh)
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
    private func advanceToNext(retry: Bool) {
        guard let s = surah else { return }
        let next = start.a + count
        advancing = true
        listener.stop()
        if retry {
            // فيه أخطاء: يظهر الخطأ لحظة، ثم يعيد الشيخ القراءة وتعيد أنت
            note = "فيه أخطاء، استمع للشيخ وأعد القراءة"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                advancing = false
                beginRound()
            }
            return
        }
        if next > s.ayahs.count {
            advancing = false
            finished = true
            phase = .idle
            return
        }
        advanced = true
        note = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            alerted = []
            start = AyahRef(s: start.s, a: next)
            count = min(count, max(1, s.ayahs.count - next + 1))
            advancing = false
            beginRound()
        }
    }

    /// جولة واحدة: (اختيارياً) الشيخ يقرأ أولاً ثم يبدأ الاستماع لك
    private func beginRound() {
        guard let s = surah else { return }
        alerted = []
        carry = []
        finished = false
        if listenFirst {
            phase = .sheikh
            let last = min(s.ayahs.count, start.a + count - 1)
            player.playRange(surah: start.s, from: start.a, through: last) {
                phase = .you
                listener.start()
            }
        } else {
            phase = .you
            listener.start()
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
        .environment(\.layoutDirection, .leftToRight)
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
        let active = listener.isListening || phase == .sheikh
        return VStack(spacing: 8) {
            if phase == .sheikh {
                Label("الشيخ يقرأ… اسمع ثم اقرأ بعده", systemImage: "ear.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            } else if let n = note, listener.isListening || advancing {
                Text(n).font(.subheadline.weight(.semibold)).foregroundStyle(Color.orange)
            } else if phase == .you && listener.isListening && listenFirst {
                Label("دورك: اقرأ الآن", systemImage: "mic.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.25, green: 0.75, blue: 0.42))
            }
            Button {
                if active {
                    player.stop()
                    listener.stop()
                    phase = .idle
                    note = nil
                    finished = !listener.heard.isEmpty || !carry.isEmpty
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
                    note = nil
                    beginRound()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: active ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 30))
                    Text(active ? "إنهاء التسميع" : (finished ? "إعادة التسميع" : "ابدأ التسميع"))
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(active ? Color.red : Theme.emerald, in: Capsule())
            }
            .buttonStyle(.plain)
            if canResume {
                Button {
                    player.stop()
                    note = nil
                    phase = .you
                    finished = false
                    listener.start()
                } label: {
                    Label("متابعة من حيث توقفت", systemImage: "play.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Theme.accent)
                        .background(Theme.accent.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// توقفت في النص: تقدر تكمل من نفس المكان بدل ما تعيد من البداية
    private var canResume: Bool {
        let n = tokens.count
        let p = result.progress
        return finished && !listener.isListening && phase != .sheikh && p > 0 && p < n
    }
}
