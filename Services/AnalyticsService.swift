import Foundation
import PostHog

final class AnalyticsService {
    static let shared = AnalyticsService()
    private var isConfigured = false

    private init() {}

    func configure() {
        let config = PostHogConfig(apiKey: Config.postHogAPIKey, host: Config.postHogHost)
        config.captureScreenViews = true
        PostHogSDK.shared.setup(config)
        isConfigured = true
    }

    func track(
        _ event: String,
        properties: [String: Any]? = nil
    ) {
        guard isConfigured else { return }

        if let properties = properties {
            PostHogSDK.shared.capture(event, properties: properties)
        } else {
            PostHogSDK.shared.capture(event)
        }
    }

    func identify(
        userId: String,
        properties: [String: Any]? = nil
    ) {
        guard isConfigured else { return }

        PostHogSDK.shared.identify(userId, userProperties: properties)
    }

    func screen(_ name: String) {
        guard isConfigured else { return }

        PostHogSDK.shared.screen(name)
    }

    func reset() {
        guard isConfigured else { return }

        PostHogSDK.shared.reset()
    }
}
