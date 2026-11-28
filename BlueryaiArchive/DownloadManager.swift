import Foundation
import SwiftUI

struct ArchiveDownload: Identifiable {
    enum Phase: Equatable {
        case resolving
        case downloading
        case complete
        case failed(String)
        case cancelled
    }

    let id: UUID
    let sourceURL: String
    let sourceName: String
    var filename: String
    var receivedBytes: Int64
    var expectedBytes: Int64
    var phase: Phase
    var fileURL: URL?

    var fractionCompleted: Double? {
        expectedBytes > 0 ? min(1, Double(receivedBytes) / Double(expectedBytes)) : nil
    }

    var progressSummary: String {
        if phase == .resolving { return "Finding a downloadable file…" }
        let received = ByteCountFormatter.string(fromByteCount: receivedBytes, countStyle: .file)
        guard expectedBytes > 0 else { return "\(received) received · total size unavailable" }
        let total = ByteCountFormatter.string(fromByteCount: expectedBytes, countStyle: .file)
        let percent = Int((fractionCompleted ?? 0) * 100)
        return "\(received) of \(total) · \(percent)%"
    }
}

final class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = DownloadManager()

    @Published private(set) var files: [URL] = []
    @Published private(set) var downloads: [ArchiveDownload] = []
    @Published var toast: String?

    private let directory: URL
    private var session: URLSession!
    private var tasks: [UUID: URLSessionDownloadTask] = [:]
    private var resolutionTasks: [UUID: Task<Void, Never>] = [:]
    private var sources: [UUID: ArchiveLink] = [:]

    private override init() {
        directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue.main)
        refresh()
    }

    var activeDownloads: Set<String> {
        Set(downloads.filter { $0.phase == .downloading || $0.phase == .resolving }.map(\.sourceURL))
    }

    func download(_ source: ArchiveLink) {
        guard source.canDownload, !activeDownloads.contains(source.id) else { return }
        let id = UUID()
        let directURL = source.downloadableURL
        downloads.insert(ArchiveDownload(
            id: id,
            sourceURL: source.id,
            sourceName: source.name,
            filename: directURL?.lastPathComponent.removingPercentEncoding ?? source.url.lastPathComponent.removingPercentEncoding ?? "download",
            receivedBytes: 0,
            expectedBytes: source.estimatedByteCount ?? 0,
            phase: directURL == nil ? .resolving : .downloading,
            fileURL: nil
        ), at: 0)
        sources[id] = source

        if let directURL {
            beginDownload(id: id, from: directURL, expectedBytes: source.estimatedByteCount ?? 0)
        } else {
            resolutionTasks[id] = Task { [weak self] in
                do {
                    let result = try await Self.resolveArchiveVideo(source)
                    try Task.checkCancellation()
                    DispatchQueue.main.async { self?.beginDownload(id: id, from: result.url, expectedBytes: result.size) }
                } catch is CancellationError {
                    DispatchQueue.main.async { self?.setCancelled(id) }
                } catch {
                    DispatchQueue.main.async { self?.setFailed(id, message: error.localizedDescription) }
                }
            }
        }
    }

    func cancel(_ id: UUID) {
        if let task = resolutionTasks.removeValue(forKey: id) {
            task.cancel()
            setCancelled(id)
            return
        }
        guard let task = tasks[id] else { return }
        setCancelled(id)
        task.cancel()
    }

    func retry(_ id: UUID) {
        guard let source = sources[id] else { return }
        download(source)
    }

    func dismiss(_ id: UUID) {
        guard !activeDownloads.contains(sources[id]?.id ?? "") else { return }
        downloads.removeAll { $0.id == id }
        sources.removeValue(forKey: id)
    }

    func refresh() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        files = urls
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true }
            .sorted {
                let first = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let second = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return first > second
            }
    }

    func delete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        refresh()
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

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription.flatMap(UUID.init(uuidString:)),
              let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].receivedBytes = totalBytesWritten
        if totalBytesExpectedToWrite > 0 {
            downloads[index].expectedBytes = totalBytesExpectedToWrite
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription.flatMap(UUID.init(uuidString:)),
              let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        guard let response = downloadTask.response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            downloads[index].phase = .failed("The server returned an unsuccessful response.")
            return
        }
        let suggestedName = response.suggestedFilename ?? URL(string: downloads[index].sourceURL)?.lastPathComponent ?? "download"
        let destination = uniqueURL(for: sanitize(suggestedName))
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            downloads[index].filename = destination.lastPathComponent
            downloads[index].fileURL = destination
            let savedBytes = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            downloads[index].receivedBytes = max(downloads[index].receivedBytes, Int64(savedBytes))
            downloads[index].expectedBytes = max(downloads[index].expectedBytes, downloads[index].receivedBytes)
            downloads[index].phase = .complete
            refresh()
            showToast("Saved \(destination.lastPathComponent)")
        } catch {
            downloads[index].phase = .failed(error.localizedDescription)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = task.taskDescription.flatMap(UUID.init(uuidString:)) else { return }
        tasks.removeValue(forKey: id)
        if let error, let index = downloads.firstIndex(where: { $0.id == id }), downloads[index].phase == .downloading {
            downloads[index].phase = .failed(error.localizedDescription)
        }
    }

    private func beginDownload(id: UUID, from url: URL, expectedBytes: Int64) {
        resolutionTasks.removeValue(forKey: id)
        guard let index = downloads.firstIndex(where: { $0.id == id }), downloads[index].phase != .cancelled else { return }
        downloads[index].phase = .downloading
        downloads[index].expectedBytes = max(downloads[index].expectedBytes, expectedBytes)
        downloads[index].filename = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        let task = session.downloadTask(with: url)
        task.taskDescription = id.uuidString
        tasks[id] = task
        task.resume()
    }

    private func setCancelled(_ id: UUID) {
        resolutionTasks.removeValue(forKey: id)
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].phase = .cancelled
    }

    private func setFailed(_ id: UUID, message: String) {
        resolutionTasks.removeValue(forKey: id)
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].phase = .failed(message)
    }

    private static func resolveArchiveVideo(_ source: ArchiveLink) async throws -> (url: URL, size: Int64) {
        guard let identifier = source.archiveOrgIdentifier,
              let metadataURL = URL(string: "https://archive.org/metadata/\(identifier)") else {
            throw ArchiveError.invalidResponse
        }
        let (data, response) = try await URLSession.shared.data(from: metadataURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let files = json["files"] as? [[String: Any]] else {
            throw ArchiveError.serverUnavailable
        }
        func isVideo(_ file: [String: Any]) -> Bool {
            guard let name = file["name"] as? String else { return false }
            return ["mp4", "m4v", "mkv", "webm", "mov", "avi", "ogv"].contains((name as NSString).pathExtension.lowercased())
        }
        guard let file = files.first(where: { isVideo($0) && ($0["source"] as? String) == "original" })
                ?? files.first(where: { isVideo($0) && (($0["name"] as? String)?.hasSuffix(".ia.mp4") == true) })
                ?? files.first(where: { isVideo($0) }),
              let name = file["name"] as? String,
              let base = URL(string: "https://archive.org/download/\(identifier)") else {
            throw ArchiveError.invalidResponse
        }
        let url = base.appendingPathComponent(name)
        let size = (file["size"] as? String).flatMap { Int64($0) } ?? (file["size"] as? NSNumber)?.int64Value ?? 0
        return (url, size)
    }

    private func showToast(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.toast == message { self?.toast = nil }
        }
    }

    private func sanitize(_ name: String) -> String {
        let cleaned = name
            .components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty || cleaned.hasPrefix(".") ? "download" + cleaned : cleaned
    }

    private func uniqueURL(for filename: String) -> URL {
        var candidate = directory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }
        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var index = 1
        repeat {
            let name = ext.isEmpty ? "\(base) (\(index))" : "\(base) (\(index)).\(ext)"
            candidate = directory.appendingPathComponent(name)
            index += 1
        } while FileManager.default.fileExists(atPath: candidate.path)
        return candidate
    }
}
