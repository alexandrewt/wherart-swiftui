import SwiftUI
import Auth

struct ProfileView: View {

    @StateObject private var service = SupabaseService.shared
    @State private var profile: Profile? = nil
    @State private var favoritesCount = 0
    @State private var viewedCount = 0
    @State private var visitsCount = 0
    @State private var showEditPrefs = false
    @State private var editTypes: [String] = []
    @State private var editVenues: [String] = []
    @State private var isSaving = false

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
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: - Avatar
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Text((profile?.firstName ?? "U").prefix(1).uppercased())
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.blue)
                        }

                        if let name = profile?.firstName, !name.isEmpty {
                            Text(name)
                                .font(.system(size: 20, weight: .semibold))
                        }
                    }
                    .padding(.top, 8)

                    // MARK: - Stats
                    HStack(spacing: 12) {
                        NavigationLink(destination: FavoritesView()) {
                            StatCard(icon: "heart.fill", label: "Favorites", count: favoritesCount, color: .red)
                        }
                        .buttonStyle(.plain)
                        NavigationLink(destination: ViewedView()) {
                            StatCard(icon: "eye.fill", label: "Viewed", count: viewedCount, color: .blue)
                        }
                        .buttonStyle(.plain)
                        StatCard(icon: "person.2.fill", label: "Visits", count: visitsCount, color: .green)
                    }
                    .padding(.horizontal, 16)
                    // MARK: - Preferences
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("My preferences")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Button(action: {
                                editTypes = profile?.preferences ?? []
                                editVenues = profile?.venueTypes ?? []
                                showEditPrefs = true
                            }) {
                                Text("Edit")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }
                        }

                        if let prefs = profile?.preferences, !prefs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Art types")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(prefs, id: \.self) { pref in
                                            Text(pref)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.blue)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.blue.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }

                        if let venues = profile?.venueTypes, !venues.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Venue types")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(venues, id: \.self) { venue in
                                            Text(venue)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.purple)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.purple.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }

                        if (profile?.preferences ?? []).isEmpty && (profile?.venueTypes ?? []).isEmpty {
                            Text("No preferences set")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 16)

                    // MARK: - Logout
                    Button(action: handleLogout) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign out")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showEditPrefs) {
            EditPreferencesSheet(
                selectedTypes: $editTypes,
                selectedVenues: $editVenues,
                artTypes: artTypes,
                venueTypes: venueTypes,
                isSaving: $isSaving,
                onSave: savePreferences
            )
            .presentationDetents([.large])
        }
        .task {
            await loadProfile()
        }
    }

    // MARK: - Actions
    private func handleLogout() {
        Task {
            try? await service.signOut()
        }
    }

    private func loadProfile() async {
        guard let userId = service.currentUser?.id.uuidString else { return }
        async let profileTask = SupabaseService.shared.fetchProfile(userId: userId)
        async let interactionsTask = SupabaseService.shared.fetchInteractions(userId: userId)
        async let groupsTask = SupabaseService.shared.fetchMyGroups(userId: userId)

        do {
            let (fetchedProfile, interactions, groups) = try await (profileTask, interactionsTask, groupsTask)
            await MainActor.run {
                self.profile = fetchedProfile
                self.favoritesCount = interactions.filter { $0.isFavorite }.count
                self.viewedCount = interactions.filter { $0.isViewed }.count
                self.visitsCount = groups.count
            }
        } catch {}
    }

    private func savePreferences() {
        guard let userId = service.currentUser?.id.uuidString else { return }
        isSaving = true
        Task {
            try? await SupabaseService.shared.updatePreferences(
                userId: userId,
                preferences: editTypes,
                venueTypes: editVenues
            )
            await MainActor.run {
                profile?.preferences = editTypes
                profile?.venueTypes = editVenues
                isSaving = false
                showEditPrefs = false
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text("\(count)")
                .font(.system(size: 22, weight: .bold))
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Edit Preferences Sheet
struct EditPreferencesSheet: View {
    @Binding var selectedTypes: [String]
    @Binding var selectedVenues: [String]
    let artTypes: [String]
    let venueTypes: [String]
    @Binding var isSaving: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Edit preferences")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Art types")
                            .font(.system(size: 16, weight: .semibold))
                        FlowLayout(items: artTypes) { type in
                            OnboardingChip(
                                label: type,
                                isSelected: selectedTypes.contains(type),
                                action: {
                                    if selectedTypes.contains(type) {
                                        selectedTypes.removeAll { $0 == type }
                                    } else {
                                        selectedTypes.append(type)
                                    }
                                }
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Venue types")
                            .font(.system(size: 16, weight: .semibold))
                        FlowLayout(items: venueTypes) { venue in
                            OnboardingChip(
                                label: venue,
                                isSelected: selectedVenues.contains(venue),
                                action: {
                                    if selectedVenues.contains(venue) {
                                        selectedVenues.removeAll { $0 == venue }
                                    } else {
                                        selectedVenues.append(venue)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            Button(action: onSave) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.blue)
                        .frame(height: 52)
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(isSaving)
            .padding(24)
        }
    }
}

#Preview {
    ProfileView()
}
