import SwiftUI

struct AppFilters {
    var types: [String] = []
    var venues: [String] = []
    var prices: [String] = []
    var distances: [String] = []
}

struct FilterSheet: View {
    @Binding var filters: AppFilters
    @Environment(\.dismiss) private var dismiss

    let artTypes = ["Painting", "Sculpture", "Photography", "Contemporary Art", "Street Art", "Abstract Art", "Installation", "Modern Art", "Asian Art", "Design"]
    let venueTypes = ["Museums", "Galleries", "Art Centers", "Foundations", "Cultural Centers", "Art Fairs"]
    let priceOptions = ["Free", "Paid"]
    let distanceOptions = ["Under 1 km", "1 - 3 km", "3 - 5 km", "Over 5 km"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Filters")
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
                    FilterSection(title: "Art genre", items: artTypes, selected: $filters.types)
                    FilterSection(title: "Venue type", items: venueTypes, selected: $filters.venues)
                    FilterSection(title: "Price", items: priceOptions, selected: $filters.prices)
                    FilterSection(title: "Distance", items: distanceOptions, selected: $filters.distances)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            HStack(spacing: 12) {
                Button(action: { filters = AppFilters() }) {
                    Text("Reset")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                }
                Button(action: { dismiss() }) {
                    Text("Apply")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            FlowLayout(items: items) { item in
                Button(action: {
                    if selected.contains(item) {
                        selected.removeAll { $0 == item }
                    } else {
                        selected.append(item)
                    }
                }) {
                    Text(item)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(selected.contains(item) ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selected.contains(item) ? Color.blue : Color(.systemGray6))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
