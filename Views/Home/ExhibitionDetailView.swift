import SwiftUI
import Auth

struct ExhibitionDetailView: View {

    let exhibition: Exhibition
    @Environment(\.dismiss) private var dismiss

    @State private var isFavorite: Bool = false
    @State private var isViewed: Bool = false
    @State private var favoriteScale: CGFloat = 1.0
    @State private var viewedScale: CGFloat = 1.0
    @State private var showPricing = false
    @State private var showAccessibility = false
    @State private var showFullSchedule = false
    @State private var visitsCount: Int? = nil
    @State private var showCreateVisit = false
    @State private var sponsoredExhibition: Exhibition? = nil
    @State private var navigateToSponsored: Exhibition? = nil

    @State private var communityDuration: String? = nil
    @State private var communityAccessibility: String? = nil
    @State private var communityWaitTime: String? = nil

    @State private var likesCount = 0
    @State private var isLiked = false
    @State private var isTogglingLike = false
    @State private var comments: [ExhibitionComment] = []
    @State private var newComment = ""
    @State private var isPostingComment = false
    @State private var currentUserFirstName = "Member"
    @State private var editingField: EditableField? = nil
    @State private var isSavingEdit = false
    @State private var showSavedConfirmation = false
    @State private var savedConfirmationField: EditableField? = nil
    @State private var showLoginPrompt = false
    @State private var showShareSheet = false
    @FocusState private var commentFieldFocused: Bool

    enum EditableField: Identifiable, Equatable {
        case duration, accessibility, waitTime
        var id: Self { self }
        var title: String {
            switch self {
            case .duration: return String(localized: "estimated_duration")
            case .accessibility: return String(localized: "accessibility")
            case .waitTime: return String(localized: "estimated_wait_time")
            }
        }
        var options: [String] {
            switch self {
            case .duration: return ["30min", "1h", "1h30", "2h", "2h+"]
            case .accessibility: return ["Wheelchair access", "Lift available", "Adapted toilets", "Audioguide available", "Guide dogs not allowed"]
            case .waitTime: return ["Unknown", "< 15 min", "15 - 30 min", "30 - 45 min", "45 min - 1h", "+ 1h"]
            }
        }
    }

    private var parsedPrice: (summary: String, hasDetails: Bool) {
        parsedPriceDisplay(exhibition.price, isFree: exhibition.isFree)
    }

    private var pricingSubtitle: String? {
        guard parsedPrice.hasDetails else { return nil }
        if let ticketLink = exhibition.ticketLink, !ticketLink.isEmpty {
            return String(localized: "see_all_prices")
        }
        return String(localized: "details_available")
    }

    private var visitsCountText: String {
        guard let count = visitsCount else { return String(localized: "loading_ellipsis") }
        guard count > 0 else { return String(localized: "no_visit_scheduled") }
        if count > 1 {
            return String(format: String(localized: "visit_scheduled_other"), count)
        }
        return String(format: String(localized: "visit_scheduled_one"), count)
    }

    // User-submitted duration takes priority over the API value — otherwise
    // an edit never shows up whenever the API already has a duration (e.g.
    // the saved value is silently masked). Same reasoning as accessibility.
    private var displayDuration: String? { communityDuration ?? exhibition.duration }
    // User-submitted accessibility takes priority over the API value: the
    // Paris Open Data field is often a vague placeholder, so a real
    // community submission should win. Falls through to "Unknown" via
    // `displayAccessibilityFormatted` when neither is present.
    private var displayAccessibility: String? { communityAccessibility ?? exhibition.accessibility }
    private var displayWaitTime: String { exhibition.waitTime ?? communityWaitTime ?? "Unknown" }

    /// The stored accessibility value is a comma-separated list of selected
    /// options; display joins them with " · " instead. Each component is
    /// mapped through `localizedAttributeLabel` for display only — the
    /// underlying comma-separated value (`displayAccessibility`, used for
    /// the edit sheet's selection state) stays canonical English.
    private var displayAccessibilityFormatted: String {
        guard let value = displayAccessibility, !value.isEmpty else { return String(localized: "unknown") }
        return value.split(separator: ",")
            .map { localizedAttributeLabel($0.trimmingCharacters(in: .whitespaces)) }
            .joined(separator: " · ")
    }

