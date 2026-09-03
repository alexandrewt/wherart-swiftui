import SwiftUI
import Supabase

struct ChatFullView: View {
    let group: WherartGroup
    let title: String

    @State private var messages: [VisitMessage] = []
    @State private var messageText = ""
    @State private var isSendingMessage = false
    @State private var chatChannel: RealtimeChannelV2? = nil
    @FocusState private var messageFieldFocused: Bool

    private var currentUserId: String? {
        SupabaseService.shared.currentUser?.id.uuidString
    }

    var body: some View {
        VStack(spacing: 0) {
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
                    .padding(16)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            HStack(spacing: 10) {
                TextField(String(localized: "message_placeholder"), text: $messageText)
                    .focused($messageFieldFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                Button(action: { Task { await sendMessage() } }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(.systemGray4) : Color(red: 0.15, green: 0.39, blue: 0.92))
                }
                .disabled(isSendingMessage || messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            .background(Color(.systemBackground))
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .task {
            await startChat()
        }
        .onDisappear {
            let channel = chatChannel
            chatChannel = nil
            Task { await channel?.unsubscribe() }
        }
    }

    private func startChat() async {
        guard let fetchedMessages = try? await SupabaseService.shared.fetchMessages(visitId: group.id) else { return }
        await MainActor.run { self.messages = fetchedMessages }
        chatChannel = SupabaseService.shared.subscribeToMessages(visitId: group.id) { message in
            guard !self.messages.contains(where: { $0.id == message.id }) else { return }
            self.messages.append(message)
        }
    }

    private func sendMessage() async {
        guard let userId = currentUserId else { return }
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let firstName = group.members?.first { $0.userId.lowercased() == userId.lowercased() }?.profile?.firstName ?? String(localized: "member_fallback")
        await MainActor.run { isSendingMessage = true }
        if let sent = try? await SupabaseService.shared.sendMessage(visitId: group.id, userId: userId, firstName: firstName, content: content) {
            await MainActor.run {
                if !messages.contains(where: { $0.id == sent.id }) { messages.append(sent) }
                messageText = ""
                isSendingMessage = false
                messageFieldFocused = false
            }
        } else {
            await MainActor.run { isSendingMessage = false }
        }
    }
}

#Preview {
    NavigationStack {
        ChatFullView(
            group: WherartGroup(
                id: 1, exhibitionId: 1, name: "Visit Pompidou",
                startDate: "2026-05-15", endDate: nil, time: "14:00",
                maxMembers: 8, createdBy: "user-123", createdAt: nil, members: nil
            ),
            title: "Visit Pompidou"
        )
    }
}
