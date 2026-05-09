import SwiftUI

struct LoginView: View {

    @StateObject private var service = SupabaseService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 32) {

                    // MARK: - Logo
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Welcome to Wherart")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Curated for you, enjoyed together")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }

                    // MARK: - Form
                    VStack(spacing: 12) {

                        if isSignUp {
                            RNTextField(placeholder: "First name *", text: $firstName)
                                .textContentType(.givenName)
                            RNTextField(placeholder: "Last name (optional)", text: $lastName)
                                .textContentType(.familyName)
                        }

                        RNTextField(placeholder: "your@email.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        RNSecureField(placeholder: "Password", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.leading)
                        }

                        Button(action: handleSubmit) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(Color.blue)
                                    .frame(height: 56)
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isSignUp ? "Create my account" : "Sign in")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(isLoading)
                        .padding(.top, 8)

                        HStack(spacing: 4) {
                            Text(isSignUp ? "Already have an account?" : "No account yet?")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Button(action: {
                                withAnimation { isSignUp.toggle(); errorMessage = nil }
                            }) {
                                Text(isSignUp ? "Sign in" : "Create an account")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }

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

// MARK: - RN-style TextField
struct RNTextField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        .font(.system(size: 15))
    }
}
