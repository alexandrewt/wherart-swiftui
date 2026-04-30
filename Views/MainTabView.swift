import SwiftUI

struct MainTabView: View {

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            NavigationStack {
                MapView()
            }
            .tabItem {
                Label("Map", systemImage: "map.fill")
            }
            .tag(1)

            VisitView()
                .tabItem {
                    Label("Visits", systemImage: "person.2.fill")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MainTabView()
}
