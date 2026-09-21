import SwiftUI

struct NotificationPreviewSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var exhibitions: [Exhibition] = []
    @State private var isLoading = true

    let exhibitionIds: [Int]
    @StateObject private var supabaseService = SupabaseService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text(String(format: String(localized: "notification_exhibitions_count"), exhibitionIds.count))
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
                        Text(String(localized: "notification_no_exhibitions"))
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
        .onAppear {
            loadExhibitions()
        }
    }

    private func loadExhibitions() {
        Task {
            do {
                let ids = exhibitionIds
                if !ids.isEmpty {
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
                    case .empty:
                        ZStack {
                            Color(.systemGray5)
                            ProgressView()
                        }
                        .frame(height: 150)
                    case .failure:
                        Color(.systemGray4)
                            .frame(height: 150)
                    @unknown default:
                        Color.gray.frame(height: 150)
                    }
                }
            } else {
                Color(.systemGray5)
                    .frame(height: 150)
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
    NotificationPreviewSheet(exhibitionIds: [123, 456, 789])
}
