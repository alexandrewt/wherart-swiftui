import SwiftUI
import Auth
import PhotosUI

struct ProfileView: View {

    @EnvironmentObject private var nav: AppNavigation
    private var service: SupabaseService { SupabaseService.shared }
    @State private var profile: Profile? = nil
    @State private var favoritesCount = 0
    @State private var viewedCount = 0
    @State private var visitsCount = 0
    @State private var showEditPrefs = false
    @State private var showNotificationSettings = false
    @State private var editTypes: [String] = []
    @State private var editVenues: [String] = []
    @State private var editReminderThreshold: Double = 25
    @State private var isSaving = false
    @State private var showChangePassword = false
    @State private var passwordResetSent = false
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showEditProfile = false
    @State private var showPhotosPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isUploadingAvatar = false

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
        ScrollView {
            VStack(spacing: 24) {

                // MARK: - Avatar
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.15, green: 0.39, blue: 0.92),
                                        Color(red: 0.45, green: 0.20, blue: 0.90)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 88, height: 88)
                        Circle()
                            .fill(Color(.systemBackground))
                            .frame(width: 80, height: 80)

                        if let urlString = profile?.avatarUrl, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    Circle().fill(Color(.systemGray5))
                                        .overlay(
                                            Text((profile?.firstName ?? "U").prefix(1).uppercased())
                                                .font(.system(size: 32, weight: .bold))
                                                .foregroundColor(.primary)
                                        )
                                }
                            }
                            .frame(width: 76, height: 76)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 76, height: 76)
                            Text((profile?.firstName ?? "U").prefix(1).uppercased())
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                        }

                        if isUploadingAvatar {
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 76, height: 76)
                            ProgressView().tint(.white)
                        }

                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Color(red: 0.15, green: 0.39, blue: 0.92))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                            .offset(x: 30, y: 30)
                    }
                    .onTapGesture {
                        if !isUploadingAvatar { showPhotosPicker = true }
                    }
                    .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotoItem, matching: .images)
                    .onChange(of: selectedPhotoItem) { newItem in
                        Task { await handlePhotoSelection(newItem) }
                    }

                    if let name = profile?.firstName, !name.isEmpty {
                        Text(name).font(.system(size: 20, weight: .semibold))
                    }
                }
                .padding(.top, 8)

                // MARK: - Stats
                HStack(spacing: 12) {
                    NavigationLink(destination: FavoritesView()) {
                        StatCard(icon: "heart.fill", label: String(localized: "favourites"), count: favoritesCount, color: .red)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: ViewedView()) {
                        StatCard(icon: "eye.fill", label: String(localized: "seen"), count: viewedCount, color: Color(red: 0.15, green: 0.39, blue: 0.92))
                    }
                    .buttonStyle(.plain)

                    Button {
                        nav.visitsDefaultTab = 1
                        nav.selectedTab = 2
                    } label: {
                        StatCard(icon: "person.2.fill", label: String(localized: "visits"), count: visitsCount, color: .green)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                // MARK: - Preferences
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(String(localized: "my_preferences")).font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Button(action: {
                            AnalyticsService.shared.track("settings_opened", properties: [
                                "user_id": service.currentUser?.id.uuidString ?? "unknown"
                            ])
                            editTypes = profile?.preferences ?? []
                            editVenues = profile?.venueTypes ?? []
                            editReminderThreshold = Double(profile?.exhibitionReminderThreshold ?? 25)
                            showEditPrefs = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil").font(.system(size: 12))
                                Text(String(localized: "edit")).font(.system(size: 14))
                            }
                            .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }

                    if let prefs = profile?.preferences, !prefs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "art_genres")).font(.system(size: 13)).foregroundColor(.secondary)
                            WrapLayout(spacing: 8) {
                                ForEach(prefs, id: \.self) { pref in
                                    Text(ArtTaxonomy.displayLabel(for: pref))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    if let venues = profile?.venueTypes, !venues.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "favourite_venues")).font(.system(size: 13)).foregroundColor(.secondary)
                            WrapLayout(spacing: 8) {
                                ForEach(venues, id: \.self) { venue in
                                    Text(ArtTaxonomy.displayLabel(for: venue))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(Color(.systemGray6))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    if (profile?.preferences ?? []).isEmpty && (profile?.venueTypes ?? []).isEmpty {
                        Text(String(localized: "no_preferences")).font(.system(size: 14)).foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 16)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 16)

                // MARK: - Menu
                VStack(spacing: 0) {
                    MenuRow(icon: "person.crop.circle", label: String(localized: "edit_profile"), action: { showEditProfile = true })
                    Divider().padding(.leading, 52)
                    MenuRow(icon: "gearshape", label: String(localized: "settings"), action: { showSettings = true })
                    Divider().padding(.leading, 52)
                    MenuRow(icon: "bell", label: "Notifications", action: {
                        // savePreferences() writes back editTypes/editVenues too, so they
                        // must be kept in sync with the current profile here — otherwise
                        // saving from this sheet alone (without ever opening "Edit
                        // preferences" first) would wipe them with their default [] state.
                        editTypes = profile?.preferences ?? []
                        editVenues = profile?.venueTypes ?? []
                        editReminderThreshold = Double(profile?.exhibitionReminderThreshold ?? 25)
                        showNotificationSettings = true
                    })
                    Divider().padding(.leading, 52)
                    MenuRow(icon: "star.fill", label: String(localized: "subscribe"), action: { showPaywall = true })
                    Divider().padding(.leading, 52)
                    MenuRow(icon: "lock", label: String(localized: "change_password"), action: { showChangePassword = true })
                    Divider().padding(.leading, 52)
                    ShareLink(
                        item: URL(string: "https://apps.apple.com/app/wherart")!,
                        subject: Text(String(localized: "share_subject")),
                        message: Text(String(localized: "share_message"))
                    ) {
                        HStack(spacing: 14) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 18)).foregroundColor(.primary).frame(width: 24)
                            Text(String(localized: "share_app")).font(.system(size: 15)).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    Divider().padding(.leading, 52)
                    Button(action: handleLogout) {
                        HStack(spacing: 14) {
                            Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 18)).foregroundColor(.secondary).frame(width: 24)
                            Text(String(localized: "sign_out")).font(.system(size: 15)).foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
        .navigationDestination(isPresented: $showEditProfile) {
            EditProfileView(profile: $profile)
        }
        .navigationDestination(isPresented: $showPaywall) {
            SubscribeView()
        }
        .sheet(isPresented: $showEditPrefs) {
            EditPreferencesSheet(
                selectedTypes: $editTypes,
                selectedVenues: $editVenues,
                reminderThreshold: $editReminderThreshold,
                artTypes: artTypes,
                venueTypes: venueTypes,
                isSaving: $isSaving,
                onSave: savePreferences
            )
            .presentationDetents([.large])
            .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showNotificationSettings) {
            NotificationSettingsSheet(
                reminderThreshold: $editReminderThreshold,
                isSaving: $isSaving,
                onSave: savePreferences
            )
            .presentationDetents([.medium])
            .presentationCornerRadius(24)
        }
        .alert(String(localized: "change_password"), isPresented: $showChangePassword) {
            Button(String(localized: "send_reset_email")) {
                guard let email = service.currentUser?.email else { return }
                Task {
                    try? await SupabaseService.shared.resetPassword(email: email)
                    await MainActor.run { passwordResetSent = true }
                }
            }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: {
            Text(String(format: String(localized: "reset_link_message"), service.currentUser?.email ?? String(localized: "your_email_fallback")))
        }
        .alert(String(localized: "email_sent"), isPresented: $passwordResetSent) {
            Button(String(localized: "ok"), role: .cancel) {}
        } message: {
            Text(String(localized: "check_inbox_reset_password"))
        }
        .task {
            AnalyticsService.shared.screen("Profile")
            await loadProfile()
        }
        .onChange(of: nav.showSubscribe) { shouldShow in
            guard shouldShow else { return }
            showPaywall = true
            nav.showSubscribe = false
        }
    }

    // MARK: - Actions

    private func handleLogout() {
        let userId = service.currentUser?.id.uuidString ?? "unknown"
        AnalyticsService.shared.track("logout_confirmed", properties: [
            "user_id": userId
        ])
        Task {
            do {
                try await service.signOut()
                AnalyticsService.shared.reset()
            } catch {
                AnalyticsService.shared.track("logout_error", properties: [
                    "error_type": String(describing: type(of: error))
                ])

                AnalyticsService.shared.trackError(
                    domain: "auth",
                    code: (error as NSError).code,
                    message: error.localizedDescription,
                    context: ["flow": "logout"]
                )
            }
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

                AnalyticsService.shared.track("profile_viewed", properties: [
                    "user_id": userId,
                    "favorites_count": self.favoritesCount,
                    "viewed_count": self.viewedCount,
                    "visits_count": self.visitsCount,
                    "reminder_threshold": fetchedProfile.exhibitionReminderThreshold ?? 25
                ])
            }
        } catch {
            AnalyticsService.shared.track("profile_load_error", properties: [
                "error_type": String(describing: type(of: error)),
                "error_message": error.localizedDescription
            ])
        }
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item, let userId = service.currentUser?.id.uuidString else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        let resized = uiImage.resized(maxDimension: 500)
        guard let jpegData = resized.jpegData(compressionQuality: 0.8) else { return }

        await MainActor.run { isUploadingAvatar = true }
        do {
            let url = try await SupabaseService.shared.uploadProfilePhoto(userId: userId, imageData: jpegData)
            if var updated = profile {
                updated.avatarUrl = url
                try await SupabaseService.shared.upsertProfile(updated)
            }
            await MainActor.run {
                profile?.avatarUrl = url
                isUploadingAvatar = false
            }
        } catch {
            await MainActor.run { isUploadingAvatar = false }
        }
    }

    private func savePreferences() {
        guard let userId = service.currentUser?.id.uuidString else { return }
        isSaving = true
        Task {
            do {
                try await SupabaseService.shared.updatePreferences(
                    userId: userId,
                    preferences: editTypes,
                    venueTypes: editVenues,
                    reminderThreshold: Int(editReminderThreshold)
                )
                await MainActor.run {
                    profile?.preferences = editTypes
                    profile?.venueTypes = editVenues
                    profile?.exhibitionReminderThreshold = Int(editReminderThreshold)

                    AnalyticsService.shared.track("preferences_updated", properties: [
                        "user_id": userId,
                        "art_types_count": editTypes.count,
                        "venue_types_count": editVenues.count,
                        "reminder_threshold": Int(editReminderThreshold),
                        "art_types": editTypes.joined(separator: ","),
                        "venue_types": editVenues.joined(separator: ",")
                    ])

                    isSaving = false
                    showEditPrefs = false
                }
            } catch {
                await MainActor.run {
                    AnalyticsService.shared.track("preferences_update_error", properties: [
                        "user_id": userId,
                        "error_type": String(describing: type(of: error))
                    ])
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    private var service: SupabaseService { SupabaseService.shared }
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false
    @State private var showDeleteError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    // Support
                    Link(destination: URL(string: "mailto:alexandre@wherart.com")!) {
                        HStack(spacing: 14) {
                            Image(systemName: "envelope")
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "contact_support"))
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                Text("alexandre@wherart.com")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    Divider().padding(.leading, 52)

                    // Privacy Policy
                    Link(destination: URL(string: "https://wherart.figma.site/politique-confidentialite")!) {
                        HStack(spacing: 14) {
                            Image(systemName: "hand.raised")
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                                .frame(width: 24)
                            Text(String(localized: "privacy_policy"))
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    Divider().padding(.leading, 52)

                    // Terms of Use
                    Link(destination: URL(string: "https://wherart.figma.site/conditions-utilisation")!) {
                        HStack(spacing: 14) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                                .frame(width: 24)
                            Text(String(localized: "terms_of_use"))
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 24)

                // MARK: - Danger Zone
                VStack(spacing: 0) {
                    Button(action: { showDeleteConfirm = true }) {
                        HStack(spacing: 14) {
                            if isDeletingAccount {
                                ProgressView()
                                    .frame(width: 24)
                            } else {
                                Image(systemName: "trash")
                                    .font(.system(size: 18))
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                            }
                            Text(String(localized: "delete_account"))
                                .font(.system(size: 15))
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeletingAccount)
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(String(localized: "settings"))
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .alert(String(localized: "delete_account_confirm_title"), isPresented: $showDeleteConfirm) {
            Button(String(localized: "delete"), role: .destructive) {
                Task { await handleDeleteAccount() }
            }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "delete_account_warning"))
        }
        .alert(String(localized: "something_went_wrong"), isPresented: $showDeleteError) {
            Button(String(localized: "ok"), role: .cancel) {}
        } message: {
            Text(String(localized: "delete_account_error_message"))
        }
    }

    // MARK: - Actions

    private func handleDeleteAccount() async {
        guard let userId = service.currentUser?.id.uuidString else { return }

        AnalyticsService.shared.track("delete_account_requested", properties: [
            "user_id": userId
        ])

        isDeletingAccount = true
        do {
            try await SupabaseService.shared.deleteAccount(userId: userId)
            await MainActor.run {
                AnalyticsService.shared.reset()
                isDeletingAccount = false
                SupabaseService.shared.isAuthenticated = false
            }
        } catch {
            await MainActor.run {
                AnalyticsService.shared.track("delete_account_error", properties: [
                    "user_id": userId,
                    "error_type": String(describing: type(of: error))
                ])
                isDeletingAccount = false
                showDeleteError = true
            }
        }
    }
}

// MARK: - Wrap Layout
struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0; var x: CGFloat = 0; var y: CGFloat = 0; var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 { y += rowHeight + spacing; x = 0; rowHeight = 0 }
            rowHeight = max(rowHeight, size.height); x += size.width + spacing
        }
        height = y + rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX { y += rowHeight + spacing; x = bounds.minX; rowHeight = 0 }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height); x += size.width + spacing
        }
    }
}

