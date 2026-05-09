import SwiftUI
import MapKit
import Auth

// MARK: - Type Colors
func typeColor(_ type: String) -> Color {
    switch type {
    case "Contemporary Art": return Color(red: 0.05, green: 0.65, blue: 0.91)
    case "Painting": return Color(red: 0.93, green: 0.29, blue: 0.60)
    case "Sculpture": return Color(red: 0.99, green: 0.73, blue: 0.45)
    case "Abstract Art": return Color(red: 0.98, green: 0.63, blue: 0.78)
    case "Photography": return Color(red: 0.43, green: 0.91, blue: 0.72)
    case "Asian Art": return Color(red: 0.99, green: 0.64, blue: 0.64)
    case "Street Art": return Color(red: 0.99, green: 0.83, blue: 0.30)
    case "Modern Art": return Color(red: 0.96, green: 0.27, blue: 0.36)
    case "Installation": return Color(red: 0.67, green: 0.56, blue: 0.99)
    case "Design": return Color(red: 0.20, green: 0.80, blue: 0.60)
    default: return Color(red: 0.58, green: 0.77, blue: 0.99)
    }
}

struct MapView: View {

    @State private var exhibitions: [Exhibition] = []
    @State private var selectedExhibition: Exhibition? = nil
    @State private var showDetail = false
    @State private var search = ""
    @State private var showFilters = false
    @State private var filters = AppFilters()
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )
    @State private var locationManager = CLLocationManager()

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
            return matchSearch && matchType && matchVenue && matchPrice && matchDist
        }
    }

    var activeFiltersCount: Int {
        filters.types.count + filters.venues.count + filters.prices.count + filters.distances.count
    }

    var body: some View {
        ZStack(alignment: .top) {

            Map(position: $cameraPosition) {
                ForEach(filteredExhibitions) { exhibition in
                    Annotation(exhibition.title, coordinate: CLLocationCoordinate2D(
                        latitude: exhibition.lat,
                        longitude: exhibition.lng
                    )) {
                        MapPinView(
                            exhibition: exhibition,
                            isSelected: selectedExhibition?.id == exhibition.id
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                selectedExhibition = exhibition
                            }
                        }
                    }
                }
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()

            // MARK: - Top Bar
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                        TextField("Search exhibitions...", text: $search)
                            .font(.system(size: 15))
                        if !search.isEmpty {
                            Button(action: { search = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button(action: { showFilters = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
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
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // MARK: - Geolocate
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: centerOnUser) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, selectedExhibition != nil ? 220 : 100)
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
        }
        .task { await loadExhibitions() }
        .onAppear { locationManager.requestWhenInUseAuthorization() }
    }

    private func centerOnUser() {
        if let location = locationManager.location {
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                ))
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

// MARK: - Map Pin
struct MapPinView: View {
    let exhibition: Exhibition
    let isSelected: Bool
    var color: Color { typeColor(exhibition.type) }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: isSelected ? 44 : 32, height: isSelected ? 44 : 32)
                    .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 2)
                Image(systemName: typeIcon(exhibition.type))
                    .font(.system(size: isSelected ? 18 : 13, weight: .medium))
                    .foregroundColor(.white)
            }
            if isSelected {
                Text(exhibition.venue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color)
                    .clipShape(Capsule())
                    .fixedSize()
            }
            Triangle()
                .fill(color)
                .frame(width: 10, height: 6)
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }

    private func typeIcon(_ type: String) -> String {
        switch type {
        case "Photography": return "camera.fill"
        case "Sculpture": return "circle.hexagongrid.fill"
        case "Street Art": return "paintbrush.fill"
        case "Design": return "pencil.and.ruler.fill"
        default: return "photo.artframe"
        }
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
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            HStack(alignment: .top, spacing: 14) {
                AsyncImage(url: URL(string: exhibition.image ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(Color(.systemGray5))
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))

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

            Button(action: onViewDetail) {
                Text("View exhibition")
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
