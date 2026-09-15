import SwiftUI
import Auth

/// Full-screen notifications feed (replaces the old idea of a
/// sheet/overlay) — the persisted, in-app counterpart to the local
/// UNUserNotificationCenter pushes EndingSoonService/NewExhibitionsService
/// already schedule. The gear icon reuses the existing
/// `NotificationSettingsSheet` (see ProfileView) rather than a second,
/// parallel settings screen — that sheet already owns the real
/// "Ending Soon" threshold/frequency fields tied to `profiles`.
struct NotificationsView: View {
    @EnvironmentObject private var nav: AppNavigation
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = false
    @State private var showSettings = false
    @State private var selectedExhibition: Exhibition? = nil
    @State private var showPreviewSheet = false
    @State private var selectedNotification: AppNotification?

    // Bindings for the reused NotificationSettingsSheet.
    @State private var editReminderThreshold: Double = 25
    @State private var editEndingSoonFrequency: String = "once"
    @State private var editTypes: [String] = []
    @State private var editVenues: [String] = []
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "notifications"))
                    .font(.system(size: 28, weight: .bold))

                Spacer()

                if !notifications.isEmpty && nav.unreadNotificationsCount > 0 {
                    Button(action: { Task { await markAllRead() } }) {
                        Text(String(localized: "mark_all_read"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                    }
                }

                Button(action: { openSettings() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                }
                .padding(.leading, 16)
            }
            .padding(16)

            Divider()

            if isLoading && notifications.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if notifications.isEmpty {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text(String(localized: "no_notifications_yet"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                        Text(String(localized: "no_notifications_subtitle"))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(notifications) { notification in
                        if notification.hasMultipleExhibitions {
                            NotificationRow(notification: notification)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    Task { await handleTapMultiple(notification) }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await delete(notification) }
                                    } label: {
                                        Label(String(localized: "delete"), systemImage: "trash")
                                    }
                                }
                        } else {
                            NotificationRow(notification: notification)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    Task { await handleTap(notification) }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await delete(notification) }
                                    } label: {
                                        Label(String(localized: "delete"), systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await loadNotifications()
                }
            }
        }
        .navigationDestination(item: $selectedExhibition) { exhibition in
            ExhibitionDetailView(exhibition: exhibition)
        }
        .sheet(isPresented: $showPreviewSheet) {
            if let notification = selectedNotification {
                NotificationPreviewSheet(notification: notification)
            }
        }
        .sheet(isPresented: $showSettings) {
            NotificationSettingsSheet(
                reminderThreshold: $editReminderThreshold,
                frequency: $editEndingSoonFrequency,
                isSaving: $isSaving,
                onSave: saveSettings
            )
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(24)
        }
        .task {
            await loadNotifications()
        }
    }

    private func loadNotifications() async {
        isLoading = true
        do {
            notifications = try await SupabaseService.shared.fetchNotifications()
        } catch {
            print("[NotificationsView] Error loading notifications: \(error)")
        }
        isLoading = false
        nav.refreshUnreadNotificationsCount()
    }

    private func openSettings() {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        Task {
            if let profile = try? await SupabaseService.shared.fetchProfile(userId: userId) {
                await MainActor.run {
                    editTypes = profile.preferences
                    editVenues = profile.venueTypes
                    editReminderThreshold = Double(profile.exhibitionReminderThreshold ?? 25)
                    editEndingSoonFrequency = profile.endingSoonFrequency ?? "once"
                    showSettings = true
                }
            }
        }
    }

    private func saveSettings() {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        isSaving = true
        Task {
            do {
                try await SupabaseService.shared.updatePreferences(
                    userId: userId,
                    preferences: editTypes,
                    venueTypes: editVenues,
                    reminderThreshold: Int(editReminderThreshold),
                    endingSoonFrequency: editEndingSoonFrequency
                )
            } catch {
                print("[NotificationsView] Error saving notification settings: \(error)")
            }
            await MainActor.run {
                isSaving = false
                showSettings = false
            }
        }
    }

    private func handleTap(_ notification: AppNotification) async {
        if !notification.isRead {
            await markRead(notification)
        }
        if let exhibitionIds = notification.exhibitionIds, let firstId = exhibitionIds.first {
            selectedExhibition = try? await SupabaseService.shared.fetchExhibitionById(id: firstId)
        }
    }

    private func handleTapMultiple(_ notification: AppNotification) async {
        if !notification.isRead {
            await markRead(notification)
        }
        selectedNotification = notification
        showPreviewSheet = true
    }

    private func markRead(_ notification: AppNotification) async {
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        notifications[index].isRead = true
        do {
            try await SupabaseService.shared.markNotificationAsRead(notificationId: notification.id)
            AnalyticsService.shared.track("notification_read", properties: [
                "notification_id": notification.id.uuidString
            ])
        } catch {
            print("[NotificationsView] Error marking notification read: \(error)")
        }
        nav.refreshUnreadNotificationsCount()
    }

    private func markAllRead() async {
        do {
            try await SupabaseService.shared.markAllNotificationsAsRead()
            for index in notifications.indices { notifications[index].isRead = true }
        } catch {
            print("[NotificationsView] Error marking all read: \(error)")
        }
        nav.refreshUnreadNotificationsCount()
    }

    private func delete(_ notification: AppNotification) async {
        notifications.removeAll { $0.id == notification.id }
        do {
            try await SupabaseService.shared.deleteNotification(notificationId: notification.id)
            AnalyticsService.shared.track("notification_deleted", properties: [
                "notification_id": notification.id.uuidString
            ])
        } catch {
            print("[NotificationsView] Error deleting notification: \(error)")
        }
        nav.refreshUnreadNotificationsCount()
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(notification.isRead ? Color.clear : Color(red: 0.15, green: 0.39, blue: 0.92))
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text(notification.body)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(relativeTime)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var relativeTime: String {
        guard let date = Self.parseTimestamp(notification.createdAt) else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private static func parseTimestamp(_ string: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: string) { return date }
        return ISO8601DateFormatter().date(from: string)
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
    .environmentObject(AppNavigation())
}
