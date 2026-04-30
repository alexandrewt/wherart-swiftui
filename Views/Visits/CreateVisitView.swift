import SwiftUI
import Auth

struct CreateVisitView: View {

    let onCreated: (WherartGroup) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var startDate = Date()
    @State private var time = Date()
    @State private var maxMembers = 6
    @State private var exhibitionId = ""
    @State private var isCreating = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Create a visit")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)

            ScrollView {
                VStack(spacing: 20) {

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Visit name")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("e.g. Sunday at Pompidou", text: $name)
                            .padding(14)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Exhibition ID")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("Exhibition ID", text: $exhibitionId)
                            .keyboardType(.numberPad)
                            .padding(14)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    DatePicker("Date", selection: $startDate, displayedComponents: .date)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Max members: \(maxMembers)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Slider(value: Binding(
                            get: { Double(maxMembers) },
                            set: { maxMembers = Int($0) }
                        ), in: 2...20, step: 1)
                        .tint(.blue)
                    }
                    .padding(14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            Button(action: handleCreate) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(canCreate ? Color.blue : Color(.systemGray4))
                        .frame(height: 52)
                    if isCreating {
                        ProgressView().tint(.white)
                    } else {
                        Text("Create visit")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(!canCreate || isCreating)
            .padding(24)
        }
    }

    private var canCreate: Bool {
        !name.isEmpty && !exhibitionId.isEmpty
    }

    private func handleCreate() {
        guard let expoId = Int(exhibitionId),
              let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            errorMessage = "Please fill in all fields correctly"
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: startDate)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: time)

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let group = try await SupabaseService.shared.createGroup(
                    exhibitionId: expoId,
                    name: name,
                    startDate: dateStr,
                    time: timeStr,
                    maxMembers: maxMembers,
                    userId: userId
                )
                await MainActor.run {
                    isCreating = false
                    onCreated(group)
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    CreateVisitView(onCreated: { _ in })
}
