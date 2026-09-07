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
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        // TEMP DIAGNOSTIC
        print("[AppDelegate] continue userActivity called, activityType: \(userActivity.activityType), webpageURL: \(userActivity.webpageURL?.absoluteString ?? "nil")")
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }

        // Password reset — see SupabaseService.resetPassword's redirectTo.
        // Reuses the exact same pendingPasswordRecoveryURL/ResetPasswordView
        // plumbing the old wherart://reset-password custom scheme drove;
        // only how the link reaches the app changed.
        if url.path == "/reset-password" {
            print("[AppDelegate] Universal Link: reset-password detected, full URL: \(url.absoluteString)")
            DispatchQueue.main.async {
                DeepLinkRouter.shared.pendingPasswordRecoveryURL = url
                print("[AppDelegate] pendingPasswordRecoveryURL set to: \(DeepLinkRouter.shared.pendingPasswordRecoveryURL?.absoluteString ?? "nil")")
            }
            return true
        }

        let pathComponents = url.pathComponents // e.g. ["/", "e", "123"]
        guard let eIndex = pathComponents.firstIndex(of: "e"),
              pathComponents.count > eIndex + 1,
              let exhibitionId = Int(pathComponents[eIndex + 1]) else {
            return false
        }
        DispatchQueue.main.async {
            DeepLinkRouter.shared.pendingExhibitionId = exhibitionId
        }
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
