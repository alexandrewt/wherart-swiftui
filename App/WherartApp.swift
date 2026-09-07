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
                // .onOpenURL is SwiftUI's unified handler for BOTH custom
                // URL schemes and Universal Links (it's fed from both
                // scene(_:openURLContexts:) and scene(_:continue:)
                // internally) — simpler and more reliably wired up by
                // SwiftUI itself than either UIApplicationDelegate method
                // or .onContinueUserActivity, neither of which ever fired
                // in testing despite the link demonstrably opening the app.
                .onOpenURL { url in
                    print("[WherartApp] onOpenURL fired: \(url.absoluteString)")
                    handleIncomingURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    print("[WherartApp] onContinueUserActivity fired, webpageURL: \(userActivity.webpageURL?.absoluteString ?? "nil")")
                    if let url = userActivity.webpageURL {
                        handleIncomingURL(url)
                    }
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

/// Shared handler for any incoming URL — custom scheme (wherart://) or
/// Universal Link (https://wherart.com/...) — regardless of which of the
/// several entry points (.onOpenURL, .onContinueUserActivity, AppDelegate's
/// application(_:open:)/application(_:continue:restorationHandler:))
/// actually received it. Both /e/{id} and /reset-password paths work the
/// same way whether they arrive as a URL path (https) or a host (custom
/// scheme, e.g. wherart://reset-password), which is why both are checked.
func handleIncomingURL(_ url: URL) {
    print("[handleIncomingURL] \(url.absoluteString)")

    if url.path == "/reset-password" || url.host == "reset-password" {
        print("[handleIncomingURL] reset-password detected")
        DispatchQueue.main.async {
            DeepLinkRouter.shared.pendingPasswordRecoveryURL = url
            print("[handleIncomingURL] pendingPasswordRecoveryURL set to: \(DeepLinkRouter.shared.pendingPasswordRecoveryURL?.absoluteString ?? "nil")")
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

    /// Fallback path — see WherartApp.body's `.onOpenURL`, which is the
    /// primary handler now (both this and it call the same
    /// handleIncomingURL(_:)). Google Sign In's own callback still only
    /// arrives here, never through SwiftUI's modifiers, so this stays.
    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        print("[AppDelegate] application(_:open:) fired (fallback path): \(url.absoluteString)")

        if url.scheme == "wherart", url.host == "reset-password" {
            handleIncomingURL(url)
            return true
        }

        return GIDSignIn.sharedInstance.handle(url)
    }

    /// Fallback path — see WherartApp.body's `.onContinueUserActivity`/
    /// `.onOpenURL`, which are the primary handlers now. Kept in case some
    /// launch scenario still routes through the app delegate instead of
    /// the scene.
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        print("[AppDelegate] continue userActivity called (fallback path), activityType: \(userActivity.activityType), webpageURL: \(userActivity.webpageURL?.absoluteString ?? "nil")")
        if let url = userActivity.webpageURL {
            handleIncomingURL(url)
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
