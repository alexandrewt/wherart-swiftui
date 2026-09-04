import SwiftUI
import Auth
import AuthenticationServices
import CryptoKit
import GoogleSignIn

struct LoginView: View {

    private var service: SupabaseService { SupabaseService.shared }

    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var appeared = false
    @State private var currentNonce: String?

    /// The sign-up legal disclaimer as one attributed string, so it renders
    /// (and wraps) as a single paragraph in `Text` rather than as separate
    /// Text/Link rows on fixed lines — see the "Privacy Policy" section in
    /// `body` for why that matters. Colors are set per-run explicitly (not
    /// via a `.foregroundColor` view modifier) since that modifier would
    /// apply uniformly and erase the link/plain-text color distinction.
    private var legalText: AttributedString {
        let brandBlue = Color(red: 0.15, green: 0.39, blue: 0.92)

        var prefix = AttributedString(String(localized: "signup_agree") + " ")
        prefix.foregroundColor = .secondary

        var privacy = AttributedString(String(localized: "privacy_policy"))
        privacy.foregroundColor = brandBlue
        privacy.link = URL(string: "https://wherart.figma.site/politique-confidentialite")

        var middle = AttributedString(" " + String(localized: "and_our") + " ")
        middle.foregroundColor = .secondary

        var terms = AttributedString(String(localized: "terms_of_use"))
        terms.foregroundColor = brandBlue
        terms.link = URL(string: "https://wherart.figma.site/conditions-utilisation")

        return prefix + privacy + middle + terms
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 32) {

                    // MARK: - Logo
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "welcome_title"))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        Text(String(localized: "welcome_subtitle"))
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 32)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.05), value: appeared)

                    // MARK: - Form
                    VStack(spacing: 12) {

                        // MARK: Fields
                        VStack(spacing: 12) {
                            if isSignUp {
                                RNTextField(placeholder: String(localized: "first_name_required_placeholder"), text: $firstName)
                                    .textContentType(.givenName)
                                RNTextField(placeholder: String(localized: "last_name_required_placeholder"), text: $lastName)
                                    .textContentType(.familyName)
                            }

                            RNTextField(placeholder: String(localized: "email_placeholder"), text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)

                            RNSecureField(placeholder: String(localized: "password_placeholder"), text: $password)
                                .textContentType(isSignUp ? .newPassword : .password)

                            if !isSignUp {
                                Button(action: handleForgotPassword) {
                                    Text(String(localized: "forgot_password"))
                                        .font(.system(size: 13))
                                        .foregroundColor(.blue)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }

                            if let error = errorMessage {
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if let success = successMessage {
                                Text(success)
                                    .font(.system(size: 13))
                                    .foregroundColor(.green)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)

                        // MARK: Actions
                        VStack(spacing: 12) {
                            Button(action: handleSubmit) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(Color(red: 0.15, green: 0.39, blue: 0.92))
                                        .frame(height: 56)
                                        .shadow(color: Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.35), radius: 12, x: 0, y: 4)
                                    if isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text(isSignUp ? String(localized: "create_my_account") : String(localized: "sign_in"))
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .disabled(isLoading)
                            .padding(.top, 8)

                            // MARK: - Privacy Policy (sign up only)
                            if isSignUp {
                                // A single attributed Text wraps as one natural paragraph —
                                // the previous two-HStack layout forced a fixed line break
                                // between "...notre" and "Politique de confidentialité"
                                // regardless of available width, which produced a choppy,
                                // non-wrapping rendering instead of a centered paragraph.
                                Text(legalText)
                                    .font(.system(size: 12))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                            HStack(spacing: 4) {
                                Text(isSignUp ? String(localized: "already_have_account") : String(localized: "no_account_yet"))
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                Button(action: {
                                    withAnimation {
                                        isSignUp.toggle()
                                        errorMessage = nil
                                        successMessage = nil
                                    }
                                }) {
                                    Text(isSignUp ? String(localized: "sign_in") : String(localized: "create_account"))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)

                            // Divider & OAuth Section
                            Divider()
                                .padding(.vertical, 16)

                            Text(isSignUp ? String(localized: "oauth_section_signup") : String(localized: "oauth_section_signin"))
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)

                            HStack(spacing: 16) {
                                // SIGN IN WITH APPLE
                                Button(action: {
                                    Task {
                                        await handleAppleSignInTapped()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "apple.logo")
                                            .font(.system(size: 18))
                                        Text("Apple")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .foregroundColor(.white)
                                    .background(Color.black)
                                    .cornerRadius(8)
                                }

                                // SIGN IN WITH GOOGLE
                                Button(action: {
                                    Task {
                                        await handleGoogleSignIn()
                                    }
                                }) {
                                    HStack {
                                        Image("GoogleLogo")
                                            .resizable()
                                            .renderingMode(.original)
                                            .frame(width: 18, height: 18)
                                        Text("Google")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .foregroundColor(.white)
                                    .background(Color(red: 0.2, green: 0.5, blue: 1.0))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.top, 8)

                            // Continue without account
                            Button(action: handleGuestMode) {
                                Text(String(localized: "browse_without_account"))
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                        }
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.25), value: appeared)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                appeared = true
                currentNonce = randomNonceString()
            }
        }
    }

    // MARK: - Actions
    private func handleSubmit() {
        errorMessage = nil
        successMessage = nil
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = String(localized: "please_fill_fields")
            return
        }
        if isSignUp && firstName.isEmpty {
            errorMessage = String(localized: "please_enter_first_name")
            return
        }
        if isSignUp && lastName.isEmpty {
            errorMessage = String(localized: "please_enter_last_name")
            return
        }
        isLoading = true

        let authEvent = isSignUp ? "signup_started" : "login_started"
        AnalyticsService.shared.track(authEvent, properties: ["email": email])

        Task {
            do {
                if isSignUp {
                    try await SupabaseService.shared.signUp(email: email, password: password, firstName: firstName)
                    await MainActor.run {
                        AnalyticsService.shared.track("signup_completed", properties: [
                            "email": email,
                            "method": "email"
                        ])
                        if let userId = SupabaseService.shared.currentUser?.id.uuidString {
                            AnalyticsService.shared.identify(userId: userId, properties: [
                                "email": email,
                                "created_at": Date().ISO8601Format(),
                                "signup_method": "email"
                            ])

                            // Si l'utilisateur était en guest mode avant, créer un alias
                            if SupabaseService.shared.isGuestMode {
                                AnalyticsService.shared.createAlias(distinctId: "guest", userId: userId)
                            }
                        }
                    }
                } else {
                    try await SupabaseService.shared.signIn(email: email, password: password)
                    await MainActor.run {
                        AnalyticsService.shared.track("login_completed", properties: [
                            "email": email,
                            "method": "email"
                        ])
                        if let userId = SupabaseService.shared.currentUser?.id.uuidString {
                            AnalyticsService.shared.identify(userId: userId, properties: [
                                "email": email,
                                "last_login_at": Date().ISO8601Format()
                            ])
                        }
                    }
                }
            } catch {
                let failEvent = isSignUp ? "signup_failed" : "login_failed"
                await MainActor.run {
                    AnalyticsService.shared.track(failEvent, properties: [
                        "email": email,
                        "error_type": String(describing: type(of: error)),
                        "error_message": error.localizedDescription
                    ])

                    AnalyticsService.shared.trackError(
                        domain: "auth",
                        code: (error as NSError).code,
                        message: error.localizedDescription,
                        context: ["flow": isSignUp ? "signup" : "login"]
                    )
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run { isLoading = false }
        }
    }

    private func handleForgotPassword() {
        errorMessage = nil
        successMessage = nil
        guard !email.isEmpty else {
            errorMessage = String(localized: "enter_email_first")
            return
        }
        isLoading = true
        Task {
            do {
                try await SupabaseService.shared.resetPassword(email: email)
                await MainActor.run {
                    AnalyticsService.shared.track("password_reset_completed", properties: [
                        "email": email
                    ])
                    successMessage = String(localized: "check_inbox_reset_password")
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    AnalyticsService.shared.track("password_reset_failed", properties: [
                        "email": email,
                        "error_type": String(describing: type(of: error)),
                        "error_message": error.localizedDescription
                    ])

                    AnalyticsService.shared.trackError(
                        domain: "auth",
                        code: (error as NSError).code,
                        message: error.localizedDescription,
                        context: ["flow": "password_reset"]
                    )
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    /// Triggers the Apple authorization request manually (used by the custom
    /// "Apple" button, styled to match the Google button, rather than the
    /// native SignInWithAppleButton whose label can't be reduced to just
    /// "Apple") and forwards the result to the existing handler.
    private func handleAppleSignInTapped() async {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        // Apple requires the SHA256 hash of the nonce here, not the raw
        // value — the raw nonce (currentNonce) is kept as-is and sent to
        // Supabase separately in handleAppleSignIn, which hashes it itself
        // to compare against the hash Apple embeds in the identity token.
        // Sending the same (raw or hashed) value to both sides is exactly
        // what causes a "nonces mismatch" error at the Supabase step.
        if let nonce = currentNonce {
            request.nonce = sha256(nonce)
        }

        let coordinator = AppleSignInCoordinator()
        let result = await coordinator.performRequest(request)
        await handleAppleSignIn(result)
    }

    private func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = String(localized: "error_invalid_apple_credential")
                AnalyticsService.shared.track("signin_apple_failed", properties: [
                    "error": "Invalid credential type"
                ])
                return
            }
            
            guard let nonce = currentNonce else {
                errorMessage = String(localized: "error_nonce_unavailable")
                AnalyticsService.shared.track("signin_apple_failed", properties: [
                    "error": "Nonce missing"
                ])
                return
            }
            
            guard let identityToken = appleIDCredential.identityToken else {
                errorMessage = String(localized: "error_unable_fetch_identity_token")
                AnalyticsService.shared.track("signin_apple_failed", properties: [
                    "error": "No identity token"
                ])
                return
            }
            
            let email = appleIDCredential.email ?? ""
            let firstName = appleIDCredential.fullName?.givenName ?? ""
            let lastName = appleIDCredential.fullName?.familyName ?? ""

            print("[AppleSignIn] Starting sign in with email: \(email), name: \(firstName) \(lastName)")

            AnalyticsService.shared.track("signin_apple_started", properties: [
                "email": email,
                "firstName": firstName,
                "lastName": lastName
            ])

            do {
                try await service.signInWithApple(
                    identityToken: identityToken,
                    nonce: nonce,
                    firstName: firstName.isEmpty ? nil : firstName,
                    lastName: lastName.isEmpty ? nil : lastName,
                    email: email.isEmpty ? nil : email
                )
                
                print("[AppleSignIn] Sign in successful")
                
                AnalyticsService.shared.track("signin_apple_completed", properties: [
                    "email": email,
                    "firstName": firstName,
                    "method": "apple"
                ])
                
            } catch {
                errorMessage = String(format: String(localized: "error_apple_signin_failed"), error.localizedDescription)
                print("[AppleSignIn] Error: \(error.localizedDescription)")
                
                AnalyticsService.shared.track("signin_apple_failed", properties: [
                    "error": error.localizedDescription,
                    "email": email,
                    "error_domain": (error as NSError).domain,
                    "error_code": (error as NSError).code
                ])
            }
        
        case .failure(let error):
            let nsError = error as NSError
            if nsError.code == ASAuthorizationError.canceled.rawValue {
                print("[AppleSignIn] User cancelled")
                return
            }
            
            errorMessage = String(format: String(localized: "error_apple_signin_error"), error.localizedDescription)
            print("[AppleSignIn] Authorization error: \(error.localizedDescription)")
            
            AnalyticsService.shared.track("signin_apple_failed", properties: [
                "error": error.localizedDescription,
                "error_type": "authorization_error"
            ])
        }
    }

    private func handleGoogleSignIn() async {
        AnalyticsService.shared.track("signin_google_started", properties: [:])

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            await MainActor.run {
                errorMessage = String(localized: "error_unable_present_google")
                AnalyticsService.shared.track("signin_google_failed", properties: [
                    "error": "no_root_view_controller"
                ])
            }
            return
        }

        do {
            // Supabase's signInWithIdToken always hashes whatever `nonce`
            // you pass it and compares that hash to the id_token's nonce
            // claim (documented on OpenIDConnectCredentials.nonce) — same
            // rule for every provider, not just Apple. So exactly like the
            // Apple flow: send the SHA256 hash to the provider (so its JWT
            // embeds that hash), and send the raw, unhashed nonce to
            // Supabase. Previously no nonce was passed to
            // signIn(withPresenting:) at all, which is what caused
            // "Passed nonce and nonce in id_token should either both exist
            // or not" — one side had none, the other did.
            let rawNonce = randomNonceString()
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: nil,
                nonce: sha256(rawNonce)
            )
            let user = result.user
            let email = user.profile?.email ?? ""
            let firstName = user.profile?.givenName ?? ""
            let lastName = user.profile?.familyName ?? ""
            let idToken = user.idToken?.tokenString ?? ""

            guard !idToken.isEmpty else {
                await MainActor.run {
                    errorMessage = String(localized: "error_unable_fetch_google_token")
                    AnalyticsService.shared.track("signin_google_failed", properties: [
                        "error": "No ID token",
                        "email": email
                    ])
                }
                return
            }

            try await SupabaseService.shared.signInWithGoogle(
                idToken: idToken,
                nonce: rawNonce,
                email: email.isEmpty ? nil : email,
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName
            )

            await MainActor.run {
                AnalyticsService.shared.track("signin_google_completed", properties: [
                    "email": email,
                    "firstName": firstName,
                    "method": "google"
                ])

                if let userId = user.userID {
                    AnalyticsService.shared.identify(userId: userId, properties: [
                        "email": email,
                        "created_at": Date().ISO8601Format(),
                        "signup_method": "google"
                    ])

                    if SupabaseService.shared.isGuestMode {
                        AnalyticsService.shared.createAlias(distinctId: "guest", userId: userId)
                    }
                }

                errorMessage = nil
            }
        } catch let error as NSError {
            await MainActor.run {
                if error.code == GIDSignInError.canceled.rawValue {
                    print("[GoogleSignIn] User cancelled")
                    return
                }

                errorMessage = String(format: String(localized: "error_google_signin_failed"), error.localizedDescription)
                AnalyticsService.shared.track("signin_google_failed", properties: [
                    "error": error.localizedDescription,
                    "error_domain": error.domain,
                    "error_code": error.code
                ])
            }
        }
    }

    private func handleGuestMode() {
        AnalyticsService.shared.track("guest_mode_selected", properties: [:])
        SupabaseService.shared.isGuestMode = true
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
}

// MARK: - RN-style TextField
struct RNTextField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            .font(.system(size: 15))
            .focused($isFocused)
    }
}

// MARK: - RN-style SecureField
struct RNSecureField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isVisible = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            if isVisible {
                TextField(placeholder, text: $text)
                    .focused($isFocused)
            } else {
                SecureField(placeholder, text: $text)
                    .focused($isFocused)
            }
            Button(action: { isVisible.toggle() }) {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .font(.system(size: 15))
    }
}

/// Wraps ASAuthorizationController's delegate-based API in an async call,
/// so the custom "Apple" button can drive the same Apple ID request the
/// native SignInWithAppleButton used to, without needing that component's
/// fixed (localized) label.
private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<Result<ASAuthorization, Error>, Never>?

    func performRequest(_ request: ASAuthorizationAppleIDRequest) async -> Result<ASAuthorization, Error> {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: .success(authorization))
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(returning: .failure(error))
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

#Preview {
    LoginView()
}
