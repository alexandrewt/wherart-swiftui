import SwiftUI
import Auth
import Supabase

struct VisitDetailView: View {

    let group: WherartGroup
    let onLeft: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var localGroup: WherartGroup
    @State private var exhibition: Exhibition? = nil
    @State private var isJoining = false
    @State private var hasJoined = false
    @State private var isCreator = false
    @State private var showLeaveConfirm = false
    @State private var showJoinConfirm = false
    @State private var showMembers = true

    @State private var messages: [VisitMessage] = []
    @State private var messageText = ""
    @State private var isSendingMessage = false
    @State private var chatChannel: RealtimeChannelV2? = nil
    @State private var showFullChat = false
    @FocusState private var messageFieldFocused: Bool

    private let successFeedback = UINotificationFeedbackGenerator()
    private let warningFeedback = UINotificationFeedbackGenerator()

    init(group: WherartGroup, onLeft: @escaping () -> Void) {
        self.group = group
        self.onLeft = onLeft
        self._localGroup = State(initialValue: group)
    }

    /// Whether the current authenticated user is a confirmed member of this
    /// visit, derived directly from the already-loaded members list — no
    /// separate query, and no special-casing for the creator (who is already
    /// inserted into group_members when the visit is created, so a plain
    /// membership check covers them too).
    private var isConfirmedMember: Bool {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return false }
        return localGroup.members?.contains { $0.userId.lowercased() == userId.lowercased() } ?? false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                if let exhibition = exhibition {
                    ExhibitionPreview(exhibition: exhibition)
                }

                VisitInfoSection(group: localGroup)

                if let members = localGroup.members, !members.isEmpty {
                    MembersSection(
                        members: members,
                        showMembers: $showMembers,
                        createdBy: localGroup.createdBy
                    )
                }

                if isConfirmedMember {
                    ChatSection(
                        messages: messages,
                        messageText: $messageText,
                        isSending: isSendingMessage,
                        isFocused: $messageFieldFocused,
                        onSend: { Task { await sendMessage() } },
                        onOpenFullChat: { showFullChat = true }
                    )
                }

