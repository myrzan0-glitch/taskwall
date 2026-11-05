import SwiftUI
import StoreKit
import Shared

/// Wallist Pro through the App Store: a monthly auto-renewable subscription
/// or a one-time Lifetime unlock (non-consumable). Both unlock the same things.
///
/// The App Store is the source of truth. Each time it's checked, the answer is
/// passed to `onChange`, which saves it in the shared store so the screens and
/// the background shortcut agree (see `AppSettings.isPro`).
@MainActor
@Observable
final class ProStore {
    enum Phase: Equatable {
        case idle
        case purchasing
        case unlocked
        case failed(String)
    }

    private(set) var products: [String: Product] = [:]
    /// The plan this Apple Account owns, or nil without Pro.
    private(set) var plan: ProPlan?
    /// Monthly only: when the current month ends.
    private(set) var periodEnd: Date?
    /// Monthly only: false once the person has cancelled; Pro then ends at `periodEnd`.
    private(set) var willRenew = true
    var phase: Phase = .idle

    /// Called with whether Pro is unlocked, after every check.
    @ObservationIgnored var onChange: (@MainActor (Bool) -> Void)?
    @ObservationIgnored private var updates: Task<Void, Never>?
    /// UI tests: pretend to own Lifetime (true) without asking the App Store.
    @ObservationIgnored private let pretendLifetime: Bool

    init(pretendLifetime: Bool = false) {
        self.pretendLifetime = pretendLifetime
        guard !pretendLifetime else { return }
        // Renewals, refunds, cancellations and purchases made elsewhere (Ask to Buy, another device).
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
    }

    var isPro: Bool { plan != nil }

    func load() async {
        if pretendLifetime {
            plan = .lifetime
            onChange?(true)
            return
        }
        let ids = ProPlan.entries.map { $0.productId }
        if let list = try? await Product.products(for: ids) {
            products = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        }
        await refresh()
    }

    func price(for plan: ProPlan) -> String? {
        products[plan.productId]?.displayPrice
    }

    /// Asks the App Store what this account owns. Works offline from StoreKit's cache.
    func refresh() async {
        guard !pretendLifetime else { return }
        let owned = await Self.ownedPlans()
        let best = ProPlan.companion.best(plans: Array(owned.keys))
        plan = best
        periodEnd = best == .monthly ? owned[.monthly] ?? nil : nil
        willRenew = true
        if best == .monthly,
           let subscription = products[ProPlan.monthly.productId]?.subscription,
           let statuses = try? await subscription.status,
           let status = statuses.first,
           case .verified(let renewal) = status.renewalInfo {
            willRenew = renewal.willAutoRenew
        }
        onChange?(best != nil)
    }

    /// What the shortcut asks before drawing the wallpaper, so a subscription
    /// that ended while the app was closed stops showing Pro choices.
    static func ownsPro() async -> Bool {
        !(await ownedPlans()).isEmpty
    }

    /// Each owned plan, with when it ends (nil for Lifetime).
    private static func ownedPlans() async -> [ProPlan: Date?] {
        var owned: [ProPlan: Date?] = [:]
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  let plan = ProPlan.companion.forProductId(id: transaction.productID) else { continue }
            owned[plan] = transaction.expirationDate
        }
        return owned
    }

    func purchase(_ plan: ProPlan) async {
        guard let product = products[plan.productId] else {
            phase = .failed("Wallist Pro isn't available right now. Please try again later.")
            return
        }
        phase = .purchasing
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refresh()
                    phase = .unlocked
                } else {
                    phase = .failed("The App Store couldn't confirm the purchase.")
                }
            case .userCancelled:
                phase = .idle
            case .pending:
                // Ask to Buy: Transaction.updates unlocks Pro once it's approved.
                phase = .failed("Waiting for approval. Pro unlocks as soon as the purchase is approved.")
            @unknown default:
                phase = .idle
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Restore Purchases. Returns whether Pro is unlocked afterwards.
    @discardableResult
    func restore() async -> Bool {
        guard !pretendLifetime else { return true }
        phase = .purchasing
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            phase = .idle
            return isPro
        } catch {
            phase = .failed(error.localizedDescription)
            return isPro
        }
        await refresh()
        phase = isPro ? .unlocked : .failed("No Wallist Pro purchase was found for this Apple Account.")
        return isPro
    }
}
