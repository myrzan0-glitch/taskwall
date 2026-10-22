import SwiftUI
import StoreKit
import Shared

/// Wallist Pro through the App Store: auto-renewable subscriptions that unlock
/// the Pro wallpaper fonts. Whether Pro is active comes from StoreKit's current
/// entitlements, which also cover renewals, refunds and Family Sharing.
@MainActor
@Observable
final class ProStore {
    enum Status: Equatable {
        /// StoreKit hasn't answered yet; nothing is reset meanwhile.
        case unknown
        case free
        case pro
    }

    enum Phase: Equatable {
        case idle
        case purchasing
        case failed(String)
    }

    private(set) var products: [String: Product] = [:]
    private(set) var status: Status
    var phase: Phase = .idle

    var isPro: Bool { status == .pro }

    /// True in TestFlight (the App Store's sandbox), never for App Store downloads.
    private(set) var isTestBuild = false

    /// In TestFlight, until the Pro subscriptions exist in App Store Connect the
    /// store returns no products. Testers can then unlock Pro on their device for free.
    var canTestUnlock: Bool { isTestBuild && products.isEmpty }

    private static let testerProKey = "testerPro"

    /// UI tests launch with `-pro` to try Pro fonts without the App Store.
    @ObservationIgnored private let alwaysPro: Bool
    @ObservationIgnored private var updates: Task<Void, Never>?

    init(alwaysPro: Bool = false) {
        self.alwaysPro = alwaysPro
        status = alwaysPro ? .pro : .unknown
        // Renewals, refunds and purchases made elsewhere arrive here.
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
    }

    func load() async {
        if case .verified(let app)? = try? await AppTransaction.shared {
            isTestBuild = app.environment == .sandbox
        }
        let ids = ProPlan.entries.map { $0.productId }
        if let list = try? await Product.products(for: ids) {
            products = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        }
        await refresh()
    }

    /// Reads the active subscriptions again.
    func refresh() async {
        guard !alwaysPro else { return }
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               ProPlan.companion.forProductId(id: transaction.productID) != nil,
               transaction.revocationDate == nil {
                active = true
            }
        }
        let testerPro = isTestBuild && UserDefaults.standard.bool(forKey: Self.testerProKey)
        status = active || testerPro ? .pro : .free
    }

    /// TestFlight only: unlocks Pro on this device without a purchase.
    func testUnlock() {
        guard canTestUnlock else { return }
        UserDefaults.standard.set(true, forKey: Self.testerProKey)
        status = .pro
        phase = .idle
    }

    func price(for plan: ProPlan) -> String? {
        products[plan.productId]?.displayPrice
    }

    /// Returns true once Pro is active.
    @discardableResult
    func purchase(_ plan: ProPlan) async -> Bool {
        guard let product = products[plan.productId] else {
            phase = .failed("Pro isn't available right now. Please try again later.")
            return false
        }
        phase = .purchasing
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    phase = .failed("The App Store couldn't confirm the purchase.")
                    return false
                }
                await transaction.finish()
                await refresh()
                phase = .idle
                return isPro
            case .userCancelled, .pending:
                phase = .idle
            @unknown default:
                phase = .idle
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
        return false
    }

    /// Asks the App Store for purchases made on another device or before a reinstall.
    @discardableResult
    func restore() async -> Bool {
        phase = .purchasing
        do {
            try await AppStore.sync()
        } catch {
            phase = .failed(error.localizedDescription)
            return false
        }
        await refresh()
        phase = isPro ? .idle : .failed("No Pro subscription was found for this Apple Account.")
        return isPro
    }
}
