import Foundation
import Combine
import Supabase

class SupabaseService: ObservableObject {

    static let shared = SupabaseService()
    private let client = WherartApp.supabase

    @Published var currentUser: User? = nil
    @Published var isAuthenticated = false
    @Published var hasRestoredSession = false
    /// True once the user taps "Browse without an account" on LoginView.
    /// Lets ContentView route to MainTabView without a session, and lets
    /// individual screens gate account-only actions behind LoginPromptSheet.
    @Published var isGuestMode = false

    private init() {
        Task { @MainActor in
            await self.restoreSession()
            await self.listenToAuthChanges()
        }
    }

    /// Explicitly restores any Keychain-persisted session on launch. Without this,
    /// a returning user's session was only ever picked up if `authStateChanges`
    /// happened to emit a handled event for it — it doesn't, so the app silently
    /// fell back to the login screen every time it was relaunched.
    private func restoreSession() async {
        if let session = try? await client.auth.session {
            currentUser = session.user
            isAuthenticated = true
        }
        hasRestoredSession = true
    }

    private func listenToAuthChanges() async {
        for await (event, session) in client.auth.authStateChanges {
            await MainActor.run {
                switch event {
                case .signedIn, .tokenRefreshed, .userUpdated:
                    self.currentUser = session?.user
                    self.isAuthenticated = session != nil
                    if session != nil {
                        self.isGuestMode = false
                        if let userId = session?.user.id.uuidString {
                            AnalyticsService.shared.identify(userId: userId)
                        }
                    }
                case .signedOut:
                    self.currentUser = nil
                    self.isAuthenticated = false
                    AnalyticsService.shared.reset()
                default:
                    break
                }
            }
        }
    }

