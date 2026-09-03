import SwiftUI

// MARK: - Design System
//
// Named design tokens for colors, corner radii, and typography used across
// the app. This file is a foundation for future refactoring — existing
// screens still use their own hardcoded values and have not been migrated
// to these tokens yet.
enum DesignSystem {
    enum Colors {
        static let brandBlue = Color(red: 0.15, green: 0.39, blue: 0.92)
        static let brandBlueLight = Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.08)
        static let brandBlueMedium = Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.12)
        static let tagBadgeBlue = Color(red: 0.58, green: 0.77, blue: 0.99)
        static let tagBadgeText = Color(red: 0.12, green: 0.23, blue: 0.37)
    }
    enum Radius {
        static let button: CGFloat = 24
        static let card: CGFloat = 20
        static let chip: CGFloat = 20
        static let thumbnail: CGFloat = 12
        static let smallChip: CGFloat = 14
    }
    enum Typography {
        static let sectionTitle: Font = .system(size: 16, weight: .semibold)
        static let body: Font = .system(size: 15, weight: .regular)
        static let caption: Font = .system(size: 13, weight: .regular)
        static let cardTitle: Font = .system(size: 16, weight: .bold)
        static let label: Font = .system(size: 14, weight: .medium)
    }
}
