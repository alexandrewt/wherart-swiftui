import SwiftUI
import Auth
import Combine

// MARK: - Chat Message

// Named `AIChatMessage`/`AIChatBubble` rather than `ChatMessage`/`ChatBubble`
// — those names are already taken by the visit chat feature (see
// VisitDetailView.swift's `ChatBubble` for `VisitMessage`).
struct AIChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

// MARK: - Conversation History (on-device)

struct AIStoredMessage: Codable {
    let text: String
    let isUser: Bool
}

struct AIConversation: Codable, Identifiable {
    let id: UUID
    var title: String
    var updatedAt: Date
    var messages: [AIStoredMessage]
}

/// Persists AI conversations as JSON in Application Support, one file per
/// signed-in user (or "guest") so accounts on the same device never see each
/// other's history. The greeting is never stored — it's re-added on load.
@MainActor
final class AIConversationStore: ObservableObject {
    @Published private(set) var conversations: [AIConversation] = []

    private let fileURL: URL
    private static let maxConversations = 50

    init() {
        let userId = SupabaseService.shared.currentUser?.id.uuidString.lowercased() ?? "guest"
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("ai_conversations_\(userId).json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([AIConversation].self, from: data) {
            conversations = decoded.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    var latest: AIConversation? { conversations.first }

    /// Creates the conversation on first call (id == nil) or updates it, and
    /// moves it to the top. Returns its id.
    @discardableResult
    func upsert(id: UUID?, messages: [AIStoredMessage]) -> UUID? {
        guard let firstUserText = messages.first(where: { $0.isUser })?.text else { return id }
        let title = String(firstUserText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        let conversationId = id ?? UUID()

        conversations.removeAll { $0.id == conversationId }
        conversations.insert(
            AIConversation(id: conversationId, title: title, updatedAt: Date(), messages: messages),
            at: 0
        )
        if conversations.count > Self.maxConversations {
            conversations = Array(conversations.prefix(Self.maxConversations))
        }
        save()
        return conversationId
    }

    func delete(id: UUID) {
        conversations.removeAll { $0.id == id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// The AI backend replies with a JSON envelope (see ask-wherart-ai/index.ts's
// system prompt); the greeting and error strings are plain localized text
// instead, so decoding is best-effort with a plain-text fallback below.
private struct AIResponse: Decodable {
    let message: String
    let exhibitions: [AIChatExhibitionRef]?
}

extension AIResponse {
    // Claude sometimes wraps the JSON in a ```json fence despite being told
    // not to — stripped here rather than tightening the prompt further.
    static func parse(_ text: String) -> AIResponse? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^```(?:json)?\\s*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s*```$", with: "", options: .regularExpression)
        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AIResponse.self, from: data)
    }
}

private struct AIChatExhibitionRef: Decodable, Identifiable {
    let id: Int
    let title: String
    let artist: String
    let reason: String
}

struct AIChatBubble: View {
    let message: AIChatMessage
    let exhibitions: [Exhibition]

    private static let brandBlue = Color(red: 0.15, green: 0.39, blue: 0.92)

    private var parsedResponse: AIResponse? {
        guard !message.isUser else { return nil }
        return AIResponse.parse(message.text)
    }

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }
            bubbleContent
            if !message.isUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if let response = parsedResponse {
            VStack(alignment: .leading, spacing: 10) {
                Text(response.message)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)

                ForEach(Array((response.exhibitions ?? []).enumerated()), id: \.element.id) { position, match in
                    if let exhibition = exhibitions.first(where: { $0.id == match.id }) {
                        NavigationLink(destination: ExhibitionDetailView(exhibition: exhibition)) {
                            AIExhibitionMatchCard(match: match)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            AnalyticsService.shared.track("ai_exhibition_selected", properties: [
                                "exhibition_id": exhibition.id,
                                "position_in_list": position
                            ])
                        })
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        } else {
            Text(message.text)
                .font(.system(size: 15))
                .foregroundColor(message.isUser ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.isUser ? Self.brandBlue : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

private struct AIExhibitionMatchCard: View {
    let match: AIChatExhibitionRef

    private static let brandBlue = Color(red: 0.15, green: 0.39, blue: 0.92)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(match.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Self.brandBlue)
            Text(match.artist)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(match.reason)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - AI Assistant Sheet

struct AIAssistantSheet: View {
    @Environment(\.dismiss) private var dismiss

    // Passed in from HomeView, which has already loaded these — avoids a
    // second round trip to Supabase just to open the chat.
    let exhibitions: [Exhibition]
    let profile: Profile?
    let favoriteIds: [Int]
    let viewedIds: [Int]

    @State private var messages: [AIChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @StateObject private var store = AIConversationStore()
    @State private var conversationId: UUID?
    @State private var showHistory = false
    @FocusState private var inputFocused: Bool

    private static let brandBlue = Color(red: 0.15, green: 0.39, blue: 0.92)

    /// Closest-first, capped — keeps the Edge Function payload (and the
    /// Claude API cost per request) small regardless of how many
    /// exhibitions are in the database.
    private var exhibitionSummaries: [AIExhibitionSummary] {
        exhibitions
            .sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
            .prefix(60)
            .map { AIExhibitionSummary(exhibition: $0) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(messages) { message in
                                AIChatBubble(message: message, exhibitions: exhibitions).id(message.id)
                            }
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .tint(.secondary)
                                    Spacer()
                                }
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: messages.count) { _ in
                        if let lastId = messages.last?.id {
                            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                        }
                    }
                }

                Divider()

                HStack(spacing: 10) {
                    TextField(String(localized: "ai_assistant_placeholder"), text: $inputText, axis: .vertical)
                        .focused($inputFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .lineLimit(1...4)
                        .disabled(isLoading)

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(canSend ? Self.brandBlue : Color(.systemGray4))
                    }
                    .disabled(!canSend)
                }
                .padding(16)
                .background(Color(.systemBackground))
            }
            .navigationTitle(String(localized: "ai_assistant_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button(action: { showHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .disabled(isLoading)
                    .accessibilityLabel(String(localized: "ai_history_title"))

                    Button(action: startNewConversation) {
                        Image(systemName: "square.and.pencil")
                    }
                    .disabled(isLoading || conversationId == nil)
                    .accessibilityLabel(String(localized: "ai_new_conversation"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "done")) { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showHistory) {
                AIHistoryView(
                    store: store,
                    onSelect: { conversation in
                        load(conversation)
                        showHistory = false
                    },
                    onDelete: { id in
                        store.delete(id: id)
                        if id == conversationId { startNewConversation() }
                    }
                )
            }
        }
        .onAppear {
            if messages.isEmpty {
                // Resume where the user left off (also what brings them back
                // to the chat after the sheet was closed on an exhibition).
                if let latest = store.latest {
                    load(latest)
                } else {
                    startNewConversation()
                }
            }
            AnalyticsService.shared.track("ai_assistant_opened")
        }
    }

    private var greetingMessage: AIChatMessage {
        AIChatMessage(text: String(localized: "ai_assistant_greeting"), isUser: false)
    }

    private func startNewConversation() {
        conversationId = nil
        messages = [greetingMessage]
    }

    private func load(_ conversation: AIConversation) {
        conversationId = conversation.id
        messages = [greetingMessage] + conversation.messages.map {
            AIChatMessage(text: $0.text, isUser: $0.isUser)
        }
    }

    private func persist() {
        let stored = messages.dropFirst().map { AIStoredMessage(text: $0.text, isUser: $0.isUser) }
        conversationId = store.upsert(id: conversationId, messages: Array(stored))
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        inputFocused = false
        messages.append(AIChatMessage(text: text, isUser: true))
        persist()
        isLoading = true
        AnalyticsService.shared.track("ai_assistant_message_sent")

        let responseStartTime = Date()

        Task {
            do {
                let reply = try await SupabaseService.shared.askWherartAI(
                    message: text,
                    profile: profile,
                    favoriteIds: favoriteIds,
                    viewedIds: viewedIds,
                    exhibitions: exhibitionSummaries
                )
                AnalyticsService.shared.track("ai_response_received", properties: [
                    "latency_ms": Int(Date().timeIntervalSince(responseStartTime) * 1000),
                    "exhibitions_suggested": AIResponse.parse(reply)?.exhibitions?.count ?? 0
                ])
                await MainActor.run {
                    messages.append(AIChatMessage(text: reply, isUser: false))
                    persist()
                    isLoading = false
                }
            } catch {
                AnalyticsService.shared.track("ai_assistant_error", properties: ["error": error.localizedDescription])
                await MainActor.run {
                    messages.append(AIChatMessage(text: String(localized: "ai_assistant_error"), isUser: false))
                    persist()
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - History

private struct AIHistoryView: View {
    @ObservedObject var store: AIConversationStore
    let onSelect: (AIConversation) -> Void
    let onDelete: (UUID) -> Void

    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        Group {
            if store.conversations.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 36))
                        .foregroundColor(.gray)
                    Text(String(localized: "ai_history_empty"))
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.conversations) { conversation in
                        Button(action: { onSelect(conversation) }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conversation.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                Text(Self.formatter.localizedString(for: conversation.updatedAt, relativeTo: Date()))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onDelete(conversation.id)
                            } label: {
                                Label(String(localized: "delete"), systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(String(localized: "ai_history_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    AIAssistantSheet(exhibitions: [], profile: nil, favoriteIds: [], viewedIds: [])
}
