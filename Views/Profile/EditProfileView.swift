import SwiftUI
import Auth

struct EditProfileView: View {
    @Binding var profile: Profile?
    @Environment(\.dismiss) private var dismiss

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var isSaving = false

    private var email: String {
        SupabaseService.shared.currentUser?.email ?? ""
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "first_name"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                TextField(String(localized: "first_name"), text: $firstName)
                    .font(.system(size: 15))
                    .padding(16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 16)

                Text(String(localized: "last_name"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                TextField(String(localized: "last_name"), text: $lastName)
                    .font(.system(size: 15))
                    .padding(16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 16)

                Text(String(localized: "email_label"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                HStack {
                    Text(email)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 16)

                Text(String(localized: "email_change_not_available"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(String(localized: "edit_profile"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: handleSave) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(String(localized: "save")).font(.system(size: 16, weight: .semibold))
                    }
                }
                .disabled(isSaving || firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            firstName = profile?.firstName ?? ""
            lastName = profile?.lastName ?? ""
        }
    }

    private func handleSave() {
        guard var updated = profile else { return }
        isSaving = true
        updated.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            try? await SupabaseService.shared.upsertProfile(updated)
            await MainActor.run {
                profile = updated
                isSaving = false
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView(profile: .constant(nil))
    }
}
