import SwiftUI
import Auth

struct ViewedView: View {

    @State private var exhibitions: [Exhibition] = []
    @State private var isLoading = true
    @State private var favoriteIds: [Int] = []
    @State private var viewedIds: [Int] = []
    @State private var selectedExhibition: Exhibition? = nil

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if exhibitions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No viewed exhibitions")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Exhibitions you mark as viewed will appear here")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(exhibitions) { exhibition in
                                ExhibitionCard(
                                    exhibition: exhibition,
                                    isFavorite: favoriteIds.contains(exhibition.id),
                                    isViewed: viewedIds.contains(exhibition.id),
                                    onTap: { selectedExhibition = exhibition },
                                    onToggleFavorite: { Task { await toggleFavorite(exhibition) } },
                                    onToggleViewed: { Task { await toggleViewed(exhibition) } }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Viewed")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $selectedExhibition) { exhibition in
                ExhibitionDetailView(exhibition: exhibition)
            }
        }
        .task {
            await loadViewed()
        }
    }

    private func loadViewed() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        do {
            let interactions = try await SupabaseService.shared.fetchInteractions(userId: userId)
            let favIds = interactions.filter { $0.isFavorite }.map { $0.exhibitionId }
            let vIds = interactions.filter { $0.isViewed }.map { $0.exhibitionId }

            if vIds.isEmpty {
                await MainActor.run {
                    self.favoriteIds = favIds
                    self.viewedIds = []
                    self.exhibitions = []
                    self.isLoading = false
                }
                return
            }

            let allExhibitions = try await SupabaseService.shared.fetchExhibitions()
            let viewedExhibitions = allExhibitions.filter { vIds.contains($0.id) }

            await MainActor.run {
                self.favoriteIds = favIds
                self.viewedIds = vIds
                self.exhibitions = viewedExhibitions
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
                exhibitions.removeAll { $0.id == exhibition.id }
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
}

#Preview {
    ViewedView()
}
