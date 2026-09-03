import SwiftUI

struct OnboardingView: View {

    let userId: String
    var onComplete: () -> Void

    @State private var currentStep = 0
    @State private var selectedTypes: [String] = []
    @State private var selectedVenues: [String] = []
    @State private var isLoading = false
    @State private var acceptedTerms = false
    @State private var onboardingStartTime: Date?

    let artTypes = [
        "Painting", "Sculpture", "Photography", "Contemporary Art", "Street Art",
        "Abstract Art", "Installation", "Modern Art", "Asian Art", "Design",
        "Drawing", "Video Art", "Architecture", "Digital Art", "Illustration",
        "Printmaking", "Mixed Media", "Textile Art", "Ceramics", "Performance"
    ]

    let venueTypes = [
        "Museums", "Galleries", "Art Centers", "Foundations",
        "Cultural Centers", "Art Fairs", "Auction Houses", "Libraries",
        "Public Spaces", "Churches & Heritage", "Cultural Institutes", "Artist Studios"
    ]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - Progress
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index <= currentStep ? Color.blue : Color(.systemGray4))
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)

                Spacer()

                // MARK: - Steps
                if currentStep == 0 {
                    stepWelcome
                } else if currentStep == 1 {
                    stepArtTypes
                } else {
                    stepVenueTypes
                }

                Spacer()

                // MARK: - Terms checkbox (step 0 uniquement)
                if currentStep == 0 {
                    Button(action: { acceptedTerms.toggle() }) {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(acceptedTerms ? Color.blue : Color(.systemGray3), lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                                if acceptedTerms {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.blue)
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }

                            Group {
                                Text(String(localized: "accept_terms_prefix"))
                                    .foregroundColor(.secondary)
                                + Text(String(localized: "privacy_policy"))
                                    .foregroundColor(.blue)
                                + Text(String(localized: "and_the"))
                                    .foregroundColor(.secondary)
                                + Text(String(localized: "terms_of_use"))
                                    .foregroundColor(.blue)
                            }
                            .font(.system(size: 13))
                            .multilineTextAlignment(.leading)
                            .overlay(
                                HStack(spacing: 0) {
                                    // Zones de tap sur les liens
                                    Color.clear
                                        .frame(maxWidth: .infinity)
                                        .onTapGesture {
                                            UIApplication.shared.open(URL(string: "https://wherart.figma.site/politique-confidentialite")!)
                                        }
                                    Color.clear
                                        .frame(maxWidth: .infinity)
                                        .onTapGesture {
                                            UIApplication.shared.open(URL(string: "https://wherart.figma.site/conditions-utilisation")!)
                                        }
                                }
                            )
                        }
                        .padding(.horizontal, 24)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 16)
                }

                // MARK: - CTA
                Button(action: handleNext) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(canProceed ? Color.blue : Color(.systemGray4))
                            .frame(height: 56)
                            .shadow(
                                color: canProceed ? Color.blue.opacity(0.3) : Color.clear,
                                radius: 12, x: 0, y: 4
                            )

                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(currentStep == 2 ? String(localized: "get_started") : String(localized: "continue_button"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(!canProceed || isLoading)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            onboardingStartTime = Date()
            AnalyticsService.shared.track("onboarding_started", properties: [
                "user_id": userId
            ])
        }
    }

    // MARK: - Step Views
    private var stepWelcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "welcome_title"))
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
            Text(String(localized: "onboarding_welcome_subtitle"))
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var stepArtTypes: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "onboarding_art_question"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                Text(String(localized: "select_at_least_one"))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            FlowLayout(items: artTypes) { type in
                OnboardingChip(
                    label: ArtTaxonomy.displayLabel(for: type),
                    isSelected: selectedTypes.contains(type),
                    action: { toggleType(type) }
                )
            }
        }
        .padding(.horizontal, 24)
    }

    private var stepVenueTypes: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "onboarding_venue_question"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                Text(String(localized: "select_at_least_one"))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            FlowLayout(items: venueTypes) { venue in
                OnboardingChip(
                    label: ArtTaxonomy.displayLabel(for: venue),
                    isSelected: selectedVenues.contains(venue),
                    action: { toggleVenue(venue) }
                )
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Logic
    private var canProceed: Bool {
        switch currentStep {
        case 0: return acceptedTerms
        case 1: return !selectedTypes.isEmpty
        case 2: return !selectedVenues.isEmpty
        default: return false
        }
    }

    private func toggleType(_ type: String) {
        let isSelected = !selectedTypes.contains(type)
        if isSelected {
            selectedTypes.append(type)
        } else {
            selectedTypes.removeAll { $0 == type }
        }
        AnalyticsService.shared.track("onboarding_preferences_changed", properties: [
            "preference_type": "art_type",
            "preference_value": type,
            "is_selected": isSelected
        ])
    }

    private func toggleVenue(_ venue: String) {
        let isSelected = !selectedVenues.contains(venue)
        if isSelected {
            selectedVenues.append(venue)
        } else {
            selectedVenues.removeAll { $0 == venue }
        }
        AnalyticsService.shared.track("onboarding_preferences_changed", properties: [
            "preference_type": "venue_type",
            "preference_value": venue,
            "is_selected": isSelected
        ])
    }

    private func handleNext() {
        if currentStep < 2 {
            let stepNames = ["terms_acceptance", "art_types", "venue_types"]
            AnalyticsService.shared.track("onboarding_step_completed", properties: [
                "step_name": stepNames[currentStep],
                "step_number": currentStep,
                "preferences_count": currentStep == 0 ? 0 : (currentStep == 1 ? selectedTypes.count : selectedVenues.count)
            ])
            withAnimation { currentStep += 1 }
        } else {
            saveAndComplete()
        }
    }

    private func saveAndComplete() {
        isLoading = true
        Task {
            do {
                try await SupabaseService.shared.updatePreferences(
                    userId: userId,
                    preferences: selectedTypes,
                    venueTypes: selectedVenues
                )
                let duration = Int(Date().timeIntervalSince(onboardingStartTime ?? Date()))
                AnalyticsService.shared.track("onboarding_completed", properties: [
                    "user_id": userId,
                    "art_types_count": selectedTypes.count,
                    "venue_types_count": selectedVenues.count,
                    "duration_seconds": duration
                ])
                await MainActor.run {
                    isLoading = false
                    onComplete()
                }
            } catch {
                AnalyticsService.shared.track("onboarding_error", properties: [
                    "user_id": userId,
                    "error_type": String(describing: type(of: error)),
                    "error_message": error.localizedDescription
                ])
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Onboarding Chip
struct OnboardingChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.blue : Color.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout
struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    @State private var totalHeight = CGFloat.zero

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        var lastHeight = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geometry.size.width {
                            width = 0
                            height -= lastHeight + 8
                        }
                        lastHeight = d.height
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= d.width + 8
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == items.last { height = 0 }
                        return result
                    }
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: HeightPreferenceKey.self,
                    value: geo.size.height
                )
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self) { value in
            totalHeight = value
        }
    }
}

struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    OnboardingView(userId: "preview") {}
}
