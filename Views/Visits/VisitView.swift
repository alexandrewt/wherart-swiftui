import SwiftUI
import Auth

struct VisitView: View {

    @Binding var defaultTab: Int
    @State private var selectedTab: Int
    @State private var discoverGroups: [WherartGroup] = []
    @State private var myGroups: [WherartGroup] = []
    @State private var isLoading = true
    @State private var selectedGroup: WherartGroup? = nil
    @State private var showCreateVisit = false
    @State private var exhibitionsMap: [Int: Exhibition] = [:]
    @State private var visitsLoadedTime: Date?

    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let warningFeedback = UINotificationFeedbackGenerator()

    init(defaultTab: Binding<Int>) {
        self._defaultTab = defaultTab
        self._selectedTab = State(initialValue: defaultTab.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                HStack(spacing: 0) {
                    PillToggleButton(label: String(localized: "discover"), isSelected: selectedTab == 0) {
                        selectionFeedback.selectionChanged()
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 0 }
                    }
                    PillToggleButton(label: String(localized: "my_visits"), isSelected: selectedTab == 1) {
                        selectionFeedback.selectionChanged()
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 1 }
                    }
                }
                .padding(4)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)

                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if selectedTab == 0 {
                    discoverContent
                        .id("discover")
                        .transition(.opacity)
                } else {
                    myVisitsContent
                        .id("myvisits")
                        .transition(.opacity)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showCreateVisit = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color(red: 0.15, green: 0.39, blue: 0.92))
                            .clipShape(Circle())
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
                .presentationCornerRadius(24)
            }
            .navigationDestination(item: $selectedGroup) { group in
                VisitDetailView(group: group, onLeft: {
                    myGroups.removeAll { $0.id == group.id }
                })
            }
        }
        .task {
            visitsLoadedTime = Date()
            AnalyticsService.shared.screen("Visits")
            await loadGroups()
        }
        .onAppear {
            if defaultTab == 1 {
                selectedTab = 1
                defaultTab = 0
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            let tabNames = ["discover", "my_visits"]
            AnalyticsService.shared.track("visits_tab_switched", properties: [
                "tab": tabNames[newTab],
                "tab_index": newTab
            ])
        }
    }

    // MARK: - Discover Content

    private var discoverContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if discoverGroups.isEmpty {
                    emptyState(icon: "person.2", title: String(localized: "no_visits_yet"), subtitle: String(localized: "be_first_organise_visit"))
                } else {
                    ForEach(Array(discoverGroups.enumerated()), id: \.element.id) { index, group in
                        VisitCard(group: group, isMyVisit: false, onTap: {
                            AnalyticsService.shared.track("visit_details_viewed", properties: [
                                "visit_id": group.id,
                                "exhibition_title": exhibitionsMap[group.exhibitionId]?.title ?? "Unknown",
                                "member_count": group.members?.count ?? 0,
                                "tab_source": "discover"
                            ])
                            selectedGroup = group
                        }, exhibitionsMap: exhibitionsMap)
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(Double(index) * 0.05),
                                value: discoverGroups.count
                            )
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - My Visits Content

    private var myVisitsContent: some View {
        List {
            if myGroups.isEmpty {
                emptyState(icon: "calendar.badge.plus", title: String(localized: "no_visits_planned"), subtitle: String(localized: "join_or_create_visit"))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(Array(myGroups.enumerated()), id: \.element.id) { index, group in
                    VisitCard(group: group, isMyVisit: true, onTap: {
                        AnalyticsService.shared.track("visit_details_viewed", properties: [
                            "visit_id": group.id,
                            "exhibition_title": exhibitionsMap[group.exhibitionId]?.title ?? "Unknown",
                            "member_count": group.members?.count ?? 0,
                            "tab_source": "my_visits"
                        ])
                        selectedGroup = group
                    }, exhibitionsMap: exhibitionsMap)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(Double(index) * 0.05),
                            value: myGroups.count
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                warningFeedback.notificationOccurred(.warning)
                                Task { await leaveGroup(group) }
                            } label: {
                                Label(String(localized: "leave"), systemImage: "rectangle.portrait.and.arrow.right")
                            }
                            .tint(.red)
                        }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.top, -8)
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 48)).foregroundColor(.secondary)
            Text(title).font(.system(size: 18, weight: .semibold))
            Text(subtitle).font(.system(size: 14)).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Data

    private func loadGroups() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        let allExhibitions = (try? await SupabaseService.shared.fetchExhibitions()) ?? []
        let map = Dictionary(uniqueKeysWithValues: allExhibitions.map { ($0.id, $0) })
        async let allGroupsTask = SupabaseService.shared.fetchGroups()
        async let myGroupsTask = SupabaseService.shared.fetchMyGroups(userId: userId)
        do {
            let (all, mine) = try await (allGroupsTask, myGroupsTask)
            await MainActor.run {
                self.exhibitionsMap = map
                self.discoverGroups = all
                self.myGroups = mine
                self.isLoading = false

                AnalyticsService.shared.track("visits_loaded", properties: [
                    "discover_count": all.count,
                    "my_visits_count": mine.count
                ])
            }
        } catch {
            await MainActor.run {
                self.exhibitionsMap = map
                self.isLoading = false

                AnalyticsService.shared.track("visits_load_error", properties: [
                    "error_type": String(describing: type(of: error))
                ])
            }
        }
    }

    private func leaveGroup(_ group: WherartGroup) async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        try? await SupabaseService.shared.leaveGroup(groupId: group.id, userId: userId)
        await MainActor.run {
            AnalyticsService.shared.track("visit_left", properties: [
                "visit_id": group.id,
                "visit_name": group.name
            ])
            myGroups.removeAll { $0.id == group.id }
        }
    }
}

// MARK: - Visit Card (ExhibitionCard-style)
struct VisitCard: View {
    let group: WherartGroup
    let isMyVisit: Bool
    let onTap: () -> Void
    var exhibitionsMap: [Int: Exhibition] = [:]

    private var exhibition: Exhibition? { exhibitionsMap[group.exhibitionId] }
    private var memberCount: Int { group.members?.count ?? 0 }
    private var isFull: Bool { memberCount >= group.maxMembers }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Image
                ZStack(alignment: .topLeading) {
                    AsyncImage(url: URL(string: exhibition?.image ?? "")) { phase in
                        Group {
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                                    .transition(.opacity)
                            case .failure:
                                Rectangle().fill(Color(.systemGray5))
                            case .empty:
                                Rectangle().fill(Color(.systemGray6))
                                    .overlay(ProgressView())
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .animation(.easeIn(duration: 0.25), value: phase.image != nil)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipped()

                    HStack(spacing: 6) {
                        if let exhibition {
                            TagBadge(label: exhibition.type, color: typeColor(exhibition.type).opacity(0.9))
                        }
                        TagBadge(
                            label: "\(memberCount)/\(group.maxMembers)",
                            color: isFull ? Color.red.opacity(0.85) : Color.white.opacity(0.92)
                        )
                    }
                    .padding(12)
                }

                // MARK: - Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(exhibition?.title ?? "Exhibition #\(group.exhibitionId)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                            Text(group.startDate.formattedVisitDate)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                        }
                        if let time = group.time {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                                Text(time)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
            }
        }
        .buttonStyle(.plain)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 2)
    }
}
