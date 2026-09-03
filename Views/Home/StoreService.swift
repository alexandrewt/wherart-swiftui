import StoreKit
import Combine

@MainActor
class StoreService: ObservableObject {
    static let shared = StoreService()
    
    @Published var isPremium = false
    @Published var products: [Product] = []
    
    let productIds = [
        "com.alexandredewitt.wherart.monthly",
        "com.alexandredewitt.wherart.annual"
    ]
    
    init() {
        Task {
            await loadProducts()
            await checkEntitlements()
        }
    }
    
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIds)
        } catch {
        }
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await checkEntitlements()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }
    
    func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if productIds.contains(transaction.productID) {
                    isPremium = true
                    return
                }
            }
        }
        isPremium = false
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let value): return value
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