    // MARK: - Auth

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String, firstName: String) async throws {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["first_name": AnyJSON.string(firstName)]
        )

        // Insertion directe dans profiles — ne compte pas sur le trigger
        if let user = response.session?.user {
            struct ProfileInsert: Encodable {
                let id: String
                let first_name: String
            }
            try await client
                .from("profiles")
                .upsert(ProfileInsert(id: user.id.uuidString, first_name: firstName))
                .execute()
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    // MARK: - Profile

    func fetchProfile(userId: String) async throws -> Profile {
        let response: Profile = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return response
    }

    func upsertProfile(_ profile: Profile) async throws {
        try await client
            .from("profiles")
            .upsert(profile)
            .execute()
    }

    func uploadProfilePhoto(userId: String, imageData: Data) async throws -> String {
        let path = "\(userId)/avatar.jpg"
        try await client.storage
            .from("avatars")
            .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg", upsert: true))
        let publicURL = try client.storage.from("avatars").getPublicURL(path: path)
        return publicURL.absoluteString
    }

    func updatePreferences(
        userId: String,
        preferences: [String],
        venueTypes: [String],
        reminderThreshold: Int? = nil
    ) async throws {
        struct PrefsUpdate: Encodable {
            let id: String
            let preferences: [String]
            let venue_types: [String]
            let exhibition_reminder_threshold: Int?
        }
        let update = PrefsUpdate(
            id: userId,
            preferences: preferences,
            venue_types: venueTypes,
            exhibition_reminder_threshold: reminderThreshold
        )
        try await client
            .from("profiles")
            .upsert(update)
            .execute()
    }

    // MARK: - Exhibitions

    func fetchExhibitions() async throws -> [Exhibition] {
        let response: [Exhibition] = try await client
            .from("exhibitions")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return response.map { $0.reclassified() }
    }

    func fetchExhibitionById(id: Int) async throws -> Exhibition {
        let response: Exhibition = try await client
            .from("exhibitions")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return response.reclassified()
    }

    // MARK: - Exhibition Edits (crowdsourced duration/accessibility)

    func fetchExhibitionEdits(exhibitionId: Int) async throws -> [ExhibitionEdit] {
        let response: [ExhibitionEdit] = try await client
            .from("user_exhibition_edits")
            .select()
            .eq("exhibition_id", value: exhibitionId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }

    func upsertExhibitionEdit(userId: String, exhibitionId: Int, duration: String?, accessibility: String?, waitTime: String? = nil) async throws {
        struct EditUpsert: Encodable {
            let user_id: String
            let exhibition_id: Int
            let duration: String?
            let accessibility: String?
            let wait_time: String?
        }
        try await client
            .from("user_exhibition_edits")
            .upsert(EditUpsert(user_id: userId, exhibition_id: exhibitionId, duration: duration, accessibility: accessibility, wait_time: waitTime))
            .execute()
    }

    // MARK: - Exhibition Likes & Comments

    func fetchLikes(exhibitionId: Int) async throws -> [ExhibitionLike] {
        let response: [ExhibitionLike] = try await client
            .from("exhibition_likes")
            .select()
            .eq("exhibition_id", value: exhibitionId)
            .execute()
            .value
        return response
    }

    func toggleLike(userId: String, exhibitionId: Int, isLiked: Bool) async throws {
        if isLiked {
            try await client
                .from("exhibition_likes")
                .delete()
                .eq("user_id", value: userId)
                .eq("exhibition_id", value: exhibitionId)
                .execute()
        } else {
            struct LikeInsert: Encodable {
                let user_id: String
                let exhibition_id: Int
            }
            try await client
                .from("exhibition_likes")
                .insert(LikeInsert(user_id: userId, exhibition_id: exhibitionId))
                .execute()
        }
    }

    func fetchComments(exhibitionId: Int) async throws -> [ExhibitionComment] {
        let response: [ExhibitionComment] = try await client
            .from("exhibition_comments")
            .select()
            .eq("exhibition_id", value: exhibitionId)
            .order("created_at", ascending: true)
            .execute()
            .value
        return response
    }

    func postComment(exhibitionId: Int, userId: String, firstName: String, content: String) async throws {
        struct CommentInsert: Encodable {
            let exhibition_id: Int
            let user_id: String
            let user_first_name: String
            let content: String
        }
        try await client
            .from("exhibition_comments")
            .insert(CommentInsert(exhibition_id: exhibitionId, user_id: userId, user_first_name: firstName, content: content))
            .execute()
    }

    // MARK: - User Interactions

    func fetchInteractions(userId: String) async throws -> [UserInteraction] {
        let response: [UserInteraction] = try await client
            .from("user_interactions")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return response
    }

    func upsertInteraction(userId: String, exhibitionId: Int, isFavorite: Bool, isViewed: Bool) async throws {
        let interaction = UserInteraction(
            userId: userId,
            exhibitionId: exhibitionId,
            isFavorite: isFavorite,
            isViewed: isViewed
        )
        try await client
            .from("user_interactions")
            .upsert(interaction)
            .execute()
    }

    // MARK: - Groups

    func fetchGroups() async throws -> [WherartGroup] {
        let response: [WherartGroup] = try await client
            .from("groups")
            .select("*, group_members(user_id, joined_at, profiles(first_name, last_name, avatar_url))")
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }

    func fetchMyGroups(userId: String) async throws -> [WherartGroup] {
        struct MemberRow: Decodable {
            let groupId: Int
            enum CodingKeys: String, CodingKey {
                case groupId = "group_id"
            }
        }

        let memberRows: [MemberRow] = try await client
            .from("group_members")
            .select("group_id")
            .eq("user_id", value: userId)
            .execute()
            .value

        let groupIds = memberRows.map { $0.groupId }
        guard !groupIds.isEmpty else { return [] }

        let response: [WherartGroup] = try await client
            .from("groups")
            .select("*, group_members(user_id, joined_at, profiles(first_name, last_name, avatar_url))")
            .in("id", values: groupIds)
            .execute()
            .value
        return response
    }

    func fetchGroupById(id: Int) async throws -> WherartGroup {
        let response: WherartGroup = try await client
            .from("groups")
            .select("*, group_members(user_id, joined_at, profiles(first_name, last_name, avatar_url))")
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return response
    }

    func createGroup(exhibitionId: Int, name: String, startDate: String, time: String?, maxMembers: Int, userId: String) async throws -> WherartGroup {
        let group: WherartGroup = try await client
            .from("groups")
            .insert([
                "exhibition_id": AnyJSON.double(Double(exhibitionId)),
                "name": AnyJSON.string(name),
                "start_date": AnyJSON.string(startDate),
                "time": time != nil ? AnyJSON.string(time!) : AnyJSON.null,
                "max_members": AnyJSON.double(Double(maxMembers)),
                "created_by": AnyJSON.string(userId)
            ])
            .select()
            .single()
            .execute()
            .value

        try await client
            .from("group_members")
            .insert([
                "group_id": AnyJSON.double(Double(group.id)),
                "user_id": AnyJSON.string(userId)
            ])
            .execute()

        let fullGroup = try await fetchGroupById(id: group.id)
        return fullGroup
    }

    func joinGroup(groupId: Int, userId: String) async throws {
        try await client
            .from("group_members")
            .insert([
                "group_id": AnyJSON.double(Double(groupId)),
                "user_id": AnyJSON.string(userId)
            ])
            .execute()
    }

    func leaveGroup(groupId: Int, userId: String) async throws {
        try await client
            .from("group_members")
            .delete()
            .eq("group_id", value: groupId)
            .eq("user_id", value: userId)
            .execute()
    }

    func deleteGroup(groupId: Int) async throws {
        try await client
            .from("groups")
            .delete()
            .eq("id", value: groupId)
            .execute()
    }

    // MARK: - Visit Messages (chat)

    func fetchMessages(visitId: Int) async throws -> [VisitMessage] {
        let response: [VisitMessage] = try await client
            .from("visit_messages")
            .select()
            .eq("visit_id", value: visitId)
            .order("created_at", ascending: true)
            .execute()
            .value
        return response
    }

    /// Inserts the message and returns the persisted row (with its server-generated
    /// id) so the caller can append it locally right away instead of waiting for
    /// the Realtime echo — while still deduplicating correctly once that echo arrives.
    @discardableResult
    func sendMessage(visitId: Int, userId: String, firstName: String, content: String) async throws -> VisitMessage {
        struct MessageInsert: Encodable {
            let visit_id: Int
            let user_id: String
            let user_first_name: String
            let content: String
        }
        let response: VisitMessage = try await client
            .from("visit_messages")
            .insert(MessageInsert(visit_id: visitId, user_id: userId, user_first_name: firstName, content: content))
            .select()
            .single()
            .execute()
            .value
        return response
    }

    /// Subscribes to new messages for a visit via Supabase Realtime. Returns the
    /// channel so the caller can unsubscribe (e.g. in `onDisappear`).
    func subscribeToMessages(visitId: Int, onMessage: @escaping (VisitMessage) -> Void) -> RealtimeChannelV2 {
        let channel = client.channel("visit_messages_\(visitId)")
        let changes = channel.postgresChange(InsertAction.self, table: "visit_messages")
        Task {
            await channel.subscribe()
            for await change in changes {
                guard let message = try? change.decodeRecord(as: VisitMessage.self, decoder: JSONDecoder()),
                      message.visitId == visitId else { continue }
                await MainActor.run { onMessage(message) }
            }
        }
        return channel
    }

    // MARK: - Account Deletion

    // RGPD: users can request account deletion per Art. 17 GDPR (right to erasure)
    // All personal data is deleted: profile, interactions, visits, messages, comments, likes, avatar
    // Auth user row deletion requires Supabase dashboard or Edge Function if admin API unavailable from client
    //
    // The Supabase Swift client SDK only exposes `client.auth.admin` when the
    // client is initialized with the service-role key — which must never be
    // embedded in a shipped iOS app (this app is initialized with the anon key,
    // see WherartApp.swift). So this function cannot delete the auth.users row
    // itself. It deletes every row of personal data manually, in FK-safe order,
    // then signs the user out. The remaining auth.users row (email + hashed
    // password only, no personal data) must be removed separately via either:
    //   a) a Supabase Edge Function (running with the service-role key) invoked
    //      from this app, e.g. `client.functions.invoke("delete-account")`, or
    //   b) manual deletion from the Supabase dashboard.
    func deleteAccount(userId: String) async throws {
        // 1. exhibition_comments (references auth.users)
        try await client
            .from("exhibition_comments")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        // 2. exhibition_likes (references auth.users)
        try await client
            .from("exhibition_likes")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        // 3. visit_messages (references auth.users)
        try await client
            .from("visit_messages")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        // 4. group_members (references auth.users)
        try await client
            .from("group_members")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        // 5. user_exhibition_edits (references auth.users)
        try await client
            .from("user_exhibition_edits")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        // 6. user_interactions (references auth.users)
        try await client
            .from("user_interactions")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        // 7. groups where creator_id = userId (references auth.users)
        try await client
            .from("groups")
            .delete()
            .eq("created_by", value: userId)
            .execute()

        // 8. profiles (references auth.users)
        try await client
            .from("profiles")
            .delete()
            .eq("id", value: userId)
            .execute()

        // 9. Storage: delete avatar file at path "{userId}/avatar.jpg" from bucket
        // "avatars". Best-effort — a user with no avatar shouldn't fail the whole
        // deletion.
        _ = try? await client.storage
            .from("avatars")
            .remove(paths: ["\(userId)/avatar.jpg"])

        // 10. Sign out locally. This does NOT delete the auth.users row — see the
        // comment above the function for why, and what still needs to run
        // server-side (Edge Function or dashboard) to finish the erasure.
        try await client.auth.signOut()
    }
}
