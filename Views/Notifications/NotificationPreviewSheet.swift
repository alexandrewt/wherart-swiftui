import SwiftUI

struct NotificationPreviewSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var nav: AppNavigation
    @State private var exhibitions: [Exhibition] = []
    @State private var isLoading = true
    @State private var selectedExhibition: Exhibition?

    let notification: AppNotification
    @StateObject private var supabaseService = SupabaseService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("\(exhibitions.count) \(exhibitions.count == 1 ? "Exhibition" : "Exhibitions")")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)

                Divider()

                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if exhibitions.isEmpty {
                    VStack {
                        Spacer()
                        Text("No exhibitions to display")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(exhibitions) { expo in
                                NavigationLink(destination: ExhibitionDetailView(exhibition: expo)) {
                                    ExhibitionPreviewCard(exhibition: expo)
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationDestination(item: $selectedExhibition) { exhibition in
            ExhibitionDetailView(exhibition: exhibition)
        }
        .onAppear {
            loadExhibitions()
        }
    }

    private func loadExhibitions() {
        Task {
            do {
                if let ids = notification.exhibitionIds, !ids.isEmpty {
                    var fetchedExhibitions: [Exhibition] = []

                    for id in ids {
                        do {
                            let expo = try await supabaseService.fetchExhibitionById(id: id)
                            fetchedExhibitions.append(expo)
                        } catch {
                            print("[NotificationPreviewSheet] Error fetching exhibition \(id): \(error)")
                        }
                    }

                    exhibitions = fetchedExhibitions
                }
                isLoading = false
            } catch {
                print("[NotificationPreviewSheet] Error loading exhibitions: \(error)")
                isLoading = false
            }
        }
    }
}

struct ExhibitionPreviewCard: View {
    let exhibition: Exhibition

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageUrl = exhibition.image {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 150)
                            .clipped()
                    case .loading:
                        ProgressView()
                            .frame(height: 150)
                    case .empty:
                        Color.gray.frame(height: 150)
                    @unknown default:
                        Color.gray.frame(height: 150)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(exhibition.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(exhibition.venue)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let distance = exhibition.distance {
                        Label("\(String(format: "%.1f", distance)) km", systemImage: "location.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    if let price = exhibition.price {
                        Text(price)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                    } else {
                        Text(String(localized: "free"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(8)
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    NotificationPreviewSheet(
        notification: AppNotification(
            id: UUID(),
            userId: UUID(),
            exhibitionIds: [123, 456, 789],
            title: "3 New Exhibitions",
            body: "Check out these new shows matching your taste",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            isRead: false
        )
    )
    .environmentObject(AppNavigation())
}
