import SwiftUI
import UIKit

struct MushafTarget: Hashable {
    let page: Int
    let focus: AyahRef?
}

/// حالة صفحات المصحف المحمّلة (تُجلب عند الحاجة وتُخزَّن على القرص)
final class MushafModel: ObservableObject {
    @Published private(set) var pages: [Int: MPage] = [:]
    @Published private(set) var failed: Set<Int> = []
    private var inflight: Set<Int> = []

    func ensure(_ n: Int) {
        guard n >= 1, n <= 604, pages[n] == nil, !inflight.contains(n) else { return }
        inflight.insert(n)
        failed.remove(n)
        Task {
            do {
                let p = try await QuranAPI.page(n)
                await MainActor.run {
                    self.pages[n] = p
                    self.inflight.remove(n)
                }
            } catch {
                await MainActor.run {
                    self.failed.insert(n)
                    self.inflight.remove(n)
                }
            }
        }
    }

    func retry(_ n: Int) {
        failed.remove(n)
        ensure(n)
    }

    func pageContaining(_ ref: AyahRef) -> Int? {
        for (n, p) in pages where p.refs.contains(ref) { return n }
        return nil
    }
}

private let mushafFontName = "AmiriQuran-Regular"

struct MushafView: View {
    let target: MushafTarget
    @EnvironmentObject var quran: QuranStore
    @EnvironmentObject var store: Store
    @EnvironmentObject var model: MushafModel
    @EnvironmentObject var player: RecitationPlayer
    @EnvironmentObject var wird: WirdStore
    @AppStorage("mushaf.lastPage") private var lastPage = 1
    @State private var page: Int
    @State private var selected: AyahRef?
    @State private var tafsirRef: AyahRef?
    @State private var memoRef: AyahRef?
    @State private var showGoto = false

    init(target: MushafTarget) {
        self.target = target
        _page = State(initialValue: min(max(target.page, 1), 604))
        _selected = State(initialValue: target.focus)
    }

