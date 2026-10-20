import SwiftUI
import StoreKit
import Shared

/// One-time tips through the App Store (consumable in-app purchases).
/// Tips unlock nothing; App Review requires tips to use in-app purchase.
@MainActor
@Observable
final class TipStore {
    enum Phase: Equatable {
        case idle
        case purchasing
        case thanked(String)
        case failed(String)
    }

    private(set) var products: [String: Product] = [:]
    var phase: Phase = .idle

    @ObservationIgnored private var updates: Task<Void, Never>?

    init() {
        // Finish tips that complete outside the app (e.g. Ask to Buy).
        updates = Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
            }
        }
    }

    func load() async {
        let ids = Tip.entries.map { $0.productId }
        guard let list = try? await Product.products(for: ids) else { return }
        products = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }

    func price(for tip: Tip) -> String? {
        products[tip.productId]?.displayPrice
    }

    func purchase(_ tip: Tip) async {
        guard let product = products[tip.productId] else {
            phase = .failed("Tips aren't available right now. Please try again later.")
            return
        }
        phase = .purchasing
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    phase = .thanked(tip.displayName)
                } else {
                    phase = .failed("The App Store couldn't confirm the purchase.")
                }
            case .userCancelled, .pending:
                phase = .idle
            @unknown default:
                phase = .idle
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
