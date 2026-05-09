import SwiftUI

struct ExhibitionCard: View {

    let exhibition: Exhibition
    let isFavorite: Bool
    let isViewed: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleViewed: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Image
                ZStack(alignment: .topLeading) {
                    AsyncImage(url: URL(string: exhibition.image ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            Rectangle().fill(Color.gray.opacity(0.3))
                        case .empty:
                            Rectangle().fill(Color.gray.opacity(0.15))
                                .overlay(ProgressView())
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 200)
                    .clipped()

                    // Tags
                    HStack(spacing: 6) {
                        TagBadge(label: exhibition.type, color: typeColor(exhibition.type))
                        TagBadge(label: exhibition.venueType, color: Color.white.opacity(0.9))
                    }
                    .padding(12)

                    // Actions
                    HStack(spacing: 8) {
                        ActionButton(
                            icon: isViewed ? "eye.fill" : "eye",
                            color: isViewed ? .blue : .gray,
                            action: onToggleViewed
                        )
                        ActionButton(
                            icon: isFavorite ? "heart.fill" : "heart",
                            color: isFavorite ? .red : .gray,
                            action: onToggleFavorite
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(12)
                }

                // MARK: - Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(exhibition.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(exhibition.venue)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    HStack {

                        Spacer()

                        HStack(spacing: 8) {
                            if let distance = exhibition.distance {
                                Text(String(format: "%.1f km", distance))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                            if exhibition.isFree {
                                Text("Free")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.blue)
                            } else if let price = exhibition.price {
                                Text(price)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    if exhibition.endingSoon {
                        Label("Ending soon", systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 2)
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "Contemporary Art": return Color(red: 0.58, green: 0.77, blue: 0.99)
        case "Painting": return Color(red: 0.98, green: 0.66, blue: 0.82)
        case "Sculpture": return Color(red: 0.99, green: 0.73, blue: 0.45)
        case "Photography": return Color(red: 0.43, green: 0.91, blue: 0.72)
        case "Street Art": return Color(red: 0.99, green: 0.83, blue: 0.30)
        default: return Color(red: 0.77, green: 0.71, blue: 0.99)
        }
    }
}

// MARK: - Tag Badge
struct TagBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(red: 0.12, green: 0.23, blue: 0.37))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
