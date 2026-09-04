import SwiftUI

struct ContentView: View {
    @State private var isReady = false

    var body: some View {
        if isReady {
            if WherartApp.supabase.auth.currentSession != nil {
                MainTabView()
            } else if SupabaseService.shared.isGuestMode {
                MainTabView()
            } else {
                LoginView()
            }
        } else {
            SplashView {
                isReady = true
            }
        }
    }
}

#Preview {
    ContentView()
}
