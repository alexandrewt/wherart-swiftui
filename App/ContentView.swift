import SwiftUI
import Auth

struct ContentView: View {

    private var service: SupabaseService { SupabaseService.shared }
    @State private var needsOnboarding = false
    @State private var isCheckingProfile = false
    @State private var isInitializing = true  // ← nouveau
    @State private var showSplash = true

    /// Same lookup `ExhibitionDetailView`/`MapView` etc. would each otherwise
    /// need on their own — done once here so every screen gets a solid
    /// status bar background without having to opt in individually.
    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 59
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if isInitializing || isCheckingProfile {
                    // Écran de splash pendant la restauration de session et la
                    // vérification du profil — même fond que les deux états pour
                    // éviter le flash blanc→noir au lancement.
                    ZStack {
                        Color(.systemBackground).ignoresSafeArea()
                        ProgressView()
                    }
                } else if service.isAuthenticated {
                    if needsOnboarding, let userId = service.currentUser?.id.uuidString {
                        OnboardingView(userId: userId) {
                            needsOnboarding = false
                        }
                    } else {
                        MainTabView()
                    }
                } else if service.isGuestMode {
                    // Guest mode skips onboarding entirely — it's tied to account
                    // creation (preferences are stored on the profile row), which
                    // doesn't exist for a guest.
                    MainTabView()
                } else if showSplash {
                    // Only shown for signed-out users — someone restoring an
                    // authenticated session lands straight in MainTabView above,
                    // never through here.
                    SplashView(onComplete: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSplash = false
                        }
                    })
                    .transition(.opacity)
                } else {
                    LoginView()
                        .transition(.opacity)
                }
            }
            .onChange(of: service.hasRestoredSession) { restored in
                if restored {
                    isInitializing = false
                }
            }
            .onChange(of: service.isAuthenticated) { authenticated in
                if isInitializing {
                    isInitializing = false
                }
                if authenticated {
                    checkOnboardingStatus()
                }
            }
            .onAppear {
                if service.hasRestoredSession {
                    isInitializing = false
                }
                // Safety-net timeout in case Supabase never responds (e.g. no network) —
                // the real signal is `hasRestoredSession` above, which fires as soon as
                // the explicit session-restoration check completes.
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    if isInitializing {
                        isInitializing = false
                    }
                }
            }
            .task {
                // Warm up StoreKit products early so the paywall/subscribe page
                // never has to show a loading state on first open.
                await StoreService.shared.loadProducts()
            }

            // Permanent white status bar background across every screen —
            // sits above all content, including hero images/maps that
            // extend behind the status bar, so no per-screen fix is needed.
            Color(.systemBackground)
                .frame(height: safeAreaTop)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
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
