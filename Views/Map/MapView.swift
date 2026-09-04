import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Type Colors
func typeColor(_ type: String) -> Color {
    switch type {
    case "Contemporary Art": return Color(red: 0.02, green: 0.48, blue: 0.78)
    case "Painting":         return Color(red: 0.82, green: 0.10, blue: 0.42)
    case "Sculpture":        return Color(red: 0.85, green: 0.45, blue: 0.00)
    case "Abstract Art":     return Color(red: 0.60, green: 0.10, blue: 0.75)
    case "Photography":      return Color(red: 0.05, green: 0.60, blue: 0.45)
    case "Asian Art":        return Color(red: 0.80, green: 0.15, blue: 0.15)
    case "Street Art":       return Color(red: 0.75, green: 0.55, blue: 0.00)
    case "Modern Art":       return Color(red: 0.85, green: 0.15, blue: 0.20)
    case "Installation":     return Color(red: 0.35, green: 0.20, blue: 0.80)
    case "Design":           return Color(red: 0.05, green: 0.55, blue: 0.35)
    default:                 return Color(red: 0.15, green: 0.39, blue: 0.92)
    }
}

// MARK: - Location Manager
final class MapLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}

// MARK: - MapView
struct MapView: View {

    @FocusState private var searchFocused: Bool
    @StateObject private var locationManager = MapLocationManager()
    @State private var exhibitions: [Exhibition] = []
    @State private var selectedExhibition: Exhibition? = nil
    @State private var showDetail = false
    @State private var search = ""
    @State private var showFilters = false
    @State private var filters = AppFilters()
    @State private var isSearchingAddress = false
    @State private var mapOpenedTime: Date?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )

    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    // MARK: - Computed

    var filteredExhibitions: [Exhibition] {
        exhibitions.filter { e in
            let matchSearch = search.isEmpty ||
                e.title.localizedCaseInsensitiveContains(search) ||
                e.venue.localizedCaseInsensitiveContains(search)
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

    var activeFiltersCount: Int {
        filters.types.count + filters.venues.count + filters.prices.count + filters.distances.count
    }

    /// Top exhibition matches for the search dropdown, ranked with title-prefix
    /// matches first (e.g. "leo" surfaces "Leonard de Vinci" before a venue-only match).
    private var searchSuggestions: [Exhibition] {
        guard !search.isEmpty else { return [] }
        let query = search.lowercased()
        let matches = exhibitions.filter {
            $0.title.lowercased().contains(query) || $0.venue.lowercased().contains(query)
        }
        let ranked = matches.sorted { a, b in
            matchScore(a, query: query) < matchScore(b, query: query)
        }
        return Array(ranked.prefix(5))
    }

    private var showSuggestions: Bool {
        searchFocused && !searchSuggestions.isEmpty
    }

    private func matchScore(_ exhibition: Exhibition, query: String) -> Int {
        let title = exhibition.title.lowercased()
        if title.hasPrefix(query) { return 0 }
        if title.contains(query) { return 1 }
        return 2
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {

            ClusteredMapView(
                region: $region,
                exhibitions: filteredExhibitions,
                selectedExhibition: $selectedExhibition,
                onSelectExhibition: { exhibition in
                    searchFocused = false
                    impactFeedback.impactOccurred()
                    AnalyticsService.shared.track("exhibition_card_clicked", properties: [
                        "exhibition_id": exhibition.id,
                        "exhibition_title": exhibition.title,
                        "source_screen": "map"
                    ])
                    selectedExhibition = exhibition
                },
                onDeselect: {
                    selectedExhibition = nil
                }
            )
            // Only extends edge-to-edge on the sides/bottom — keeping the
            // top safe area respected here (rather than covering it with
            // an overlay afterwards) avoids relying on SwiftUI compositing
            // order against MapKit's own native rendering (route-number
            // badges etc. draw at a level that a plain Color overlay on
            // top, in a separate layer, was confirmed not to cover).
            .ignoresSafeArea(edges: [.horizontal, .bottom])

            // MARK: - Top Bar
            VStack(spacing: 8) {
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                        TextField(String(localized: "search_exhibitions_address"), text: $search)
                            .focused($searchFocused)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .submitLabel(.search)
                            .onSubmit { performSearchOrGeocode() }
                        if isSearchingAddress {
                            ProgressView().scaleEffect(0.7)
                        }
                        if searchFocused || !search.isEmpty {
                            Button(action: {
                                search = ""
                                searchFocused = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                            }
                            .accessibilityLabel(String(localized: "clear_search"))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 0)

                if showSuggestions {
                    VStack(spacing: 0) {
                        ForEach(searchSuggestions) { exhibition in
                            Button(action: { selectSuggestion(exhibition) }) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(typeColor(exhibition.type).opacity(0.15))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Image(systemName: "mappin")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(typeColor(exhibition.type))
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exhibition.title)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(exhibition.venue)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            if exhibition.id != searchSuggestions.last?.id {
                                Divider().padding(.leading, 58)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.15), value: showSuggestions)

            // MARK: - Geolocate + Filter
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Button(action: {
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
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
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

                        Button(action: centerOnUser) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(width: 44, height: 44)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 24)
                }
            }

            // MARK: - Bottom Sheet
            if let exhibition = selectedExhibition {
                VStack {
                    Spacer()
                    BottomSheetCard(
                        exhibition: exhibition,
                        onDismiss: {
                            withAnimation(.spring(response: 0.3)) { selectedExhibition = nil }
                        },
                        onViewDetail: { showDetail = true }
                    )
                    .padding(.bottom, 83)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationDestination(isPresented: $showDetail) {
            if let exhibition = selectedExhibition {
                ExhibitionDetailView(exhibition: exhibition)
            }
        }
        .sheet(isPresented: $showFilters) {
            FilterSheet(filters: $filters)
                .presentationDetents([.large])
                .presentationCornerRadius(24)
        }
        .task {
            mapOpenedTime = Date()
            AnalyticsService.shared.screen("Map")

            impactFeedback.prepare()
            locationManager.requestLocation()
            await loadExhibitions()

            AnalyticsService.shared.track("map_opened", properties: [
                "exhibition_count": exhibitions.count,
                "center_lat": region.center.latitude,
                "center_lng": region.center.longitude
            ])
        }
        .onChange(of: locationManager.location) { _, location in
            AnalyticsService.shared.track("location_permission_granted", properties: [
                "latitude": location?.coordinate.latitude ?? 0,
                "longitude": location?.coordinate.longitude ?? 0
            ])

            recomputeDistances()
            if let sel = selectedExhibition, let updated = exhibitions.first(where: { $0.id == sel.id }) {
                selectedExhibition = updated
            }
        }
        .onChange(of: filters) { _, _ in
            AnalyticsService.shared.track("map_location_filtered", properties: [
                "filter_types_count": filters.types.count,
                "filter_venues_count": filters.venues.count,
                "filter_prices_count": filters.prices.count,
                "filter_distances_count": filters.distances.count,
                "exhibition_count": exhibitions.count
            ])
        }
        .onDisappear {
            if let mapOpenedTime = mapOpenedTime {
                let duration = Int(Date().timeIntervalSince(mapOpenedTime))
                AnalyticsService.shared.track("map_view_duration", properties: [
                    "duration_seconds": duration,
                    "exhibition_count": exhibitions.count,
                    "interactions_count": selectedExhibition != nil ? 1 : 0
                ])
            }
        }
    }

    // MARK: - Helpers

    private func selectSuggestion(_ exhibition: Exhibition) {
        impactFeedback.impactOccurred()
        search = ""
        searchFocused = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            selectedExhibition = exhibition
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: exhibition.lat, longitude: exhibition.lng),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }
    }

    private func performSearchOrGeocode() {
        searchFocused = false
        guard !search.isEmpty, searchSuggestions.isEmpty else { return }
        Task { await geocodeAddress(search) }
    }

    private func geocodeAddress(_ query: String) async {
        await MainActor.run { isSearchingAddress = true }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )
        let localSearch = MKLocalSearch(request: request)
        let response = try? await localSearch.start()
        await MainActor.run {
            isSearchingAddress = false
            guard let coordinate = response?.mapItems.first?.placemark.coordinate else { return }
            withAnimation {
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
        }
    }

    private func centerOnUser() {
        locationManager.requestLocation()
        if let location = locationManager.location {
            withAnimation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                )
            }
        }
    }

    private func loadExhibitions() async {
        if let data = try? await SupabaseService.shared.fetchExhibitions() {
            let userLat = locationManager.location?.coordinate.latitude ?? 48.8566
            let userLng = locationManager.location?.coordinate.longitude ?? 2.3522
            let withDistance = data.map { ex -> Exhibition in
                var e = ex
                e.distance = haversine(lat1: userLat, lon1: userLng, lat2: ex.lat, lon2: ex.lng)
                return e
            }
            await MainActor.run { self.exhibitions = withDistance }
        }
    }

    private func recomputeDistances() {
        guard let loc = locationManager.location else { return }
        let userLat = loc.coordinate.latitude
        let userLng = loc.coordinate.longitude
        exhibitions = exhibitions.map { ex in
            var e = ex
            e.distance = haversine(lat1: userLat, lon1: userLng, lat2: ex.lat, lon2: ex.lng)
            return e
        }
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

// MARK: - Exhibition Annotation

final class ExhibitionAnnotation: NSObject, MKAnnotation {
    let exhibition: Exhibition
    var coordinate: CLLocationCoordinate2D
    var title: String? { exhibition.title }

    init(exhibition: Exhibition) {
        self.exhibition = exhibition
        self.coordinate = CLLocationCoordinate2D(latitude: exhibition.lat, longitude: exhibition.lng)
    }
}

// MARK: - Manual Clustering
//
// MapKit's built-in `clusteringIdentifier` clustering doesn't give precise
// control over exactly when clusters dissolve — in practice it could leave
// a handful of exhibitions permanently stuck inside a cluster pin at any
// zoom level. Clusters are computed here instead, in plain Swift, driven
// entirely by the map's current span, so the dissolution point is exact
// and every exhibition is always reachable at street-level zoom.

/// A group of exhibitions rendered as a single pin when they're close enough
/// together at the current zoom level.
struct MapClusterGroup {
    let exhibitions: [Exhibition]

    var coordinate: CLLocationCoordinate2D {
        let count = Double(exhibitions.count)
        let avgLat = exhibitions.reduce(0) { $0 + $1.lat } / count
        let avgLng = exhibitions.reduce(0) { $0 + $1.lng } / count
        return CLLocationCoordinate2D(latitude: avgLat, longitude: avgLng)
    }
}

/// Groups exhibitions into clusters based on proximity, with the threshold
/// scaling to how zoomed-out the map currently is:
/// - below 0.005° span (street level): no clustering, every pin individual
/// - 0.005°–0.05° span (neighborhood level): group within ~100m
/// - above 0.05° span (city level): group within ~500m
func computeMapClusters(exhibitions: [Exhibition], span: MKCoordinateSpan) -> [MapClusterGroup] {
    let maxSpan = max(span.latitudeDelta, span.longitudeDelta)

    guard maxSpan >= 0.005 else {
        return exhibitions.map { MapClusterGroup(exhibitions: [$0]) }
    }

    let thresholdMeters: Double = maxSpan > 0.05 ? 500 : 100

    var groups: [[Exhibition]] = []
    var assigned = Set<Int>()

    for exhibition in exhibitions {
        guard !assigned.contains(exhibition.id) else { continue }
        var group = [exhibition]
        assigned.insert(exhibition.id)
        for candidate in exhibitions {
            guard !assigned.contains(candidate.id) else { continue }
            if metersBetween(exhibition, candidate) <= thresholdMeters {
                group.append(candidate)
                assigned.insert(candidate.id)
            }
        }
        groups.append(group)
    }

    return groups.map { MapClusterGroup(exhibitions: $0) }
}

private func metersBetween(_ a: Exhibition, _ b: Exhibition) -> Double {
    let R = 6_371_000.0
    let dLat = (b.lat - a.lat) * .pi / 180
    let dLon = (b.lng - a.lng) * .pi / 180
    let sinLat = sin(dLat / 2)
    let sinLon = sin(dLon / 2)
    let h = sinLat * sinLat + cos(a.lat * .pi / 180) * cos(b.lat * .pi / 180) * sinLon * sinLon
    return R * 2 * atan2(sqrt(h), sqrt(1 - h))
}

// MARK: - Overlapping Pin Spread
//
// At street level, individual (unclustered) exhibitions can still sit on
// top of each other exactly — most commonly several exhibitions at the same
// venue. This detects those near-identical coordinates and nudges each
// pin's *display* position into a small spread around the shared point, so
// every one stays visible and tappable. The underlying Exhibition models
// (and their real lat/lng) are never touched — only where the pin is drawn.

/// Groups of exhibitions within this many degrees of each other (~10m) are
/// treated as sharing a venue and get spread apart.
private let overlapProximityThreshold = 0.0001

/// Detects same-venue groups among already-individual exhibition pins and
/// offsets each pin's display coordinate so the group fans out instead of
/// stacking exactly on top of one another.
func spreadOverlappingPins(_ annotations: [ExhibitionAnnotation]) {
    guard annotations.count > 1 else { return }
    var assigned = Set<Int>()

    for annotation in annotations {
        let exhibition = annotation.exhibition
        guard !assigned.contains(exhibition.id) else { continue }

        var group = [annotation]
        assigned.insert(exhibition.id)
        for candidate in annotations {
            guard !assigned.contains(candidate.exhibition.id) else { continue }
            let latDiff = abs(candidate.exhibition.lat - exhibition.lat)
            let lonDiff = abs(candidate.exhibition.lng - exhibition.lng)
            if latDiff <= overlapProximityThreshold && lonDiff <= overlapProximityThreshold {
                group.append(candidate)
                assigned.insert(candidate.exhibition.id)
            }
        }

        guard group.count > 1 else { continue }
        let center = CLLocationCoordinate2D(latitude: exhibition.lat, longitude: exhibition.lng)
        let positions = spreadCoordinates(around: center, count: group.count)
        for (member, position) in zip(group, positions) {
            member.coordinate = position
        }
    }
}

/// Computes display coordinates for `count` pins fanned out around `center`:
/// - 2 pins: one offset left, one right (longitude only)
/// - 3+ pins: evenly spaced around a circle (a triangle for exactly 3)
private func spreadCoordinates(around center: CLLocationCoordinate2D, count: Int) -> [CLLocationCoordinate2D] {
    guard count > 1 else { return [center] }
    let radius = 0.00015

    if count == 2 {
        return [
            CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude - radius),
            CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude + radius)
        ]
    }

    return (0..<count).map { index in
        let angle = (2 * Double.pi / Double(count)) * Double(index)
        return CLLocationCoordinate2D(
            latitude: center.latitude + radius * sin(angle),
            longitude: center.longitude + radius * cos(angle)
        )
    }
}

final class ManualClusterAnnotation: NSObject, MKAnnotation {
    let group: MapClusterGroup
    var coordinate: CLLocationCoordinate2D

    init(group: MapClusterGroup) {
        self.group = group
        self.coordinate = group.coordinate
    }
}

// MARK: - Clustered Map View (UIKit MKMapView bridge)

struct ClusteredMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let exhibitions: [Exhibition]
    @Binding var selectedExhibition: Exhibition?
    let onSelectExhibition: (Exhibition) -> Void
    let onDeselect: () -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
        mapView.setRegion(region, animated: false)
        context.coordinator.refreshClusters(in: mapView, exhibitions: exhibitions)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        if context.coordinator.lastExhibitionIds != Set(exhibitions.map({ $0.id })) {
            context.coordinator.refreshClusters(in: mapView, exhibitions: exhibitions)
        }

        if !context.coordinator.isApproximatelyEqual(mapView.region, region) {
            mapView.setRegion(region, animated: true)
        }

        if selectedExhibition == nil, !mapView.selectedAnnotations.isEmpty {
            for annotation in mapView.selectedAnnotations {
                mapView.deselectAnnotation(annotation, animated: true)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ClusteredMapView
        private(set) var lastExhibitionIds: Set<Int> = []
        private var currentExhibitions: [Exhibition] = []

        init(_ parent: ClusteredMapView) {
            self.parent = parent
        }

        func isApproximatelyEqual(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
            abs(a.center.latitude - b.center.latitude) < 0.0001 &&
            abs(a.center.longitude - b.center.longitude) < 0.0001 &&
            abs(a.span.latitudeDelta - b.span.latitudeDelta) < 0.0001 &&
            abs(a.span.longitudeDelta - b.span.longitudeDelta) < 0.0001
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
            refreshClusters(in: mapView, exhibitions: currentExhibitions)
        }

        /// Recomputes clusters for the map's current span and replaces the
        /// annotation set. Called on load, whenever the filtered exhibitions
        /// list changes, and on every region change (zoom/pan), so clusters
        /// are always accurate for what's currently on screen.
        func refreshClusters(in mapView: MKMapView, exhibitions: [Exhibition]) {
            currentExhibitions = exhibitions
            lastExhibitionIds = Set(exhibitions.map { $0.id })

            let selectedId = parent.selectedExhibition?.id
            mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })

            let span = mapView.region.span
            let groups = computeMapClusters(exhibitions: exhibitions, span: span)
            var newAnnotations: [MKAnnotation] = []
            var individualPins: [ExhibitionAnnotation] = []
            for group in groups {
                if group.exhibitions.count == 1 {
                    let pin = ExhibitionAnnotation(exhibition: group.exhibitions[0])
                    newAnnotations.append(pin)
                    individualPins.append(pin)
                } else {
                    newAnnotations.append(ManualClusterAnnotation(group: group))
                }
            }

            // Street level (no clustering) is exactly where same-venue
            // exhibitions can end up stacked on the same coordinate.
            if max(span.latitudeDelta, span.longitudeDelta) < 0.005 {
                spreadOverlappingPins(individualPins)
            }

            mapView.addAnnotations(newAnnotations)

            if let selectedId,
               let match = newAnnotations.first(where: { ($0 as? ExhibitionAnnotation)?.exhibition.id == selectedId }) {
                mapView.selectAnnotation(match, animated: false)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let cluster = annotation as? ManualClusterAnnotation {
                let identifier = "exhibitionCluster"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                    ?? MKAnnotationView(annotation: cluster, reuseIdentifier: identifier)
                view.annotation = cluster
                let image = Self.renderClusterImage(count: cluster.group.exhibitions.count, diameter: 40)
                view.image = image
                view.centerOffset = .zero
                view.displayPriority = .required
                return view
            }

            guard let exhibitionAnnotation = annotation as? ExhibitionAnnotation else { return nil }
            let identifier = "exhibitionPin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: exhibitionAnnotation, reuseIdentifier: identifier)
            view.annotation = exhibitionAnnotation
            let isSelected = parent.selectedExhibition?.id == exhibitionAnnotation.exhibition.id
            let image = Self.renderPinImage(exhibition: exhibitionAnnotation.exhibition, isSelected: isSelected)
            view.image = image
            view.centerOffset = CGPoint(x: 0, y: -image.size.height / 2)
            view.displayPriority = .required
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? ManualClusterAnnotation {
                zoomToCluster(cluster, in: mapView)
                return
            }
            guard let exhibitionAnnotation = view.annotation as? ExhibitionAnnotation else { return }
            let image = Self.renderPinImage(exhibition: exhibitionAnnotation.exhibition, isSelected: true)
            view.image = image
            view.centerOffset = CGPoint(x: 0, y: -image.size.height / 2)
            parent.onSelectExhibition(exhibitionAnnotation.exhibition)
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            guard let exhibitionAnnotation = view.annotation as? ExhibitionAnnotation else { return }
            let image = Self.renderPinImage(exhibition: exhibitionAnnotation.exhibition, isSelected: false)
            view.image = image
            view.centerOffset = CGPoint(x: 0, y: -image.size.height / 2)
            parent.onDeselect()
        }

        /// Zooms into a tapped cluster: centers on its coordinate and shrinks
        /// the span to a third of its current size, so a single tap makes real
        /// visible progress splitting it apart. `regionDidChangeAnimated`
        /// recomputes clusters for the new span once the zoom lands.
        private func zoomToCluster(_ cluster: ManualClusterAnnotation, in mapView: MKMapView) {
            mapView.deselectAnnotation(cluster, animated: false)
            let currentSpan = mapView.region.span
            let newRegion = MKCoordinateRegion(
                center: cluster.coordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: currentSpan.latitudeDelta / 3,
                    longitudeDelta: currentSpan.longitudeDelta / 3
                )
            )
            mapView.setRegion(newRegion, animated: true)
            parent.region = newRegion
        }

        @MainActor
        static func renderPinImage(exhibition: Exhibition, isSelected: Bool) -> UIImage {
            let renderer = ImageRenderer(content: MapPinView(exhibition: exhibition, isSelected: isSelected))
            renderer.scale = UIScreen.main.scale
            return renderer.uiImage ?? UIImage()
        }

        @MainActor
        static func renderClusterImage(count: Int, diameter: CGFloat) -> UIImage {
            let renderer = ImageRenderer(content: ClusterPinView(count: count, diameter: diameter))
            renderer.scale = UIScreen.main.scale
            return renderer.uiImage ?? UIImage()
        }
    }
}

