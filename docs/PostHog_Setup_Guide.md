# WHERART — PostHog Analytics Guide

**Last updated:** Sept 21, 2026
**PostHog workspace:** https://eu.i.posthog.com
**Status:** 75 events tracked | 1 to add (blocked) | 5 dashboards + 4 funnels to build

Event names below are the ones actually sent by the code (`AnalyticsService.shared.track(...)`, `Services/AnalyticsService.swift`). To re-verify:

```bash
grep -rhoE 'track\(\s*"[a-z_]+"' --include='*.swift' Views Services App Models | sort -u
```

## Configuration

- SDK: PostHog iOS, set up in `AnalyticsService.configure()` (`Config.postHogAPIKey` / `Config.postHogHost`).
- `captureScreenViews = true` (automatic screen events).
- Super properties on every event: `app_version`, `build_number`, `device_type`, `os_version`, `app_locale`.
- `identify(userId:)` on sign-in, `reset()` on sign-out.
- Errors: `trackError(...)` emits `api_error`.

## Existing events (75)

71 literal names + 4 computed in `LoginView` (`signup_started`, `login_started`, `signup_failed`, `login_failed`).

### Auth and onboarding
| Event | Notes / properties |
|---|---|
| `onboarding_started`, `onboarding_step_completed`, `onboarding_preferences_changed`, `onboarding_completed`, `onboarding_error` | Onboarding flow |
| `signup_started`, `signup_completed`, `signup_failed` | email/password sign-up (`signup_*` / `login_*` names are computed in `LoginView`) |
| `login_started`, `login_completed`, `login_failed` | email/password sign-in |
| `signin_apple_started` / `_completed` / `_failed` | Sign in with Apple |
| `signin_google_started` / `_completed` / `_failed` | Google Sign-In |
| `guest_mode_selected`, `guest_converted_to_user` | Guest -> account conversion |
| `password_reset_completed`, `password_reset_failed` | Reset flow |
| `logout_confirmed`, `logout_error`, `delete_account_requested`, `delete_account_error` | Account lifecycle |

### Discovery and engagement
| Event | Notes / properties |
|---|---|
| `tab_clicked` | `tab` |
| `search_performed` | `search_term` |
| `filter_applied` | `art_types`, `venue_types`, `distances`, `prices` (counts) |
| `sort_changed` | `sort_option` |
| `exhibition_card_clicked` | `exhibition_id`, `exhibition_title`, `source_screen` ("home" / "map") |
| `exhibition_favorited`, `exhibition_unfavorited` | favorites |
| `exhibition_viewed_toggled` | "seen" toggle |
| `exhibition_shared` | share |
| `map_opened`, `map_view_duration`, `map_location_filtered` | Map (`center_lat`, `center_lng`, `exhibition_count`) |
| `location_permission_granted` | |

### Visits and chat
`create_visit_opened`, `create_visit_info_filled`, `create_visit_error`, `visit_created`, `visit_joined`, `visit_left`, `visit_detail_viewed`, `visit_details_viewed`, `visits_tab_switched`, `visits_loaded`, `visits_load_error`, `chat_message_sent`

> `visit_detail_viewed` and `visit_details_viewed` look like duplicates: consolidate.

### Profile and settings
`profile_viewed`, `profile_load_error`, `settings_opened`, `preferences_updated`, `preferences_update_error`

### Notifications
`notification_read`, `notification_deleted`, `notification_opened` (`notification_id`, `exhibition_count`), `notification_preview_exhibition_selected` (`exhibition_id`), `notification_settings_changed` (`reminder_threshold`, `ending_soon_frequency`), `ending_soon_notification_sent`, `new_exhibitions_notification_sent`

### Monetization
| Event | Notes / properties |
|---|---|
| `paywall_shown`, `paywall_dismissed`, `paywall_tier_selected` | `billing_cycle`, `context` |
| `purchase_initiated`, `purchase_completed`, `purchase_failed` | |

