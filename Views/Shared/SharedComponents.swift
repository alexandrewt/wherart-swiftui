import SwiftUI

// MARK: - Tag Badge
struct TagBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(red: 0.12, green: 0.23, blue: 0.37))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
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

/// Inserts a space between a lowercase letter immediately followed by an
/// uppercase letter (e.g. "eurosEnfant" → "euros Enfant", "19h00Fermé" →
/// "19h00 Fermé") — the Paris Open Data API frequently concatenates words
/// with no separator.
func insertMissingSpaces(_ text: String) -> String {
    text.replacingOccurrences(
        of: "([a-zà-ÿ])([A-ZÀ-Ÿ])",
        with: "$1 $2",
        options: .regularExpression
    )
}

/// Inserts a space between a digit immediately followed by a lowercase
/// letter (e.g. "2026de" → "2026 de").
private func insertSpaceAfterDigit(_ text: String) -> String {
    text.replacingOccurrences(
        of: #"(\d)([a-zà-ÿ])"#,
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

private func extractedPriceNumbers(_ text: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: #"\d+[,.]?\d*"#) else { return [] }
    let range = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, range: range).compactMap {
        Range($0.range, in: text).map { String(text[$0]) }
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
    let containsGratuit = lowercased.contains("gratuit")
    let numbers = extractedPriceNumbers(cleaned)
    let hasConditionKeyword = priceConditionKeywords.contains { lowercased.contains($0) }
    let isLong = cleaned.count > 30

    // Whenever "free" applies, the summary is always just "Free" — any
    // extra prices/conditions only surface via hasDetails, which routes the
    // user to the PricingSheet for the full breakdown.
    if isFree || containsGratuit {
        let withoutGratuit = lowercased
            .replacingOccurrences(of: "gratuit", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasDetails = !numbers.isEmpty || !withoutGratuit.isEmpty || isLong
        return (String(localized: "free"), hasDetails)
    }

    if numbers.count == 1 {
        return ("\(numbers[0])€", hasConditionKeyword || isLong)
    } else if numbers.count >= 2 {
        return (String(format: String(localized: "price_range_format"), numbers[0], numbers[1]), hasConditionKeyword || isLong)
    }

    return (cleaned, hasConditionKeyword || isLong)
}

