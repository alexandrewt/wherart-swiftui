import SwiftUI
import Auth

struct VisitView: View {

    @State private var selectedTab = 0
    @State private var discoverGroups: [WherartGroup] = []
    @State private var myGroups: [WherartGroup] = []
    @State private var isLoading = true
    @State private var selectedGroup: WherartGroup? = nil
    @State private var showCreateVisit = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: - Tabs
                HStack(spacing: 0) {
                    TabButton(title: "Discover", isSelected: selectedTab == 0) {
                        withAnimation { selectedTab = 0 }
                    }
                    TabButton(title: "My visits", isSelected: selectedTab == 1) {
                        withAnimation { selectedTab = 1 }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)

                // MARK: - Content
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if selectedTab == 0 {
                    discoverContent
                } else {
                    myVisitsContent
                }
            }
            .navigationTitle("Visits")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showCreateVisit = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .sheet(isPresented: $showCreateVisit) {
                CreateVisitView(onCreated: { group in
                    myGroups.insert(group, at: 0)
                    showCreateVisit = false
                    selectedTab = 1
                })
                .presentationDetents([.large])
            }
            .navigationDestination(item: $selectedGroup) { group in
                VisitDetailView(group: group, onLeft: {
                    myGroups.removeAll { $0.id == group.id }
                })
            }
        }
        .task {
            await loadGroups()
        }
    }

    // MARK: - Discover
    private var discoverContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if discoverGroups.isEmpty {
                    emptyState(
                        icon: "person.2",
                        title: "No visits yet",
                        subtitle: "Be the first to organise a visit"
                    )
                } else {
                    ForEach(discoverGroups) { group in
                        GroupCard(
                            group: group,
                            isMyVisit: false,
                            onTap: { selectedGroup = group }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - My Visits
    private var myVisitsContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if myGroups.isEmpty {
                    emptyState(
                        icon: "calendar.badge.plus",
                        title: "No visits planned",
                        subtitle: "Join or create a visit to get started"
                    )
                } else {
                    ForEach(myGroups) { group in
                        GroupCard(
                            group: group,
                            isMyVisit: true,
                            onTap: { selectedGroup = group }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await leaveGroup(group) }
                            } label: {
                                Label("Leave", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Empty State
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 18, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Data
    private func loadGroups() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        async let allGroupsTask = SupabaseService.shared.fetchGroups()
        async let myGroupsTask = SupabaseService.shared.fetchMyGroups(userId: userId)
        do {
            let (all, mine) = try await (allGroupsTask, myGroupsTask)
            await MainActor.run {
                self.discoverGroups = all
                self.myGroups = mine
                self.isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func leaveGroup(_ group: WherartGroup) async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        try? await SupabaseService.shared.leaveGroup(groupId: group.id, userId: userId)
        await MainActor.run {
            myGroups.removeAll { $0.id == group.id }
        }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(height: 2)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }
}

// MARK: - Group Card
struct GroupCard: View {
    let group: WherartGroup
    let isMyVisit: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Exhibition #\(group.exhibitionId)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 16) {
                    Label(group.startDate, systemImage: "calendar")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    if let time = group.time {
                        Label(time, systemImage: "clock")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    let memberCount = group.members?.count ?? 0
                    Label("\(memberCount)/\(group.maxMembers)", systemImage: "person.2")
                        .font(.system(size: 13))
                        .foregroundColor(memberCount >= group.maxMembers ? .red : .secondary)
                }

                if isMyVisit {
                    Text("Swipe left to leave")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VisitView()
}