// MARK: - Menu Row
struct MenuRow: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(.primary).frame(width: 24)
                Text(label).font(.system(size: 15)).foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
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
            Image(systemName: icon).font(.system(size: 20)).foregroundColor(color)
            Text("\(count)").font(.system(size: 22, weight: .bold))
            Text(label).font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Notification Settings Sheet
/// Standalone entry point to the "Ending Soon" reminder threshold —
/// same slider/save logic as EditPreferencesSheet, but reachable directly
/// from a "Notifications" row in the profile menu instead of being buried
/// inside the preferences editor.
struct NotificationSettingsSheet: View {
    @Binding var reminderThreshold: Double
    @Binding var isSaving: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Notifications").font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(.secondary)
                }
            }
            .padding(24)

            VStack(alignment: .leading, spacing: 12) {
                Text("Ending Soon Reminders").font(.system(size: 16, weight: .semibold))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Remind me when exhibition has").font(.system(size: 14))
                    HStack {
                        Slider(value: $reminderThreshold, in: 0...100, step: 5)
                        Text("\(Int(reminderThreshold))%").font(.system(size: 14, weight: .bold)).frame(width: 40)
                    }
                    Text("Days left = Total duration × \(Int(reminderThreshold))%").font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: {
                onSave()
                dismiss()
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.15, green: 0.39, blue: 0.92)).frame(height: 52)
                    if isSaving { ProgressView().tint(.white) }
                    else { Text(String(localized: "save")).font(.system(size: 16, weight: .semibold)).foregroundColor(.white) }
                }
            }
            .disabled(isSaving).padding(24)
        }
    }
}

