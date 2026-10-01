import Foundation
import StoreKit
import Observation

@MainActor @Observable
final class SubscriptionStore {
    static let productIDs = ["com.nextbirthday.app.pro.monthly", "com.nextbirthday.app.pro.yearly"]
    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var isBusy = false
    var message: String?
    private var updates: Task<Void, Never>?

    func start() async {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await self.refreshEntitlements()
                    await transaction.finish()
                }
            }
        }
        await refreshEntitlements()
        await loadProducts()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.productIDs).sorted { $0.price < $1.price }
            message = products.isEmpty ? "Plans are currently unavailable. You can continue using all free features." : nil
        } catch { message = "Unable to load plans. Please try again when you’re connected." }
    }

    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil,
               !transaction.isUpgraded,
               let expiration = transaction.expirationDate, expiration > Date() {
                entitled = true
            }
        }
        isPro = entitled
    }

    func purchase(_ product: Product) async {
        guard !isBusy else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await refreshEntitlements()
                await transaction.finish()
            case .success(.unverified): message = "Apple could not verify this purchase. Please restore purchases or try again."
            case .pending: message = "Your purchase is awaiting approval. Pro will unlock when Apple confirms it."
            case .userCancelled: break
            @unknown default: message = "Purchase not completed. Please try again."
            }
        } catch { message = "Purchase could not be completed. Please try again." }
    }

    func restore() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = isPro ? "Your Pro subscription has been restored." : "No active Pro subscription was found for this Apple Account."
        } catch { message = "Unable to restore purchases. Please try again." }
    }
}