    private var accessibilitySelection: Set<String> {
        guard let value = displayAccessibility else { return [] }
        return Set(value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
    }

    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)

    private let horizontalPadding: CGFloat = 20
    private let sponsoredContentEnabled = false

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 59
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Hero Image
                ZStack(alignment: .bottom) {
                    GeometryReader { geo in
                        AsyncImage(url: URL(string: exhibition.image ?? "")) { phase in
                            Group {
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                        .transition(.opacity)
                                default:
                                    Rectangle().fill(Color.gray.opacity(0.3))
                                }
                            }
                            .animation(.easeIn(duration: 0.25), value: phase.image != nil)
                        }
                        .frame(width: geo.size.width, height: 360)
                        .clipped()
                    }
                    .frame(height: 360)

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.75)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .frame(height: 360)

                    // Titre en bas de l'image
                    VStack(alignment: .leading, spacing: 6) {
                        TagBadge(label: exhibition.type, color: Color(red: 0.58, green: 0.77, blue: 0.99))
                        Text(exhibition.title)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        Text(exhibition.venue)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 20)

                    // Overlay top : bannière + boutons
                    VStack(spacing: 0) {

                        if sponsoredContentEnabled, let sponsored = sponsoredExhibition {
                            Button(action: { navigateToSponsored = sponsored }) {
                                SponsoredTopBanner(exhibition: sponsored, topInset: safeAreaTop)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear.frame(height: safeAreaTop)
                        }

                        // Boutons ← oeil coeur
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.black.opacity(0.55))
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
                            }
                            .accessibilityLabel(String(localized: "back"))

                            Spacer()

                            HStack(spacing: 10) {
                                Button(action: { Task { await shareExhibition() } }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Color.black.opacity(0.55))
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
                                }
                                .accessibilityLabel(String(localized: "share"))

                                Button(action: {
                                    if SupabaseService.shared.isGuestMode {
                                        showLoginPrompt = true
                                    } else {
                                        impactLight.impactOccurred()
                                        animateViewed()
                                        Task { await toggleViewed() }
                                    }
                                }) {
                                    Image(systemName: isViewed ? "eye.fill" : "eye")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(isViewed ? Color(red: 0.4, green: 0.8, blue: 1.0) : .white)
                                        .frame(width: 36, height: 36)
                                        .background(Color.black.opacity(0.55))
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
                                        .scaleEffect(viewedScale)
                                }
                                .accessibilityLabel(isViewed ? String(localized: "mark_as_not_seen") : String(localized: "mark_as_seen"))

                                Button(action: {
                                    if SupabaseService.shared.isGuestMode {
                                        showLoginPrompt = true
                                    } else {
                                        impactMedium.impactOccurred()
                                        animateFavorite()
                                        Task { await toggleFavorite() }
                                    }
                                }) {
                                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(isFavorite ? .red : .white)
                                        .frame(width: 36, height: 36)
                                        .background(Color.black.opacity(0.55))
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
                                        .scaleEffect(favoriteScale)
                                }
                                .accessibilityLabel(isFavorite ? String(localized: "remove_from_favorites") : String(localized: "add_to_favorites"))
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, 8)

                        Spacer()
                    }
                    .frame(height: 360)
                }

                // MARK: - Content
                VStack(alignment: .leading, spacing: 24) {

                    HStack(alignment: .top, spacing: 12) {
                        QuickInfoCard(
                            label: String(localized: "distance"),
                            value: exhibition.distance.map { String(format: "%.1f km", $0) } ?? String(localized: "not_available"),
                            subtitle: String(localized: "get_directions"),
                            action: { openMaps() }
                        )
                        QuickInfoCard(
                            label: String(localized: "pricing"),
                            value: parsedPrice.summary,
                            subtitle: pricingSubtitle,
                            action: parsedPrice.hasDetails ? { showPricing = true } : nil
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "available_visits")).font(.system(size: 16, weight: .semibold))
                        RoundedRectangle(cornerRadius: 16)
                            .fill(visitsCount ?? 0 > 0 ? Color.green.opacity(0.1) : Color(.systemGray6))
                            .frame(height: 52)
                            .overlay(
                                Text(visitsCountText)
                                    .font(.system(size: 14))
                                    .foregroundColor(visitsCount ?? 0 > 0 ? .green : .secondary)
                                    .padding(.horizontal, 16),
                                alignment: .leading
                            )
                    }

                    if let description = exhibition.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "about")).font(.system(size: 16, weight: .semibold))
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(String(localized: "practical_information"))
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.bottom, 12)

                        VStack(spacing: 0) {
                            PracticalInfoRow(
                                icon: "mappin.and.ellipse",
                                label: String(localized: "address"),
                                value: exhibition.address,
                                hasAction: true,
                                action: { openMaps() }
                            )
                            Divider().padding(.leading, 48)
                            openingHoursRow
                            Divider().padding(.leading, 48)
                            PracticalInfoRow(
                                icon: "clock",
                                label: String(localized: "estimated_duration"),
                                value: localizedAttributeLabel(displayDuration ?? "Unknown"),
                                editAction: { beginEditing(.duration) }
                            )
                            .overlay(alignment: .trailing) {
                                if showSavedConfirmation && savedConfirmationField == .duration {
                                    savedConfirmationBadge
                                        .padding(.trailing, 44)
                                        .transition(.opacity)
                                }
                            }
                            Divider().padding(.leading, 48)
                            PracticalInfoRow(
                                icon: "figure.roll",
                                label: String(localized: "accessibility"),
                                value: displayAccessibilityFormatted,
                                hasAction: displayAccessibility != nil,
                                showChevron: false,
                                action: { showAccessibility = true },
                                editAction: { beginEditing(.accessibility) }
                            )
                            Divider().padding(.leading, 48)
                            PracticalInfoRow(
                                icon: "hourglass",
                                label: String(localized: "wait_time"),
                                value: localizedAttributeLabel(displayWaitTime),
                                editAction: { beginEditing(.waitTime) }
                            )
                            .overlay(alignment: .trailing) {
                                if showSavedConfirmation && savedConfirmationField == .waitTime {
                                    savedConfirmationBadge
                                        .padding(.trailing, 44)
                                        .transition(.opacity)
                                }
                            }
                            Divider().padding(.leading, 48)
                            PracticalInfoRow(icon: "phone", label: String(localized: "contact"), value: exhibition.phone ?? String(localized: "unknown"))
                        }
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }

                    SocialSection(
                        likesCount: likesCount,
                        isLiked: isLiked,
                        comments: comments,
                        newComment: $newComment,
                        isPostingComment: isPostingComment,
                        isCommentFieldFocused: $commentFieldFocused,
                        onToggleLike: {
                            if SupabaseService.shared.isGuestMode {
                                showLoginPrompt = true
                            } else {
                                Task { await toggleLike() }
                            }
                        },
                        onPostComment: {
                            if SupabaseService.shared.isGuestMode {
                                showLoginPrompt = true
                            } else {
                                Task { await postComment() }
                            }
                        }
                    )

                    VStack(spacing: 12) {
                        Button(action: {
                            if SupabaseService.shared.isGuestMode {
                                showLoginPrompt = true
                            } else {
                                showCreateVisit = true
                            }
                        }) {
                            Text(visitsCount ?? 0 > 0 ? String(localized: "visit_with_others") : String(localized: "organise_visit"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color(red: 0.15, green: 0.39, blue: 0.92))
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                        }

                        if let ticketLink = exhibition.ticketLink, !ticketLink.isEmpty {
                            Button(action: { openURL(ticketLink) }) {
                                Text(exhibition.isFree ? String(localized: "get_more_info") : String(localized: "buy_ticket"))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(red: 0.15, green: 0.39, blue: 0.92), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 20)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(false)
        .enableSwipeBack()
        .navigationDestination(item: $navigateToSponsored) { expo in
            ExhibitionDetailView(exhibition: expo)
        }
        .sheet(isPresented: $showPricing) {
            PricingSheet(exhibition: exhibition)
                .presentationDetents([.medium])
                .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showAccessibility) {
            AccessibilitySheet(text: displayAccessibilityFormatted)
                .presentationDetents([.medium])
                .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showFullSchedule) {
            FullScheduleSheet(schedule: openingHoursDisplay)
                .presentationDetents([.medium])
                .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showCreateVisit) {
            CreateVisitView(preselectedExhibition: exhibition, onCreated: { _ in showCreateVisit = false })
                .presentationDetents([.large])
                .presentationCornerRadius(24)
        }
        .sheet(item: $editingField) { field in
            Group {
                if field == .accessibility {
                    AccessibilityEditSheet(
                        options: field.options,
                        initialSelection: accessibilitySelection,
                        isSaving: isSavingEdit,
                        onSave: { selected in Task { await saveAccessibilityEdit(selected) } }
                    )
                } else {
                    EditFieldSheet(
                        field: field,
                        currentValue: currentValue(for: field),
                        isSaving: isSavingEdit,
                        onSelect: { value in Task { await saveEdit(field, value: value) } }
                    )
                }
            }
            .presentationDetents(field == .waitTime ? [.medium, .large] : [.medium])
            .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareActivityView(
                itemsToShare: [
                    shareExhibitionText(),
                    URL(string: "https://wherart.app/exhibition/\(exhibition.id)") ?? URL(string: "https://wherart.app")!
                ]
            )
        }
        .sheet(isPresented: $showLoginPrompt) {
            LoginPromptSheet()
        }
        .task { await loadInitialState() }
    }

    // MARK: - Community Edits

    private func beginEditing(_ field: EditableField) {
        if SupabaseService.shared.isGuestMode {
            showLoginPrompt = true
            return
        }
        editingField = field
    }

    private func currentValue(for field: EditableField) -> String? {
        switch field {
        case .duration: return displayDuration
        case .accessibility: return displayAccessibility
        case .waitTime: return displayWaitTime
        }
    }

    private var savedConfirmationBadge: some View {
        Text(String(localized: "saved_confirmation"))
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.green)
            .clipShape(Capsule())
    }

    /// Shows the "Saved ✓" badge next to `field`'s row for 1.5s.
    private func triggerSavedConfirmation(for field: EditableField) {
        savedConfirmationField = field
        withAnimation(.easeInOut(duration: 0.25)) { showSavedConfirmation = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) { showSavedConfirmation = false }
            }
        }
    }

    private func saveAccessibilityEdit(_ selected: [String]) async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        let joined = selected.joined(separator: ", ")
        await MainActor.run { isSavingEdit = true }
        try? await SupabaseService.shared.upsertExhibitionEdit(
            userId: userId,
            exhibitionId: exhibition.id,
            duration: communityDuration,
            accessibility: joined,
            waitTime: communityWaitTime
        )
        await MainActor.run {
            communityAccessibility = joined
            isSavingEdit = false
            editingField = nil
        }
    }

    private func saveEdit(_ field: EditableField, value: String) async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        await MainActor.run { isSavingEdit = true }
        do {
            try await SupabaseService.shared.upsertExhibitionEdit(
                userId: userId,
                exhibitionId: exhibition.id,
                duration: field == .duration ? value : communityDuration,
                accessibility: field == .accessibility ? value : communityAccessibility,
                waitTime: field == .waitTime ? value : communityWaitTime
            )
            // Local state — and the "Saved" confirmation — only update once
            // the upsert has actually succeeded, so the UI never claims a
            // save that didn't persist.
            await MainActor.run {
                switch field {
                case .duration: communityDuration = value
                case .accessibility: communityAccessibility = value
                case .waitTime: communityWaitTime = value
                }
                isSavingEdit = false
                editingField = nil
                triggerSavedConfirmation(for: field)
            }
        } catch {
            await MainActor.run { isSavingEdit = false }
        }
    }

    // MARK: - Bounce Animation

    private func animateFavorite() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
            favoriteScale = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                favoriteScale = 1.0
            }
        }
    }

    private func animateViewed() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
            viewedScale = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                viewedScale = 1.0
            }
        }
    }

    // MARK: - Opening Hours Row

    private var isScheduleLong: Bool { openingHoursDisplay.count > 80 }

    /// Built to match `PracticalInfoRow`'s exact structure. Note the tap
    /// target is only wrapped in a `Button` when there's somewhere to go —
    /// a `Button` left in place but `.disabled` would have SwiftUI
    /// auto-dim its label/value text, which is what made this row (and any
    /// `PracticalInfoRow` with `hasAction: false`) look faded before.
    private var openingHoursRow: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "clock")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .frame(width: 24)
                .padding(.top, 2)

            if isScheduleLong {
                Button(action: { showFullSchedule = true }) {
                    openingHoursContent
                }
                .buttonStyle(.plain)
            } else {
                openingHoursContent
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var openingHoursContent: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "opening_hours"))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                Text(openingHoursDisplay)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.primary)
                    .lineLimit(isScheduleLong ? 3 : nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isScheduleLong {
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.secondary)
            }
        }
    }

    private var openingHoursDisplay: String {
        guard let schedule = exhibition.schedule else { return String(localized: "not_provided") }
        let parts = parseSchedule(cleanedScheduleString(schedule))
        return [parts.dates, parts.hours].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: - Helpers

    private func parseSchedule(_ schedule: String) -> (dates: String?, hours: String?) {
        let hoursPattern = #"\d{1,2}[h:]\d{0,2}\s*[-–]\s*\d{1,2}[h:]\d{0,2}"#
        if let range = schedule.range(of: hoursPattern, options: .regularExpression) {
            let hours = String(schedule[range])
            let dates = schedule.replacingCharacters(in: range, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return (dates.isEmpty ? nil : dates, hours)
        }
        return (nil, schedule)
    }

    private func openMaps() {
        let encoded = exhibition.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encoded)") { UIApplication.shared.open(url) }
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) { UIApplication.shared.open(url) }
    }

    private func loadInitialState() async {
        // Everything here except the interactions/profile lookups is public
        // data (visit count, community edits, likes, comments) — a guest
        // (nil userId) still needs it to see the exhibition's real state,
        // just without their own favorite/viewed/liked flags.
        let userId = SupabaseService.shared.currentUser?.id.uuidString

        if let userId, let interactions = try? await SupabaseService.shared.fetchInteractions(userId: userId) {
            let interaction = interactions.first { $0.exhibitionId == exhibition.id }
            await MainActor.run {
                isFavorite = interaction?.isFavorite ?? false
                isViewed = interaction?.isViewed ?? false
            }
        }
        if let groups = try? await SupabaseService.shared.fetchGroups() {
            await MainActor.run {
                visitsCount = groups.filter { $0.exhibitionId == exhibition.id }.count
            }
        }
        if let all = try? await SupabaseService.shared.fetchExhibitions() {
            let candidates = all.filter { $0.id != exhibition.id }
            await MainActor.run { sponsoredExhibition = candidates.randomElement() }
        }
        if let edits = try? await SupabaseService.shared.fetchExhibitionEdits(exhibitionId: exhibition.id) {
            await MainActor.run {
                communityDuration = edits.compactMap { $0.duration }.first
                communityAccessibility = edits.compactMap { $0.accessibility }.first
                communityWaitTime = edits.compactMap { $0.waitTime }.first
            }
        }
        if let userId, let profile = try? await SupabaseService.shared.fetchProfile(userId: userId), let firstName = profile.firstName, !firstName.isEmpty {
            await MainActor.run { currentUserFirstName = firstName }
        }
        if let likes = try? await SupabaseService.shared.fetchLikes(exhibitionId: exhibition.id) {
            await MainActor.run {
                likesCount = likes.count
                isLiked = userId.map { uid in likes.contains { $0.userId.lowercased() == uid.lowercased() } } ?? false
            }
        }
        if let fetchedComments = try? await SupabaseService.shared.fetchComments(exhibitionId: exhibition.id) {
            await MainActor.run { comments = fetchedComments }
        }
    }

    private func toggleLike() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString, !isTogglingLike else { return }
        isTogglingLike = true
        let wasLiked = isLiked
        isLiked.toggle()
        likesCount += isLiked ? 1 : -1
        try? await SupabaseService.shared.toggleLike(userId: userId, exhibitionId: exhibition.id, isLiked: wasLiked)
        isTogglingLike = false
    }

    private func postComment() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        let content = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        await MainActor.run { isPostingComment = true }
        try? await SupabaseService.shared.postComment(exhibitionId: exhibition.id, userId: userId, firstName: currentUserFirstName, content: content)
        if let fetchedComments = try? await SupabaseService.shared.fetchComments(exhibitionId: exhibition.id) {
            await MainActor.run { comments = fetchedComments }
        }
        await MainActor.run {
            newComment = ""
            isPostingComment = false
            commentFieldFocused = false
        }
    }

    private func toggleFavorite() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        let wasFavorite = isFavorite
        isFavorite.toggle()
        if wasFavorite {
            NotificationService.shared.cancelNotification(
                identifier: NotificationService.endingSoonIdentifier(exhibitionId: exhibition.id)
            )
        }
        try? await SupabaseService.shared.upsertInteraction(userId: userId, exhibitionId: exhibition.id, isFavorite: isFavorite, isViewed: isViewed)
    }

    private func toggleViewed() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        isViewed.toggle()
        try? await SupabaseService.shared.upsertInteraction(userId: userId, exhibitionId: exhibition.id, isFavorite: isFavorite, isViewed: isViewed)
    }

    private func shareExhibitionText() -> String {
        let duration = exhibition.duration ?? "Variable"
        let price = exhibition.price ?? "Free"
        return """
        \(exhibition.title)
        @ \(exhibition.venue)

        \(exhibition.description ?? "")

        Duration: \(duration)
        Price: \(price)

        Discover more on Wherart
        """
    }

    private func shareExhibition() async {
        AnalyticsService.shared.track("exhibition_shared", properties: [
            "exhibition_id": exhibition.id,
            "title": exhibition.title,
            "venue": exhibition.venue
        ])

        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)

        showShareSheet = true
    }
}

