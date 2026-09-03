import SwiftUI

struct ExhibitionCard: View {

    let exhibition: Exhibition
    let isFavorite: Bool
    let isViewed: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleViewed: () -> Void

    private var daysRemaining: Int {
        EndingSoonService.shared.daysRemaining(for: exhibition)
    }

    private var thresholdDays: Int {
        EndingSoonService.shared.reminderThresholdDays(for: exhibition, userThresholdPercent: 25)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Image
                ZStack(alignment: .topLeading) {
                    AsyncImage(url: URL(string: exhibition.image ?? "")) { phase in
                        Group {
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                                    .transition(.opacity)
                            case .failure:
                                Rectangle().fill(Color(.systemGray5))
                            case .empty:
                                Rectangle().fill(Color(.systemGray6))
                                    .overlay(ProgressView())
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .animation(.easeIn(duration: 0.25), value: phase.image != nil)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()

                    // Tags
                    HStack(spacing: 6) {
                        TagBadge(label: exhibition.type, color: typeColor(exhibition.type).opacity(0.9))
                        TagBadge(label: exhibition.venueType, color: Color.white.opacity(0.92))
                    }
                    .padding(12)

                    // Actions
                    HStack(spacing: 8) {
                        CardActionButton(
                            icon: isViewed ? "eye.fill" : "eye",
                            color: isViewed ? .blue : Color(.systemGray2),
                            accessibilityLabel: isViewed ? String(localized: "mark_as_not_seen") : String(localized: "mark_as_seen"),
                            hapticStyle: .light,
                            action: onToggleViewed
                        )
                        CardActionButton(
                            icon: isFavorite ? "heart.fill" : "heart",
                            color: isFavorite ? .red : Color(.systemGray2),
                            accessibilityLabel: isFavorite ? String(localized: "remove_from_favorites") : String(localized: "add_to_favorites"),
                            hapticStyle: .medium,
                            action: onToggleFavorite
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(12)

                    // Ending Soon Badge
                    if daysRemaining > 0 && daysRemaining <= thresholdDays {
                        VStack(alignment: .trailing, spacing: 2) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("\(daysRemaining)d")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(6)
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                }

                // MARK: - Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .bottom) {
                        Text(exhibition.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                        Spacer()
                        if let distance = exhibition.distance {
                            Text(String(format: "%.1f km", distance))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }

                    HStack(alignment: .top) {
                        Text(exhibition.venue)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                        let parsed = parsedPriceDisplay(exhibition.price, isFree: exhibition.isFree)
                        HStack(spacing: 4) {
                            Text(parsed.summary)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                                .lineLimit(1)
                            if parsed.hasDetails {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
            }
        }
        .buttonStyle(.plain)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 2)
    }
}

// MARK: - Card Action Button
struct CardActionButton: View {
    let icon: String
    let color: Color
    let accessibilityLabel: String
    /// Fired at tap time, ahead of `action` — centralizes the haptic here
    /// instead of duplicating it in every screen that uses this button
    /// (HomeView, FavoritesView, ViewedView).
    let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: hapticStyle).impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.92))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
