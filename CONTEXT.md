# WHERART PROJECT CONTEXT

## QUICK START FOR CLAUDE CODE

### PROJECT INFO
- **App**: Wherart iOS (SwiftUI native)
- **Supabase Project**: etfarydonmbkuxdharjl
- **Bundle ID**: com.alexandrewt.wherart
- **Current Version**: v1.6.2 (build 62)
- **TestFlight**: https://testflight.apple.com/join/A128eb3V
- **Repo**: https://github.com/alexandrewt/wherart-swiftui

### STACK
- iOS 16+ native SwiftUI
- Supabase (auth + DB + Edge Functions)
- PostHog analytics
- Anthropic Claude API (ask-wherart-ai)

### KEY FEATURES (v1.6.2)
✅ Personalized exhibition discovery
✅ Group visits organization
✅ Reset password via email (deep links)
✅ Kids Friendly filter (community-based)
✅ Share to Chat (WhatsApp/iMessage)
✅ Wherart AI assistant (Claude Sonnet 5)
✅ Notifications (ending soon, new recommendations)
✅ Map view with interactive markers

### CURRENT ISSUES TO FIX
1. HomeView greeting "Hello, [name]!" disappeared
2. ✅ DONE — Notification overlay for 2+ exhibitions
3. Post v1.6.2: set up PostHog dashboards

### KNOWN ANALYTICS DATA-QUALITY ISSUES (fix after PostHog dashboards)
- `location_permission_granted` (MapView `onChange` of location) fires on every location update, not when permission is granted: misnamed and inflated.
- `visit_left` is only sent when a member leaves; the creator deleting a visit (`VisitDetailView.leaveOrDelete`) sends nothing.
- `visit_detail_viewed` and `visit_details_viewed` are near-duplicates.
- Events fired before `AnalyticsService.configure()` (which runs in WherartApp's `.task`) are silently dropped: a cold-start deep link or notification tap can lose its `deep_link_opened`.

### RECENT WORK SESSION (Sept 15, 2026)
- Fixed 22 exhibition duplicates in DB
- Normalized spaces in exhibition titles/venues
- sync-exhibitions v9 deployed with normalizeText()
- Wherart AI fully functional (crédits chargés)
- Kids Friendly filter + Share to Chat ready to test
- Password reset working (deep links + AASA)

### SUPABASE TABLES
- exhibitions (961 rows, 321 active as of Sept 21, 2026)
- profiles (user data)
- user_exhibition_edits (community tags: kids_friendly, wheelchair)
- visits (group visits organization)
- notifications (user notifications)

### EDGE FUNCTIONS DEPLOYED
- share-exhibition (v1)
- sync-exhibitions (v9 - active)
- ask-wherart-ai (v3 - active, needs testing)

### FILE STRUCTURE

```
Wherart/
├── App/WherartApp.swift (main)
├── Views/
│   ├── Home/HomeView.swift (main feed)
│   ├── Home/ExhibitionDetailView.swift
│   ├── Map/MapView.swift
│   ├── Visits/VisitDetailView.swift
│   ├── Profile/ProfileView.swift
│   ├── Notifications/NotificationsView.swift + NotificationPreviewSheet.swift (multi-expo chooser, done)
│   └── Home/AIAssistantSheet.swift (working, needs testing)
├── Models/
│   ├── Models.swift (Exhibition, Profile, Visit, etc.)
│   └── (AppNotification lives in Models.swift, with exhibitionIds array)
├── Services/
│   ├── SupabaseService.swift (all DB/API calls)
│   └── AnalyticsService.swift (PostHog)
├── supabase/
│   ├── functions/sync-exhibitions/index.ts (v9)
│   ├── functions/ask-wherart-ai/index.ts (v3)
│   ├── functions/share-exhibition/index.ts
│   └── migrations/ (applied by `supabase db push`)
│       └── 20260915000001_update_notifications_to_multiple_exhibitions.sql
├── sql/ (manual scripts, run in the Supabase SQL Editor)
│   └── 2026-09-prevent-exhibition-duplicates.sql (+ 3 others)
└── Xcode/
    ├── Wherart.xcodeproj
    ├── Podfile (if CocoaPods used)
    └── project.pbxproj
```

### NEXT TASKS (Prioritized)
1. **Fix HomeView greeting** (5 min, prompt ready)
2. ✅ DONE — **Notification overlay for 2+ expos**
3. **Test Wherart AI on device** (5 min, live now)
4. **PostHog dashboards setup** (30 min, backlog)
5. **Submit v1.6.2 to App Store** (after all tests pass)

### IMPORTANT NOTES
- Never modify Supabase schema without migration file
- sync-exhibitions runs on schedule (check Edge Function logs)
- Crédits Anthropic: $20 charged (sufficient for beta)
- Always test on simulator (Paris location, 9:41 time)
- Commit only what changed (no .DS_Store, no build artifacts)

### CLAUDE CODE WORKFLOW FOR THIS PROJECT
1. Open ~/Developer/Wherart in Claude Code
2. Read this CONTEXT.md first
3. Use prompts from session transcripts: /mnt/transcripts/
4. Always `supabase db push` after schema migrations
5. Build with: ⌘B (Xcode)
6. Run on simulator: ⌘R (Xcode)

### SESSION TRANSCRIPTS
Latest session: /mnt/transcripts/2026-09-15-13-57-53-wherart-ios-session-4.txt
All sessions: /mnt/transcripts/journal.txt

### CONTACTS / RESOURCES
- Supabase Dashboard: https://app.supabase.com (project: etfarydonmbkuxdharjl)
- PostHog: https://eu.i.posthog.com
- Anthropic Console: https://console.anthropic.com
- App Store Connect: https://appstoreconnect.apple.com

---

**Last updated**: Sept 21, 2026
**By**: Alexandre de Witt
