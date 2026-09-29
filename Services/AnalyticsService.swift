import Foundation
import UIKit
import PostHog

final class AnalyticsService {
    static let shared = AnalyticsService()
    private var isConfigured = false

    // Calls made before configure() (e.g. a cold-start deep link handled
    // before WherartApp's .task runs, or restoreSession's identify()) are
    // held here as closures and replayed, in order, once PostHog is set up.
    // Every public method funnels through perform(_:) so none of them can
    // silently no-op before setup — track() used to be the only one
    // protected this way; identify/screen/reset/updateUserProperties had
    // their own early `guard isConfigured else { return }` that just
    // dropped the call.
    private let lock = NSLock()
    private var pendingActions: [() -> Void] = []
    private static let maxPendingActions = 100

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

        lock.lock()
        isConfigured = true
        let queued = pendingActions
        pendingActions.removeAll()
        lock.unlock()

        for action in queued {
            action()
        }
    }

    /// Runs `action` immediately once configured, otherwise queues it (up
    /// to maxPendingActions, to bound memory if configure() never runs).
    private func perform(_ action: @escaping () -> Void) {
        lock.lock()
        if !isConfigured {
            if pendingActions.count < Self.maxPendingActions {
                pendingActions.append(action)
            }
            lock.unlock()
            return
        }
        lock.unlock()

        action()
    }

    func track(
        _ event: String,
        properties: [String: Any]? = nil
    ) {
        perform {
            if let properties = properties {
                PostHogSDK.shared.capture(event, properties: properties)
            } else {
                PostHogSDK.shared.capture(event)
            }
        }
    }

    func identify(
        userId: String,
        properties: [String: Any]? = nil
    ) {
        perform {
            PostHogSDK.shared.identify(userId, userProperties: properties)
        }
    }

    func screen(_ name: String) {
        perform {
            PostHogSDK.shared.screen(name)
        }
    }

    func reset() {
        perform {
            PostHogSDK.shared.reset()
        }
    }

    func updateUserProperties(
        _ properties: [String: Any]
    ) {
        perform {
            PostHogSDK.shared.register(properties)
        }
    }

    func trackError(
        domain: String,
        code: Int,
        message: String,
        context: [String: Any]? = nil
    ) {
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
        // Note: PostHog iOS SDK gère automatiquement les alias via identify()
        // L'alias guest → userId est implicite quand on appelle identify() avec un nouvel ID
        track("guest_converted_to_user", properties: [
            "previous_distinct_id": distinctId,
            "new_user_id": userId
        ])
    }
}
