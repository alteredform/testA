import Foundation

/// Submits a dead-link report to `api/report/report.js`.
struct ReportClient {
    static func submit(item: ArchiveItem, brokenLinks: [Backup]) async throws {
        guard !brokenLinks.isEmpty else { return }

        let fmt = ISO8601DateFormatter()
        let body: [String: Any] = [
            "DateSumbittedGMT2": fmt.string(from: Date()),
            "DateEntry":         item.dateString ?? "",
            "Title":             item.title,
            "Selected Links":    brokenLinks.map { ["Name": $0.name, "Url": $0.url] },
        ]

        var req = URLRequest(url: APIConfig.reportURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.badResponse((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }
}