// MARK: - Sponsored Top Banner

struct SponsoredTopBanner: View {
    let exhibition: Exhibition
    var topInset: CGFloat = 0
    private let contentHeight: CGFloat = 64

    var body: some View {
        let totalHeight = contentHeight + topInset

        GeometryReader { geo in
            ZStack(alignment: .top) {
                AsyncImage(url: URL(string: exhibition.image ?? "")) { phase in
                    Group {
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                                .transition(.opacity)
                        default:
                            Color(.systemGray3)
                        }
                    }
                    .animation(.easeIn(duration: 0.25), value: phase.image != nil)
                }
                .frame(width: geo.size.width, height: totalHeight)
                .clipped()

                Color.black.opacity(0.65)
                    .frame(width: geo.size.width, height: totalHeight)

                VStack(spacing: 0) {
                    Color.clear.frame(height: topInset)
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "museum_partner_label"))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .tracking(1.5)
                            Text(exhibition.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(exhibition.venue)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(String(localized: "discover"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    .frame(height: contentHeight)
                    .padding(.horizontal, 16)
                }

                // Ending Soon Badge
                if EndingSoonService.shared.daysRemaining(for: exhibition) > 0 &&
                   EndingSoonService.shared.daysRemaining(for: exhibition) <= EndingSoonService.shared.reminderThresholdDays(for: exhibition, userThresholdPercent: 25) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("\(EndingSoonService.shared.daysRemaining(for: exhibition)) days left")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(8)
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .frame(width: geo.size.width, height: totalHeight)
        }
        .frame(maxWidth: .infinity)
        .frame(height: totalHeight)
    }
}

// MARK: - Social Section (likes & comments)

struct SocialSection: View {
    let likesCount: Int
    let isLiked: Bool
    let comments: [ExhibitionComment]
    @Binding var newComment: String
    let isPostingComment: Bool
    var isCommentFieldFocused: FocusState<Bool>.Binding
    let onToggleLike: () -> Void
    let onPostComment: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                Button(action: onToggleLike) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .secondary)
                        Text("\(likesCount)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .foregroundColor(.secondary)
                    Text("\(comments.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }

            if !comments.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(comments) { comment in
                        CommentRow(comment: comment)
                        if comment.id != comments.last?.id {
                            Divider()
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                TextField(String(localized: "add_comment"), text: $newComment)
                    .focused(isCommentFieldFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                Button(action: onPostComment) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(.systemGray4) : Color(red: 0.15, green: 0.39, blue: 0.92))
                }
                .disabled(isPostingComment || newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct CommentRow: View {
    let comment: ExhibitionComment

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(comment.userFirstName)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(comment.createdAt, style: .date)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Text(comment.content)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Quick Info Card

/// Shared by every `QuickInfoCard` (Distance, Pricing, ...) so they can
/// never drift apart in background color regardless of content length.
private let quickInfoCardBackground = Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.08)
private let quickInfoCardCornerRadius: CGFloat = 20
private let quickInfoCardMinHeight: CGFloat = 96

struct QuickInfoCard: View {
    let label: String
    let value: String
    let subtitle: String?
    let action: (() -> Void)?

    init(label: String, value: String, subtitle: String? = nil, action: (() -> Void)? = nil) {
        self.label = label; self.value = value; self.subtitle = subtitle; self.action = action
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12)).foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(.primary)
            if let subtitle = subtitle {
                Text(subtitle).font(.system(size: 11)).foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
            } else {
                Text(" ").font(.system(size: 11))
            }
        }
        .frame(maxWidth: .infinity, minHeight: quickInfoCardMinHeight, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(quickInfoCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: quickInfoCardCornerRadius))
    }

    var body: some View {
        // Same auto-dim pitfall as PracticalInfoRow: only wrap in a Button
        // when there's an action, so a card without one doesn't render
        // with washed-out text/background from an implicitly disabled Button.
        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

// MARK: - Practical Info Row

struct PracticalInfoRow: View {
    let icon: String
    let label: String
    let value: String
    var hasAction: Bool = false
    var showChevron: Bool = true
    var action: (() -> Void)? = nil
    var editAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .frame(width: 24)
                .padding(.top, 2)

            // A Button wrapping this content while `.disabled` would make
            // SwiftUI auto-dim the label/value text — only wrap in a
            // Button when there's actually somewhere to go, so rows
            // without an action render with full, undimmed color.
            if hasAction {
                Button(action: { action?() }) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }

            if let editAction {
                Button(action: editAction) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color(red: 0.15, green: 0.39, blue: 0.92))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if hasAction && showChevron {
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Pricing Sheet

struct PricingSheet: View {
    let exhibition: Exhibition
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(String(localized: "pricing")).font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "full_pricing_details"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text(insertMissingSpaces((exhibition.price ?? String(localized: "not_available")).cleanedFromHTML))
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Accessibility Sheet

// MARK: - Edit Field Sheet

struct EditFieldSheet: View {
    let field: ExhibitionDetailView.EditableField
    let currentValue: String?
    let isSaving: Bool
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(field.title).font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(.secondary)
                }
            }
            Text(String(localized: "help_other_visitors_edit"))
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                ForEach(field.options, id: \.self) { option in
                    let isSelected = currentValue == option
                    Button(action: { onSelect(option) }) {
                        HStack {
                            Text(localizedAttributeLabel(option))
                                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? Color(red: 0.15, green: 0.39, blue: 0.92) : .primary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(isSelected ? Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.08) : Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                }
            }

            if isSaving {
                ProgressView().frame(maxWidth: .infinity)
            }
            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Accessibility Edit Sheet (multi-select)

struct AccessibilityEditSheet: View {
    let options: [String]
    let isSaving: Bool
    let onSave: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String>

    init(options: [String], initialSelection: Set<String>, isSaving: Bool, onSave: @escaping ([String]) -> Void) {
        self.options = options
        self.isSaving = isSaving
        self.onSave = onSave
        self._selected = State(initialValue: initialSelection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(String(localized: "accessibility")).font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(.secondary)
                }
            }
            Text(String(localized: "help_other_visitors_select"))
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selected.contains(option)
                    Button(action: {
                        if isSelected { selected.remove(option) } else { selected.insert(option) }
                    }) {
                        HStack {
                            Text(localizedAttributeLabel(option))
                                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? Color(red: 0.15, green: 0.39, blue: 0.92) : .primary)
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundColor(isSelected ? Color(red: 0.15, green: 0.39, blue: 0.92) : Color(.systemGray3))
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(isSelected ? Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.08) : Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                }
            }

            Button(action: { onSave(options.filter { selected.contains($0) }) }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(selected.isEmpty ? Color(.systemGray4) : Color(red: 0.15, green: 0.39, blue: 0.92))
                        .frame(height: 52)
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(String(localized: "save")).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    }
                }
            }
            .disabled(isSaving || selected.isEmpty)

            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Full Schedule Sheet

struct FullScheduleSheet: View {
    let schedule: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(String(localized: "opening_hours")).font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(.secondary)
                }
            }
            Text(schedule)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .lineSpacing(4)
            Spacer()
        }
        .padding(24)
    }
}

struct AccessibilitySheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    let items = [
        (icon: "checkmark.circle.fill", color: Color.green, text: "Wheelchair access"),
        (icon: "checkmark.circle.fill", color: Color.green, text: "Lift available"),
        (icon: "checkmark.circle.fill", color: Color.green, text: "Adapted toilets"),
        (icon: "checkmark.circle.fill", color: Color.green, text: "Audioguide available"),
        (icon: "xmark.circle.fill", color: Color.gray, text: "Guide dogs not allowed"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(String(localized: "accessibility")).font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(.secondary)
                }
            }
            Text(text).font(.system(size: 14)).foregroundColor(.secondary)
            VStack(spacing: 10) {
                ForEach(items, id: \.text) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.icon).foregroundColor(item.color)
                        Text(localizedAttributeLabel(item.text)).font(.system(size: 14))
                        Spacer()
                    }
                }
            }
            Spacer()
        }
        .padding(24)
    }
}

#Preview {
    NavigationStack {
        ExhibitionDetailView(exhibition: Exhibition(
            id: 1, title: "Gerhard Richter", artist: "Gerhard Richter",
            venue: "Fondation Louis Vuitton", venueType: "Foundations",
            type: "Contemporary Art", address: "8 Avenue du Mahatma Gandhi, 75116 Paris",
            schedule: "Mon-Fri: 12pm-7pm", description: "A major retrospective.",
            ticketLink: "https://fondationlouisvuitton.fr", image: nil,
            lat: 48.8738, lng: 2.2654, price: "16€", duration: "2h",
            accessibility: "Wheelchair accessible", waitTime: nil, phone: "+33 1 40 69 96 00",
            isFree: false, endingSoon: false, endDate: nil, distance: 6.8
        ))
    }
}

// MARK: - Share Activity View

struct ShareActivityView: UIViewControllerRepresentable {
    let itemsToShare: [Any]
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: itemsToShare,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact
        ]
        controller.completionWithItemsHandler = { _, _, _, _ in
            dismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
