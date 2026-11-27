import SwiftUI

struct ItemCard: View {
    let item: ArchiveItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                AsyncImage(url: item.primaryThumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        Color(hex: "#21262d")
                            .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                    default:
                        Color(hex: "#21262d")
                    }
                }
                .frame(height: 100)
                .clipped()
                .cornerRadius(8)

                HStack {
                    if item.isNew { badge("NEW", color: .green) }
                    Spacer()
                    if item.isMissing { badge("MISSING", color: .red) }
                }
                .padding(6)
            }

            Text(item.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .foregroundColor(Color(hex: "#c9d1d9"))

            HStack(spacing: 4) {
                ForEach(item.availableBackups.prefix(2), id: \.self) { b in
                    Text(b.name)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#2ea043"))
                        .foregroundColor(.white)
                        .cornerRadius(3)
                }
                Spacer()
                if let date = item.formattedDate {
                    Text(date)
                        .font(.caption2)
                        .foregroundColor(Color(hex: "#8b949e"))
                }
            }
        }
        .padding(8)
        .background(Color(hex: "#161b22"))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(item.isMissing ? Color.red : Color(hex: "#21262d"), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
}