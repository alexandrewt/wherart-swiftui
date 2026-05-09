import SwiftUI

struct OnboardingView: View {

    let userId: String
    var onComplete: () -> Void

    @State private var currentStep = 0
    @State private var selectedTypes: [String] = []
    @State private var selectedVenues: [String] = []
    @State private var isLoading = false

    let artTypes = [
        "Contemporary Art", "Photography", "Painting", "Sculpture",
        "Drawing", "Video Art", "Street Art", "Design",
        "Architecture", "Digital Art", "Illustration", "Printmaking"
    ]

    let venueTypes = [
        "Museums", "Galleries", "Art Centers", "Foundations",
        "Cultural Centers", "Auction Houses", "Art Fairs", "Public Spaces"
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

                // MARK: - CTA
                Button(action: handleNext) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(canProceed ? Color.blue : Color(.systemGray4))
                            .frame(height: 56)
                            .shadow(
                                color: canProceed ? Color.blue.opacity(0.3) : Color.clear,
                                radius: 12, x: 0, y: 4
                            )

                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(currentStep == 2 ? "Get started" : "Continue")
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
    }

    // MARK: - Step Views
    private var stepWelcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome to Wherart")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)

            Text("Let's personalise your art discovery experience")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var stepArtTypes: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What art do you love?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                Text("Select at least one")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            FlowLayout(items: artTypes) { type in
                OnboardingChip(
                    label: type,
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
                Text("Where do you like to go?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                Text("Select at least one")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            FlowLayout(items: venueTypes) { venue in
                OnboardingChip(
                    label: venue,
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
        case 0: return true
        case 1: return !selectedTypes.isEmpty
        case 2: return !selectedVenues.isEmpty
        default: return false
        }
    }

    private func toggleType(_ type: String) {
        if selectedTypes.contains(type) {
            selectedTypes.removeAll { $0 == type }
        } else {
            selectedTypes.append(type)
        }
    }

    private func toggleVenue(_ venue: String) {
        if selectedVenues.contains(venue) {
            selectedVenues.removeAll { $0 == venue }
        } else {
            selectedVenues.append(venue)
        }
    }

    private func handleNext() {
        if currentStep < 2 {
            withAnimation { currentStep += 1 }
        } else {
            saveAndComplete()
        }
    }

    private func saveAndComplete() {
        isLoading = true
        Task {
            try? await SupabaseService.shared.updatePreferences(
                userId: userId,
                preferences: selectedTypes,
                venueTypes: selectedVenues
            )
            await MainActor.run {
                isLoading = false
                onComplete()
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
