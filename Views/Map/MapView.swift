import SwiftUI
import MapKit
import Auth

struct MapView: View {

    @State private var exhibitions: [Exhibition] = []
    @State private var selectedExhibition: Exhibition? = nil
    @State private var showDetail = false
    @State private var search = ""
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )
    @State private var locationManager = CLLocationManager()

    var filteredExhibitions: [Exhibition] {
        guard !search.isEmpty else { return exhibitions }
        return exhibitions.filter {
            $0.title.localizedCaseInsensitiveContains(search) ||
            $0.venue.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {

            // MARK: - Map
            Map(position: $cameraPosition) {
                ForEach(filteredExhibitions) { exhibition in
                    Annotation(exhibition.title, coordinate: CLLocationCoordinate2D(
                        latitude: exhibition.lat,
                        longitude: exhibition.lng
                    )) {
                        MapMarker(exhibition: exhibition, isSelected: selectedExhibition?.id == exhibition.id)
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

            // MARK: - Search Bar
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search exhibitions...", text: $search)
                        .font(.system(size: 15))
                    if !search.isEmpty {
                        Button(action: { search = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }

            // MARK: - Geolocate Button
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
                    .padding(.bottom, selectedExhibition != nil ? 260 : 100)
                }
            }

            // MARK: - Bottom Sheet
            if let exhibition = selectedExhibition {
                VStack {
                    Spacer()
                    BottomSheetCard(
                        exhibition: exhibition,
                        onDismiss: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedExhibition = nil
                            }
                        },
                        onViewDetail: {
                            showDetail = true
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationDestination(isPresented: $showDetail) {
            if let exhibition = selectedExhibition {
                ExhibitionDetailView(exhibition: exhibition)
            }
        }
        .task {
            await loadExhibitions()
        }
        .onAppear {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    // MARK: - Actions
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
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        if let data = try? await SupabaseService.shared.fetchExhibitions() {
            let userLat = locationManager.location?.coordinate.latitude ?? 48.8566
            let userLng = locationManager.location?.coordinate.longitude ?? 2.3522
            let withDistance = data.map { ex -> Exhibition in
                var e = ex
                e.distance = haversine(lat1: userLat, lon1: userLng, lat2: ex.lat, lon2: ex.lng)
                return e
            }
            await MainActor.run {
                self.exhibitions = withDistance
            }
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

// MARK: - Map Marker
struct MapMarker: View {
    let exhibition: Exhibition
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color.white)
                    .frame(width: isSelected ? 44 : 36, height: isSelected ? 44 : 36)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                Image(systemName: "photo.artframe")
                    .font(.system(size: isSelected ? 18 : 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .blue)
            }

            if isSelected {
                Text(exhibition.venue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(Capsule())
                    .fixedSize()
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Bottom Sheet Card
struct BottomSheetCard: View {
    let exhibition: Exhibition
    let onDismiss: () -> Void
    let onViewDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            HStack(alignment: .top, spacing: 14) {

                // Image
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

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    TagBadge(label: exhibition.type, color: Color(red: 0.58, green: 0.77, blue: 0.99))

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

            // CTA
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
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: -4)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

#Preview {
    NavigationStack {
        MapView()
    }
}
