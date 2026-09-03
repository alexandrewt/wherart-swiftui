import Foundation

// MARK: - Exhibition
struct Exhibition: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let artist: String
    let venue: String
    var venueType: String
    var type: String
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
    let waitTime: String?
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
        case waitTime = "wait_time"
    }
}

// MARK: - Exhibition Reclassification
//
// The Paris Open Data sync (Edge Function) sometimes leaves `type` / `venue_type`
// empty or defaulted ("Contemporary Art" / "Museums"). This client-side fallback
// infers a better value from the title/description/venue/address when that happens.
extension Exhibition {
    private static let genericTypes: Set<String> = ["", "Contemporary Art"]
    private static let genericVenueTypes: Set<String> = ["", "Museums"]

    private static let typeKeywords: [(type: String, keywords: [String])] = [
        ("Painting", ["peinture", "tableau", "huile"]),
        ("Photography", ["photo", "photographie"]),
        ("Sculpture", ["sculpture", "bronze", "marbre"]),
        ("Street Art", ["street art", "graffiti", "urban"]),
        ("Modern Art", ["moderne", "modern"]),
        ("Asian Art", ["asie", "japon", "chine", "corée"]),
        ("Design", ["design", "architecture"]),
        ("Installation", ["installation", "dispositif"]),
        ("Video Art", ["vidéo", "video", "film", "cinéma"]),
        ("Contemporary Art", ["contemporain", "contemporary"])
    ]

    private static let venueTypeKeywords: [(venueType: String, keywords: [String])] = [
        ("Museums", ["musée", "museum"]),
        ("Galleries", ["galerie", "gallery"]),
        ("Foundations", ["fondation", "foundation"]),
        ("Art Centers", ["centre d'art", "art center"]),
        ("Cultural Centers", ["centre culturel", "maison de la culture"])
    ]

    /// Returns a copy with `type`/`venueType` inferred from keywords when the
    /// existing value is missing or a generic default. Leaves real values untouched.
    func reclassified() -> Exhibition {
        var copy = self

        if Self.genericTypes.contains(copy.type) {
            let haystack = [title, description ?? ""].joined(separator: " ").lowercased()
            if let match = Self.typeKeywords.first(where: { entry in
                entry.keywords.contains(where: { haystack.contains($0) })
            }) {
                copy.type = match.type
            }
        }

        if Self.genericVenueTypes.contains(copy.venueType) {
            let haystack = [venue, address].joined(separator: " ").lowercased()
            if let match = Self.venueTypeKeywords.first(where: { entry in
                entry.keywords.contains(where: { haystack.contains($0) })
            }) {
                copy.venueType = match.venueType
            }
        }

        return copy
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

// MARK: - ExhibitionEdit
// User-submitted duration/accessibility values, used when the source API
// doesn't report them. See `user_exhibition_edits` table.
struct ExhibitionEdit: Codable {
    let userId: String
    let exhibitionId: Int
    var duration: String?
    var accessibility: String?
    var waitTime: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case exhibitionId = "exhibition_id"
        case duration, accessibility
        case waitTime = "wait_time"
        case createdAt = "created_at"
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
    let createdBy: String?
    let createdAt: String?
    var members: [GroupMember]?

    enum CodingKeys: String, CodingKey {
        case id, name, time
        case exhibitionId = "exhibition_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case maxMembers = "max_members"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case members = "group_members"
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: WherartGroup, rhs: WherartGroup) -> Bool { lhs.id == rhs.id }
}

// MARK: - GroupMember
struct GroupMember: Codable, Hashable {
    let userId: String
    let joinedAt: String?
    var profile: MemberProfile?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case joinedAt = "joined_at"
        case profile = "profiles"
    }

    func hash(into hasher: inout Hasher) { hasher.combine(userId) }
    static func == (lhs: GroupMember, rhs: GroupMember) -> Bool { lhs.userId == rhs.userId }
}

// MARK: - ExhibitionLike
struct ExhibitionLike: Codable, Hashable {
    let userId: String
    let exhibitionId: Int
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case exhibitionId = "exhibition_id"
        case createdAt = "created_at"
    }
}

// MARK: - ExhibitionComment
struct ExhibitionComment: Codable, Identifiable, Hashable {
    let id: UUID
    let exhibitionId: Int
    let userId: String
    let userFirstName: String
    let content: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case exhibitionId = "exhibition_id"
        case userId = "user_id"
        case userFirstName = "user_first_name"
        case content
        case createdAt = "created_at"
    }
}

// MARK: - VisitMessage
// Note: `visitId` is Int (not UUID) to match `groups.id`, which is how visits
// are actually keyed in this schema (see WherartGroup.id).
struct VisitMessage: Codable, Identifiable, Hashable {
    let id: UUID
    let visitId: Int
    let userId: String
    let userFirstName: String
    let content: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case visitId = "visit_id"
        case userId = "user_id"
        case userFirstName = "user_first_name"
        case content
        case createdAt = "created_at"
    }
}

// MARK: - MemberProfile (subset de Profile pour les joins)
struct MemberProfile: Codable {
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
    }
}
