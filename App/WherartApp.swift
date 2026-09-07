import SwiftUI
import Supabase
import UserNotifications
import GoogleSignIn

@main
struct WherartApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: "491672411506-d24eengmk6605ksmg19qedg0q5m3m0at.apps.googleusercontent.com")
    }

    static let supabase = SupabaseClient(
        supabaseURL: Config.supabaseURL,
        supabaseKey: Config.supabaseAnonKey,
        options: .init(
            auth: .init(
                autoRefreshToken: true,
                emitLocalSessionAsInitialSession: true
            )
        )
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                // For a scene-lifecycle SwiftUI app, Universal Link
                // continuation can be delivered to the scene rather than
                // (or instead of) UIApplicationDelegate's
                // application(_:continue:restorationHandler:) below — that
                // method's own diagnostic print never fired in testing
                // despite the link demonstrably opening the app (no Safari
                // page shown), which is exactly this scene-vs-app-delegate
                // routing gap. This modifier is SwiftUI's own recommended,
                // scene-native way to receive it, so it's the reliable
                // primary path; the AppDelegate method stays as a fallback.
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    print("[WherartApp] onContinueUserActivity fired, webpageURL: \(userActivity.webpageURL?.absoluteString ?? "nil")")
                    handleUniversalLink(userActivity)
                }
                .task {
                    AnalyticsService.shared.configure()
                    await NotificationService.shared.requestPermission()
                    await EndingSoonService.shared.requestNotificationPermission()
                    // Checked once per launch rather than on a recurring
                    // Timer — a Timer here previously caused an
                    // AttributeGraph cycle (see startReminderCheck below).
                    await EndingSoonService.shared.checkAndSendReminders()
                    await NewExhibitionsService.shared.checkAndSendNewExhibitions()
                    // Refresh the app icon badge with however many
                    // notifications are still unread — the two checks above
                    // may have just added new ones. MainTabView's own
                    // `AppNavigation.refreshUnreadNotificationsCount()` keeps
                    // the in-app tab/Profile badges in sync separately.
                    if let count = try? await SupabaseService.shared.getUnreadNotificationCount() {
                        await MainActor.run {
                            UIApplication.shared.applicationIconBadgeNumber = count
                        }
                    }
                    // ⏸️ TEMPORARILY DISABLED - caused AttributeGraph cycle
                    // startReminderCheck()
                }
        }
    }

    /*
    private func startReminderCheck() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                await EndingSoonService.shared.checkAndSendReminders()
            }
        }
    }
    */
}

/// Shared by both the `.onContinueUserActivity` SwiftUI modifier (the
/// primary path) and AppDelegate's `application(_:continue:restorationHandler:)`
/// (kept as a fallback) — see WherartApp.body for why both exist.
func handleUniversalLink(_ userActivity: NSUserActivity) {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else {
        return
    }

    if url.path == "/reset-password" {
        print("[handleUniversalLink] reset-password detected, full URL: \(url.absoluteString)")
        DispatchQueue.main.async {
            DeepLinkRouter.shared.pendingPasswordRecoveryURL = url
            print("[handleUniversalLink] pendingPasswordRecoveryURL set to: \(DeepLinkRouter.shared.pendingPasswordRecoveryURL?.absoluteString ?? "nil")")
        }
        return
    }

    let pathComponents = url.pathComponents // e.g. ["/", "e", "123"]
    guard let eIndex = pathComponents.firstIndex(of: "e"),
          pathComponents.count > eIndex + 1,
          let exhibitionId = Int(pathComponents[eIndex + 1]) else {
        return
    }
    DispatchQueue.main.async {
        DeepLinkRouter.shared.pendingExhibitionId = exhibitionId
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = EndingSoonService.shared
        return true
    }

    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // TEMP DIAGNOSTIC — remove once the reset-password deep link is
        // confirmed working end to end.
        print("[AppDelegate] Received deep link: \(url.scheme ?? "nil")://\(url.host ?? "nil")?query=\(url.query ?? "nil")")

        if url.scheme == "wherart", url.host == "reset-password" {
            print("[AppDelegate] ✅ Reset password deep link detected — setting pendingPasswordRecoveryURL")
            print("[AppDelegate] Full URL: \(url.absoluteString)")
            DispatchQueue.main.async {
                DeepLinkRouter.shared.pendingPasswordRecoveryURL = url
                print("[AppDelegate] pendingPasswordRecoveryURL set to: \(DeepLinkRouter.shared.pendingPasswordRecoveryURL?.absoluteString ?? "nil")")
            }
            return true
        }

        print("[AppDelegate] URL is not wherart://reset-password, delegating to Google Sign In")
        return GIDSignIn.sharedInstance.handle(url)
    }

    /// Universal Link entry point (https://wherart.com/e/{id}) — reached
    /// only when the app is already installed; iOS intercepts the tap at
    /// the OS level using the cached apple-app-site-association file and
    /// never touches the web fallback in that case. Reuses DeepLinkRouter,
    /// the same mechanism EndingSoonService already uses for notification
    /// taps, so MainTabView/HomeView's existing observation of it handles
    /// the navigation without any new plumbing there.
    /// Fallback path — see WherartApp.body's `.onContinueUserActivity` for
    /// why the SwiftUI modifier is the primary one now. Kept in case some
    /// launch scenario still routes through the app delegate instead of
    /// the scene.
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        print("[AppDelegate] continue userActivity called (fallback path), activityType: \(userActivity.activityType), webpageURL: \(userActivity.webpageURL?.absoluteString ?? "nil")")
        handleUniversalLink(userActivity)
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[APNs] Device token: \(token)")
    }
}
