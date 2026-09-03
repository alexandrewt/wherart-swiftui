import SwiftUI

struct ContentView: View {
    @State private var isSessionLoading = true
    @State private var sessionTimeout: Timer?

    var body: some View {
        ZStack {
            if isSessionLoading {
                SplashView()
            } else {
                if WherartApp.supabase.auth.currentSession != nil {
                    MainTabView()
                } else if SupabaseService.shared.isGuestMode {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
        }
        .onAppear {
            checkSession()
        }
    }

    private func checkSession() {
        sessionTimeout = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            print("[ContentView] Session timeout - forcing load")
            isSessionLoading = false
        }

        Task {
            await Task.sleep(500_000_000)

            await MainActor.run {
                sessionTimeout?.invalidate()
                isSessionLoading = false
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("Wherart")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))

                Text("Curated for you, enjoyed together")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Spacer()

                ProgressView()
                    .tint(Color(red: 0.15, green: 0.39, blue: 0.92))

                Spacer()
            }
        }
    }
}

#Preview {
    ContentView()
}
