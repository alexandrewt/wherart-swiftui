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
        "Mixed Media": "Technique mixte",
        "Textile Art": "Art textile",
        "Ceramics": "Céramique",
        "Performance": "Performance",
    ]

    static let venueTypeLabels: [String: String] = [
        "Museum": "Musée",
        "Gallery": "Galerie",
        "Art Center": "Centre d'art",
        "Foundation": "Fondation",
        "Cultural Center": "Centre culturel",
        "Auction House": "Maison de vente",
        "Art Fair": "Foire d'art",
        "Public Space": "Espace public",
        "Historic Site": "Site historique",
        "Library": "Bibliothèque",
        "Church & Heritage": "Église et patrimoine",
        "Cultural Institute": "Institut culturel",
        "Artist Studio": "Atelier d'artiste",
    ]

    /// Localized display label for a stored art-type or venue-type value.
    /// Falls back to the raw value when it isn't recognized, so an
    /// unexpected/new category from the API never disappears from the UI.
    static func displayLabel(for value: String) -> String {
        artTypeLabels[value] ?? venueTypeLabels[value] ?? value
    }
}
