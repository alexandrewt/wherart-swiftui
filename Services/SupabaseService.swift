import Foundation
import Combine
import Supabase

class SupabaseService: ObservableObject {

    static let shared = SupabaseService()
    private let client = WherartApp.supabase

    @Published var currentUser: User? = nil
    @Published var isAuthenticated = false

    private init() {
        Task { @MainActor in
            await self.listenToAuthChanges()
        }
    }

    private func listenToAuthChanges() async {
        for await (event, session) in client.auth.authStateChanges {
            await MainActor.run {
                switch event {
                case .signedIn, .tokenRefreshed, .userUpdated:
                    self.currentUser = session?.user
                    self.isAuthenticated = session != nil
                case .signedOut:
                    self.currentUser = nil
                    self.isAuthenticated = false
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
        try await client.auth.signUp(
            email: email,
            password: password,
            data: ["first_name": AnyJSON.string(firstName)]
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
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

    func updatePreferences(userId: String, preferences: [String], venueTypes: [String]) async throws {
        try await client
            .from("profiles")
            .upsert([
                "id": AnyJSON.string(userId),
                "preferences": AnyJSON.array(preferences.map { .string($0) }),
                "venue_types": AnyJSON.array(venueTypes.map { .string($0) })
            ])
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
        return response
    }

    func fetchExhibitionById(id: Int) async throws -> Exhibition {
        let response: Exhibition = try await client
            .from("exhibitions")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return response
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
            .select("*, group_members(user_id, joined_at)")
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }

    func fetchMyGroups(userId: String) async throws -> [WherartGroup] {
        let memberRows: [[String: AnyJSON]] = try await client
            .from("group_members")
            .select("group_id")
            .eq("user_id", value: userId)
            .execute()
            .value

        let groupIds = memberRows.compactMap { row -> Int? in
            if case .double(let d) = row["group_id"] { return Int(d) }
            return nil
        }

        guard !groupIds.isEmpty else { return [] }

        let response: [WherartGroup] = try await client
            .from("groups")
            .select("*, group_members(user_id, joined_at)")
            .in("id", values: groupIds)
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
        return group
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
}
