import SwiftUI

struct JoinVisitConfirmView: View {

    let group: WherartGroup
    let exhibition: Exhibition?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 16)
                .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 24) {

                Text(String(localized: "join_this_visit"))
                    .font(.system(size: 22, weight: .bold))

                // Exhibition preview
                if let exhibition = exhibition {
                    HStack(spacing: 14) {
                        AsyncImage(url: URL(string: exhibition.image ?? "")) { phase in
                            Group {
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                        .transition(.opacity)
                                default:
                                    Rectangle().fill(Color(.systemGray5))
                                }
                            }
                            .animation(.easeIn(duration: 0.25), value: phase.image != nil)
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(exhibition.title)
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(2)
                            Text(exhibition.venue)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Visit details
                VStack(spacing: 0) {
                    ConfirmInfoRow(icon: "person.2", label: String(localized: "visit_name"), value: group.name)
                    Divider().padding(.leading, 44)
                    ConfirmInfoRow(icon: "calendar", label: String(localized: "date_label"), value: group.startDate.formattedVisitDate)
                    if let time = group.time {
                        Divider().padding(.leading, 44)
                        ConfirmInfoRow(icon: "clock", label: String(localized: "time_label"), value: time)
                    }
                    Divider().padding(.leading, 44)
                    ConfirmInfoRow(
                        icon: "person.2.fill",
                        label: String(localized: "members"),
                        value: "\(group.members?.count ?? 0) / \(group.maxMembers)"
                    )
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(spacing: 12) {
                    Button(action: onConfirm) {
                        Text(String(localized: "confirm"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                    }

                    Button(action: onCancel) {
                        Text(String(localized: "cancel"))
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

struct ConfirmInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 14))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
