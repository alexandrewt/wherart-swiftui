import SwiftUI

/// Shown when the app is opened via the "https://wherart.com/reset-password"
/// Universal Link from the password reset email (see WherartApp's
/// `.onOpenURL`/`handleIncomingURL(_:)` and
/// SupabaseService.resetPassword/establishSession(fromRecoveryLink:)).
/// Presented at the ContentView root regardless of auth state, since the
/// user may be signed out when tapping the link.
struct ResetPasswordView: View {
    let recoveryURL: URL
    let onComplete: () -> Void

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isEstablishingSession = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if isEstablishingSession {
                ProgressView()
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "reset_password_title"))
                            .font(.system(size: 26, weight: .bold))
                        Text(String(localized: "reset_password_subtitle"))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 12) {
                        RNSecureField(placeholder: String(localized: "new_password_placeholder"), text: $newPassword)
                        RNSecureField(placeholder: String(localized: "confirm_password_placeholder"), text: $confirmPassword)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let successMessage {
                            Text(successMessage)
                                .font(.system(size: 13))
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Button(action: resetPassword) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(red: 0.15, green: 0.39, blue: 0.92))
                                .frame(height: 56)
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text(String(localized: "reset_password_action"))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .disabled(isSaving || successMessage != nil)

                    Spacer()
                }
                .padding(24)
            }
        }
        .task {
            do {
                try await SupabaseService.shared.establishSession(fromRecoveryLink: recoveryURL)
                isEstablishingSession = false
            } catch {
                isEstablishingSession = false
                errorMessage = String(format: String(localized: "reset_password_link_invalid"), error.localizedDescription)
            }
        }
    }

    private func resetPassword() {
        errorMessage = nil
        guard !newPassword.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = String(localized: "please_fill_fields")
            return
        }
        guard newPassword.count >= 6 else {
            errorMessage = String(localized: "password_too_short")
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = String(localized: "passwords_dont_match")
            return
        }

        isSaving = true
        Task {
            do {
                try await SupabaseService.shared.updatePassword(newPassword)
                await MainActor.run {
                    successMessage = String(localized: "password_reset_success")
                    isSaving = false
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { onComplete() }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    ResetPasswordView(recoveryURL: URL(string: "wherart://reset-password")!, onComplete: {})
}
