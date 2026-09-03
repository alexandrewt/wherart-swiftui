import SwiftUI
import CoreLocation
import Combine
import Auth

struct HomeView: View {

    @EnvironmentObject private var nav: AppNavigation
    @StateObject private var locationManager = LocationManager()
    @State private var exhibitions: [Exhibition] = []
    @State private var sponsoredExhibitions: [Exhibition] = []
    @State private var favoriteIds: [Int] = []
    @State private var viewedIds: [Int] = []
    @State private var profile: Profile? = nil
    @State private var isLoading = true
    @State private var search = ""
    @State private var floatingSearch = ""
    @State private var sortBy: SortOption = .closest
    @State private var showSortMenu = false
    @State private var showFilters = false
    @State private var filters = AppFilters()
    @State private var selectedExhibition: Exhibition? = nil
    @State private var showFloatingSearch = false
    @State private var floatingExpanded = false
    @State private var showPaywall = false
    @State private var showLoginPrompt = false
    @AppStorage("paywallShowCount") private var paywallCount = 0
    @FocusState private var searchFocused: Bool
    @FocusState private var floatingSearchFocused: Bool

    private let maxPaywallShows = 1
    private let sponsoredCardsEnabled = false
    private let impactLight = UIImpactFeedbackGenerator(style: .light)

    var activeFiltersCount: Int {
        filters.types.count + filters.venues.count + filters.prices.count + filters.distances.count
    }

    private var activeSearch: String { showFloatingSearch ? floatingSearch : search }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {

                    // MARK: - Search Bar
                    HStack(spacing: 10) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.system(size: 15))
                            TextField(String(localized: "search_exhibitions"), text: $search)
                                .font(.system(size: 15))
                                .focused($searchFocused)
                                .onChange(of: search) { val in
                                    if !showFloatingSearch { floatingSearch = val }
                                    if !val.isEmpty {
                                        AnalyticsService.shared.track("search_performed", properties: ["search_term": val])
                                    }
                                }
                                .onSubmit {
                                    searchFocused = false
                                }
                            if !search.isEmpty {
                                Button(action: {
                                    search = ""
                                    floatingSearch = ""
                                    searchFocused = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 14))
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)

