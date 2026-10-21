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
        list.first(where: { $0.id == tafsirID })?.name ?? "التفسير"
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
                                ForEach(list) { t in Text(t.name).tag(t.id) }
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
            Text(text)
                .font(.system(size: 19))
                .lineSpacing(8)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
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
