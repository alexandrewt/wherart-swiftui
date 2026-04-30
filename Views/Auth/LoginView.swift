import SwiftUI

struct LoginView: View {

    @StateObject private var service = SupabaseService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {

                    // MARK: - Logo
                    VStack(spacing: 8) {
                        Text("Wherart")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(.white)
                        Text("Discover art in Paris")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 80)

                    // MARK: - Form
                    VStack(spacing: 16) {

                        if isSignUp {
                            TextField("First name", text: $firstName)
                                .textFieldStyle(WherartTextFieldStyle())
                                .textContentType(.givenName)
                        }

                        TextField("Email", text: $email)
                            .textFieldStyle(WherartTextFieldStyle())
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        SecureField("Password", text: $password)
                            .textFieldStyle(WherartTextFieldStyle())
                            .textContentType(isSignUp ? .newPassword : .password)

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        // MARK: - CTA
                        Button(action: handleSubmit) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white)
                                    .frame(height: 52)

                                if isLoading {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Text(isSignUp ? "Create account" : "Sign in")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                        .disabled(isLoading)

                        // MARK: - Toggle
                        Button(action: {
                            withAnimation {
                                isSignUp.toggle()
                                errorMessage = nil
                            }
                        }) {
                            Text(isSignUp ? "Already have an account? Sign in" : "No account? Create one")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }

    // MARK: - Actions
    private func handleSubmit() {
        errorMessage = nil
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }
        if isSignUp && firstName.isEmpty {
            errorMessage = "Please enter your first name"
            return
        }

        isLoading = true
        Task {
            do {
                if isSignUp {
                    try await service.signUp(email: email, password: password, firstName: firstName)
                } else {
                    try await service.signIn(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Custom TextField Style
struct WherartTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .foregroundColor(.white)
            .font(.system(size: 16))
            .tint(.white)
    }
}

#Preview {
    LoginView()
}