// MARK: - Cluster Pin

struct ClusterPinView: View {
    let count: Int
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.15, green: 0.39, blue: 0.92))
                .frame(width: diameter, height: diameter)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            Circle()
                .stroke(Color.white, lineWidth: 2.5)
                .frame(width: diameter, height: diameter)
            Text("\(count)")
                .font(.system(size: diameter * 0.36, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: diameter + 6, height: diameter + 6)
    }
}

// MARK: - Map Pin
struct MapPinView: View {
    let exhibition: Exhibition
    let isSelected: Bool
    var color: Color { typeColor(exhibition.type) }

    private var circleDiameter: CGFloat { isSelected ? 52 : 36 }
    private var triangleWidth: CGFloat { isSelected ? 14 : 10 }
    private var triangleHeight: CGFloat { isSelected ? 8 : 6 }

    var body: some View {
        // This pin is a teardrop — circle plus a pointed tail — not a plain
        // circle, so a single Circle clip isn't enough: the shadow needs to
        // trace that whole silhouette. Same root cause and fix as the
        // cluster pin: rendered offscreen via ImageRenderer, an unclipped
        // shape's shadow traces its square layer bounds instead of its
        // alpha silhouette. Clipping the fully composited pin to the
        // unified teardrop shape *before* the shadow forces the shadow to
        // follow the actual circle+tail outline.
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(color)
                Circle()
                    .stroke(Color.white, lineWidth: isSelected ? 3 : 2)
                Image(systemName: typeIcon(exhibition.type))
                    .font(.system(size: isSelected ? 22 : 15, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: circleDiameter, height: circleDiameter)

            Triangle()
                .fill(color)
                .frame(width: triangleWidth, height: triangleHeight)
        }
        .compositingGroup()
        .clipShape(MapPinShape(circleDiameter: circleDiameter, triangleWidth: triangleWidth, triangleHeight: triangleHeight))
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }

