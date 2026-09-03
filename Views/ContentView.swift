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
            SplashView()
                .onAppear {
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        await MainActor.run {
                            withAnimation {
                                isReady = true
                            }
                        }
                    }
                }
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(UIColor.systemBackground), Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.04)],
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