### Wherart AI
`ai_assistant_opened`, `ai_assistant_message_sent`, `ai_response_received` (`latency_ms`, `exhibitions_suggested`), `ai_exhibition_selected` (`exhibition_id`, `position_in_list`), `ai_assistant_error`

### Deep links
`deep_link_opened` (`type`: `reset_password` / `exhibition` / `notification`; `source`: `url_scheme` / `universal_link`, or the notification kind; `exhibition_id` or `exhibition_count`)

### Errors
`api_error`

## Events to add (1)

Already covered, so not repeated here: visits (`visit_created`, `visit_joined`, `chat_message_sent`), sharing (`exhibition_shared`), AI open/message/error.

| Event | Where | Suggested properties |
|---|---|---|
| `visit_feedback_submitted` | `VisitDetailView` | `visit_id`, `rating` — **blocked: requires feedback UI** (no rating/feedback screen exists yet) |

## Dashboards (5) ✅ DONE

1. **Acquisition and onboarding ✅ DONE**
   - Daily signups: `signup_completed`
   - Funnel: `onboarding_started` -> `onboarding_completed` -> `signup_completed`
   - Auth methods: `signup_completed` / `signin_apple_completed` / `signin_google_completed` / `login_completed`
   - Guest conversion: `guest_mode_selected` -> `guest_converted_to_user`
2. **Discovery ✅ DONE**
   - `search_performed` volume + top `search_term`
   - `filter_applied` volume; `sort_changed` by `sort_option`
   - `exhibition_card_clicked` by `source_screen`; top `exhibition_title`
   - `map_opened` and `map_view_duration`
3. **Engagement ✅ DONE**
   - `exhibition_favorited` vs `exhibition_unfavorited`
   - `exhibition_viewed_toggled`, `exhibition_shared`
   - `tab_clicked` by `tab`
4. **Wherart AI ✅ DONE**
   - Sessions: `ai_assistant_opened`; questions: `ai_assistant_message_sent`
   - Error rate: `ai_assistant_error` / `ai_assistant_opened`
   - Latency: `ai_response_received` (`latency_ms`); click-through: `ai_exhibition_selected`
5. **Health and errors ✅ DONE**
   - `api_error`, `*_failed`, `*_error` (all listed above), by `error_message`
   - `purchase_failed`, `signin_*_failed`

Visits and monetization can be added as extra tiles: visit funnel `create_visit_opened` -> `create_visit_info_filled` -> `visit_created`; paywall funnel `paywall_shown` -> `paywall_tier_selected` -> `purchase_initiated` -> `purchase_completed`.

## Funnels (4)

| Funnel | Steps | Target | Alert |
|---|---|---|---|
| Signup -> discovery | `signup_completed` -> `exhibition_card_clicked` -> `exhibition_favorited` | > 40% | < 25% |
| Search -> engage | `search_performed` -> `exhibition_card_clicked` -> `exhibition_favorited` | > 15% | |
| Filter -> engage | `filter_applied` -> `exhibition_card_clicked` -> `exhibition_favorited` | > 20% | |
| AI -> action | `ai_assistant_message_sent` -> `ai_response_received` -> `ai_exhibition_selected` | > 30% | < 10% |

Targets are starting guesses, to be adjusted once real data exists.

## Roadmap

1. **Verify (2h):** open the Events tab and confirm the events above appear; build dashboards 1-2 and the first two funnels.
2. **AI events (3h): ✅ DONE** (events added); build dashboard 4 and the AI funnel; alerts on AI error rate and latency > 5000 ms.
3. **Notifications (2h): ✅ DONE** — added `notification_opened`, `notification_preview_exhibition_selected`, `notification_settings_changed`.
4. **Remaining events: ✅ DONE** — `deep_link_opened` added. `map_marker_tapped` dropped (duplicate of `exhibition_card_clicked` with `source_screen: "map"`). `visit_feedback_submitted` is blocked until a feedback UI exists.
5. **Advanced:** dashboard 5, D7/D30 retention, cohort AI users vs non-AI users.

**Owner:** Alexandre | **Next review:** Sept 28, 2026
