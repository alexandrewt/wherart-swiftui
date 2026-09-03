import Foundation

final class AnalyticsService {
    static let shared = AnalyticsService()

    private init() {}

    func configure() {
        // PostHog removed due to linker issues
    }

    func track(_ event: String, properties: [String: Any]? = nil) {
        // No-op
    }

    func identify(userId: String, properties: [String: Any]? = nil) {
        // No-op
    }

    func screen(_ name: String) {
        // No-op
    }

    func reset() {
        // No-op
    }

    func updateUserProperties(_ properties: [String: Any]) {
        // No-op
    }

    func trackError(
        domain: String,
        code: Int,
        message: String,
        context: [String: Any]? = nil
    ) {
        // No-op
    }

    func createAlias(distinctId: String, userId: String) {
        // No-op
    }
}