                CTASection(
                    isCreator: isCreator,
                    hasJoined: hasJoined,
                    isJoining: isJoining,
                    onLeave: {
                        warningFeedback.notificationOccurred(.warning)
                        showLeaveConfirm = true
                    },
                    onJoin: { showJoinConfirm = true }
                )
                .padding(.bottom, 32)
            }
            .padding(16)
        }
        .navigationTitle(localGroup.name)
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .alert(String(localized: "are_you_sure"), isPresented: $showLeaveConfirm) {
            Button(String(localized: "cancel"), role: .cancel) {}
            Button(isCreator ? String(localized: "delete") : String(localized: "leave"), role: .destructive) {
                Task { await leaveOrDelete() }
            }
        } message: {
            Text(isCreator ? String(localized: "delete_visit_warning") : String(localized: "leave_visit_warning"))
        }
        .sheet(isPresented: $showJoinConfirm) {
            JoinVisitConfirmView(
                group: localGroup,
                exhibition: exhibition,
                onConfirm: {
                    showJoinConfirm = false
                    Task { await joinGroup() }
                },
                onCancel: { showJoinConfirm = false }
            )
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(24)
        }
        .navigationDestination(isPresented: $showFullChat) {
            ChatFullView(group: localGroup, title: exhibition?.title ?? localGroup.name)
        }
        .task {
            await loadData()

            AnalyticsService.shared.track("visit_detail_viewed", properties: [
                "visit_id": group.id,
                "creator_id": group.createdBy ?? "Unknown",
                "member_count": group.members?.count ?? 0,
                "is_creator": isCreator
            ])
        }
        .onAppear {
            // Re-establish the subscription when returning to this screen (e.g.
            // after ChatFullView, whose own .onDisappear tears down its channel,
            // is popped) — .task only runs once per view identity, not on every
            // re-appearance, so this is the hook that catches that case.
            if isConfirmedMember && chatChannel == nil {
                Task { await startChat() }
            }
        }
        .onDisappear {
            let channel = chatChannel
            chatChannel = nil
            Task { await channel?.unsubscribe() }
        }
    }

    // MARK: - Chat

    private func startChat() async {
        guard let fetchedMessages = try? await SupabaseService.shared.fetchMessages(visitId: group.id) else { return }
        await MainActor.run { self.messages = fetchedMessages }
        chatChannel = SupabaseService.shared.subscribeToMessages(visitId: group.id) { message in
            guard !self.messages.contains(where: { $0.id == message.id }) else { return }
            self.messages.append(message)
        }
    }

    private func sendMessage() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let firstName = localGroup.members?.first { $0.userId.lowercased() == userId.lowercased() }?.profile?.firstName ?? String(localized: "member_fallback")
        await MainActor.run { isSendingMessage = true }
        if let sent = try? await SupabaseService.shared.sendMessage(visitId: group.id, userId: userId, firstName: firstName, content: content) {
            await MainActor.run {
                if !messages.contains(where: { $0.id == sent.id }) { messages.append(sent) }

                AnalyticsService.shared.track("chat_message_sent", properties: [
                    "visit_id": group.id,
                    "message_length": content.count,
                    "message_type": "text"
                ])

                messageText = ""
                isSendingMessage = false
                messageFieldFocused = false
            }
        } else {
            await MainActor.run { isSendingMessage = false }
        }
    }

    // MARK: - Data

    private func loadData() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        do {
            let updated = try await SupabaseService.shared.fetchGroupById(id: group.id)
            await MainActor.run {
                localGroup = updated
                isCreator = updated.createdBy?.lowercased() == userId.lowercased()
                hasJoined = updated.members?.contains { $0.userId.lowercased() == userId.lowercased() } ?? false
                if isCreator { hasJoined = true }
            }
        } catch {}
        if let expo = try? await SupabaseService.shared.fetchExhibitionById(id: group.exhibitionId) {
            await MainActor.run { exhibition = expo }
        }
        if isConfirmedMember { await startChat() }
    }

    private func joinGroup() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        isJoining = true
        try? await SupabaseService.shared.joinGroup(groupId: group.id, userId: userId)
        if let updated = try? await SupabaseService.shared.fetchGroupById(id: group.id) {
            await MainActor.run {
                localGroup = updated
                hasJoined = true
                isJoining = false
                successFeedback.notificationOccurred(.success)
                AnalyticsService.shared.track("visit_joined", properties: [
                    "visit_id": group.id,
                    "exhibition_id": group.exhibitionId,
                    "member_count_after": updated.members?.count ?? 0
                ])
            }
            await startChat()
        } else {
            await MainActor.run {
                hasJoined = true
                isJoining = false
                successFeedback.notificationOccurred(.success)
                AnalyticsService.shared.track("visit_joined", properties: [
                    "visit_id": group.id,
                    "exhibition_id": group.exhibitionId,
                    "member_count_after": 1
                ])
            }
            await startChat()
        }
        NotificationService.shared.scheduleVisitReminder(for: localGroup, exhibitionTitle: exhibition?.title)
    }

    private func leaveOrDelete() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        if isCreator {
            try? await SupabaseService.shared.deleteGroup(groupId: group.id)
        } else {
            try? await SupabaseService.shared.leaveGroup(groupId: group.id, userId: userId)

            AnalyticsService.shared.track("visit_left", properties: [
                "visit_id": group.id,
                "exhibition_id": group.exhibitionId,
                "member_count_after": (localGroup.members?.count ?? 1) - 1
            ])
        }
        NotificationService.shared.cancelNotification(identifier: NotificationService.visitReminderIdentifier(groupId: group.id))
        await MainActor.run {
            onLeft()
            dismiss()
        }
    }
}

// MARK: - Exhibition Preview

private struct ExhibitionPreview: View {
    let exhibition: Exhibition

    var body: some View {
        HStack(spacing: 14) {
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
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Visit Info Section

private struct VisitInfoSection: View {
    let group: WherartGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "visit_details"))
                .font(.system(size: 16, weight: .semibold))

            VStack(spacing: 0) {
                DetailInfoRow(icon: "calendar", label: String(localized: "date_label"), value: group.startDate.formattedVisitDate)
                if let time = group.time {
                    Divider().padding(.leading, 44)
                    DetailInfoRow(icon: "clock", label: String(localized: "time_label"), value: time)
                }
                Divider().padding(.leading, 44)
                DetailInfoRow(
                    icon: "person.2",
                    label: String(localized: "members"),
                    value: "\(group.members?.count ?? 0) / \(group.maxMembers)"
                )
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Detail Info Row

private struct DetailInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
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
}

// MARK: - Members Section

private struct MembersSection: View {
    let members: [GroupMember]
    @Binding var showMembers: Bool
    let createdBy: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation { showMembers.toggle() } }) {
                HStack {
                    Text(String(format: String(localized: "members_count"), members.count))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: showMembers ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showMembers {
                VStack(spacing: 12) {
                    ForEach(members, id: \.userId) { member in
                        MemberRow(member: member, createdBy: createdBy)
                    }
                }
            }
        }
    }
}

