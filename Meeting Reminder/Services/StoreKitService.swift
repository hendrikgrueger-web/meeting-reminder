// Meeting Reminder/Services/StoreKitService.swift
import StoreKit
import SwiftUI

@MainActor
final class StoreKitService: ObservableObject {

    static let shared = StoreKitService()

    // MARK: - Product IDs

    static let monthlyID = "de.hendrikgrueger.nevrlate.premium.monthly"
    static let annualID  = "de.hendrikgrueger.nevrlate.premium.annual"

    // MARK: - Published State

    @Published var hasActiveSubscription: Bool = false
    @Published var products: [Product] = []
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: String? = nil

    // MARK: - Private

    private var transactionListener: Task<Void, Never>?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        transactionListener = Task { [weak self] in
            for await verificationResult in StoreKit.Transaction.updates {
                await self?.handle(verificationResult)
            }
        }
        Task { await loadProducts() }
        Task { await checkEntitlements() }
    }

    // MARK: - Produkte laden

    private func loadProducts() async {
        do {
            let loaded = try await Product.products(for: [Self.monthlyID, Self.annualID])
            // Jährlich zuerst anzeigen
            products = loaded.sorted { a, _ in a.id == Self.annualID }
        } catch {
            print("[StoreKit] Produkte laden fehlgeschlagen: \(error)")
        }
    }

    // MARK: - Entitlements prüfen

    func checkEntitlements() async {
        var active = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productType == .autoRenewable,
               transaction.revocationDate == nil {
                active = true
            }
        }
        hasActiveSubscription = active
    }

    // MARK: - Kaufen

    func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification)
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
            print("[StoreKit] Kauf fehlgeschlagen: \(error)")
        }
    }

    // MARK: - Käufe wiederherstellen

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            purchaseError = error.localizedDescription
            print("[StoreKit] Wiederherstellen fehlgeschlagen: \(error)")
        }
    }

    // MARK: - Transaction verarbeiten

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await checkEntitlements()
    }
}
