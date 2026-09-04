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
                        NotificationsView()
                    }
                }
            }
            .tabItem {
                Label(String(localized: "notifications"), systemImage: "bell.fill")
            }
            .badge(nav.unreadNotificationsCount)
            .tag(3)

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
            .tag(4)
        }
        .tint(Color(red: 0.15, green: 0.39, blue: 0.92))
        .environmentObject(nav)
        // Visits, Notifications and Profile are entirely account-only in
        // guest mode — tapping any of them surfaces the login prompt over
        // the placeholder content above, rather than mounting views that
        // expect a signed-in user.
        .onChange(of: nav.selectedTab) { newTab in
            let tabNames = ["home", "map", "visits", "notifications", "profile"]
            if newTab < tabNames.count {
                AnalyticsService.shared.track("tab_clicked", properties: ["tab": tabNames[newTab]])
            }

            if service.isGuestMode && (2...4).contains(newTab) {
                showLoginPrompt = true
            }
        }
        .task {
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
