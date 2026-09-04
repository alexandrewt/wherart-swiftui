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

    private init() {}
}
