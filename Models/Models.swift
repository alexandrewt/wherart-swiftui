import Foundation

// MARK: - Exhibition
struct Exhibition: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let artist: String
    let venue: String
    let venueType: String
    let type: String
    let address: String
    let schedule: String?
    let description: String?
    let ticketLink: String?
    let image: String?
    let lat: Double
    let lng: Double
    let price: String?
    let duration: String?
    let accessibility: String?
    let phone: String?
    let isFree: Bool
    let endingSoon: Bool
    let endDate: String?
    var distance: Double?

    enum CodingKeys: String, CodingKey {
        case id, title, artist, venue, address, schedule, description, image
        case lat, lng, price, duration, accessibility, phone
        case venueType = "venue_type"
        case type = "type"
        case ticketLink = "ticket_link"
        case isFree = "is_free"
        case endingSoon = "ending_soon"
        case endDate = "end_date"
    }
}

// MARK: - Profile
struct Profile: Codable {
    let id: String
    var firstName: String?
    var lastName: String?
    var preferences: [String]
    var venueTypes: [String]
    var avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case preferences
        case venueTypes = "venue_types"
        case avatarUrl = "avatar_url"
    }
}

// MARK: - UserInteraction
struct UserInteraction: Codable {
    let userId: String
    let exhibitionId: Int
    var isFavorite: Bool
    var isViewed: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case exhibitionId = "exhibition_id"
        case isFavorite = "is_favorite"
        case isViewed = "is_viewed"
    }
}

// MARK: - Group (Visit)
struct WherartGroup: Codable, Identifiable, Hashable {
    let id: Int
    let exhibitionId: Int
    let name: String
    let startDate: String
    let endDate: String?
    let time: String?
    let maxMembers: Int
    let createdBy: String
    let createdAt: String?
    var members: [GroupMember]?
    var memberCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, time
        case exhibitionId = "exhibition_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case maxMembers = "max_members"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case members = "group_members"
        case memberCount
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WherartGroup, rhs: WherartGroup) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - GroupMember
struct GroupMember: Codable, Hashable {
    let groupId: Int
    let userId: String
    let joinedAt: String?
    var profile: Profile?

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case profile = "profiles"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(groupId)
        hasher.combine(userId)
    }

    static func == (lhs: GroupMember, rhs: GroupMember) -> Bool {
        lhs.groupId == rhs.groupId && lhs.userId == rhs.userId
    }
}
