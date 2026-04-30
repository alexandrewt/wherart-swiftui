import SwiftUI
import Auth

struct VisitDetailView: View {

    let group: WherartGroup
    let onLeft: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var exhibition: Exhibition? = nil
    @State private var isJoining = false
    @State private var hasJoined = false
    @State private var showLeaveConfirm = false
    @State private var isCreator = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Exhibition Preview
                if let exhibition = exhibition {
                    HStack(spacing: 14) {
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

                        VStack(alignment: .leading, spacing: 4) {
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
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // MARK: - Visit Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Visit details")
                        .font(.system(size: 16, weight: .semibold))

                    VStack(spacing: 0) {
                        InfoRow(icon: "calendar", label: "Date", value: group.startDate)
                        Divider().padding(.leading, 44)
                        if let time = group.time {
                            InfoRow(icon: "clock", label: "Time", value: time)
                            Divider().padding(.leading, 44)
                        }
                        InfoRow(
                            icon: "person.2",
                            label: "Members",
                            value: "\(group.members?.count ?? 0) / \(group.maxMembers)"
                        )
                    }
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // MARK: - Members
                if let members = group.members, !members.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Members")
                            .font(.system(size: 16, weight: .semibold))

                        ForEach(members, id: \.userId) { member in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text(member.userId.prefix(1).uppercased())
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.blue)
                                    )
                                Text(member.profile?.firstName ?? "Member")
                                    .font(.system(size: 14))
                                Spacer()
                                if member.userId == SupabaseService.shared.currentUser?.id.uuidString {
                                    Text("You")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // MARK: - CTAs
                VStack(spacing: 12) {
                    if isCreator {
                        Button(action: { showLeaveConfirm = true }) {
                            Text("Delete visit")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 26))
                        }
                    } else if hasJoined {
                        Button(action: { showLeaveConfirm = true }) {
                            Text("Leave visit")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 26))
                        }
                    } else {
                        Button(action: { Task { await joinGroup() } }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 26)
                                    .fill(Color.blue)
                                    .frame(height: 52)
                                if isJoining {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Join visit")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(isJoining)
                    }
                }
                .padding(.bottom, 32)
            }
            .padding(16)
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Are you sure?", isPresented: $showLeaveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button(isCreator ? "Delete" : "Leave", role: .destructive) {
                Task { await leaveOrDelete() }
            }
        } message: {
            Text(isCreator ? "This will delete the visit for all members." : "You will leave this visit.")
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Info Row
    private func InfoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 14))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Data
    private func loadData() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        isCreator = group.createdBy == userId
        hasJoined = group.members?.contains { $0.userId == userId } ?? false
        if let expo = try? await SupabaseService.shared.fetchExhibitionById(id: group.exhibitionId) {
            await MainActor.run { exhibition = expo }
        }
    }

    private func joinGroup() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        isJoining = true
        try? await SupabaseService.shared.joinGroup(groupId: group.id, userId: userId)
        await MainActor.run {
            hasJoined = true
            isJoining = false
        }
    }

    private func leaveOrDelete() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        if isCreator {
            try? await SupabaseService.shared.deleteGroup(groupId: group.id)
        } else {
            try? await SupabaseService.shared.leaveGroup(groupId: group.id, userId: userId)
        }
        await MainActor.run {
            onLeft()
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        VisitDetailView(group: WherartGroup(
            id: 1,
            exhibitionId: 1,
            name: "Visit Pompidou",
            startDate: "2026-05-15",
            endDate: nil,
            time: "14:00",
            maxMembers: 8,
            createdBy: "user-123",
            createdAt: nil
        ), onLeft: {})
    }
}
