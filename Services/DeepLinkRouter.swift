import Foundation
import Combine

/// Bridges tapping a local notification (handled by
/// EndingSoonService.userNotificationCenter(didReceive:), which runs
/// outside the SwiftUI view hierarchy) to actually navigating to the
/// relevant exhibition. MainTabView observes `pendingExhibitionId` to
/// switch to the Home tab, and HomeView observes it to fetch that
/// exhibition and push it via its existing navigationDestination(item:).
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    @Published var pendingExhibitionId: Int?

    /// Set from WherartApp's `application(_:open:)` when a
    /// "wherart://reset-password?..." link is opened (from the password
    /// reset email). ContentView observes this to present ResetPasswordView
    /// regardless of the current auth state — the user may well be signed
    /// out entirely when tapping the link.
    @Published var pendingPasswordRecoveryURL: URL?

    private init() {}
}
