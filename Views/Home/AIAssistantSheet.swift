import SwiftUI

// MARK: - Chat Message

// Named `AIChatMessage`/`AIChatBubble` rather than `ChatMessage`/`ChatBubble`
// — those names are already taken by the visit chat feature (see
// VisitDetailView.swift's `ChatBubble` for `VisitMessage`).
struct AIChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "done")) { dismiss() }
                }
            }
        }
        .onAppear {
            if messages.isEmpty {
                messages.append(AIChatMessage(text: String(localized: "ai_assistant_greeting"), isUser: false))
            }
            AnalyticsService.shared.track("ai_assistant_opened")
        }
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
                    isLoading = false
                }
            } catch {
                AnalyticsService.shared.track("ai_assistant_error", properties: ["error": error.localizedDescription])
                await MainActor.run {
                    messages.append(AIChatMessage(text: String(localized: "ai_assistant_error"), isUser: false))
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    AIAssistantSheet(exhibitions: [], profile: nil, favoriteIds: [], viewedIds: [])
}
