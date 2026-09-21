# PostHog Setup Guide

Analytics for Wherart iOS. All events go through `AnalyticsService.shared.track(...)` (`Services/AnalyticsService.swift`).

## Configuration

- SDK: PostHog iOS, configured in `AnalyticsService.configure()` with `Config.postHogAPIKey` / `Config.postHogHost`.
- `captureScreenViews = true` (automatic screen events).
- Super properties on every event: `app_version`, `build_number`, `device_type`, `os_version`, `app_locale`.
- `identify(userId:)` is called on sign-in (`SupabaseService`); `reset()` on sign-out.
- Errors: `trackError(domain:code:message:context:)` emits `api_error`.

## Events currently implemented (67)

65 literal event names found in the code, plus 2 dynamic ones (`signup_failed` / `login_failed`, chosen in `LoginView`).

### Auth and onboarding
`onboarding_started`, `onboarding_step_completed`, `onboarding_preferences_changed`, `onboarding_completed`, `onboarding_error`, `signup_completed`, `signup_failed`, `login_completed`, `login_failed`, `signin_apple_started`, `signin_apple_completed`, `signin_apple_failed`, `signin_google_started`, `signin_google_completed`, `signin_google_failed`, `guest_mode_selected`, `guest_converted_to_user`, `password_reset_completed`, `password_reset_failed`, `logout_confirmed`, `logout_error`, `delete_account_requested`, `delete_account_error`

### Discovery
`tab_clicked`, `exhibition_card_clicked`, `search_performed`, `filter_applied`, `sort_changed`, `exhibition_favorited`, `exhibition_unfavorited`, `exhibition_viewed_toggled`, `exhibition_shared`, `map_opened`, `map_view_duration`, `map_location_filtered`, `location_permission_granted`

### Visits and chat
`create_visit_opened`, `create_visit_info_filled`, `create_visit_error`, `visit_created`, `visit_joined`, `visit_left`, `visit_detail_viewed`, `visit_details_viewed`, `visits_tab_switched`, `visits_loaded`, `visits_load_error`, `chat_message_sent`

### Profile and settings
`profile_viewed`, `profile_load_error`, `settings_opened`, `preferences_updated`, `preferences_update_error`

### Notifications
`notification_read`, `notification_deleted`, `ending_soon_notification_sent`, `new_exhibitions_notification_sent`

### Monetization
`paywall_shown`, `paywall_dismissed`, `paywall_tier_selected`, `purchase_initiated`, `purchase_completed`, `purchase_failed`

### AI assistant
`ai_assistant_opened`, `ai_assistant_message_sent`, `ai_assistant_error`

### Errors
`api_error`

> Note: `visit_detail_viewed` and `visit_details_viewed` look like duplicates; consider consolidating.

## Events to implement (suggested)

| Event | Where | Why |
|---|---|---|
| `notification_preview_opened` | `NotificationsView.handleTapMultiple` | Measure multi-exhibition sheet usage |
| `notification_preview_exhibition_selected` | `NotificationPreviewSheet` | Which card users pick from the sheet |
| `notification_opened` (with `exhibition_count`) | `NotificationsView.handleTap*` | Notification tap-through by type |
| `kids_friendly_filter_applied` | `FilterSheet` | Adoption of the community filter |
| `exhibition_tag_edited` | Exhibition detail edit flow | Community contribution rate |
| `share_to_chat_tapped` | Exhibition detail | Share funnel |
| `deep_link_opened` (with `type`) | `DeepLinkRouter` | Reset-password / share link conversion |
| `ai_assistant_response_received` | `AIAssistantSheet` | AI latency / completion |
| `map_marker_tapped` | `MapView` | Map engagement |
| `session_visit_reminder_scheduled` | `NotificationService` | Reminder adoption |

## Dashboards to create (5)

1. **Acquisition and onboarding funnel** — `onboarding_started` -> `onboarding_completed` -> `signup_completed` / `login_completed`; break down by `app_version`; include guest -> user (`guest_converted_to_user`).
2. **Discovery engagement** — `exhibition_card_clicked`, `exhibition_favorited`, `search_performed`, `filter_applied`, `map_opened`; trends + top filters.
3. **Visits and social** — `visit_created`, `visit_joined`, `visit_left`, `chat_message_sent`; funnel `create_visit_opened` -> `create_visit_info_filled` -> `visit_created`.
4. **Notifications and retention** — `notification_read` / `notification_deleted`, sent vs opened, D1/D7/D30 retention.
5. **Monetization and AI / errors** — paywall funnel (`paywall_shown` -> `paywall_tier_selected` -> `purchase_initiated` -> `purchase_completed`), `ai_assistant_*`, and an error board on `api_error` and every `*_error` / `*_failed` event.

## Setup checklist

- [ ] Verify `Config.postHogAPIKey` and host (EU: `https://eu.i.posthog.com`) in the release build.
- [ ] Create the 5 dashboards above in PostHog.
- [ ] Add alerts on `api_error` spikes and `purchase_failed`.
- [ ] Implement the suggested events, then update this document.