                        Button(action: {
                            impactLight.impactOccurred()
                            searchFocused = false
                            showFilters = true
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 44, height: 44)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                                if activeFiltersCount > 0 {
                                    Text("\(activeFiltersCount)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 16, height: 16)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                        .offset(x: 4, y: -4)
                                }
                            }
                        }
                        .accessibilityLabel(activeFiltersCount > 0 ? String(format: String(localized: "filters_count_active"), activeFiltersCount) : String(localized: "filters"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)

                    if isLoading {
                        skeletonFeed
                            .transition(.opacity)
                    } else {
                        feedContent
                            .transition(.opacity)
                    }
                }
                .padding(.top, 8)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.frame(in: .global).minY) { value in
                                // Only the scroll-derived visibility of the floating search
                                // button should change here — never clear search text or
                                // reset the feed. A keyboard dismissal can momentarily shift
                                // this same frame value, and previously that was
                                // mis-detected as "scrolled back to top", wiping out
                                // whatever the user had searched for.
                                withAnimation(.spring(response: 0.3)) {
                                    showFloatingSearch = value < -80
                                }
                            }
                    }
                )
            }
            .scrollDismissesKeyboard(.interactively)

            // MARK: - Floating Search
            if showFloatingSearch {
                ZStack {
                    if floatingExpanded {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.system(size: 15))
                            TextField(String(localized: "search_exhibition_singular"), text: $floatingSearch)
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                                .focused($floatingSearchFocused)
                                .onChange(of: floatingSearch) { val in search = val }
                            Button(action: {
                                floatingSearch = ""
                                search = ""
                                withAnimation(.spring(response: 0.3)) {
                                    floatingExpanded = false
                                    floatingSearchFocused = false
                                }
                            }) {
                                Image(systemName: floatingSearch.isEmpty ? "xmark" : "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
                        .padding(.horizontal, 16)
                        .onAppear { floatingSearchFocused = true }
                        .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
                    } else {
                        Button(action: {
                            impactLight.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                floatingExpanded = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                Text(String(localized: "search"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .clipShape(Capsule())
                            .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: floatingExpanded)
                .scaleEffect(showFloatingSearch ? 1.0 : 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showFloatingSearch)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // MARK: - Paywall Overlay
            if showPaywall {
                PaywallOverlay(
                    isPresented: $showPaywall,
                    onSubscribeTapped: {
                        nav.selectedTab = 3
                        nav.showSubscribe = true
                    }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .navigationTitle(greeting)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .principal) { Text("") }
        }
        .onChange(of: sortBy) { newSort in
            AnalyticsService.shared.track("sort_changed", properties: ["sort_option": newSort.rawValue])
        }
        .onChange(of: showPaywall) { isShown in
            if isShown {
                AnalyticsService.shared.track("paywall_shown")
            } else {
                AnalyticsService.shared.track("paywall_dismissed")
            }
        }
        .sheet(isPresented: $showSortMenu) {
            SortMenuSheet(sortBy: $sortBy)
                .presentationDetents([.medium])
                .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showFilters) {
            FilterSheet(filters: $filters)
                .presentationDetents([.large])
                .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showLoginPrompt) {
            LoginPromptSheet()
        }
        .navigationDestination(item: $selectedExhibition) { exhibition in
            ExhibitionDetailView(exhibition: exhibition)
        }
        .task {
            impactLight.prepare()
            await loadData()
        }
        .onAppear {
            schedulePaywall()
        }
    }

    // MARK: - Paywall

    private func schedulePaywall() {
        return
        guard paywallCount < maxPaywallShows else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            guard paywallCount < maxPaywallShows else { return }
            // showPaywall = true — disabled, paywall overlay is turned off
            paywallCount += 1
        }
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        let filtered = filteredExhibitions
        let forYou = sorted(filtered.filter { matchesProfile($0) })
        let mightLike = sorted(filtered.filter { !matchesProfile($0) })
        let hasPrefs = (profile?.preferences.isEmpty == false) || (profile?.venueTypes.isEmpty == false)

        return Group {
            if hasPrefs {
                if !forYou.isEmpty {
                    sectionHeader(title: String(localized: "exhibitions_for_you"))
                    feedRows(forYou)
                }
                if !mightLike.isEmpty {
                    sectionHeader(title: String(localized: "exhibitions_might_like"), showSortButton: false)
                    feedRows(mightLike)
                }
            } else {
                sectionHeader(title: String(localized: "exhibitions_near_you"))
                feedRows(sorted(filtered))
            }
        }
    }

    private func feedRows(_ list: [Exhibition]) -> some View {
        ForEach(Array(list.enumerated()), id: \.element.id) { index, exhibition in
            Group {
                if sponsoredCardsEnabled && index > 0 && index % 7 == 0 && !sponsoredExhibitions.isEmpty {
                    let rawIndex = (index / 7) - 1
                    let sponsoredIndex = rawIndex % sponsoredExhibitions.count
                    if sponsoredIndex >= 0 && sponsoredIndex < sponsoredExhibitions.count {
                        SponsoredExhibitionCard(
                            exhibition: sponsoredExhibitions[sponsoredIndex],
                            onTap: {
                                impactLight.impactOccurred()
                                selectedExhibition = sponsoredExhibitions[sponsoredIndex]
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }

                ExhibitionCard(
                    exhibition: exhibition,
                    isFavorite: favoriteIds.contains(exhibition.id),
                    isViewed: viewedIds.contains(exhibition.id),
                    onTap: {
                        impactLight.impactOccurred()
                        AnalyticsService.shared.track("exhibition_card_clicked", properties: [
                            "exhibition_id": exhibition.id,
                            "exhibition_title": exhibition.title,
                            "source_screen": "home"
                        ])
                        selectedExhibition = exhibition
                    },
                    onToggleFavorite: {
                        if SupabaseService.shared.isGuestMode {
                            showLoginPrompt = true
                        } else {
                            Task { await toggleFavorite(exhibition) }
                        }
                    },
                    onToggleViewed: {
                        if SupabaseService.shared.isGuestMode {
                            showLoginPrompt = true
                        } else {
                            Task { await toggleViewed(exhibition) }
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func sectionHeader(title: String, showSortButton: Bool = true) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            Spacer()
            if showSortButton {
                Button(action: { showSortMenu = true }) {
                    HStack(spacing: 4) {
                        Text(String(localized: "sort_by")).font(.system(size: 14)).foregroundColor(.secondary)
                        Image(systemName: "chevron.down").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Skeleton

    private var skeletonFeed: some View {
        ForEach(0..<4, id: \.self) { _ in
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 20).fill(Color(.systemGray5)).frame(height: 200)
                RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5)).frame(height: 16).padding(.horizontal, 16)
                RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)).frame(width: 120, height: 12).padding(.horizontal, 16)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .redacted(reason: .placeholder)
            .shimmering()
        }
    }

    // MARK: - Computed

    private var greeting: String {
        if let name = profile?.firstName, !name.isEmpty { return String(format: String(localized: "hello_name"), name) }
        return String(localized: "discover")
    }

    private var filteredExhibitions: [Exhibition] {
        exhibitions.filter { e in
            let q = activeSearch
            let matchSearch = q.isEmpty || e.title.localizedCaseInsensitiveContains(q) || e.venue.localizedCaseInsensitiveContains(q)
            let matchType = filters.types.isEmpty || filters.types.contains(e.type)
            let matchVenue = filters.venues.isEmpty || filters.venues.contains(e.venueType)
            let matchPrice = filters.prices.isEmpty ||
                (filters.prices.contains("Free") && e.isFree) ||
                (filters.prices.contains("Paid") && !e.isFree)
            let matchDist: Bool = {
                guard !filters.distances.isEmpty, let dist = e.distance else { return true }
                if filters.distances.contains("Under 1 km") && dist < 1 { return true }
                if filters.distances.contains("1 - 3 km") && dist >= 1 && dist < 3 { return true }
                if filters.distances.contains("3 - 5 km") && dist >= 3 && dist < 5 { return true }
                if filters.distances.contains("Over 5 km") && dist >= 5 { return true }
                return false
            }()
            let matchWaitTime = filters.waitTimes.isEmpty || filters.waitTimes.contains(e.waitTime ?? "Unknown")
            return matchSearch && matchType && matchVenue && matchPrice && matchDist && matchWaitTime
        }
    }

    private func matchesProfile(_ exhibition: Exhibition) -> Bool {
        // Si des filtres sont actifs, on utilise uniquement les préférences du profil
        // pour séparer les sections, pas les filtres
        let prefs = profile?.preferences ?? []
        let venues = profile?.venueTypes ?? []
        if prefs.isEmpty && venues.isEmpty { return true }
        return prefs.contains(exhibition.type) || venues.contains(exhibition.venueType)
    }

    private func sorted(_ list: [Exhibition]) -> [Exhibition] {
        list.sorted { a, b in
            switch sortBy {
            case .relevance: return false
            case .closest: return (a.distance ?? 999) < (b.distance ?? 999)
            case .endingSoon:
                let aDate = a.endDate.flatMap { ISO8601DateFormatter().date(from: $0) } ?? .distantFuture
                let bDate = b.endDate.flatMap { ISO8601DateFormatter().date(from: $0) } ?? .distantFuture
                return aDate < bDate
            case .priceAsc:
                if a.isFree && !b.isFree { return true }
                if !a.isFree && b.isFree { return false }
                return (Int(a.price ?? "999") ?? 999) < (Int(b.price ?? "999") ?? 999)
            case .priceDesc:
                if !a.isFree && b.isFree { return true }
                if a.isFree && !b.isFree { return false }
                return (Int(a.price ?? "0") ?? 0) > (Int(b.price ?? "0") ?? 0)
            case .durationAsc: return parseDuration(a.duration) < parseDuration(b.duration)
            }
        }
    }

    private func parseDuration(_ duration: String?) -> Int {
        guard let d = duration, let match = d.range(of: #"(\d+)"#, options: .regularExpression) else { return 999 }
        return Int(d[match]) ?? 999
    }

    // MARK: - Data

    private func loadData() async {
        // The exhibition feed itself is public — only the profile and
        // favorite/viewed state are tied to a signed-in user, so a guest
        // (nil userId) still gets the full feed, just without personalization.
        let userId = SupabaseService.shared.currentUser?.id.uuidString
        await locationManager.requestLocation()
        async let exhibitionsTask = SupabaseService.shared.fetchExhibitions()
        async let profileTask = fetchProfileIfSignedIn(userId)
        async let interactionsTask = fetchInteractionsIfSignedIn(userId)
        do {
            let fetchedExhibitions = try await exhibitionsTask
            let fetchedProfile = await profileTask
            let interactions = await interactionsTask
            let userLat = locationManager.location?.coordinate.latitude ?? 48.8566
            let userLng = locationManager.location?.coordinate.longitude ?? 2.3522
            let withDistance = fetchedExhibitions.map { ex -> Exhibition in
                var e = ex
                e.distance = haversine(lat1: userLat, lon1: userLng, lat2: ex.lat, lon2: ex.lng)
                return e
            }
            let sponsored = Array(withDistance.shuffled().prefix(12))
            await MainActor.run {
                self.profile = fetchedProfile
                self.exhibitions = withDistance
                self.sponsoredExhibitions = sponsored
                self.favoriteIds = interactions.filter { $0.isFavorite }.map { $0.exhibitionId }
                self.viewedIds = interactions.filter { $0.isViewed }.map { $0.exhibitionId }
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLoading = false
                }
            }
        }
    }

    private func fetchProfileIfSignedIn(_ userId: String?) async -> Profile? {
        guard let userId else { return nil }
        return try? await SupabaseService.shared.fetchProfile(userId: userId)
    }

    private func fetchInteractionsIfSignedIn(_ userId: String?) async -> [UserInteraction] {
        guard let userId else { return [] }
        return (try? await SupabaseService.shared.fetchInteractions(userId: userId)) ?? []
    }

    private func toggleFavorite(_ exhibition: Exhibition) async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        let wasFavorite = favoriteIds.contains(exhibition.id)
        await MainActor.run {
            if wasFavorite { favoriteIds.removeAll { $0 == exhibition.id } }
            else { favoriteIds.append(exhibition.id) }
        }
        if wasFavorite {
            NotificationService.shared.cancelNotification(
                identifier: NotificationService.endingSoonIdentifier(exhibitionId: exhibition.id)
            )
            AnalyticsService.shared.track("exhibition_unfavorited", properties: [
                "exhibition_id": exhibition.id,
                "exhibition_title": exhibition.title
            ])
        } else {
            AnalyticsService.shared.track("exhibition_favorited", properties: [
                "exhibition_id": exhibition.id,
                "exhibition_title": exhibition.title
            ])
        }
        try? await SupabaseService.shared.upsertInteraction(
            userId: userId, exhibitionId: exhibition.id,
            isFavorite: !wasFavorite, isViewed: viewedIds.contains(exhibition.id)
        )
    }

    private func toggleViewed(_ exhibition: Exhibition) async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        let wasViewed = viewedIds.contains(exhibition.id)
        await MainActor.run {
            if wasViewed { viewedIds.removeAll { $0 == exhibition.id } }
            else { viewedIds.append(exhibition.id) }
        }
        AnalyticsService.shared.track("exhibition_viewed_toggled", properties: [
            "exhibition_id": exhibition.id,
            "exhibition_title": exhibition.title,
            "is_viewed": !wasViewed
        ])
        try? await SupabaseService.shared.upsertInteraction(
            userId: userId, exhibitionId: exhibition.id,
            isFavorite: favoriteIds.contains(exhibition.id), isViewed: !wasViewed
        )
    }

    private func haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat/2)*sin(dLat/2) + cos(lat1 * .pi/180) * cos(lat2 * .pi/180) * sin(dLon/2)*sin(dLon/2)
        return (R * 2 * atan2(sqrt(a), sqrt(1-a)) * 10).rounded() / 10
    }
}

// MARK: - Sponsored Exhibition Card

struct SponsoredExhibitionCard: View {
    let exhibition: Exhibition
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: exhibition.image ?? "")) { phase in
                    Group {
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                                .transition(.opacity)
                        default:
                            Rectangle().fill(Color(.systemGray4))
                        }
                    }
                    .animation(.easeIn(duration: 0.25), value: phase.image != nil)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipped()

                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 140)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "sponsored_label"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(1)
                        Text(exhibition.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(exhibition.venue)
                            .font(.system(size: 12))
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
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sort Option

enum SortOption: String, CaseIterable {
    case relevance, closest, endingSoon, priceAsc, priceDesc, durationAsc
    var label: String {
        switch self {
        case .relevance: return String(localized: "sort_relevance")
        case .closest: return String(localized: "sort_closest")
        case .endingSoon: return String(localized: "sort_ending_soon")
        case .priceAsc: return String(localized: "sort_price_asc")
        case .priceDesc: return String(localized: "sort_price_desc")
        case .durationAsc: return String(localized: "sort_duration_asc")
        }
    }
}

// MARK: - Sort Menu Sheet

struct SortMenuSheet: View {
    @Binding var sortBy: SortOption
    @Environment(\.dismiss) private var dismiss

    private let selectionFeedback = UISelectionFeedbackGenerator()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "sort_by"))
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)

            VStack(spacing: 10) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    let isSelected = option == sortBy
                    Button(action: {
                        selectionFeedback.selectionChanged()
                        sortBy = option
                        dismiss()
                    }) {
                        HStack {
                            Text(option.label)
                                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .blue : .secondary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(isSelected ? Color.blue.opacity(0.08) : Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation? = nil

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() async {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

// MARK: - Shimmer

extension View {
    func shimmering() -> some View { self.modifier(ShimmerModifier()) }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, Color.white.opacity(0.4), .clear]),
                    startPoint: .init(x: phase - 0.3, y: 0.5),
                    endPoint: .init(x: phase + 0.3, y: 0.5)
                )
                .blendMode(.screen)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}
