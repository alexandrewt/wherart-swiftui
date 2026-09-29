import Foundation

// MARK: - Art Taxonomy
//
// `Exhibition.type` / `Exhibition.venueType` and `Profile.preferences` /
// `Profile.venueTypes` are canonical English values produced by the
// Supabase `sync-exhibitions` Edge Function (detectType / detectVenueType)
// and stored as-is in Supabase. They drive cross-locale matching — the
// personalized feed, FilterSheet, and preference editing all compare these
// values directly — so the stored/compared value must never be translated.
// This maps each canonical value to a French display label for the UI only.
enum ArtTaxonomy {
    static let artTypeLabels: [String: String] = [
        "Contemporary Art": "Art contemporain",
        "Photography": "Photographie",
        "Painting": "Peinture",
        "Sculpture": "Sculpture",
        "Drawing": "Dessin",
        "Video Art": "Art vidéo",
        "Street Art": "Street Art",
        "Design": "Design",
        "Architecture": "Architecture",
        "Digital Art": "Art numérique",
        "Illustration": "Illustration",
        "Printmaking": "Estampe",
        "Abstract Art": "Art abstrait",
        "Modern Art": "Art moderne",
        "Asian Art": "Art asiatique",
        "Installation": "Installation",
        "Mixed Media": "Techniques mixtes",
        "Textile Art": "Art textile",
        "Ceramics": "Céramique",
        "Performance": "Performance",
    ]

    static let venueTypeLabels: [String: String] = [
        "Museum": "Musées",
        "Gallery": "Galeries",
        "Art Center": "Centres d'art",
        "Foundation": "Fondations",
        "Cultural Center": "Centres culturels",
        "Auction House": "Maisons de vente",
        "Art Fair": "Foires d'art",
        "Public Space": "Espaces publics",
        "Historic Site": "Sites historiques",
        "Library": "Bibliothèques",
        "Church & Heritage": "Églises et patrimoine",
        "Cultural Institute": "Instituts culturels",
        "Artist Studio": "Ateliers d'artistes",
    ]

    /// Localized display label for a stored art-type or venue-type value.
    /// Falls back to the raw value when it isn't recognized, so an
    /// unexpected/new category from the API never disappears from the UI.
    static func displayLabel(for value: String) -> String {
        artTypeLabels[value] ?? venueTypeLabels[value] ?? value
    }
}
