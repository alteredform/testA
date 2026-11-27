import Foundation
import SwiftUI

@MainActor
final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var files: [URL] = []
    @Published private(set) var activeDownloads: Set<String> = []
    @Published var toast: String?

    private let directory: URL

    private init() {
        directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        refresh()
    }

    func download(_ source: ArchiveLink) {
        guard let url = source.downloadableURL else { return }
        let key = url.absoluteString
        guard !activeDownloads.contains(key) else { return }
        activeDownloads.insert(key)

        Task {
            defer { activeDownloads.remove(key) }
            do {
                let (temporaryURL, response) = try await URLSession.shared.download(from: url)
                if let response = response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
                    throw ArchiveError.serverUnavailable
                }
                let suggestedName = response.suggestedFilename ?? url.lastPathComponent
                let proposedName = suggestedName.isEmpty ? url.lastPathComponent : suggestedName
                let destination = uniqueURL(for: sanitize(proposedName))
                try FileManager.default.moveItem(at: temporaryURL, to: destination)
                refresh()
                showToast("Saved \(destination.lastPathComponent)")
            } catch {
                showToast("Download failed. Try opening the source instead.")
            }
        }
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

    private func showToast(_ message: String) {
        toast = message
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            if self?.toast == message { self?.toast = nil }
        }
    }

    private func sanitize(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
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
