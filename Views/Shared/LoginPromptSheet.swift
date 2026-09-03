import SwiftUI

// MARK: - Login Prompt Sheet
//
// Shown in place of an account-only action (favorite, comment, create visit,
// the Visits/Profile tabs, ...) whenever `SupabaseService.shared.isGuestMode`
// is true. The CTA hands control back to ContentView by flipping guest mode
// off, which routes straight to LoginView.
struct LoginPromptSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(String(localized: "sign_in_to_continue"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                Text(String(localized: "login_prompt_subtitle"))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 12)

            VStack(spacing: 12) {
                Button(action: {
                    dismiss()
                    SupabaseService.shared.isGuestMode = false
                }) {
                    Text(String(localized: "sign_in_or_create_account"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(red: 0.15, green: 0.39, blue: 0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }

                Button(action: { dismiss() }) {
                    Text(String(localized: "not_now"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationCornerRadius(24)
    }
}

// MARK: - Guest Gate View
//
// Placeholder content for tabs that are entirely account-only (Visits,
// Profile) while in guest mode. Shown behind LoginPromptSheet.
struct GuestGateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(String(localized: "sign_in_to_continue"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        LoginPromptSheet()
    }
}