// MARK: - Member Row

private struct MemberRow: View {
    let member: GroupMember
    let createdBy: String?

    private var currentUserId: String? {
        SupabaseService.shared.currentUser?.id.uuidString
    }

    private var displayName: String {
        if let first = member.profile?.firstName, !first.isEmpty {
            if let last = member.profile?.lastName, !last.isEmpty {
                return "\(first) \(last)"
            }
            return first
        }
        return String(localized: "member_fallback")
    }

    private var initials: String {
        if let first = member.profile?.firstName, !first.isEmpty {
            return String(first.prefix(1)).uppercased()
        }
        return "?"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.15))
                    .frame(width: 40, height: 40)

                if let urlString = member.profile?.avatarUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        Group {
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                                    .transition(.opacity)
                            default:
                                Text(initials)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                            }
                        }
                        .animation(.easeIn(duration: 0.25), value: phase.image != nil)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Text(initials)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                }
            }

            Text(displayName)
                .font(.system(size: 14, weight: .medium))

            Spacer()

            HStack(spacing: 6) {
                if member.userId.lowercased() == currentUserId?.lowercased() {
                    BadgeView(text: String(localized: "you_badge"), color: .secondary, background: Color(.systemGray6))
                }
                if member.userId.lowercased() == createdBy?.lowercased() {
                    BadgeView(text: String(localized: "host"), color: Color(red: 0.15, green: 0.39, blue: 0.92), background: Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.1))
                }
            }
        }
    }
}

// MARK: - Badge View

private struct BadgeView: View {
    let text: String
    let color: Color
    let background: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
    }
}

// MARK: - Chat Section

private struct ChatSection: View {
    let messages: [VisitMessage]
    @Binding var messageText: String
    let isSending: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onOpenFullChat: () -> Void

    private var currentUserId: String? {
        SupabaseService.shared.currentUser?.id.uuidString
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "chat"))
                .font(.system(size: 16, weight: .semibold))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if messages.isEmpty {
                            Text(String(localized: "no_messages_yet"))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 24)
                        }
                        ForEach(messages) { message in
                            ChatBubble(
                                message: message,
                                isMine: message.userId.lowercased() == currentUserId?.lowercased()
                            )
                            .id(message.id)
                        }
                    }
                    .padding(12)
                }
                .frame(height: 280)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            HStack(spacing: 10) {
                TextField(String(localized: "message_placeholder"), text: $messageText)
                    .focused(isFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(.systemGray4) : Color(red: 0.15, green: 0.39, blue: 0.92))
                }
                .disabled(isSending || messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Button(action: onOpenFullChat) {
                HStack(spacing: 8) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text(String(localized: "open_full_chat"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color(red: 0.15, green: 0.39, blue: 0.92))
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
    }
}

struct ChatBubble: View {
    let message: VisitMessage
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                if !isMine {
                    Text(message.userFirstName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(isMine ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMine ? Color(red: 0.15, green: 0.39, blue: 0.92) : Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(message.createdAt, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            if !isMine { Spacer(minLength: 40) }
        }
    }
}

// MARK: - CTA Section

private struct CTASection: View {
    let isCreator: Bool
    let hasJoined: Bool
    let isJoining: Bool
    let onLeave: () -> Void
    let onJoin: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if isCreator {
                Button(action: onLeave) {
                    Text(String(localized: "delete_visit"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            } else if hasJoined {
                Button(action: onLeave) {
                    Text(String(localized: "leave_visit"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            } else {
                Button(action: onJoin) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(red: 0.15, green: 0.39, blue: 0.92))
                            .frame(height: 52)
                        if isJoining {
                            ProgressView().tint(.white)
                        } else {
                            Text(String(localized: "join_visit"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(isJoining)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VisitDetailView(
            group: WherartGroup(
                id: 1,
                exhibitionId: 1,
                name: "Visit Pompidou",
                startDate: "2026-05-15",
                endDate: nil,
                time: "14:00",
                maxMembers: 8,
                createdBy: "user-123",
                createdAt: nil,
                members: nil
            ),
            onLeft: {}
        )
    }
}
