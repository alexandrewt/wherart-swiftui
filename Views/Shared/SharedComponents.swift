import SwiftUI

// MARK: - Tag Badge
struct TagBadge: View {
    let label: String
    let color: Color
    /// Defaults to the original dark navy, which only reads well on the
    /// near-white venueType pill. The saturated per-category `typeColor(_:)`
    /// backgrounds (deep blues, reds, purples...) are too dark for that same
    /// navy text to meet contrast — callers using those pass `.white`.
    var textColor: Color = Color(red: 0.12, green: 0.23, blue: 0.37)

    var body: some View {
        // Unclassified exhibitions carry an empty type/venueType (see
        // sync-exhibitions' classifyExhibition) — no badge rather than an
        // empty pill.
        if !label.isEmpty {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(textColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Pill Toggle Button
struct PillToggleButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(isSelected ? Color(.systemBackground) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Visit Date Formatting

/// Parses the app's stored "yyyy-MM-dd" date strings. Locale is pinned to
/// `en_US_POSIX` (the standard choice for fixed-format parsing) so the
/// input format is never affected by the device's region settings.
private let visitDateInputFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

/// Renders visit dates in the device's current language (e.g. "May 15, 2026"
/// in English, "15 mai 2026" in French). Built from a locale-aware template
/// rather than a fixed "MMMM d, yyyy" pattern, since day/month order isn't
/// the same across languages.
private let visitDateOutputFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("dMMMMy")
    formatter.locale = Locale.autoupdatingCurrent
    return formatter
}()

extension String {
    /// Formats a "yyyy-MM-dd" visit date string into readable English
    /// (e.g. "May 15, 2026"). Falls back to the raw string if it doesn't
    /// match the expected format.
    var formattedVisitDate: String {
        guard let date = visitDateInputFormatter.date(from: self) else { return self }
        return visitDateOutputFormatter.string(from: date)
    }
}

// MARK: - HTML Entity Cleanup

extension String {
    /// Strips the HTML entities/tags found in the Paris Open Data API's raw
    /// text fields (schedule, price) so they render cleanly in SwiftUI Text.
    var cleanedFromHTML: String {
        self
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&euro;", with: "€")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Text Cleanup Helpers

/// Inserts a space wherever the Paris Open Data API concatenated two tokens
/// with no separator — most often a stripped `<br>`/`<p>` boundary that
/// glued the end of one sentence straight onto the next (real prod example:
/// "...Mémorial de la Shoah à ParisTarif : gratuit", "...20 juin
/// 2026Vernissage : jeudi..."). Covers the three letter/digit-case
/// transitions that reliably mark a lost boundary in this data:
///   - lowercase → uppercase: "eurosEnfant" → "euros Enfant"
///   - digit → uppercase: "2026Vernissage" → "2026 Vernissage"
///   - letter → digit: "Paris17 h 45" → "Paris 17 h 45"
///
/// Uses \p{Ll}/\p{Lu}/\p{L} (Unicode letter categories), NOT hand-rolled
/// [a-zà-ÿ]/[A-ZÀ-Ÿ] ranges — verified directly against NSRegularExpression
/// that the latter is broken: e.g. [A-ZÀ-Ÿ] matches every accented
/// LOWERCASE letter too (ô, é, à, ç...), not just uppercase ones, which
/// silently split words like "bientôt" into "bient ôt" for any French text
/// carrying an accent, in every price/schedule string that happened to have
/// an uppercase letter anywhere after it.
///
/// Deliberately leaves digit → lowercase alone (unlike the other two
/// transitions, real prod text glues digits directly to short suffixes,
/// not full words — "18h30", "1er", "3ème" — so that transition can't be
/// treated as a lost boundary the way the other three can).
func insertMissingSpaces(_ text: String) -> String {
    var result = text
    result = result.replacingOccurrences(of: #"(\p{Ll})(\p{Lu})"#, with: "$1 $2", options: .regularExpression)
    result = result.replacingOccurrences(of: #"(\d)(\p{Lu})"#, with: "$1 $2", options: .regularExpression)
    result = result.replacingOccurrences(of: #"(\p{L})(\d)"#, with: "$1 $2", options: .regularExpression)
    return result
}

/// Inserts a space between a digit immediately followed by a lowercase
/// letter (e.g. "2026de" → "2026 de").
private func insertSpaceAfterDigit(_ text: String) -> String {
    text.replacingOccurrences(
        of: #"(\d)(\p{Ll})"#,
        with: "$1 $2",
        options: .regularExpression
    )
}

/// Cleans the raw French schedule text from the Paris Open Data API: strips
/// HTML entities, fixes concatenated words, and removes a dangling trailing
/// colon.
func cleanedScheduleString(_ raw: String) -> String {
    var result = raw.cleanedFromHTML
    result = insertMissingSpaces(result)
    result = insertSpaceAfterDigit(result)
    result = result.trimmingCharacters(in: .whitespacesAndNewlines)
    while result.hasSuffix(":") {
        result.removeLast()
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    while result.contains("  ") {
        result = result.replacingOccurrences(of: "  ", with: " ")
    }
    return result
}

// MARK: - Localized Attribute Labels
//
// Filter options and community-submitted exhibition attributes (price,
// distance, accessibility, wait time) are stored and compared as fixed
// English strings — in `AppFilters`, in Supabase's `user_exhibition_edits`
// rows shared across every user regardless of device language, and in
// equality checks like `filters.prices.contains("Free")`. Translating those
// canonical values directly would break that matching the moment a French
// device saved or filtered on one. This maps a canonical value to its
// localized *display* text only; the value itself is never touched.
func localizedAttributeLabel(_ raw: String) -> String {
    // Values coming from the app itself (the filter sheet, the community
    // edit checkboxes) always use the exact canonical strings on the left.
    // Values scraped from Paris Open Data don't make that promise — the
    // same underlying fact ("this venue has wheelchair access") can show up
    // as "wheelchair accessible", "Wheelchair Accessible", "handicap
    // accessible", etc., none of which matched this map's old exact-string
    // lookup and so were displayed as raw, untranslated English even on a
    // French device. Matched case-insensitively against every known
    // variant instead of a single exact key.
    let variants: [(matches: [String], key: String)] = [
        (["free"], "filter_free"),
        (["paid"], "filter_paid"),
        (["under 1 km"], "filter_under_1km"),
        (["1 - 3 km", "1-3 km"], "filter_1_3km"),
        (["3 - 5 km", "3-5 km"], "filter_3_5km"),
        (["over 5 km"], "filter_over_5km"),
        (["wheelchair access", "wheelchair accessible", "wheelchair accessibility", "handicap accessible", "handicap access"], "filter_wheelchair"),
        (["lift available", "elevator available"], "filter_lift"),
        (["adapted toilets", "accessible toilets", "accessible restrooms"], "filter_toilets"),
        (["audioguide available", "audio guide available"], "filter_audioguide"),
        (["guide dogs not allowed", "no guide dogs"], "filter_no_guide_dogs"),
        (["kid friendly", "kids friendly", "family friendly", "family-friendly"], "filter_kid_friendly"),
        (["see venue website", "check venue website", "see website", "check website"], "filter_see_venue_website"),
        (["unknown"], "unknown"),
        (["< 15 min"], "filter_wait_under_15"),
        (["15 - 30 min", "15-30 min"], "filter_wait_15_30"),
        (["30 - 45 min", "30-45 min"], "filter_wait_30_45"),
        (["45 min - 1h", "45 min-1h"], "filter_wait_45_1h"),
        (["+ 1h", "+1h"], "filter_wait_over_1h"),
    ]

    let normalized = raw.trimmingCharacters(in: .whitespaces).lowercased()
    guard let match = variants.first(where: { $0.matches.contains(normalized) }) else { return raw }
    return String(localized: String.LocalizationValue(match.key))
}

// MARK: - Price Parsing

/// Words that indicate the raw price string carries conditions beyond a
/// single flat rate (reduced rate, age restrictions, etc.) — when present,
/// the parsed summary alone isn't the full story and callers should surface
/// an affordance (info icon, subtitle) pointing to the full text.
private let priceConditionKeywords = [
    "sous", "présentation", "billet", "réduit", "enfant", "adulte",
    "étudiant", "chômeur", "groupe", "gratuit"
]

private let priceFrenchPrefixes = ["de ", "à ", "De ", "À ", "Du ", "Dès "]

private func cleanedPriceString(_ raw: String) -> String {
    var result = raw.cleanedFromHTML
    result = insertMissingSpaces(result)
    for prefix in priceFrenchPrefixes where result.hasPrefix(prefix) {
        result.removeFirst(prefix.count)
    }
    result = result.trimmingCharacters(in: .whitespacesAndNewlines)
    while result.hasSuffix(".") || result.hasSuffix(",") {
        result.removeLast()
    }
    result = result.trimmingCharacters(in: .whitespacesAndNewlines)
    while result.contains("  ") {
        result = result.replacingOccurrences(of: "  ", with: " ")
    }
    return result
}

// Requires the digits to be immediately adjacent to a currency marker
// (€ or euro/euros) — a bare number alone is ambiguous with a percentage
// ("100% gratuites") or an unrelated number in the text (a phone number,
// e.g. "50€ les 3h, le matériel est compris. Inscription au 0623781910").
private func extractedPriceNumbers(_ text: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: #"(\d+[,.]?\d*)\s*(?:€|euros?)"#, options: [.caseInsensitive]) else { return [] }
    let range = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, range: range).compactMap { match in
        guard match.numberOfRanges > 1, let numberRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[numberRange])
    }
}

/// Parses the raw French price text from the Paris Open Data API into a
/// short English summary plus a flag indicating whether the full raw text
/// has details (conditions, multiple rates) worth showing separately.
func parsedPriceDisplay(_ price: String?, isFree: Bool) -> (summary: String, hasDetails: Bool) {
    guard let rawPrice = price, !rawPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return (String(localized: "free"), false)
    }

    let cleaned = cleanedPriceString(rawPrice)
    let lowercased = cleaned.lowercased()
    let numbers = extractedPriceNumbers(cleaned)
    let hasConditionKeyword = priceConditionKeywords.contains { lowercased.contains($0) }
    let isLong = cleaned.count > 30

    // A real price number (adjacent to €/euro) always wins, even if the
    // text also mentions "gratuit" as a partial exception — e.g. "À partir
    // de 16.5€. Gratuit pour les enfants de moins de 3 ans." is fundamentally
    // a paid exhibition, not a free one, despite containing "gratuit". Only
    // the first number is shown (not a "X€ to Y€" range): free text can
    // mention several € amounts that aren't a second price tier at all —
    // e.g. "16.5€... Tarif préférentiel en ligne : -1€ par rapport au tarif
    // sur place" is one price and a discount, not a "16.5€ to 1€" range.
    // Any remaining numbers still surface via hasDetails, in the full raw
    // text behind "Voir le détail des tarifs".
    if let firstNumber = numbers.first {
        return ("\(firstNumber)€", hasConditionKeyword || isLong || numbers.count > 1)
    }

    // No price number found — now check for free-entry wording. "Accès
    // libre"/"entrée libre" are treated the same (interchangeable in the
    // source data; "accès libre" is by far the more common phrasing).
    // Alone (nothing else in the string) -> a plain "Free". Attached to an
    // actual explanatory sentence ("Gratuit le premier dimanche du mois",
    // "Accès libre sans réservation") -> "Free (conditions apply)" with a
    // details link to the raw sentence. isFree (the API's own flag) is
    // folded into the same check, but only once no explicit price number
    // was found above — a numeric price in the text always takes priority
    // over a possibly-stale isFree flag.
    let freeWordings = ["entrée libre", "entree libre", "accès libre", "acces libre", "gratuit"]
    let containsFreeWording = freeWordings.contains { lowercased.contains($0) }
    if isFree || containsFreeWording {
        var stripped = lowercased
        for wording in freeWordings {
            stripped = stripped.replacingOccurrences(of: wording, with: "")
        }
        let hasCondition = !stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasCondition
            ? (String(localized: "free_with_conditions"), true)
            : (String(localized: "free"), false)
    }

    // No number, no free wording — just explanatory text (e.g. "Tarif
    // variable, se renseigner à l'accueil"). Never show the raw sentence
    // directly on a card — point to the pricing sheet instead, which shows
    // the untouched API text.
    return (String(localized: "see_pricing_details"), true)
}

