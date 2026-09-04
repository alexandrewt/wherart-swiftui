import Foundation
import UIKit
import UserNotifications
import Supabase

/// "New exhibitions matching your taste" — a daily digest notification,
/// capped once per 24h per user (tracked in `new_exhibitions_notifications`,
/// see SupabaseService). Checked once per app launch alongside
/// EndingSoonService.checkAndSendReminders() (see WherartApp's .task) —
/// there's no reliable way to run at an exact wall-clock time (8 AM) without
/// BGTaskScheduler, which needs its own capability/Info.plist entry and is
/// still only opportunistic, so this schedules the local notification itself
/// for the next 8 AM rather than firing immediately.
final class NewExhibitionsService {

    static let shared = NewExhibitionsService()

    private init() {}

    func checkAndSendNewExhibitions() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }

        do {
            let canSend = try await SupabaseService.shared.shouldSendNewExhibitionsNotification(userId: userId)
            guard canSend else { return }

            let newExhibitions = try await SupabaseService.shared.getNewExhibitionsForUser(userId: userId)
            guard !newExhibitions.isEmpty else { return }

            let count = newExhibitions.count
            let title = "✨ \(count) new exhibition\(count > 1 ? "s" : "")"
            let firstExhibitionName = newExhibitions.first?.title ?? "New exhibitions"
            let body = firstExhibitionName + (count > 1 ? " + \(count - 1) more" : "")

            await scheduleNextMorningNotification(
                title: title,
                body: body,
                userInfo: [
                    "type": "new_exhibitions",
                    "count": count,
                    "exhibition_ids": newExhibitions.map { $0.id }
                ]
            )

            try await SupabaseService.shared.markNewExhibitionsNotificationSent(userId: userId)

            AnalyticsService.shared.track("new_exhibitions_notification_sent", properties: [
                "count": count,
                "exhibition_ids": newExhibitions.map { String($0.id) }
            ])
        } catch {
            print("[NewExhibitions] Error: \(error)")
        }
    }

    /// Schedules a one-shot local notification for 8 AM the next time that
    /// hour occurs (today if it hasn't passed yet, otherwise tomorrow) —
    /// `UNCalendarNotificationTrigger` with only hour/minute set and
    /// `repeats: false` fires at the next matching time automatically.
    private func scheduleNextMorningNotification(
        title: String,
        body: String,
        userInfo: [AnyHashable: Any]
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.userInfo = userInfo

        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("[NewExhibitions] Notification scheduled for next 8 AM")
        } catch {
            print("[NewExhibitions] Failed to schedule notification: \(error)")
        }
    }
}
