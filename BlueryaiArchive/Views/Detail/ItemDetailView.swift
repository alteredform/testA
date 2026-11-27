import SwiftUI

struct ItemDetailView: View {
    let item: ArchiveItem

    @State private var selectedBackup: Backup?
    @State private var chatViewer: ChatSelection?
    @State private var showReport = false
    @State private var showAllBackups = false

    private var activeBackup: Backup? {
        selectedBackup ?? item.defaultBackup
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // MARK: Player
                if let backup = activeBackup {
                    VideoPlayerView(backup: backup)
                        .frame(height: 220)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#21262d"))
                        .frame(height: 220)
                        .overlay(
                            Text("No playable source")
                                .foregroundColor(.secondary)
                        )
                }

                // MARK: Source picker
                if item.availableBackups.count > 1 {
                    Picker("Source", selection: Binding(
                        get: { activeBackup ?? item.availableBackups[0] },
                        set: { selectedBackup = $0 }
                    )) {
                        ForEach(item.availableBackups) { b in
                            Text(b.name).tag(b)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color(hex: "#58a6ff"))
                }

                // MARK: Title + meta
                Text(item.title)
                    .font(.title3.bold())
                    .foregroundColor(Color(hex: "#c9d1d9"))

                HStack(spacing: 6) {
                    if let date = item.formattedDate { Text(date) }
                    if item.isMissing { Text("•").foregroundColor(.red) ; Text("Missing").foregroundColor(.red) }
                    if item.isNew     { Text("•").foregroundColor(.green); Text("New").foregroundColor(.green) }
                }
                .font(.caption)
                .foregroundColor(Color(hex: "#8b949e"))

                // MARK: Tags
                if !item.tags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(item.tags, id: \.self) {
                            TagPill(text: $0, color: Color(hex: "#a371f7"))
                        }
                    }
                }

                // MARK: Description
                if let d = item.description, !d.isEmpty {
                    Text(d)
                        .font(.body)
                        .foregroundColor(Color(hex: "#c9d1d9"))
                }

                // MARK: All backups
                if !item.backups.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Sources").font(.headline)
                                .foregroundColor(Color(hex: "#c9d1d9"))
                            Spacer()
                            Button {
                                showReport = true
                            } label: {
                                Label("Report dead link", systemImage: "exclamationmark.bubble")
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "#8b949e"))
                            }
                        }

                        FlowLayout(spacing: 8) {
                            ForEach(item.backups) { b in
                                backupChip(b)
                            }
                        }
                    }
                }

                // MARK: Chats
                if !item.chat.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chats").font(.headline)
                            .foregroundColor(Color(hex: "#c9d1d9"))

                        FlowLayout(spacing: 8) {
                            ForEach(item.chat.keys.sorted(), id: \.self) { key in
                                Button {
                                    chatViewer = ChatSelection(name: key, url: item.chat[key] ?? "")
                                } label: {
                                    Label(key, systemImage: "bubble.left.and.bubble.right")
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(hex: "#21262d"))
                                        .foregroundColor(Color(hex: "#58a6ff"))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(hex: "#0d1117").ignoresSafeArea())
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $chatViewer) { chat in
            NavigationStack {
                ChatView(chat: chat)
                    .navigationTitle(chat.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { chatViewer = nil }
                        }
                    }
            }
        }
        .sheet(isPresented: $showReport) {
            NavigationStack {
                ReportView(item: item)
                    .navigationTitle("Report dead link")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showReport = false }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func backupChip(_ b: Backup) -> some View {
        let chip = Text(b.name)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .cornerRadius(6)

        if b.unavailable {
            chip
                .background(Color(hex: "#b91c1c").opacity(0.3))
                .foregroundColor(Color(hex: "#f0f0f0"))
} else if b.playbackURL != nil, b.isYouTube || b.isDirectMedia {
    Button { selectedBackup = b } label: {
        chip
            .background(Color(hex: "#21262d"))
            .foregroundColor(Color(hex: "#c9d1d9"))
    }
} else if let url = URL(string: b.url) {
            Link(destination: url) {
                chip
                    .background(Color(hex: "#21262d"))
                    .foregroundColor(Color(hex: "#58a6ff"))
            }
        }
    }
}

// MARK: - Small supporting types

struct ChatSelection: Identifiable {
    let id = UUID()
    let name: String
    let url: String
}

private struct ChatView: View {
    let chat: ChatSelection

    var body: some View {
        if let proxied = APIConfig.chatProxyURL(for: chat.url) {
            WebPageView(url: proxied)
        } else {
            Text("Invalid chat URL")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}