import SwiftUI

struct NativeArchiveItemDetailView: View {
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var playback: ArchivePlaybackManager
    let item: ArchiveItem

    @State private var selectedSourceID: String?

    private var sources: [ArchiveLink] { item.availableSources }
    private var selectedSource: ArchiveLink? {
        sources.first(where: { $0.id == selectedSourceID }) ?? sources.first
    }
    private var chatSources: [ArchiveChat.Source] { item.chat?.sources ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let source = selectedSource {
                    ArchivePlayerView(source: source, playbackTime: $playback.playbackTime)
                        .padding(.top, 8)
                    playerSourceSelector
                } else {
                    missingPlayer
                }

                itemInformation
                if !chatSources.isEmpty {
                    ChatReplayView(sources: chatSources, playbackTime: $playback.playbackTime)
                }
                if let altPOV = item.altPOV {
                    alternatePerspectives(altPOV)
                }
                sourceList
                Text("Downloads are saved in Files under On My iPhone › Blueryai Archive.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(Color.archiveBackground)
        .navigationTitle(item.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let source = selectedSource { playback.prepare(source) }
        }
        .onChange(of: selectedSourceID) { _ in
            if let source = selectedSource { playback.prepare(source) }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: item.shortURL) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share short link")
            }
        }
    }

    private var playerSourceSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PLAYING IN APP").font(.system(size: 9, weight: .bold)).tracking(1.2).foregroundStyle(Color.archiveBlue)
                Spacer()
                Text(playbackClock(playback.playbackTime)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(sources) { source in
                        Button {
                            selectedSourceID = source.id
                        } label: {
                            Text(source.name)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .foregroundStyle(source.id == selectedSource?.id ? Color.archiveBlue : Color.archiveMuted)
                                .background(source.id == selectedSource?.id ? Color.archiveBlue.opacity(0.15) : Color.archiveSurface, in: Capsule())
                                .overlay(Capsule().stroke(source.id == selectedSource?.id ? Color.archiveBlue.opacity(0.45) : Color.archiveBorder))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var itemInformation: some View {
        VStack(alignment: .leading, spacing: 11) {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(item.categories ?? [], id: \.self) { category in
                        Text(category)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .foregroundStyle(Color.archiveBlue)
                            .background(Color.archiveBlue.opacity(0.13), in: Capsule())
                    }
                    if item.isNew { Text("NEW").font(.system(size: 8, weight: .bold)).foregroundStyle(.green) }
                    if item.isUnavailable { Text("PARTIAL / MISSING").font(.system(size: 8, weight: .bold)).foregroundStyle(.red.opacity(0.9)) }
                }
            }
            .scrollIndicators(.hidden)
            Text(item.displayTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.archiveText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if let date = item.date { Label(date, systemImage: "calendar").lineLimit(1) }
                if let duration = item.duration { Label(duration, systemImage: "clock").lineLimit(1) }
            }
            .font(.caption)
            .foregroundStyle(Color.archiveMuted)
            if !item.displayServices.isEmpty {
                Text(item.displayServices.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(Color.archiveMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let description = item.description, !description.isEmpty {
                Text(attributedDescription(description))
                    .font(.subheadline)
                    .foregroundStyle(Color.archiveText.opacity(0.88))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .environment(\.openURL, OpenURLAction { url in
                        if url.scheme == "archive-seek", let seconds = Double(url.host ?? "") {
                            playback.seek(to: seconds)
                            return .handled
                        }
                        return .systemAction
                    })
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let segments = item.segment, !segments.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(segments, id: \.self) { segment in
                            Text(segment)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.archiveSurface, in: Capsule())
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var sourceList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AVAILABLE SOURCES").font(.system(size: 9, weight: .bold)).tracking(1.2).foregroundStyle(Color.archiveBlue)
                    Text("Choose a source to play it above").font(.caption2).foregroundStyle(Color.archiveMuted)
                }
                Spacer()
                Text("\(sources.count)").font(.caption.monospacedDigit()).foregroundStyle(Color.archiveMuted)
            }
            if sources.isEmpty {
                Text("No playback sources are listed for this item.")
                    .font(.subheadline).foregroundStyle(Color.archiveMuted)
                    .padding(.vertical, 14)
            } else {
                ForEach(sources) { source in
                    SourceActionRow(source: source, isSelected: source.id == selectedSource?.id)
                        .onTapGesture {
                            selectedSourceID = source.id
                        }
                }
            }
        }
        .padding(13)
        .background(Color.archiveSurface, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.archiveBorder))
    }

    private var missingPlayer: some View {
        VStack(spacing: 8) {
            Image(systemName: "play.rectangle").font(.title2).foregroundStyle(Color.archiveMuted)
            Text("No embedded source is available").font(.subheadline.weight(.medium))
            Text("Check the source list below for alternate copies.").font(.caption).foregroundStyle(Color.archiveMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 210)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 12))
        .padding(.top, 8)
    }

    private func alternatePerspectives(_ value: String) -> some View {
        let entries: [(title: String, url: URL)] = value.split(separator: "|").compactMap { part in
            let pair = part.split(separator: ";", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard pair.count == 2, let url = URL(string: pair[1]) else { return nil }
            return (title: pair[0], url: url)
        }
        return Group {
            if !entries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ALTERNATE PERSPECTIVES").font(.system(size: 9, weight: .bold)).tracking(1.2).foregroundStyle(Color.archiveBlue)
                    ForEach(entries.indices, id: \.self) { index in
                        Link(destination: entries[index].url) {
                            Label(entries[index].title, systemImage: "arrow.up.right.square")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.archiveBlue)
                        }
                    }
                }
            }
        }
    }

    private func attributedDescription(_ source: String) -> AttributedString {
        var attributed = (try? AttributedString(markdown: source, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(source)
        let expression = try? NSRegularExpression(pattern: "(?<![0-9])(?:[0-9]{1,2}:)?[0-9]{1,2}:[0-9]{2}(?![0-9])")
        let sourceString = source as NSString
        let matches = expression?.matches(in: source, range: NSRange(location: 0, length: sourceString.length)) ?? []
        for match in matches {
            let stamp = sourceString.substring(with: match.range)
            guard let seconds = seconds(for: stamp),
                  let range = attributed.range(of: stamp),
                  let url = URL(string: "archive-seek://\(Int(seconds))") else { continue }
            attributed[range].link = url
        }
        return attributed
    }

    private func seconds(for stamp: String) -> Double? {
        let parts = stamp.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 || parts.count == 3 else { return nil }
        if parts.count == 3 { return Double(parts[0] * 3600 + parts[1] * 60 + parts[2]) }
        return Double(parts[0] * 60 + parts[1])
    }

    private func playbackClock(_ seconds: Double) -> String {
        let value = max(0, Int(seconds))
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        let remainder = value % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, remainder) : String(format: "%d:%02d", minutes, remainder)
    }
}

