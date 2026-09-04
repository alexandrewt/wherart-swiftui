import Foundation
import UIKit
import PostHog

final class AnalyticsService {
    static let shared = AnalyticsService()
    private var isConfigured = false

    private init() {}

    func configure() {
        let config = PostHogConfig(apiKey: Config.postHogAPIKey, host: Config.postHogHost)
        config.captureScreenViews = true
        PostHogSDK.shared.setup(config)

        // Register super properties (context automatiquement ajouté à chaque événement)
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

        PostHogSDK.shared.register([
            "app_version": appVersion,
            "build_number": buildNumber,
            "device_type": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion,
            "app_locale": Locale.current.identifier
        ])

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

    func updateUserProperties(
        _ properties: [String: Any]
    ) {
        guard isConfigured else { return }

        PostHogSDK.shared.register(properties)
    }

    func trackError(
        domain: String,
        code: Int,
        message: String,
        context: [String: Any]? = nil
    ) {
        guard isConfigured else { return }

        var properties: [String: Any] = [
            "error_domain": domain,
            "error_code": code,
            "error_message": message,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        if let context = context {
            properties.merge(context) { _, new in new }
        }

        track("api_error", properties: properties)
    }

    func createAlias(
        distinctId: String,
        userId: String
    ) {
        guard isConfigured else { return }

        // Note: PostHog iOS SDK gère automatiquement les alias via identify()
        // L'alias guest → userId est implicite quand on appelle identify() avec un nouvel ID
        track("guest_converted_to_user", properties: [
            "previous_distinct_id": distinctId,
            "new_user_id": userId
        ])
    }
}
