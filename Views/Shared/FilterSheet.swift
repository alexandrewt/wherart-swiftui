import SwiftUI

struct AppFilters: Equatable {
    var types: [String] = []
    var venues: [String] = []
    var prices: [String] = []
    var distances: [String] = []
    var durations: [String] = []
    var accessibility: [String] = []
    var waitTimes: [String] = []
}

struct FilterSheet: View {
    @Binding var filters: AppFilters
    @Environment(\.dismiss) private var dismiss

    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    let artTypes = ["Painting", "Sculpture", "Photography", "Contemporary Art", "Street Art", "Abstract Art", "Installation", "Modern Art", "Asian Art", "Design", "Drawing", "Video Art", "Architecture", "Digital Art", "Illustration", "Printmaking", "Mixed Media", "Textile Art", "Ceramics", "Performance"]
    let venueTypes = ["Museums", "Galleries", "Art Centers", "Foundations", "Cultural Centers", "Art Fairs", "Auction Houses", "Libraries", "Public Spaces", "Churches & Heritage", "Cultural Institutes", "Artist Studios"]
    let priceOptions = ["Free", "Paid"]
    let distanceOptions = ["Under 1 km", "1 - 3 km", "3 - 5 km", "Over 5 km"]
    let durationOptions = ["30min", "1h", "1h30", "2h", "2h+"]
    let accessibilityOptions = ["Wheelchair access", "Lift available", "Adapted toilets", "Audioguide available", "Guide dogs not allowed"]
    let waitTimeOptions = ["Unknown", "< 15 min", "15 - 30 min", "30 - 45 min", "45 min - 1h", "+ 1h"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "filters"))
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    FilterSection(title: String(localized: "art_genre"), items: artTypes, selected: $filters.types)
                    FilterSection(title: String(localized: "venue_type"), items: venueTypes, selected: $filters.venues)
                    FilterSection(title: String(localized: "price"), items: priceOptions, selected: $filters.prices)
                    FilterSection(title: String(localized: "distance_filter"), items: distanceOptions, selected: $filters.distances)
                    FilterSection(title: String(localized: "duration_filter"), items: durationOptions, selected: $filters.durations)
                    FilterSection(title: String(localized: "accessibility"), items: accessibilityOptions, selected: $filters.accessibility)
                    FilterSection(title: String(localized: "wait_time"), items: waitTimeOptions, selected: $filters.waitTimes)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            HStack(spacing: 12) {
                Button(action: {
                    impactFeedback.impactOccurred()
                    filters = AppFilters()
                }) {
                    Text(String(localized: "reset"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                Button(action: {
                    let filterCount = filters.types.count + filters.venues.count + filters.prices.count + filters.distances.count + filters.durations.count + filters.accessibility.count + filters.waitTimes.count
                    AnalyticsService.shared.track("filter_applied", properties: [
                        "art_types": filters.types.count,
                        "venue_types": filters.venues.count,
                        "prices": filters.prices.count,
                        "distances": filters.distances.count,
                        "durations": filters.durations.count,
                        "accessibility": filters.accessibility.count,
                        "wait_times": filters.waitTimes.count,
                        "total_filters": filterCount
                    ])
                    dismiss()
                }) {
                    Text(String(localized: "apply"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(red: 0.15, green: 0.39, blue: 0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            }
            .padding(20)
        }
    }
}

struct FilterSection: View {
    let title: String
    let items: [String]
    @Binding var selected: [String]

    private let selectionFeedback = UISelectionFeedbackGenerator()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))

            WrapLayout(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Button(action: {
                        selectionFeedback.selectionChanged()
                        if selected.contains(item) {
                            selected.removeAll { $0 == item }
                        } else {
                            selected.append(item)
                        }
                    }) {
                        Text(localizedAttributeLabel(ArtTaxonomy.displayLabel(for: item)))
                            .font(.system(size: 13, weight: selected.contains(item) ? .semibold : .regular))
                            .foregroundColor(selected.contains(item) ? Color(red: 0.15, green: 0.39, blue: 0.92) : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selected.contains(item) ? Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.08) : Color(.systemGray6))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
