import SwiftUI

struct ReportView: View {
    let item: ArchiveItem

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<Backup> = []
    @State private var isSubmitting = false
    @State private var status: String?

    private var links: [Backup] {
        item.backups.filter { !$0.unavailable }
    }

    var body: some View {
        List {
            Section("Title") {
                Text(item.title)
            }
            Section("Which sources are dead?") {
                ForEach(links) { b in
                    Button {
                        if selected.contains(b) { selected.remove(b) }
                        else { selected.insert(b) }
                    } label: {
                        HStack {
                            Image(systemName: selected.contains(b) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selected.contains(b) ? .accentColor : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.name)
                                Text(b.url).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Section {
                Button {
                    submit()
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting { ProgressView() }
                        Text("Submit report")
                        Spacer()
                    }
                }
                .disabled(selected.isEmpty || isSubmitting)

                if let status {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(status.hasPrefix("✓") ? .green : .red)
                }
            }
        }
    }

    private func submit() {
        isSubmitting = true
        status = nil
        Task {
            do {
                try await ReportClient.submit(item: item, brokenLinks: Array(selected))
                status = "✓ Report submitted. Thanks!"
                selected.removeAll()
            } catch {
                status = "Failed: \(error.localizedDescription)"
            }
            isSubmitting = false
        }
    }
}