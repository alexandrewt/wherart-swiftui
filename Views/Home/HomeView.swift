import SwiftUI
import CoreLocation
import Combine
import Auth

struct HomeView: View {

    @StateObject private var locationManager = LocationManager()
    @State private var exhibitions: [Exhibition] = []
    @State private var favoriteIds: [Int] = []
    @State private var viewedIds: [Int] = []
    @State private var profile: Profile? = nil
    @State private var isLoading = true
    @State private var search = ""
    @State private var sortBy: SortOption = .relevance
    @State private var showSortMenu = false
    @State private var selectedExhibition: Exhibition? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {

                    // MARK: - Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search exhibitions...", text: $search)
                            .font(.system(size: 15))
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                    // MARK: - Feed
                    if isLoading {
                        skeletonFeed
                    } else {
                        feedContent
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSortMenu = true }) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 15, weight: .medium))
                    }
                }
            }
            .confirmationDialog("Sort by", isPresented: $showSortMenu, titleVisibility: .visible) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(option.label) { sortBy = option }
                }
                Button("Cancel", role: .cancel) {}
            }
            .navigationDestination(item: $selectedExhibition) { exhibition in
                ExhibitionDetailView(exhibition: exhibition)
            }
        }
        .task {
            await loadData()
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
                    sectionHeader(title: "Exhibitions for you")
                    ForEach(forYou) { exhibition in
                        ExhibitionCard(
                            exhibition: exhibition,
                            isFavorite: favoriteIds.contains(exhibition.id),
                            isViewed: viewedIds.contains(exhibition.id),
                            onTap: { selectedExhibition = exhibition },
                            onToggleFavorite: { Task { await toggleFavorite(exhibition) } },
                            onToggleViewed: { Task { await toggleViewed(exhibition) } }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
                if !mightLike.isEmpty {
                    sectionHeader(title: "Exhibitions you might like")
                    ForEach(mightLike) { exhibition in
                        ExhibitionCard(
                            exhibition: exhibition,
                            isFavorite: favoriteIds.contains(exhibition.id),
                            isViewed: viewedIds.contains(exhibition.id),
                            onTap: { selectedExhibition = exhibition },
                            onToggleFavorite: { Task { await toggleFavorite(exhibition) } },
                            onToggleViewed: { Task { await toggleViewed(exhibition) } }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            } else {
                sectionHeader(title: "Exhibitions near you")
                ForEach(sorted(filtered)) { exhibition in
                    ExhibitionCard(
                        exhibition: exhibition,
                        isFavorite: favoriteIds.contains(exhibition.id),
                        isViewed: viewedIds.contains(exhibition.id),
                        onTap: { selectedExhibition = exhibition },
                        onToggleFavorite: { Task { await toggleFavorite(exhibition) } },
                        onToggleViewed: { Task { await toggleViewed(exhibition) } }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
    }

    // MARK: - Skeleton
    private var skeletonFeed: some View {
        ForEach(0..<4, id: \.self) { _ in
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray5))
                    .frame(height: 200)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                    .padding(.horizontal, 16)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(width: 120, height: 12)
                    .padding(.horizontal, 16)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .redacted(reason: .placeholder)
            .shimmering()
        }
    }

    // MARK: - Computed
    private var greeting: String {
        if let name = profile?.firstName, !name.isEmpty {
            return "Hello, \(name)"
        }
        return "Discover"
    }

    private var filteredExhibitions: [Exhibition] {
        guard !search.isEmpty else { return exhibitions }
        return exhibitions.filter {
            $0.title.localizedCaseInsensitiveContains(search) ||
            $0.venue.localizedCaseInsensitiveContains(search)
        }
    }

    private func matchesProfile(_ exhibition: Exhibition) -> Bool {
        let prefs = profile?.preferences ?? []
        let venues = profile?.venueTypes ?? []
        if prefs.isEmpty && venues.isEmpty { return true }
        let typeMatch = prefs.isEmpty || prefs.contains(exhibition.type)
        let venueMatch = venues.isEmpty || venues.contains(exhibition.venueType)
        return typeMatch && venueMatch
    }

    private func sorted(_ list: [Exhibition]) -> [Exhibition] {
        list.sorted { a, b in
            switch sortBy {
            case .relevance: return false
            case .closest:
                return (a.distance ?? 999) < (b.distance ?? 999)
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
            case .durationAsc:
                return parseDuration(a.duration) < parseDuration(b.duration)
            }
        }
    }

    private func parseDuration(_ duration: String?) -> Int {
        guard let d = duration, let match = d.range(of: #"(\d+)"#, options: .regularExpression) else { return 999 }
        return Int(d[match]) ?? 999
    }

    // MARK: - Data
    private func loadData() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }

        await locationManager.requestLocation()

        async let profileTask = SupabaseService.shared.fetchProfile(userId: userId)
        async let exhibitionsTask = SupabaseService.shared.fetchExhibitions()
        async let interactionsTask = SupabaseService.shared.fetchInteractions(userId: userId)

        do {
            let (fetchedProfile, fetchedExhibitions, interactions) = try await (profileTask, exhibitionsTask, interactionsTask)

            let userLat = locationManager.location?.coordinate.latitude ?? 48.8566
            let userLng = locationManager.location?.coordinate.longitude ?? 2.3522

            let withDistance = fetchedExhibitions.map { ex -> Exhibition in
                var e = ex
                e.distance = haversine(lat1: userLat, lon1: userLng, lat2: ex.lat, lon2: ex.lng)
                return e
            }

            await MainActor.run {
                self.profile = fetchedProfile
                self.exhibitions = withDistance
                self.favoriteIds = interactions.filter { $0.isFavorite }.map { $0.exhibitionId }
                self.viewedIds = interactions.filter { $0.isViewed }.map { $0.exhibitionId }
                self.isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func toggleFavorite(_ exhibition: Exhibition) async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        let wasFavorite = favoriteIds.contains(exhibition.id)
        await MainActor.run {
            if wasFavorite {
                favoriteIds.removeAll { $0 == exhibition.id }
            } else {
                favoriteIds.append(exhibition.id)
            }
        }
        try? await SupabaseService.shared.upsertInteraction(
            userId: userId,
            exhibitionId: exhibition.id,
            isFavorite: !wasFavorite,
            isViewed: viewedIds.contains(exhibition.id)
        )
    }

    private func toggleViewed(_ exhibition: Exhibition) async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        let wasViewed = viewedIds.contains(exhibition.id)
        await MainActor.run {
            if wasViewed {
                viewedIds.removeAll { $0 == exhibition.id }
            } else {
                viewedIds.append(exhibition.id)
            }
        }
        try? await SupabaseService.shared.upsertInteraction(
            userId: userId,
            exhibitionId: exhibition.id,
            isFavorite: favoriteIds.contains(exhibition.id),
            isViewed: !wasViewed
        )
    }

    private func haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat/2)*sin(dLat/2) +
            cos(lat1 * .pi/180) * cos(lat2 * .pi/180) *
            sin(dLon/2)*sin(dLon/2)
        return (R * 2 * atan2(sqrt(a), sqrt(1-a)) * 10).rounded() / 10
    }
}

// MARK: - Sort Option
enum SortOption: String, CaseIterable {
    case relevance, closest, endingSoon, priceAsc, priceDesc, durationAsc

    var label: String {
        switch self {
        case .relevance: return "Relevance"
        case .closest: return "Closest"
        case .endingSoon: return "Ending soon"
        case .priceAsc: return "Price: low to high"
        case .priceDesc: return "Price: high to low"
        case .durationAsc: return "Duration: shortest first"
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

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}

// MARK: - Shimmer
extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        Color.white.opacity(0.4),
                        .clear
                    ]),
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
