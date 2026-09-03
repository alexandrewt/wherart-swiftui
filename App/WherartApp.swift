import SwiftUI
import Supabase

@main
struct WherartApp: App {
    
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
                }
        }
    }
}
