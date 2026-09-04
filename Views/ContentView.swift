import SwiftUI

struct ContentView: View {
    private enum Destination {
        case mainTabs
        case login
    }

    @State private var destination: Destination?

    var body: some View {
        switch destination {
        case .mainTabs:
            MainTabView()
        case .login:
            LoginView()
        case nil:
            SplashView {
                let hasSession = WherartApp.supabase.auth.currentSession != nil
                let isGuest = SupabaseService.shared.isGuestMode
                destination = (hasSession || isGuest) ? .mainTabs : .login
            }
        }
    }
}

#Preview {
    ContentView()
}