// MARK: - Edit Preferences Sheet
struct EditPreferencesSheet: View {
    @Binding var selectedTypes: [String]
    @Binding var selectedVenues: [String]
    @Binding var reminderThreshold: Double
    let artTypes: [String]
    let venueTypes: [String]
    @Binding var isSaving: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let selectionFeedback = UISelectionFeedbackGenerator()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(String(localized: "edit_preferences")).font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(.secondary)
                }
            }
            .padding(24)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "art_types")).font(.system(size: 16, weight: .semibold))
                        WrapLayout(spacing: 8) {
                            ForEach(artTypes, id: \.self) { type in
                                Button(action: {
                                    selectionFeedback.selectionChanged()
                                    if selectedTypes.contains(type) { selectedTypes.removeAll { $0 == type } }
                                    else { selectedTypes.append(type) }
                                }) {
                                    Text(ArtTaxonomy.displayLabel(for: type)).font(.system(size: 13, weight: .medium))
                                        .foregroundColor(selectedTypes.contains(type) ? .white : .primary)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(selectedTypes.contains(type) ? Color(red: 0.15, green: 0.39, blue: 0.92) : Color(.systemGray6))
                                        .clipShape(Capsule())
                                }.buttonStyle(.plain)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "venue_types")).font(.system(size: 16, weight: .semibold))
                        WrapLayout(spacing: 8) {
                            ForEach(venueTypes, id: \.self) { venue in
                                Button(action: {
                                    selectionFeedback.selectionChanged()
                                    if selectedVenues.contains(venue) { selectedVenues.removeAll { $0 == venue } }
                                    else { selectedVenues.append(venue) }
                                }) {
                                    Text(ArtTaxonomy.displayLabel(for: venue)).font(.system(size: 13, weight: .medium))
                                        .foregroundColor(selectedVenues.contains(venue) ? .white : .primary)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(selectedVenues.contains(venue) ? Color(red: 0.15, green: 0.39, blue: 0.92) : Color(.systemGray6))
                                        .clipShape(Capsule())
                                }.buttonStyle(.plain)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ending Soon Reminders").font(.system(size: 16, weight: .semibold))
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Remind me when exhibition has").font(.system(size: 14))
                            HStack {
                                Slider(value: $reminderThreshold, in: 0...100, step: 5)
                                Text("\(Int(reminderThreshold))%").font(.system(size: 14, weight: .bold)).frame(width: 40)
                            }
                            Text("Days left = Total duration × \(Int(reminderThreshold))%").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
            }

            Button(action: onSave) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.15, green: 0.39, blue: 0.92)).frame(height: 52)
                    if isSaving { ProgressView().tint(.white) }
                    else { Text(String(localized: "save")).font(.system(size: 16, weight: .semibold)).foregroundColor(.white) }
                }
            }
            .disabled(isSaving).padding(24)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AppNavigation())
    }
}

// MARK: - UIImage Resize

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else { return self }
        let scale = maxDimension / largestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
