import SwiftUI
import Auth

struct CreateVisitView: View {

    let onCreated: (WherartGroup) -> Void
    let preselectedExhibition: Exhibition?

    init(preselectedExhibition: Exhibition? = nil, onCreated: @escaping (WherartGroup) -> Void) {
        self.preselectedExhibition = preselectedExhibition
        self.onCreated = onCreated
    }

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var startDate = Date()
    @State private var time = Date()
    @State private var maxMembers = 6
    @State private var isCreating = false
    @State private var errorMessage: String? = nil
    @State private var exhibitionSearch = ""
    @State private var searchResults: [Exhibition] = []
    @State private var selectedExhibition: Exhibition? = nil
    @State private var isSearching = false
    @State private var hasTrackedOpen = false

    private let successFeedback = UINotificationFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(String(localized: "create_a_visit"))
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)

            ScrollView {
                VStack(spacing: 20) {

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "visit_name"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField(String(localized: "visit_name_placeholder"), text: $name)
                            .padding(14)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "exhibition_label"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)

                        if let selected = selectedExhibition {
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: selected.image ?? "")) { phase in
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
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selected.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .lineLimit(1)
                                    Text(selected.venue)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button(action: {
                                    impactFeedback.impactOccurred()
                                    selectedExhibition = nil
                                    exhibitionSearch = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .background(Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.3), lineWidth: 1)
                            )
                        } else {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                                TextField(String(localized: "search_an_exhibition"), text: $exhibitionSearch)
                                    .font(.system(size: 15))
                                    .onChange(of: exhibitionSearch) { value in
                                        searchExhibitions(query: value)
                                    }
                                if isSearching {
                                    ProgressView().scaleEffect(0.7)
                                }
                            }
                            .padding(14)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            if !searchResults.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(searchResults) { exhibition in
                                        Button(action: {
                                            selectionFeedback.selectionChanged()
                                            selectedExhibition = exhibition
                                            exhibitionSearch = ""
                                            searchResults = []
                                        }) {
                                            HStack(spacing: 12) {
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
                                                .frame(width: 44, height: 44)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))

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
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                        }
                                        .buttonStyle(.plain)

                                        if exhibition.id != searchResults.last?.id {
                                            Divider().padding(.leading, 68)
                                        }
                                    }
                                }
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                            }
                        }
                    }

                    DatePicker(String(localized: "date_label"), selection: $startDate, displayedComponents: .date)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    DatePicker(String(localized: "time_label"), selection: $time, displayedComponents: .hourAndMinute)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: String(localized: "max_members_count"), maxMembers))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Slider(value: Binding(
                            get: { Double(maxMembers) },
                            set: { newVal in
                                selectionFeedback.selectionChanged()
                                maxMembers = Int(newVal)
                            }
                        ), in: 2...20, step: 1)
                        .tint(Color(red: 0.15, green: 0.39, blue: 0.92))
                    }
                    .padding(14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            Button(action: handleCreate) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(canCreate ? Color(red: 0.15, green: 0.39, blue: 0.92) : Color(.systemGray4))
                        .frame(height: 52)
                    if isCreating {
                        ProgressView().tint(.white)
                    } else {
                        Text(String(localized: "create_visit_button"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(!canCreate || isCreating)
            .padding(24)
        }
        .onAppear {
            if let preselected = preselectedExhibition {
                selectedExhibition = preselected
            }

            if !hasTrackedOpen {
                AnalyticsService.shared.track("create_visit_opened", properties: [
                    "exhibition_id": preselectedExhibition?.id ?? 0,
                    "exhibition_title": preselectedExhibition?.title ?? "None selected"
                ])
                hasTrackedOpen = true
            }
        }
    }

    private var canCreate: Bool {
        !name.isEmpty && selectedExhibition != nil
    }

    private func searchExhibitions(query: String) {
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        isSearching = true
        Task {
            if let results = try? await SupabaseService.shared.fetchExhibitions() {
                let filtered = results.filter {
                    $0.title.localizedCaseInsensitiveContains(query) ||
                    $0.venue.localizedCaseInsensitiveContains(query)
                }.prefix(6)
                await MainActor.run {
                    searchResults = Array(filtered)
                    isSearching = false
                }
            }
        }
    }

    private func handleCreate() {
        guard let exhibition = selectedExhibition,
              let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            errorMessage = String(localized: "please_select_exhibition")
            return
        }

        AnalyticsService.shared.track("create_visit_info_filled", properties: [
            "group_name_length": name.count
        ])

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: startDate)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: time)

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let group = try await SupabaseService.shared.createGroup(
                    exhibitionId: exhibition.id,
                    name: name,
                    startDate: dateStr,
                    time: timeStr,
                    maxMembers: maxMembers,
                    userId: userId
                )
                await MainActor.run {
                    isCreating = false
                    successFeedback.notificationOccurred(.success)
                    AnalyticsService.shared.track("visit_created", properties: [
                        "visit_id": group.id,
                        "exhibition_id": exhibition.id,
                        "exhibition_title": exhibition.title,
                        "group_name": name,
                        "initial_members": 1
                    ])
                    onCreated(group)
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    successFeedback.notificationOccurred(.error)
                    AnalyticsService.shared.track("create_visit_error", properties: [
                        "error_type": String(describing: type(of: error)),
                        "exhibition_id": exhibition.id
                    ])
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    CreateVisitView(onCreated: { _ in })
}
