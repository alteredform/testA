import SwiftUI
import WebKit

final class DownloadItem: ObservableObject, Identifiable {
    enum State: Equatable {
        case running
        case failed(String)
    }

    let id = UUID()
    @Published var filename: String
    @Published var fraction: Double = 0
    @Published var state: State = .running

    var destination: URL?
    fileprivate let download: WKDownload
    fileprivate var observation: NSKeyValueObservation?

    init(download: WKDownload) {
        self.download = download
        self.filename = download.originalRequest?.url?.lastPathComponent ?? "Download"
    }
}

/// Receives WKDownloads from any tab and saves them into the app's Documents folder,
/// which is exposed in the Files app (UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace).
final class DownloadManager: NSObject, ObservableObject, WKDownloadDelegate {
    static let shared = DownloadManager()

    @Published private(set) var active: [DownloadItem] = []
    @Published private(set) var files: [URL] = []
    @Published var toast: String?

    let directory: URL
    private var items: [ObjectIdentifier: DownloadItem] = [:]

    private override init() {
        directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        super.init()
        refresh()
    }

    var runningCount: Int {
        active.filter { $0.state == .running }.count
    }

    // MARK: Registration

    func register(_ download: WKDownload) {
        let item = DownloadItem(download: download)
        download.delegate = self
        items[ObjectIdentifier(download)] = item
        item.observation = download.progress.observe(\.fractionCompleted) { [weak item] progress, _ in
            let value = progress.fractionCompleted
            DispatchQueue.main.async { item?.fraction = value }
        }
        DispatchQueue.main.async {
            self.active.insert(item, at: 0)
            self.showToast("Downloading…")
        }
    }

    // MARK: WKDownloadDelegate

    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let destination = uniqueURL(for: sanitize(suggestedFilename))
        if let item = items[ObjectIdentifier(download)] {
            item.destination = destination
            DispatchQueue.main.async {
                item.filename = destination.lastPathComponent
                self.showToast("Downloading \(destination.lastPathComponent)")
            }
        }
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let item = items.removeValue(forKey: ObjectIdentifier(download)) else { return }
        DispatchQueue.main.async {
            self.active.removeAll { $0.id == item.id }
            self.refresh()
            self.showToast("Saved \(item.filename) to Files")
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        // Cancelled downloads were already removed from `items`.
        guard let item = items[ObjectIdentifier(download)] else { return }
        items.removeValue(forKey: ObjectIdentifier(download))
        if let destination = item.destination {
            try? FileManager.default.removeItem(at: destination)
        }
        DispatchQueue.main.async {
            item.state = .failed(error.localizedDescription)
            self.refresh()
        }
    }

    // MARK: Actions

    func cancel(_ item: DownloadItem) {
        if let key = items.first(where: { $0.value.id == item.id })?.key {
            items.removeValue(forKey: key)
        }
        item.download.cancel()
        if let destination = item.destination {
            try? FileManager.default.removeItem(at: destination)
        }
        active.removeAll { $0.id == item.id }
        refresh()
    }

    func dismissFailed(_ item: DownloadItem) {
        active.removeAll { $0.id == item.id }
    }

    func delete(_ urls: [URL]) {
        for url in urls { try? FileManager.default.removeItem(at: url) }
        refresh()
    }

    func refresh() {
        let inProgress = Set(active.compactMap { $0.state == .running ? $0.destination?.standardizedFileURL : nil })
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles])) ?? []
        files = urls
            .filter { !inProgress.contains($0.standardizedFileURL) }
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return a > b
            }
    }

    func details(for url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        var parts: [String] = []
        if let size = values?.fileSize {
            parts.append(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
        }
        if let date = values?.contentModificationDate {
            parts.append(date.formatted(date: .abbreviated, time: .shortened))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Helpers

    private func showToast(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.toast == message { self?.toast = nil }
        }
    }

    private func sanitize(_ name: String) -> String {
        var cleaned = name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty || cleaned.hasPrefix(".") { cleaned = "download" + cleaned }
        return cleaned
    }

    private func uniqueURL(for filename: String) -> URL {
        var candidate = directory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }
        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var n = 1
        repeat {
            let name = ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)"
            candidate = directory.appendingPathComponent(name)
            n += 1
        } while FileManager.default.fileExists(atPath: candidate.path)
        return candidate
    }
}
