import Foundation
import UserNotifications

/// Local notification scheduling for visit reminders and "ending soon"
/// favorites reminders. Uses `UNUserNotificationCenter` only — no APNs /
/// remote push, no backend required. Notifications are scheduled with
/// deterministic identifiers (one per group / exhibition) so re-scheduling
/// on every app launch simply replaces the previous pending notification
/// instead of stacking duplicates, and so callers can cancel a specific one
/// later without having to remember an ID they generated themselves.
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission

    func requestPermission() async {
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    // MARK: - Visit Reminder

    static func visitReminderIdentifier(groupId: Int) -> String {
        "visit-reminder-\(groupId)"
    }

    /// Schedules a local notification 24h before `group`'s start date/time.
    /// No-ops if the date can't be parsed, or if that 24h-before point has
    /// already passed.
    ///
    /// `WherartGroup` doesn't carry the exhibition's title (only its id), so
    /// callers that already have the `Exhibition` loaded (as `VisitDetailView`
    /// does) can pass it in for the notification body; otherwise this falls
    /// back to the visit's own name.
    func scheduleVisitReminder(for group: WherartGroup, exhibitionTitle: String? = nil) {
        guard let startDate = Self.visitStartDate(from: group) else { return }
        let reminderDate = startDate.addingTimeInterval(-24 * 60 * 60)
        let interval = reminderDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your visit is tomorrow"
        let titleText = exhibitionTitle ?? group.name
        let timeText = group.time.map { " at \($0)" } ?? ""
        content.body = "\(titleText) — \(group.startDate.formattedVisitDate)\(timeText)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.visitReminderIdentifier(groupId: group.id),
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Ending Soon

    static func endingSoonIdentifier(exhibitionId: Int) -> String {
        "ending-soon-\(exhibitionId)"
    }

    /// Schedules a local notification if `exhibition.endDate` falls within
    /// the next 7 days. Fires the following morning at 9am local time — a
    /// single reasonable heads-up rather than an exact-to-the-second
    /// reminder, since this isn't backend-driven: it's recomputed (and
    /// re-scheduled, replacing any pending notification with the same
    /// identifier) every time the favorites list loads.
    func scheduleEndingSoonNotification(for exhibition: Exhibition) {
        guard let endDateString = exhibition.endDate,
              let endDate = Self.parseDate(endDateString) else { return }

        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? -1
        guard (0...7).contains(daysRemaining) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Ending soon"
        content.body = "\(exhibition.title) closes on \(endDateString.formattedVisitDate). Don't miss it."
        content.sound = .default

        var fireComponents = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: Date().addingTimeInterval(24 * 60 * 60)
        )
        fireComponents.hour = 9
        fireComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: fireComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: Self.endingSoonIdentifier(exhibitionId: exhibition.id),
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Cancellation

    /// Cancels a pending notification — e.g. when the user leaves a visit
    /// (`visitReminderIdentifier(groupId:)`) or removes a favorite
    /// (`endingSoonIdentifier(exhibitionId:)`).
    func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Date Parsing

    private static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    private static func visitStartDate(from group: WherartGroup) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let time = group.time, !time.isEmpty {
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter.date(from: "\(group.startDate) \(time)")
        }
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: group.startDate)
    }
}
