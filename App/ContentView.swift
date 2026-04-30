import SwiftUI
import Auth

struct ContentView: View {

    @StateObject private var service = SupabaseService.shared
    @State private var needsOnboarding = false
    @State private var isCheckingProfile = false

    var body: some View {
        Group {
            if service.isAuthenticated {
                if isCheckingProfile {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        ProgressView().tint(.white)
                    }
                } else if needsOnboarding, let userId = service.currentUser?.id.uuidString {
                    OnboardingView(userId: userId) {
                        needsOnboarding = false
                    }
                } else {
                    MainTabView()
                }
            } else {
                LoginView()
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: service.isAuthenticated) { authenticated in
            if authenticated {
                checkOnboardingStatus()
            }
        }
        .onAppear {
            if service.isAuthenticated {
                checkOnboardingStatus()
            }
        }
    }

    private func checkOnboardingStatus() {
        guard let userId = service.currentUser?.id.uuidString else { return }
        isCheckingProfile = true
        Task {
            do {
                let profile = try await SupabaseService.shared.fetchProfile(userId: userId)
                await MainActor.run {
                    needsOnboarding = profile.preferences.isEmpty
                    isCheckingProfile = false
                }
            } catch {
                await MainActor.run {
                    needsOnboarding = true
                    isCheckingProfile = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