    var body: some View {
        ZStack {
            AppBackground(kind: .quran, dim: 0.6)
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(1...604, id: \.self) { n in
                        MushafPageView(number: n, selected: $selected)
                            .tag(n)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                bottomBars
            }
        }
        .navigationTitle("صفحة \(store.fmt.number(page))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showGoto = true } label: { Image(systemName: "list.bullet") }
                    .accessibilityLabel("الانتقال إلى سورة أو صفحة")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("القارئ", selection: Binding(get: { player.reciterID }, set: { player.setReciter($0) })) {
                        ForEach(RecitationPlayer.reciters, id: \.id) { r in Text(r.name).tag(r.id) }
                    }
                } label: {
                    Image(systemName: "person.wave.2")
                }
                .accessibilityLabel("اختيار القارئ")
            }
        }
        .onAppear { preload(page) }
        .task(id: page) {
            // الصفحة تُحسب مقروءة إذا بقيت فيها ٣ ثوانٍ
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if Task.isCancelled { return }
            wird.visit(page)
        }
        .onChange(of: page) { _, n in
            lastPage = n
            preload(n)
        }
        .onChange(of: player.currentAyah) { _, ref in follow(ref) }
        .sheet(item: $tafsirRef) { ref in TafsirSheet(ref: ref) }
        .sheet(item: $memoRef) { ref in MemorizeView(start: ref) }
        .sheet(isPresented: $showGoto) { MushafGotoView(page: $page) }
    }

    private func preload(_ n: Int) {
        for k in [n, n + 1, n - 1, n + 2] { model.ensure(k) }
    }

    /// أثناء التلاوة تنتقل الصفحة وحدها عند الوصول لآية في صفحة أخرى
    private func follow(_ ref: AyahRef?) {
        guard let ref = ref else { return }
        if model.pages[page]?.refs.contains(ref) == true { return }
        if let n = model.pageContaining(ref) {
            withAnimation { page = n }
            return
        }
        Task {
            if let n = try? await QuranAPI.pageNumber(of: ref) {
                await MainActor.run { withAnimation { page = n } }
            }
        }
    }

    @ViewBuilder
    private var bottomBars: some View {
        VStack(spacing: 8) {
            if player.loading || player.isPlaying || player.currentAyah != nil || player.error != nil {
                playerBar
            }
            if let ref = selected {
                selectionBar(ref)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, selected != nil || player.currentAyah != nil || player.loading ? 8 : 0)
    }

    private var playerBar: some View {
        HStack(spacing: 14) {
            if player.loading {
                ProgressView().tint(Theme.accent)
            } else {
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title3)
                }
                .accessibilityLabel(player.isPlaying ? "إيقاف مؤقت" : "تشغيل")
            }
            VStack(alignment: .leading, spacing: 2) {
                if let e = player.error {
                    Text(e).font(.footnote).foregroundStyle(.red)
                } else {
                    Text(player.reciterName).font(.footnote.weight(.semibold))
                    if let r = player.currentAyah, let s = quran.surah(r.s) {
                        Text("سورة \(s.name) · آية \(store.fmt.number(r.a))")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
            Spacer()
            Button { player.stop(); player.error = nil } label: {
                Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(Theme.inkSecondary)
            }
            .accessibilityLabel("إيقاف التلاوة")
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassCard(20)
    }

    private func selectionBar(_ ref: AyahRef) -> some View {
        let name = quran.surah(ref.s)?.name ?? ""
        return VStack(spacing: 8) {
            Text("سورة \(name) · آية \(store.fmt.number(ref.a))")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
            HStack(spacing: 6) {
                actionButton("play.circle.fill", "استماع") { player.play(surah: ref.s, ayah: ref.a) }
                actionButton("text.book.closed.fill", "تفسير") { tafsirRef = ref }
                actionButton("mic.circle.fill", "تسميع") { memoRef = ref }
                actionButton(quran.isFavorite(ref) ? "star.fill" : "star", "مفضلة") { quran.toggleFavorite(ref) }
                actionButton("bookmark.fill", "علّم هنا") { quran.lastRead = ref }
                actionButton("xmark", "إلغاء") { selected = nil }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .glassCard(20)
    }

    private func actionButton(_ symbol: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: صفحة واحدة

private enum MushafRow {
    case header(Int)
    case basmala
    case line([MWord])
}

struct MushafPageView: View {
    let number: Int
    @Binding var selected: AyahRef?
    @EnvironmentObject var model: MushafModel
    @EnvironmentObject var player: RecitationPlayer
    @EnvironmentObject var quran: QuranStore
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) private var scheme

    private var paper: Color {
        scheme == .dark ? Color(red: 0.06, green: 0.09, blue: 0.09) : Color(red: 0.99, green: 0.97, blue: 0.91)
    }
    private var ink: Color {
        scheme == .dark ? Color(red: 0.93, green: 0.91, blue: 0.84) : Color(red: 0.10, green: 0.10, blue: 0.10)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(paper)
                RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(0.55), lineWidth: 1.2)
                if let page = model.pages[number] {
                    content(page, size: geo.size)
                } else if model.failed.contains(number) {
                    VStack(spacing: 10) {
                        Text("تعذّر تحميل الصفحة").foregroundStyle(ink)
                        Text("تأكد من الإنترنت. بعد أول تحميل تعمل الصفحة دون إنترنت.")
                            .font(.footnote)
                            .foregroundStyle(ink.opacity(0.6))
                            .multilineTextAlignment(.center)
                        Button("إعادة المحاولة") { model.retry(number) }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(20)
                } else {
                    ProgressView().tint(Theme.accent)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .task { model.ensure(number) }
    }

    private func rows(_ page: MPage) -> [MushafRow] {
        var out: [MushafRow] = []
        for line in page.lines {
            if let f = line.first, f.ayah == 1, f.position == 1, !f.isEnd {
                out.append(.header(f.surah))
                if f.surah != 1 && f.surah != 9 { out.append(.basmala) }
            }
            out.append(.line(line))
        }
        return out
    }

    private func endMark(_ n: Int) -> String {
        "\u{FD3F}\(store.fmt.number(n))\u{FD3E}"
    }

    private func lineText(_ line: [MWord]) -> String {
        line.map { $0.isEnd ? endMark($0.ayah) : $0.text }.joined(separator: " ")
    }

    private func naturalWidth(_ line: [MWord], size: CGFloat) -> CGFloat {
        let font = UIFont(name: mushafFontName, size: size) ?? UIFont.systemFont(ofSize: size)
        return (lineText(line) as NSString).size(withAttributes: [.font: font]).width
    }

    @ViewBuilder
    private func content(_ page: MPage, size: CGSize) -> some View {
        let rs = rows(page)
        let availW = size.width - 24
        let availH = size.height - 44
        let maxNatural = page.lines.map { naturalWidth($0, size: 100) }.max() ?? 1
        let widthFit = availW / max(maxNatural, 1) * 100 * 0.97
        let heightFit = availH / CGFloat(max(rs.count, 1)) / 1.85
        let fontSize = max(12, min(widthFit, heightFit, 36))
        let rowH = min(availH / CGFloat(max(rs.count, 1)), fontSize * 2.4)

        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                ForEach(Array(rs.enumerated()), id: \.offset) { _, row in
                    rowView(row, fontSize: fontSize, availW: availW)
                        .frame(height: rowH)
                }
            }
            .frame(width: availW)
            Spacer(minLength: 0)
            Text(store.fmt.number(number))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ink.opacity(0.55))
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func rowView(_ row: MushafRow, fontSize: CGFloat, availW: CGFloat) -> some View {
        switch row {
        case .header(let n):
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.accent, lineWidth: 1.4)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.accent.opacity(0.10))
                Text("سورة \(quran.surah(n)?.name ?? "")")
                    .font(.custom(mushafFontName, size: fontSize * 0.95))
                    .foregroundStyle(ink)
            }
            .padding(.vertical, 3)
        case .basmala:
            Text(quran.bismillah ?? "")
                .font(.custom(mushafFontName, size: fontSize * 0.95))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
        case .line(let line):
            lineView(line, fontSize: fontSize, availW: availW)
        }
    }

    private func lineView(_ line: [MWord], fontSize: CGFloat, availW: CGFloat) -> some View {
        let natural = naturalWidth(line, size: fontSize)
        let justify = natural > availW * 0.80
        return HStack(spacing: justify ? 0 : fontSize * 0.22) {
            ForEach(Array(line.enumerated()), id: \.element.id) { idx, w in
                wordView(w, fontSize: fontSize)
                if justify && idx < line.count - 1 {
                    Spacer(minLength: fontSize * 0.12)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func wordView(_ w: MWord, fontSize: CGFloat) -> some View {
        let isSelected = selected == w.ref
        let isPlaying = player.currentWord == WordKey(surah: w.surah, ayah: w.ayah, position: w.position)
        return Text(w.isEnd ? endMark(w.ayah) : w.text)
            .font(.custom(mushafFontName, size: fontSize))
            .foregroundStyle(w.isEnd ? Theme.accent : ink)
            .fixedSize()
            .padding(.horizontal, 1)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isPlaying ? Theme.accent.opacity(0.50) : (isSelected ? Theme.accent.opacity(0.20) : Color.clear))
            )
            .contentShape(Rectangle())
            .onTapGesture { selected = isSelected ? nil : w.ref }
    }
}

// MARK: الانتقال

struct MushafGotoView: View {
    @Binding var page: Int
    @EnvironmentObject var quran: QuranStore
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            List {
                Section("رقم الصفحة") {
                    HStack {
                        TextField("١ – ٦٠٤", text: $text)
                            .keyboardType(.numberPad)
                        Button("اذهب") {
                            if let n = Int(QuranText.asciiDigits(text)), (1...604).contains(n) {
                                page = n
                                dismiss()
                            }
                        }
                    }
                }
                Section("السور") {
                    ForEach(quran.surahs) { s in
                        Button {
                            page = QuranAPI.startPage(ofSurah: s.n)
                            dismiss()
                        } label: {
                            HStack {
                                Text("\(store.fmt.number(s.n)). \(s.name)")
                                Spacer()
                                Text("ص \(store.fmt.number(QuranAPI.startPage(ofSurah: s.n)))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("الانتقال")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("إغلاق") { dismiss() } }
            }
        }
    }
}
