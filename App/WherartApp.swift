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
                // internally) — confirmed via testing as the one reliable
                // entry point; AppDelegate's application(_:continue:
                // restorationHandler:) and .onContinueUserActivity below
                // never fired even once, on either the reset-password or
                // exhibition share Universal Link, despite both
                // demonstrably opening the app with no Safari page shown
                // in between. Kept as fallbacks regardless — cheap, and
                // there's no real downside to also handling the activity
                // if some other launch path ever does route through them.
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
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
    // Several entry points can deliver the same URL — see above.
    let dedupKey = url.absoluteString
    if dedupKey == lastHandledURL, Date().timeIntervalSince(lastHandledURLDate) < 2 { return }
    lastHandledURL = dedupKey
    lastHandledURLDate = Date()

    // Never include the URL itself: the reset-password link carries a token.
    let source = url.scheme == "wherart" ? "url_scheme" : "universal_link"

    if url.path == "/reset-password" || url.host == "reset-password" {
        AnalyticsService.shared.track("deep_link_opened", properties: [
            "type": "reset_password",
            "source": source
        ])
        DispatchQueue.main.async {
            DeepLinkRouter.shared.pendingPasswordRecoveryURL = url
        }
        return
    }

    let pathComponents = url.pathComponents // e.g. ["/", "e", "123"]
    guard let eIndex = pathComponents.firstIndex(of: "e"),
          pathComponents.count > eIndex + 1,
          let exhibitionId = Int(pathComponents[eIndex + 1]) else {
        return
    }
    AnalyticsService.shared.track("deep_link_opened", properties: [
        "type": "exhibition",
        "source": source,
        "exhibition_id": exhibitionId
    ])
    DispatchQueue.main.async {
        DeepLinkRouter.shared.pendingExhibitionId = exhibitionId
    }
}

private var lastHandledURL: String?
private var lastHandledURLDate = Date.distantPast

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