    func typeIcon(_ type: String) -> String {
        switch type {
        case "Photography":      return "camera.fill"
        case "Sculpture":        return "circle.hexagongrid.fill"
        case "Street Art":       return "paintbrush.fill"
        case "Design":           return "pencil.and.ruler.fill"
        case "Painting":         return "paintpalette.fill"
        case "Contemporary Art": return "sparkles"
        case "Modern Art":       return "flame.fill"
        case "Abstract Art":     return "scribble.variable"
        case "Installation":     return "cube.fill"
        case "Asian Art":        return "seal.fill"
        default:                 return "photo.artframe"
        }
    }
}

// MARK: - Map Pin Shape
//
// Unifies the pin's circle and pointed tail into a single Shape so
// `.clipShape` + `.shadow` can trace the whole teardrop silhouette as one
// piece, rather than the circle and the tail each casting their own
// (incorrectly square, under ImageRenderer) shadow independently.
struct MapPinShape: Shape {
    let circleDiameter: CGFloat
    let triangleWidth: CGFloat
    let triangleHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(ellipseIn: CGRect(x: rect.minX, y: rect.minY, width: circleDiameter, height: circleDiameter))

        let midX = rect.minX + circleDiameter / 2
        let tailTop = rect.minY + circleDiameter
        let tailBottom = tailTop + triangleHeight

