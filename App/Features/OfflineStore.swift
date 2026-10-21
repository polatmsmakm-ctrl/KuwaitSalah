import Foundation
import SwiftUI

/// ملفات الصوت المنزَّلة (لكل قارئ وسورة)
enum OfflineAudio {
    static var dir: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("offline-audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func fileURL(reciter: Int, chapter: Int) -> URL {
        dir.appendingPathComponent("\(reciter)-\(chapter).mp3")
    }

    static func localURL(reciter: Int, chapter: Int) -> URL? {
        let u = fileURL(reciter: reciter, chapter: chapter)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    static func size(reciter: Int, chapter: Int) -> Int64? {
        let u = fileURL(reciter: reciter, chapter: chapter)
        guard let a = try? FileManager.default.attributesOfItem(atPath: u.path), let n = a[.size] as? NSNumber else { return nil }
        return n.int64Value
    }
}

/// التنزيل للاستخدام بدون إنترنت: صفحات المصحف + صوت السور
@MainActor
final class OfflineStore: ObservableObject {
    @Published private(set) var cachedPages = 0
    @Published private(set) var pagesBusy = false
    @Published private(set) var pagesDone = 0
    @Published private(set) var pagesFailed = 0
    /// السور قيد التنزيل
    @Published private(set) var downloading: Set<Int> = []
    @Published private(set) var failed: Set<Int> = []
    /// يتغيّر عند أي تنزيل/حذف لتحديث الواجهة
    @Published private(set) var revision = 0

    private var pagesTask: Task<Void, Never>?

    init() {
        cachedPages = QuranAPI.cachedPageCount()
    }

    func refresh() {
        cachedPages = QuranAPI.cachedPageCount()
        revision += 1
    }

    // MARK: الصفحات

    func downloadAllPages() {
        guard !pagesBusy else { return }
        pagesBusy = true
        pagesDone = 0
        pagesFailed = 0
        pagesTask = Task { [weak self] in
            // ٣ طلبات متوازية
            let pages = Array(1...604)
            var index = 0
            while index < pages.count {
                if Task.isCancelled { break }
                let chunk = Array(pages[index..<min(index + 3, pages.count)])
                index += 3
                let results = await withTaskGroup(of: Bool.self) { group -> [Bool] in
                    for n in chunk {
                        group.addTask { (try? await QuranAPI.page(n)) != nil }
                    }
                    var out: [Bool] = []
                    for await r in group { out.append(r) }
                    return out
                }
                guard let self = self else { return }
                for ok in results {
                    if ok { self.pagesDone += 1 } else { self.pagesFailed += 1 }
                }
            }
            guard let self = self else { return }
            self.pagesBusy = false
            self.refresh()
        }
    }

    func cancelPages() {
        pagesTask?.cancel()
        pagesBusy = false
        refresh()
    }

    // MARK: الصوت

    func isDownloaded(reciter: Int, chapter: Int) -> Bool {
        _ = revision
        return OfflineAudio.localURL(reciter: reciter, chapter: chapter) != nil
    }

    func downloadAudio(reciter: Int, chapter: Int) {
        guard !downloading.contains(chapter) else { return }
        downloading.insert(chapter)
        failed.remove(chapter)
        Task { [weak self] in
            var ok = false
            do {
                let audio = try await QuranAPI.chapterAudio(reciter: reciter, chapter: chapter)
                let (tmp, resp) = try await URLSession.shared.download(from: audio.url)
                if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                    let dest = OfflineAudio.fileURL(reciter: reciter, chapter: chapter)
                    try? FileManager.default.removeItem(at: dest)
                    try FileManager.default.moveItem(at: tmp, to: dest)
                    ok = true
                }
            } catch {
                ok = false
            }
            guard let self = self else { return }
            self.downloading.remove(chapter)
            if !ok { self.failed.insert(chapter) }
            self.refresh()
        }
    }

    func deleteAudio(reciter: Int, chapter: Int) {
        try? FileManager.default.removeItem(at: OfflineAudio.fileURL(reciter: reciter, chapter: chapter))
        refresh()
    }
}
