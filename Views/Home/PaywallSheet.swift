import SwiftUI
import StoreKit

// MARK: - Shared Paywall Content

struct PaywallBodyView: View {
    var onDismiss: (() -> Void)? = nil
    var showSecondaryActions: Bool = true
    /// When set, tapping "Subscribe" dismisses and hands off to this instead of
    /// attempting the purchase right here (used by the HomeView popup, which
    /// should hand off to the full SubscribeView page rather than transact inline).
    var onSubscribeTapped: (() -> Void)? = nil

    private var store: StoreService { StoreService.shared }
    @State private var billingCycle: BillingCycle = .annual
    @State private var isPurchasing = false

    enum BillingCycle { case annual, monthly }

    private let impact = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()

    private var selectedProduct: Product? {
        store.products.first(where: {
            billingCycle == .annual
                ? $0.id.contains("annual")
                : $0.id.contains("monthly")
        })
    }

    var body: some View {
        VStack(spacing: 20) {

            VStack(spacing: 6) {
                Text("Wherart Pass")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Text(String(localized: "paywall_subtitle"))
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 28)

            // Billing toggle
            HStack(spacing: 0) {
                PillToggleButton(
                    label: String(localized: "billing_monthly"),
                    isSelected: billingCycle == .monthly,
                    action: {
                        selectionFeedback.selectionChanged()
                        billingCycle = .monthly
                    }
                )
                PillToggleButton(
                    label: String(localized: "billing_annual"),
                    isSelected: billingCycle == .annual,
                    action: {
                        selectionFeedback.selectionChanged()
                        billingCycle = .annual
                    }
                )
            }
            .padding(4)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 24))

            // Price card
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(billingCycle == .annual ? Color.blue.opacity(0.08) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(billingCycle == .annual ? Color.blue : Color.clear, lineWidth: 1.5)
                    )
                    .frame(height: 100)

                VStack(spacing: 4) {
                    if billingCycle == .annual {
                        Text(selectedProduct?.displayPrice ?? "€49.99")
                            .font(.system(size: 36, weight: .heavy))
                            .foregroundColor(.primary)
                        Text(String(localized: "per_year_save"))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("€4.17/month")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        Text(selectedProduct?.displayPrice ?? "€4.99")
                            .font(.system(size: 36, weight: .heavy))
                            .foregroundColor(.primary)
                        Text(String(localized: "per_month"))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 100)

                if billingCycle == .annual {
                    Text(String(localized: "most_popular"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .clipShape(Capsule())
                        .offset(y: -14)
                }
            }
            .padding(.top, billingCycle == .annual ? 14 : 0)

            // Features
            VStack(alignment: .leading, spacing: 14) {
                PaywallFeatureRow(icon: "star", text: String(localized: "feature_vernissage_title"), subtitle: String(localized: "feature_vernissage_subtitle"))
                PaywallFeatureRow(icon: "bolt", text: String(localized: "feature_skip_line_title"), subtitle: String(localized: "feature_skip_line_subtitle"))
                PaywallFeatureRow(icon: "mic", text: String(localized: "feature_guided_visit_title"), subtitle: String(localized: "feature_guided_visit_subtitle"))
            }

            // CTAs
            VStack(spacing: 12) {
                Button(action: {
                    if let onSubscribeTapped {
                        impact.impactOccurred()
                        onDismiss?()
                        onSubscribeTapped()
                        return
                    }
                    if store.isPremium {
                        onDismiss?()
                        return
                    }
                    guard let product = selectedProduct else {
                        // Products may still be loading (e.g. first launch) — retry
                        // instead of freezing the button in a permanent spinner.
                        Task { await store.loadProducts() }
                        return
                    }
                    impact.impactOccurred()
                    isPurchasing = true
                    Task {
                        do {
                            try await store.purchase(product)
                            await MainActor.run {
                                isPurchasing = false
                                if store.isPremium { onDismiss?() }
                            }
                        } catch {
                            await MainActor.run { isPurchasing = false }
                        }
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.blue)
                            .frame(height: 54)
                        if isPurchasing {
                            ProgressView().tint(.white)
                        } else if store.isPremium {
                            Text(String(localized: "active_wherart_pass"))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text(billingCycle == .annual ? String(localized: "subscribe_annual_price") : String(localized: "subscribe_monthly_price"))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(isPurchasing)
                .frame(maxWidth: .infinity)

                if showSecondaryActions {
                    Button(action: {
                        Task { await store.checkEntitlements() }
                    }) {
                        Text(String(localized: "restore_purchases"))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    if let onDismiss {
                        Button(action: onDismiss) {
                            Text(String(localized: "continue_without_subscription"))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Modal Paywall (auto-triggered overlay, e.g. from HomeView)

struct PaywallOverlay: View {
    @Binding var isPresented: Bool
    var onSubscribeTapped: (() -> Void)? = nil
    @State private var isVisible = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            PaywallBodyView(onDismiss: dismiss, onSubscribeTapped: onSubscribeTapped)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 24)
                .contentShape(Rectangle())
                .onTapGesture {}
                .scaleEffect(isVisible ? 1.0 : 0.92)
                .opacity(isVisible ? 1.0 : 0.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isVisible)
        }
        .onAppear {
            isVisible = true
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
}

// MARK: - Full-Page Paywall (Profile → Subscribe)

struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            PaywallBodyView(onDismiss: { dismiss() }, showSecondaryActions: false)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "subscribe"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PaywallFeatureRow: View {
    let icon: String
    let text: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

