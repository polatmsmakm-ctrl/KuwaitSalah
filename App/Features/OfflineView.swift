import SwiftUI

struct OfflineView: View {
    @EnvironmentObject var offline: OfflineStore
    @EnvironmentObject var player: RecitationPlayer
    @EnvironmentObject var quran: QuranStore
    @EnvironmentObject var store: Store

    private func sizeText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var body: some View {
        let fmt = store.fmt
        ZStack {
            AppBackground(kind: .quran, dim: 0.55)
            ScrollView {
                VStack(spacing: 14) {
                    pagesCard(fmt)
                    audioCard(fmt)
                    Text("التفسير يُحفظ تلقائياً بعد أول فتح لكل آية. صوت السور كبير الحجم (سورة البقرة وحدها عشرات الميغابايت)، فنزّله وأنت على الواي فاي.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                }
                .padding(16)
            }
        }
        .navigationTitle("بدون إنترنت")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { offline.refresh() }
    }

    private func pagesCard(_ fmt: Fmt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("صفحات المصحف").font(.headline)
            Text("\(fmt.number(offline.cachedPages)) من ٦٠٤ صفحة على جهازك")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
            ProgressView(value: Double(offline.cachedPages), total: 604).tint(Theme.gold)
            if offline.pagesBusy {
                HStack {
                    ProgressView()
                    Text("جارٍ التنزيل… \(fmt.number(offline.pagesDone))")
                        .font(.footnote)
                    Spacer()
                    Button("إيقاف") { offline.cancelPages() }.font(.footnote)
                }
            } else {
                Button {
                    offline.downloadAllPages()
                } label: {
                    Label(offline.cachedPages >= 604 ? "كل الصفحات منزَّلة" : "تنزيل كل المصحف",
                          systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.gold, in: Capsule())
                        .foregroundStyle(Color.black.opacity(0.85))
                }
                .disabled(offline.cachedPages >= 604)
                if offline.pagesFailed > 0 {
                    Text("تعذّر تنزيل \(fmt.number(offline.pagesFailed)) صفحة، أعد المحاولة.")
                        .font(.caption).foregroundStyle(Color.orange)
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(14)
        .glassCard(18)
    }

    private func audioCard(_ fmt: Fmt) -> some View {
        let reciter = player.reciterID
        return VStack(alignment: .leading, spacing: 10) {
            Text("صوت السور").font(.headline)
            Picker("القارئ", selection: Binding(get: { player.reciterID }, set: { player.setReciter($0) })) {
                ForEach(RecitationPlayer.reciters, id: \.id) { r in Text(r.name).tag(r.id) }
            }
            .pickerStyle(.menu)
            ForEach(quran.surahs) { s in
                HStack {
                    Text("\(fmt.number(s.n)). \(s.name)").font(.subheadline)
                    Spacer()
                    if offline.downloading.contains(s.n) {
                        ProgressView()
                    } else if offline.isDownloaded(reciter: reciter, chapter: s.n) {
                        if let b = OfflineAudio.size(reciter: reciter, chapter: s.n) {
                            Text(sizeText(b)).font(.caption2).foregroundStyle(Theme.inkSecondary)
                        }
                        Button { offline.deleteAudio(reciter: reciter, chapter: s.n) } label: {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.green)
                        }
                        .buttonStyle(.plain)
                    } else {
                        if offline.failed.contains(s.n) {
                            Text("فشل").font(.caption2).foregroundStyle(Color.orange)
                        }
                        Button { offline.downloadAudio(reciter: reciter, chapter: s.n) } label: {
                            Image(systemName: "arrow.down.circle").foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            Text("اضغط العلامة الخضراء لحذف الملف.").font(.caption2).foregroundStyle(Theme.inkSecondary)
        }
        .foregroundStyle(Theme.ink)
        .padding(14)
        .glassCard(18)
    }
}
