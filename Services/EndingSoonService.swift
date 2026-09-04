import Foundation
import UserNotifications
import UIKit
import Supabase

class EndingSoonService: NSObject {

    static let shared = EndingSoonService()
    private let supabase = WherartApp.supabase

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Demander la permission APNs au premier lancement
    func requestNotificationPermission() async {
        do {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            print("[EndingSoon] Permission denied: \(error)")
        }
    }

    // MARK: - Calculer les jours restants pour une exposition
    func daysRemaining(for exhibition: Exhibition) -> Int {
        guard let endDateString = exhibition.endDate,
              let endDate = Self.parseDate(endDateString) else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return max(0, components.day ?? 0)
    }

    // MARK: - Calculer le seuil de rappel en jours
    func reminderThresholdDays(
        for exhibition: Exhibition,
        userThresholdPercent: Int
    ) -> Int {
        guard let endDateString = exhibition.endDate,
              let endDate = Self.parseDate(endDateString) else { return 0 }

        let startDate = Date()
        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1
        let thresholdDays = max(1, (totalDays * userThresholdPercent) / 100)

        return thresholdDays
    }

    // MARK: - Vérifier si un utilisateur doit être notifié
    func shouldSendReminder(
        userId: String,
        exhibitionId: Int
    ) async -> Bool {
        do {
            struct ReminderParams: Encodable {
                let p_user_id: String
                let p_exhibition_id: Int
            }

            let params = ReminderParams(p_user_id: userId, p_exhibition_id: exhibitionId)
            let response: [Bool] = try await supabase
                .rpc("should_send_exhibition_reminder", params: params)
                .execute()
                .value

            return response.first ?? false
        } catch {
            print("[EndingSoon] Error checking reminder: \(error)")
            return false
        }
    }

    // MARK: - Envoyer une notification locale APNs
    func sendLocalNotification(
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

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("[EndingSoon] Notification sent: \(title)")
        } catch {
            print("[EndingSoon] Failed to send notification: \(error)")
        }
    }

    // MARK: - Marquer une reminder comme envoyée
    func markReminderSent(
        userId: String,
        exhibitionId: Int
    ) async {
        do {
            struct ReminderParams: Encodable {
                let p_user_id: String
                let p_exhibition_id: Int
            }

            let params = ReminderParams(p_user_id: userId, p_exhibition_id: exhibitionId)
            try await supabase
                .rpc("mark_reminder_sent", params: params)
                .execute()
            print("[EndingSoon] Reminder marked sent for exhibition \(exhibitionId)")
        } catch {
            print("[EndingSoon] Error marking reminder sent: \(error)")
        }
    }

    // MARK: - Vérifier toutes les expositions et envoyer reminders nécessaires
    //
    // Threshold check (has this exhibition crossed the user's reminder %?)
    // is computed client-side via daysRemaining/reminderThresholdDays.
    // Whether to actually send — given the user's chosen recurrence
    // (once/daily/weekly) — is delegated to
    // SupabaseService.shouldSendEndingSoonNotification, which tracks the
    // last-sent timestamp per (user, exhibition, frequency) in
    // ending_soon_notifications_sent. This replaces the older
    // shouldSendReminder/markReminderSent RPC pair (kept below, unused, in
    // case anything server-side still depends on them) since that RPC has
    // no notion of recurrence — once it recorded a reminder as sent, it
    // would never fire again for that exhibition.
    func checkAndSendReminders() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }

        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let todayString = formatter.string(from: Date())

            let exhibitions: [Exhibition] = try await supabase
                .from("exhibitions")
                .select()
                .gt("end_date", value: todayString)
                .execute()
                .value

            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            let userThreshold = profile.exhibitionReminderThreshold ?? 25
            let frequency = profile.endingSoonFrequency ?? "once"

            for exhibition in exhibitions {
                let daysLeft = daysRemaining(for: exhibition)
                let thresholdDays = reminderThresholdDays(for: exhibition, userThresholdPercent: userThreshold)
                guard daysLeft <= thresholdDays else { continue }

                do {
                    let canSend = try await SupabaseService.shared.shouldSendEndingSoonNotification(
                        userId: userId,
                        exhibitionId: exhibition.id,
                        frequency: frequency
                    )
                    guard canSend else { continue }
                } catch {
                    print("[EndingSoon] Error checking notification frequency: \(error)")
                    continue
                }

                let title = "⏰ \(exhibition.title)"
                let body = "Only \(daysLeft) days left! Don't miss this exhibition."

                await sendLocalNotification(
                    title: title,
                    body: body,
                    userInfo: [
                        "exhibition_id": exhibition.id,
                        "days_left": daysLeft
                    ]
                )

                do {
                    try await SupabaseService.shared.markEndingSoonNotificationSent(
                        userId: userId,
                        exhibitionId: exhibition.id,
                        frequency: frequency
                    )
                } catch {
                    print("[EndingSoon] Error marking notification sent: \(error)")
                }

                AnalyticsService.shared.track("ending_soon_notification_sent", properties: [
                    "exhibition_id": exhibition.id,
                    "days_remaining": daysLeft,
                    "frequency": frequency
                ])
            }
        } catch {
            print("[EndingSoon] Error checking reminders: \(error)")
        }
    }

    // MARK: - Date Parsing
    private static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension EndingSoonService: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("[EndingSoon] Received notification: \(userInfo)")

        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let exhibitionId = userInfo["exhibition_id"] as? Int {
            print("[EndingSoon] User tapped notification for exhibition \(exhibitionId)")
            DispatchQueue.main.async {
                DeepLinkRouter.shared.pendingExhibitionId = exhibitionId
            }
        }

        completionHandler()
    }
}
