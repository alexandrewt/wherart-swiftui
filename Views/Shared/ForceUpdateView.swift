import SwiftUI

/// Compares two "x.y.z"-style version strings component by component
/// (missing trailing components treated as 0, e.g. "1.6" == "1.6.0").
/// A non-numeric component (shouldn't happen for a real app version, but
/// app_config.value is free-form text an admin could mistype) is treated
/// as 0 rather than crashing.
func isAppVersion(_ current: String, olderThan minimum: String) -> Bool {
    let currentParts = current.split(separator: ".").map { Int($0) ?? 0 }
    let minimumParts = minimum.split(separator: ".").map { Int($0) ?? 0 }
    let count = max(currentParts.count, minimumParts.count)
    for i in 0..<count {
        let c = i < currentParts.count ? currentParts[i] : 0
        let m = i < minimumParts.count ? minimumParts[i] : 0
        if c != m { return c < m }
    }
    return false
}

/// Full-screen, non-dismissible gate shown when the installed app is older
/// than Supabase's `app_config.minimum_required_version` — see ContentView,
/// which checks this once at launch, before any other screen (including
/// guest mode) can render. Deliberately not a sheet/alert: those can be
/// swiped away or tapped outside.
struct ForceUpdateView: View {
    var body: some View {
        ZStack {
            Color(red: 0.15, green: 0.39, blue: 0.92)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("Vector")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)

                VStack(spacing: 12) {
                    Text(String(localized: "force_update_title"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(String(localized: "force_update_message"))
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button(action: openAppStore) {
                    Text(String(localized: "force_update_button"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.15, green: 0.39, blue: 0.92))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
        }
    }

    private func openAppStore() {
        guard let url = URL(string: "https://apps.apple.com/app/wherart") else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    ForceUpdateView()
}
