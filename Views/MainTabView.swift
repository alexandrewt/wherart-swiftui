import SwiftUI
import Combine

final class AppNavigation: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var visitsDefaultTab: Int = 0
    @Published var showSubscribe: Bool = false
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
            .tag(3)
        }
        .tint(Color(red: 0.15, green: 0.39, blue: 0.92))
        .environmentObject(nav)
        // Visits and Profile are entirely account-only in guest mode — tapping
        // either tab surfaces the login prompt over the placeholder content
        // above, rather than mounting views that expect a signed-in user.
        .onChange(of: nav.selectedTab) { newTab in
            let tabNames = ["home", "map", "visits", "profile"]
            if newTab < tabNames.count {
                AnalyticsService.shared.track("tab_clicked", properties: ["tab": tabNames[newTab]])
            }

            if service.isGuestMode && (newTab == 2 || newTab == 3) {
                showLoginPrompt = true
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
