import SwiftUI

/// تفسير آية: يجلب التفاسير العربية من quran.com (الميسر افتراضياً) ويخزّنها للاستخدام دون إنترنت
struct TafsirSheet: View {
    let ref: AyahRef
    @EnvironmentObject var quran: QuranStore
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("mushaf.tafsirID") private var tafsirID = 0
    @State private var list: [TafsirInfo] = []
    @State private var text: String?
    @State private var failed = false

    private var currentName: String {
        list.first(where: { $0.id == tafsirID })?.displayName ?? "التفسير"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(kind: .quran, dim: 0.55)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let s = quran.surah(ref.s), let t = quran.ayahText(ref) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("سورة \(s.name) · آية \(store.fmt.number(ref.a))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                                Text(t)
                                    .font(QuranFont.font(quran.fontName, size: 24))
                                    .foregroundStyle(Theme.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(14)
                            .glassCard(18)
                        }
                        content
                    }
                    .padding(16)
                }
            }
            .navigationTitle(currentName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("إغلاق") { dismiss() }
                }
                if list.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("التفسير", selection: $tafsirID) {
                                ForEach(list) { t in Text(t.displayName).tag(t.id) }
                            }
                        } label: {
                            Image(systemName: "books.vertical")
                        }
                        .accessibilityLabel("اختيار التفسير")
                    }
                }
            }
            .task(id: tafsirID) { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let text = text {
            Text(Self.display(text))
                .font(Font.custom("Amiri-Regular", size: 23))
                .lineSpacing(12)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .environment(\.layoutDirection, .rightToLeft)
                .textSelection(.enabled)
                .padding(14)
                .glassCard(18)
        } else if failed {
            VStack(spacing: 10) {
                Text("تعذّر تحميل التفسير").font(.headline)
                Text("تأكد من الإنترنت. بعد أول تحميل يعمل التفسير دون إنترنت.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                Button("إعادة المحاولة") { Task { await load() } }
                    .buttonStyle(.borderedProminent)
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(20)
            .glassCard(18)
        } else {
            ProgressView().tint(Theme.accent).frame(maxWidth: .infinity).padding(30)
        }
    }

    /// بعض التفاسير تأتي بمحارف اتجاه مختلطة فتنقلب الفقرة (الكلمات تُقرأ من اليسار):
    /// نحذف محارف التحكم القديمة ونثبّت اتجاه كل فقرة من اليمين لليسار.
    static func display(_ raw: String) -> String {
        let controls = Set<Character>(["\u{200E}", "\u{200F}", "\u{202A}", "\u{202B}", "\u{202C}", "\u{202D}", "\u{202E}",
                                      "\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}", "\u{061C}"])
        let clean = String(raw.filter { !controls.contains($0) })
        return clean.components(separatedBy: "\n")
            .map { $0.isEmpty ? $0 : "\u{200F}" + $0 }
            .joined(separator: "\n")
    }

    private func load() async {
        text = nil
        failed = false
        if list.isEmpty, let l = try? await QuranAPI.arabicTafsirs() { list = l }
        if tafsirID == 0 {
            let preferred = list.first(where: { $0.name.contains("ميسر") || $0.name.lowercased().contains("muyassar") })
            tafsirID = preferred?.id ?? 16
            return   // يُعاد التحميل تلقائياً لأن tafsirID تغيّر
        }
        do {
            let t = try await QuranAPI.tafsir(id: tafsirID, ref: ref)
            text = t.isEmpty ? "لا يوجد تفسير لهذه الآية في هذا المصدر." : t
        } catch {
            failed = true
        }
    }
}
