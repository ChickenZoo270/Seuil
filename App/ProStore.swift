import Foundation
import StoreKit
import IntentionCore

/// Seuil Pro through StoreKit 2. Purchases only become possible once the paid
/// apps agreement is signed and the products exist in App Store Connect; until
/// then the store simply reports no product and the paywall says so.
@MainActor
final class ProStore: ObservableObject {
    /// One store for the whole app. Views read it directly instead of through
    /// the environment, where a sheet that forgets to pass it along crashes.
    static let shared = ProStore()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = false
    @Published private(set) var isLoading = true
    @Published var message = ""

    private var updates: Task<Void, Never>?
    /// Local unlock for TestFlight builds, before the products exist.
    private let testerKey = "seuil.proTester"

    var isTester: Bool {
        get { UserDefaults.standard.bool(forKey: testerKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: testerKey)
            isPro = newValue || isPro
            objectWillChange.send()
        }
    }

    init() {
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self, case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self.refresh()
            }
        }
        Task { await load() }
    }

    deinit { updates?.cancel() }

    func load() async {
        isLoading = true
        products = (try? await Product.products(for: ProProducts.all))?.sorted { $0.price < $1.price } ?? []
        await refresh()
        isLoading = false
    }

    func refresh() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, ProProducts.all.contains(transaction.productID) {
                owned = transaction.revocationDate == nil
            }
        }
        isPro = owned || UserDefaults.standard.bool(forKey: testerKey)
    }

    func purchase(_ product: Product) async {
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refresh()
                message = "Bienvenue dans Seuil Pro."
            case .success(.unverified):
                message = "Achat non vérifié par Apple."
            case .userCancelled:
                break
            case .pending:
                message = "Achat en attente de validation."
            @unknown default:
                break
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
        message = isPro ? "Achat restauré." : "Aucun achat à restaurer."
    }

    /// Plans shown on the paywall, from StoreKit when available.
    var plans: [ProPlan] {
        guard !products.isEmpty else {
            return [
                ProPlan(id: ProProducts.annual, title: "Annuel", price: "bientôt", detail: "7 jours d’essai gratuit",
                        perDay: "", badge: "7 JOURS OFFERTS"),
                ProPlan(id: ProProducts.monthly, title: "Mensuel", price: "bientôt", detail: "Sans engagement",
                        perDay: "", badge: nil),
            ]
        }
        return products.map { product in
            let days = product.id == ProProducts.monthly ? 30 : (product.id == ProProducts.lifetime ? 365 * 3 : 365)
            return ProPlan(id: product.id,
                           title: product.displayName,
                           price: product.displayPrice,
                           detail: product.id == ProProducts.annual ? "7 jours d’essai gratuit" : product.description,
                           perDay: ProPlan.perDay(price: NSDecimalNumber(decimal: product.price).doubleValue, days: days),
                           badge: product.id == ProProducts.annual ? "7 JOURS OFFERTS" : nil)
        }
    }

    func product(for plan: ProPlan) -> Product? { products.first { $0.id == plan.id } }
}