private struct SourceActionRow: View {
    @EnvironmentObject private var downloads: DownloadManager
    let source: ArchiveLink
    let isSelected: Bool

    private var download: ArchiveDownload? { downloads.downloads.first(where: { $0.sourceURL == source.id }) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: source.youtubeId != nil ? "play.rectangle.fill" : "play.circle")
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? Color.archiveBlue : Color.archiveMuted)
                .frame(width: 36, height: 36)
                .background(Color.archiveBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(source.name).font(.caption.weight(.semibold)).foregroundStyle(Color.archiveText).lineLimit(1)
                Text(source.description ?? source.url.host ?? "Archive source")
                    .font(.caption2).foregroundStyle(Color.archiveMuted).lineLimit(1)
            }
            Spacer(minLength: 4)
            if let download {
                switch download.phase {
                case .resolving:
                    ProgressView().controlSize(.small)
                case .downloading:
                    if let fraction = download.fractionCompleted {
                        ProgressView(value: fraction).frame(width: 32)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                case .complete:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                case .failed, .cancelled:
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                }
            }
            if source.canDownload {
                Button { downloads.download(source) } label: {
                    Image(systemName: downloads.activeDownloads.contains(source.id) ? "arrow.down.circle.fill" : "arrow.down.to.line")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.archiveBlue)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Download from \(source.name)")
            }
        }
        .padding(9)
        .background(isSelected ? Color.archiveBlue.opacity(0.09) : Color.archiveBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.archiveBlue.opacity(0.35) : Color.archiveBorder))
    }
}
