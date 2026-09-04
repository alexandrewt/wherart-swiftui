import SwiftUI
import Combine

final class AppNavigation: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var visitsDefaultTab: Int = 0
    @Published var showSubscribe: Bool = false
    // Single source of truth for the unread notifications badge — shared
    // by the tab bar icon, ProfileView's "Notifications" row, and the app
    // icon badge, so marking/deleting a notification anywhere updates all
    // three at once instead of drifting independently.
    @Published var unreadNotificationsCount: Int = 0

    func refreshUnreadNotificationsCount() {
        Task {
            let count = (try? await SupabaseService.shared.getUnreadNotificationCount()) ?? 0
            await MainActor.run {
                self.unreadNotificationsCount = count
                UIApplication.shared.applicationIconBadgeNumber = count
            }
        }
    }
}

// MARK: - MainTabView
struct MainTabView: View {

    @StateObject private var nav = AppNavigation()
    private var service: SupabaseService { SupabaseService.shared }
    @State private var showLoginPrompt = false
    @ObservedObject private var deepLinkRouter = DeepLinkRouter.shared

    var body: some View {
        TabView(selection: $nav.selectedTab) {

            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label(String(localized: "home"), systemImage: "house.fill")
            }
            .tag(0)

            NavigationStack {
                MapView()
            }
            .tabItem {
                Label(String(localized: "map_tab"), systemImage: "map.fill")
            }
            .tag(1)

            Group {
                if service.isGuestMode {
                    GuestGateView()
                } else {
                    VisitView(defaultTab: $nav.visitsDefaultTab)
                }
            }
            .tabItem {
                Label(String(localized: "visits"), systemImage: "person.2.fill")
            }
            .tag(2)

            Group {
                if service.isGuestMode {
                    GuestGateView()
                } else {
                    NavigationStack {
                        ProfileView()
                    }
                }
            }
            .tabItem {
                Label(String(localized: "profile_tab"), systemImage: "person.fill")
            }
            .badge(nav.unreadNotificationsCount)
            .tag(3)
        }
        .tint(Color(red: 0.15, green: 0.39, blue: 0.92))
        .environmentObject(nav)
        // Visits and Profile are entirely account-only in guest mode — tapping
        // either tab surfaces the login prompt over the placeholder content
        // above, rather than mounting views that expect a signed-in user.
        // Notifications is reached only from ProfileView's own "Notifications"
        // row (pushed full-screen), not from a tab — there's no separate tab
        // bar icon for it.
        .onChange(of: nav.selectedTab) { newTab in
            let tabNames = ["home", "map", "visits", "profile"]
            if newTab < tabNames.count {
                AnalyticsService.shared.track("tab_clicked", properties: ["tab": tabNames[newTab]])
            }

            if service.isGuestMode && (newTab == 2 || newTab == 3) {
                showLoginPrompt = true
            }

            // ProfileView's own `.task` only runs once per view identity, so
            // switching back to an already-mounted Profile tab wouldn't
            // otherwise pick up a notification read/deleted while on another
            // tab — refresh explicitly whenever Profile becomes active.
            if !service.isGuestMode && newTab == 3 {
                nav.refreshUnreadNotificationsCount()
            }
        }
        .task {
            if !service.isGuestMode {
                nav.refreshUnreadNotificationsCount()
            }
        }
        // Covers the case a notification arrived (or was acted on elsewhere,
        // e.g. from a notification banner) while the app was backgrounded —
        // without this the badge would only catch up on the next tab switch.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if !service.isGuestMode {
                nav.refreshUnreadNotificationsCount()
            }
        }
        .sheet(isPresented: $showLoginPrompt) {
            LoginPromptSheet()
        }
        // Tapping an Ending Soon notification sets this from anywhere in
        // the app (even the background) — jump to Home so HomeView's own
        // observation of the same router can fetch and push that
        // exhibition via its navigationDestination(item:). Checked both on
        // appear (cold launch from tapping the notification — the router
        // already has the value by the time this view first renders, so
        // onChange alone would never fire) and on change (app already
        // running in the background when the notification is tapped).
        .onAppear {
            if deepLinkRouter.pendingExhibitionId != nil {
                nav.selectedTab = 0
            }
        }
        .onChange(of: deepLinkRouter.pendingExhibitionId) { exhibitionId in
            if exhibitionId != nil {
                nav.selectedTab = 0
            }
        }
    }
}

#Preview {
    MainTabView()
}
