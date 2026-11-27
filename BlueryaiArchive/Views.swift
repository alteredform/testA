import SwiftUI
import WebKit
import QuickLook

// MARK: - Web view wrapper

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Main browser screen

struct BrowserScreen: View {
    @ObservedObject var store: TabStore
    @ObservedObject var tab: BrowserTab
    @ObservedObject private var downloads = DownloadManager.shared

    @State private var showTabs = false
    @State private var showDownloads = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .top) {
                WebViewContainer(webView: tab.webView)
                if tab.isLoading && tab.progress < 1 {
                    ProgressView(value: tab.progress)
                        .progressViewStyle(.linear)
                }
            }
            Divider()
            bottomBar
        }
        .overlay(alignment: .top) { toastView }
        .animation(.easeInOut(duration: 0.2), value: downloads.toast)
        .sheet(isPresented: $showTabs) { TabSwitcher(store: store) }
        .sheet(isPresented: $showDownloads) { DownloadsView() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: tab.url?.scheme == "https" ? "lock.fill" : "globe")
                .font(.footnote)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(tab.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(tab.url?.host ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                if tab.isLoading { tab.webView.stopLoading() } else { tab.webView.reload() }
            } label: {
                Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
            }
            Menu {
                ForEach(SiteSection.all) { section in
                    Button { tab.load(section.url) } label: {
                        Label(section.title, systemImage: section.icon)
                    }
                }
                Divider()
                Button { store.openTab(url: Site.home) } label: {
                    Label("New Tab", systemImage: "plus.square")
                }
                if let url = tab.url {
                    Button { UIApplication.shared.open(url) } label: {
                        Label("Open in Safari", systemImage: "safari")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .font(.title3)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack {
            barButton("chevron.left", enabled: tab.canGoBack) { tab.webView.goBack() }
            barButton("chevron.right", enabled: tab.canGoForward) { tab.webView.goForward() }

            ShareLink(item: tab.url ?? Site.home) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
            }

            Button { showDownloads = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                    if downloads.runningCount > 0 {
                        Text("\(downloads.runningCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(Color.blue))
                            .offset(x: 10, y: -8)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Button { showTabs = true } label: {
                Text("\(store.tabs.count)")
                    .font(.caption.bold())
                    .frame(width: 22, height: 22)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(lineWidth: 1.8))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func barButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .disabled(!enabled)
    }

    @ViewBuilder
    private var toastView: some View {
        if let message = downloads.toast {
            Text(message)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
                .shadow(radius: 4)
                .padding(.top, 56)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Tab switcher

struct TabSwitcher: View {
    @ObservedObject var store: TabStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.tabs) { tab in
                    TabRow(tab: tab, isSelected: tab.id == store.selectedID) {
                        store.selectedID = tab.id
                        dismiss()
                    } onClose: {
                        store.close(tab)
                    }
                }
            }
            .navigationTitle("\(store.tabs.count) Tab\(store.tabs.count == 1 ? "" : "s")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        store.openTab(url: Site.home)
                        dismiss()
                    } label: {
                        Label("New Tab", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct TabRow: View {
    @ObservedObject var tab: BrowserTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title).font(.body).lineLimit(1)
                Text(tab.url?.host ?? "New Tab")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark").foregroundStyle(.blue)
            }
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - Downloads

struct DownloadsView: View {
    @ObservedObject private var manager = DownloadManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var preview: URL?

    var body: some View {
        NavigationStack {
            List {
                if !manager.active.isEmpty {
                    Section("In progress") {
                        ForEach(manager.active) { item in
                            ActiveDownloadRow(item: item, manager: manager)
                        }
                    }
                }
                Section {
                    if manager.files.isEmpty {
                        Text("No downloads yet")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(manager.files, id: \.self) { url in
                        Button { preview = url } label: {
                            HStack(spacing: 12) {
                                Image(systemName: icon(for: url))
                                    .font(.title2)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(url.lastPathComponent)
                                        .lineLimit(2)
                                        .foregroundStyle(.primary)
                                    Text(manager.details(for: url))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .contextMenu {
                            ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                            Button(role: .destructive) { manager.delete([url]) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { offsets in
                        manager.delete(offsets.map { manager.files[$0] })
                    }
                } header: {
                    Text("Saved files")
                } footer: {
                    Text("These files are also available in the Files app under On My iPhone › Blueryai Archive.")
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .quickLookPreview($preview)
            .onAppear { manager.refresh() }
        }
    }

    private func icon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mp4", "mov", "mkv", "webm", "m4v": return "film"
        case "mp3", "m4a", "wav", "flac", "ogg": return "music.note"
        case "zip", "rar", "7z", "tar", "gz": return "doc.zipper"
        case "jpg", "jpeg", "png", "gif", "webp": return "photo"
        case "txt", "json", "csv", "md": return "doc.text"
        default: return "doc"
        }
    }
}

struct ActiveDownloadRow: View {
    @ObservedObject var item: DownloadItem
    let manager: DownloadManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.filename).lineLimit(1)
                Spacer()
                Button {
                    if case .failed = item.state {
                        manager.dismissFailed(item)
                    } else {
                        manager.cancel(item)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            switch item.state {
            case .running:
                ProgressView(value: item.fraction)
                Text("\(Int(item.fraction * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .failed(let message):
                Text("Failed: \(message)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }
}
