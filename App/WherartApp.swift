import SwiftUI
import Supabase
import UserNotifications
import GoogleSignIn

@main
struct WherartApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: "YOUR_GOOGLE_CLIENT_ID")
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
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[APNs] Device token: \(token)")
    }
}
