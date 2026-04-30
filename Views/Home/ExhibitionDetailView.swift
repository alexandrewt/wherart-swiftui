import SwiftUI
import Auth

struct ExhibitionDetailView: View {

    let exhibition: Exhibition
    @Environment(\.dismiss) private var dismiss

    @State private var isFavorite: Bool = false
    @State private var isViewed: Bool = false
    @State private var showPricing = false
    @State private var showAccessibility = false
    @State private var visitsCount: Int? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Hero Image
                ZStack(alignment: .bottom) {
                    AsyncImage(url: URL(string: exhibition.image ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Rectangle().fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipped()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .frame(height: 320)

                    VStack(alignment: .leading, spacing: 6) {
                        TagBadge(label: exhibition.type, color: Color(red: 0.58, green: 0.77, blue: 0.99))
                        Text(exhibition.title)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        Text(exhibition.venue)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 24) {

                    HStack(spacing: 12) {
                        QuickInfoCard(
                            label: "Distance",
                            value: exhibition.distance.map { String(format: "%.1f km", $0) } ?? "N/A",
                            subtitle: "Get directions",
                            action: { openMaps() }
                        )
                        QuickInfoCard(
                            label: "Pricing",
                            value: exhibition.isFree ? "Free" : (exhibition.price.map { "From \($0)" } ?? "N/A"),
                            subtitle: exhibition.isFree ? nil : "See all prices",
                            action: exhibition.isFree ? nil : { showPricing = true }
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available visits")
                            .font(.system(size: 16, weight: .semibold))

                        RoundedRectangle(cornerRadius: 16)
                            .fill(visitsCount ?? 0 > 0 ? Color.green.opacity(0.1) : Color(.systemGray6))
                            .frame(height: 52)
                            .overlay(
                                Text(visitsCount == nil ? "Loading..." : visitsCount! > 0 ? "\(visitsCount!) visit\(visitsCount! > 1 ? "s" : "") scheduled" : "No visit scheduled for this exhibition")
                                    .font(.system(size: 14))
                                    .foregroundColor(visitsCount ?? 0 > 0 ? .green : .secondary)
                                    .padding(.horizontal, 16),
                                alignment: .leading
                            )
                    }

                    if let description = exhibition.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.system(size: 16, weight: .semibold))
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Practical information")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.bottom, 12)

                        VStack(spacing: 0) {
                            PracticalInfoRow(
                                icon: "mappin.and.ellipse",
                                label: "Address",
                                value: exhibition.address,
                                hasAction: true,
                                action: { openMaps() }
                            )
                            Divider().padding(.leading, 44)
                            openingHoursRow
                            Divider().padding(.leading, 44)
                            PracticalInfoRow(
                                icon: "clock",
                                label: "Estimated duration",
                                value: exhibition.duration ?? "Not provided"
                            )
                            Divider().padding(.leading, 44)
                            PracticalInfoRow(
                                icon: "figure.roll",
                                label: "Accessibility",
                                value: exhibition.accessibility ?? "Not provided",
                                hasAction: exhibition.accessibility != nil,
                                action: { showAccessibility = true }
                            )
                            Divider().padding(.leading, 44)
                            PracticalInfoRow(
                                icon: "phone",
                                label: "Contact",
                                value: exhibition.phone ?? "Not provided"
                            )
                        }
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }

                    VStack(spacing: 12) {
                        Button(action: {}) {
                            Text(visitsCount ?? 0 > 0 ? "Visit with others" : "Organise a visit")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 26))
                        }

                        if let ticketLink = exhibition.ticketLink, !ticketLink.isEmpty {
                            Button(action: { openURL(ticketLink) }) {
                                Text(exhibition.isFree ? "Plan my visit" : "Buy a ticket")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 26))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 26)
                                            .stroke(Color.blue, lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    Button(action: { Task { await toggleViewed() } }) {
                        Image(systemName: isViewed ? "eye.fill" : "eye")
                            .font(.system(size: 15))
                            .foregroundColor(isViewed ? .blue : .white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Button(action: { Task { await toggleFavorite() } }) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 15))
                            .foregroundColor(isFavorite ? .red : .white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .sheet(isPresented: $showPricing) {
            PricingSheet(exhibition: exhibition)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAccessibility) {
            AccessibilitySheet(text: exhibition.accessibility ?? "")
                .presentationDetents([.medium])
        }
        .task {
            await loadInitialState()
        }
    }

    // MARK: - Opening Hours Row
    private var openingHoursRow: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "clock")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 20)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 6) {
                Text("Opening hours")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                if let schedule = exhibition.schedule {
                    let parts = parseSchedule(schedule)
                    HStack(spacing: 10) {
                        if let dates = parts.dates {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DATES")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(dates)
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        if let hours = parts.hours {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("HOURS")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(hours)
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                } else {
                    Text("Not provided")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 12)

            Spacer()
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Helpers
    private func parseSchedule(_ schedule: String) -> (dates: String?, hours: String?) {
        let hoursPattern = #"\d{1,2}[h:]\d{0,2}\s*[-–]\s*\d{1,2}[h:]\d{0,2}"#
        if let range = schedule.range(of: hoursPattern, options: .regularExpression) {
            let hours = String(schedule[range])
            let dates = schedule.replacingCharacters(in: range, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return (dates.isEmpty ? nil : dates, hours)
        }
        return (nil, schedule)
    }

    private func openMaps() {
        let address = exhibition.address
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func loadInitialState() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        if let interactions = try? await SupabaseService.shared.fetchInteractions(userId: userId) {
            let interaction = interactions.first { $0.exhibitionId == exhibition.id }
            isFavorite = interaction?.isFavorite ?? false
            isViewed = interaction?.isViewed ?? false
        }
        if let groups = try? await SupabaseService.shared.fetchGroups() {
            visitsCount = groups.filter { $0.exhibitionId == exhibition.id }.count
        }
    }

    private func toggleFavorite() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        isFavorite.toggle()
        try? await SupabaseService.shared.upsertInteraction(
            userId: userId,
            exhibitionId: exhibition.id,
            isFavorite: isFavorite,
            isViewed: isViewed
        )
    }

    private func toggleViewed() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        isViewed.toggle()
        try? await SupabaseService.shared.upsertInteraction(
            userId: userId,
            exhibitionId: exhibition.id,
            isFavorite: isFavorite,
            isViewed: isViewed
        )
    }
}

// MARK: - Quick Info Card
struct QuickInfoCard: View {
    let label: String
    let value: String
    let subtitle: String?
    let action: (() -> Void)?

    init(label: String, value: String, subtitle: String? = nil, action: (() -> Void)? = nil) {
        self.label = label
        self.value = value
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        Button(action: { action?() }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.blue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

// MARK: - Practical Info Row
struct PracticalInfoRow: View {
    let icon: String
    let label: String
    let value: String
    var hasAction: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }

                Spacer()

                if hasAction {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(!hasAction)
    }
}

// MARK: - Pricing Sheet
struct PricingSheet: View {
    let exhibition: Exhibition
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Pricing")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            VStack(spacing: 12) {
                PriceRow(label: "Full price", value: exhibition.price ?? "N/A")
                PriceRow(label: "Reduced price", value: "On presentation of valid ID")
                PriceRow(label: "Free", value: "Under 18 and job seekers")
                PriceRow(label: "Group rate", value: "Contact the venue")
            }
            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Price Row
struct PriceRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Accessibility Sheet
struct AccessibilitySheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    let items = [
        (icon: "checkmark.circle.fill", color: Color.green, text: "Wheelchair access"),
        (icon: "checkmark.circle.fill", color: Color.green, text: "Lift available"),
        (icon: "checkmark.circle.fill", color: Color.green, text: "Adapted toilets"),
        (icon: "checkmark.circle.fill", color: Color.green, text: "Audioguide available"),
        (icon: "xmark.circle.fill", color: Color.gray, text: "Guide dogs not allowed"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Accessibility")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            VStack(spacing: 10) {
                ForEach(items, id: \.text) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .foregroundColor(item.color)
                        Text(item.text)
                            .font(.system(size: 14))
                        Spacer()
                    }
                }
            }
            Spacer()
        }
        .padding(24)
    }
}

#Preview {
    NavigationStack {
        ExhibitionDetailView(exhibition: Exhibition(
            id: 1,
            title: "Gerhard Richter",
            artist: "Gerhard Richter",
            venue: "Fondation Louis Vuitton",
            venueType: "Foundations",
            type: "Contemporary Art",
            address: "8 Avenue du Mahatma Gandhi, 75116 Paris",
            schedule: "Mon-Fri: 12pm-7pm",
            description: "A major retrospective of Gerhard Richter's work.",
            ticketLink: "https://fondationlouisvuitton.fr",
            image: nil,
            lat: 48.8738,
            lng: 2.2654,
            price: "16€",
            duration: "2h",
            accessibility: "Wheelchair accessible",
            phone: "+33 1 40 69 96 00",
            isFree: false,
            endingSoon: false,
            endDate: nil,
            distance: 6.8
        ))
    }
}
