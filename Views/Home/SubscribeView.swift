import SwiftUI
import StoreKit

// MARK: - Subscribe View (full page, reached from ProfileView)
//
// Temporarily replaced with a "Coming soon" placeholder. The full
// StoreKit-backed subscription flow that used to live here is preserved
// below, commented out, so it can be re-enabled later.

struct SubscribeView: View {
    @Environment(\.dismiss) private var dismiss
    // @StateObject private var store = StoreService.shared

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "star.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))

            Text(String(localized: "coming_soon"))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)

            Text(String(localized: "wherart_pass_coming_soon_body"))
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Wherart Pass")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        SubscribeView()
    }
}
