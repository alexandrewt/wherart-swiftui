import SwiftUI
import Supabase

@main
struct WherartApp: App {
    
    static let supabase = SupabaseClient(
        supabaseURL: Config.supabaseURL,
        supabaseKey: Config.supabaseAnonKey
    )
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
