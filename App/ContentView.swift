import SwiftUI
import Auth
import Supabase

struct ContentView: View {

    @ObservedObject private var service = SupabaseService.shared
    @ObservedObject private var deepLinkRouter = DeepLinkRouter.shared
    @State private var needsOnboarding = false
    @State private var isCheckingProfile = false
    @State private var isInitializing = true  // ← nouveau
    @State private var showSplash = true

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
        }
        // Shown over whatever's currently on screen — signed in, signed
        // out, mid-onboarding, doesn't matter. Tapping the reset-password
        // email link can happen from any of those states. `URL` isn't
        // Identifiable, so this drives the cover off a derived Bool
        // binding rather than `fullScreenCover(item:)`.
        .fullScreenCover(isPresented: Binding(
            get: {
                let isSet = deepLinkRouter.pendingPasswordRecoveryURL != nil
                return isSet
            },
            set: { if !$0 { deepLinkRouter.pendingPasswordRecoveryURL = nil } }
        )) {
            if let url = deepLinkRouter.pendingPasswordRecoveryURL {
                ResetPasswordView(recoveryURL: url) {
                    deepLinkRouter.pendingPasswordRecoveryURL = nil
                }
            }
        }
        // TEMP DIAGNOSTIC
        .onChange(of: deepLinkRouter.pendingPasswordRecoveryURL) { newValue in
            print("[ContentView] pendingPasswordRecoveryURL changed to: \(newValue?.absoluteString ?? "nil")")
        }
        // Note: a global "white status bar" overlay was tried here and
        // confirmed NOT to work against views that themselves extend
        // content under the top safe area (e.g. a full-bleed MKMapView) —
        // that content renders through it regardless of ZStack order. Each
        // screen that needs to go edge-to-edge must scope its own
        // .ignoresSafeArea() to exclude .top (see MapView), or otherwise
        // provide its own opaque covering, rather than relying on a
        // catch-all here.
    }

    private func checkOnboardingStatus() {
        guard let userId = service.currentUser?.id.uuidString else { return }
        isCheckingProfile = true
        Task {
            var lastError: Error?
            // Up to 5 attempts, 400ms apart (~2s total) — only for a "0
            // rows" result, see below.
            for attempt in 0..<5 {
                do {
                    let profile = try await SupabaseService.shared.fetchProfile(userId: userId)
                    await MainActor.run {
                        needsOnboarding = profile.preferences.isEmpty
                        isCheckingProfile = false
                    }
                    return
                } catch {
                    lastError = error
                    // A brand-new Apple/Google/email sign-up's profile row
                    // is written by a concurrent upsert inside
                    // signInWithApple/signInWithGoogle/signUp — but
                    // `isAuthenticated` (which triggers this check) is
                    // flipped by SupabaseService's independent
                    // listenToAuthChanges() loop as soon as the auth
                    // session itself exists, with no ordering guarantee
                    // relative to that upsert. For a genuinely brand-new
                    // user this races the profile row's very creation:
                    // fetchProfile can see "0 rows" (PGRST116) before the
                    // row exists at all. Retry briefly rather than
                    // treating that as "no onboarding needed" — which
                    // previously skipped onboarding entirely for new
                    // Apple/Google accounts.
                    let isMissingRow = (error as? PostgrestError)?.code == "PGRST116"
                    guard isMissingRow, attempt < 4 else { break }
                    try? await Task.sleep(nanoseconds: 400_000_000)
                }
            }
            // Any other error (or the row still missing after retrying) —
            // don't force needsOnboarding = true here: a transient network
            // hiccup on an already fully set-up returning user would
            // otherwise wrongly bounce them back to onboarding every time
            // the app relaunches. Fails open to MainTabView instead of
            // trapping the user on a stuck check.
            print("[ContentView] Failed to fetch profile for onboarding check: \(String(describing: lastError))")
            await MainActor.run {
                isCheckingProfile = false
            }
        }
    }
}

#Preview {
    ContentView()
}