        var tail = Path()
        tail.move(to: CGPoint(x: midX, y: tailBottom))
        tail.addLine(to: CGPoint(x: midX - triangleWidth / 2, y: tailTop))
        tail.addLine(to: CGPoint(x: midX + triangleWidth / 2, y: tailTop))
        tail.closeSubpath()

        path.addPath(tail)
        return path
    }
}

// MARK: - Triangle
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Bottom Sheet Card
struct BottomSheetCard: View {
    let exhibition: Exhibition
    let onDismiss: () -> Void
    let onViewDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                AsyncImage(url: URL(string: exhibition.image ?? "")) { phase in
                    Group {
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                                .transition(.opacity)
                        default:
                            Rectangle().fill(Color(.systemGray5))
                        }
                    }
                    .animation(.easeIn(duration: 0.25), value: phase.image != nil)
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 24))

                VStack(alignment: .leading, spacing: 6) {
                    TagBadge(label: exhibition.type, color: typeColor(exhibition.type).opacity(0.85))
                    Text(exhibition.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(2)
                    Text(exhibition.venue)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    if let distance = exhibition.distance {
                        Label(String(format: "%.1f km", distance), systemImage: "location.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        Label(String(localized: "locating"), systemImage: "location")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)

            Button(action: onViewDetail) {
                Text(String(localized: "view_exhibition"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: -4)
        .padding(.horizontal, 12)
    }
}

#Preview {
    NavigationStack {
        MapView()
    }
}
