import Foundation
import SwiftUI

struct ChatReplayMessage: Identifiable, Sendable {
    let id: String
    let videoSeconds: Double
    let displayName: String
    let text: String
    let colorHex: String?
    let avatarURL: URL?
}

private struct ChatReplayService {
    func loadMessages(from chatURL: URL) async throws -> [ChatReplayMessage] {
        var components = URLComponents(string: "https://media.blueryai.xyz/api/chat/chat.js")!
        components.queryItems = [URLQueryItem(name: "url", value: chatURL.absoluteString)]
        guard let url = components.url else { throw ArchiveError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ArchiveError.serverUnavailable
        }
        return try Self.decode(data)
    }

    private static func decode(_ data: Data) throws -> [ChatReplayMessage] {
        let object = try JSONSerialization.jsonObject(with: data)
        let entries: [[String: Any]]
        if let array = object as? [[String: Any]] {
            entries = array
        } else if let dictionary = object as? [String: [String: Any]] {
            entries = Array(dictionary.values)
        } else if let dictionary = object as? [String: Any] {
            entries = dictionary.values.compactMap { $0 as? [String: Any] }
        } else {
            throw ArchiveError.invalidResponse
        }

        return entries.enumerated().compactMap { index, entry in
            guard let text = entry["message"] as? String, !text.isEmpty else { return nil }
            let rawTime = entry["video_ts_ms"]
            let milliseconds = (rawTime as? String).flatMap { Double($0) } ?? (rawTime as? NSNumber)?.doubleValue ?? 0
            guard milliseconds.isFinite else { return nil }
            let tags = entry["tags"] as? [String: Any]
            let name = entry["display_name"] as? String ?? tags?["display-name"] as? String ?? "Anonymous"
            let rawID = entry["id"].map { String(describing: $0) } ?? "\(index)"
            let color = tags?["color"] as? String
            let avatar = (entry["icon"] as? String) ?? (entry["profile_image_url"] as? String)
            return ChatReplayMessage(
                id: rawID,
                videoSeconds: milliseconds / 1000,
                displayName: name,
                text: text,
                colorHex: color,
                avatarURL: avatar.flatMap { URL(string: $0) }
            )
        }
        .sorted { $0.videoSeconds < $1.videoSeconds }
    }
}

@MainActor
private final class ChatReplayStore: ObservableObject {
    @Published private(set) var messages: [ChatReplayMessage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published var errorMessage: String?

    private let chatURL: URL
    private let service = ChatReplayService()

    init(chatURL: URL) { self.chatURL = chatURL }

    func load() async {
        guard !isLoading, !hasLoaded else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            messages = try await service.loadMessages(from: chatURL)
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ChatReplayView: View {
    let sources: [ArchiveChat.Source]
    @Binding var playbackTime: Double
    @State private var selectedSourceID: String?

    private var selectedSource: ArchiveChat.Source? {
        sources.first(where: { $0.id == selectedSourceID }) ?? sources.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if sources.count > 1 {
                Text("CHAT SOURCES")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(Color.siteMuted)
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        ForEach(sources) { source in
                            Button { selectedSourceID = source.id } label: {
                                Text(source.name)
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .foregroundStyle(source.id == selectedSource?.id ? Color.siteBlue : Color.siteMuted)
                                    .background(source.id == selectedSource?.id ? Color.siteBlue.opacity(0.14) : Color.siteCard, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            if let selectedSource {
                ChatReplayPanel(source: selectedSource, playbackTime: $playbackTime)
                    .id(selectedSource.id)
            }
        }
    }
}

private struct ChatReplayPanel: View {
    @StateObject private var store: ChatReplayStore
    @Binding private var playbackTime: Double
    @State private var isExpanded = false
    @State private var followsPlayback = true
    let sourceName: String

    init(source: ArchiveChat.Source, playbackTime: Binding<Double>) {
        sourceName = source.name
        _store = StateObject(wrappedValue: ChatReplayStore(chatURL: source.url))
        _playbackTime = playbackTime
    }

    private var visibleMessages: [ChatReplayMessage] {
        guard playbackTime > 0 else { return Array(store.messages.prefix(150)) }
        let endIndex = store.messages.firstIndex(where: { $0.videoSeconds > playbackTime + 2 }) ?? store.messages.endIndex
        return Array(store.messages[..<endIndex].suffix(150))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                if !store.hasLoaded && !store.isLoading { Task { await store.load() } }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(sourceName) chat replay").font(.headline)
                        Text(store.hasLoaded ? "\(store.messages.count.formatted()) messages · synced to playback" : "Load the archived stream chat")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.hasLoaded {
                        Button { followsPlayback.toggle() } label: {
                            Image(systemName: followsPlayback ? "arrow.down.to.line" : "pause.fill")
                                .foregroundStyle(Color.siteBlue)
                                .padding(5)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(followsPlayback ? "Pause chat follow" : "Follow playback")
                    }
                    if store.isLoading { ProgressView() }
                    else { Image(systemName: isExpanded ? "chevron.up" : "chevron.down").foregroundStyle(.secondary) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                if let error = store.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error).font(.caption).foregroundStyle(.secondary)
                        Button("Retry") { Task { await store.load() } }.font(.caption.weight(.semibold))
                    }
                    .padding(.vertical, 10)
                } else if store.isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading chat archive…").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 90)
                } else if store.hasLoaded {
                    if visibleMessages.isEmpty {
                        Text("No messages at this playback point.")
                            .font(.caption).foregroundStyle(.secondary).padding(.vertical, 12)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 7) {
                                    ForEach(visibleMessages) { message in
                                        ChatLine(message: message)
                                    }
                                }
                                .padding(.vertical, 3)
                            }
                            .onChange(of: visibleMessages.last?.id) { messageID in
                                guard followsPlayback, let messageID else { return }
                                withAnimation(.linear(duration: 0.12)) { proxy.scrollTo(messageID, anchor: .bottom) }
                            }
                            .frame(height: 300)
                        }
                    }
                } else {
                    Button("Load chat replay") { Task { await store.load() } }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.siteBlue)
                        .padding(.vertical, 10)
                }
            }
        }
        .padding(14)
        .background(Color.siteCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.siteBorder))
    }
}

private struct ChatLine: View {
    let message: ChatReplayMessage

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Group {
                if let avatarURL = message.avatarURL {
                    AsyncImage(url: avatarURL) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                        else { avatarFallback }
                    }
                } else {
                    avatarFallback
                }
            }
            .frame(width: 22, height: 22)
            .clipShape(Circle())
            Text(timestamp(message.videoSeconds))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(message.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color(message.colorHex))
                Text(message.text)
                    .font(.caption)
                    .foregroundStyle(Color.siteText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var avatarFallback: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.siteMuted)
    }

    private func timestamp(_ value: Double) -> String {
        let seconds = max(0, Int(value))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, remainder) : String(format: "%d:%02d", minutes, remainder)
    }

    private func color(_ value: String?) -> Color {
        guard let value, value.hasPrefix("#"), let number = UInt64(value.dropFirst(), radix: 16) else { return Color.siteBlue }
        return Color(red: Double((number >> 16) & 0xff) / 255, green: Double((number >> 8) & 0xff) / 255, blue: Double(number & 0xff) / 255)
    }
}
