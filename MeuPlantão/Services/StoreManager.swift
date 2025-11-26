import Foundation
import StoreKit
import Combine // <--- Adicionado para corrigir o erro de ObservableObject

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    
    // CORRIGIDO: "private let" separado (estava "privatelet")
    private let productDict: [String: String] = [
        "com.meuplantao.mensal": "Mensal",
        "com.meuplantao.anual": "Anual"
    ]
    
    // Simulação de status Premium (para teste)
    @Published var isPremium = false
    
    func loadProducts() async {
        do {
            let products = try await Product.products(for: productDict.keys)
            self.products = products.sorted(by: { $0.price < $1.price })
            await updateCustomerProductStatus()
        } catch {
            print("Erro ao buscar produtos: \(error)")
        }
    }
    
    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                // Compra deu certo
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateCustomerProductStatus()
                isPremium = true
            case .userCancelled, .pending:
                break
            default:
                break
            }
        } catch {
            print("Falha na compra: \(error)")
        }
    }
    
    func restorePurchases() async {
        // O StoreKit 2 sincroniza automaticamente, mas forçamos a atualização
        try? await AppStore.sync()
        await updateCustomerProductStatus()
    }
    
    func updateCustomerProductStatus() async {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchasedProductIDs.insert(transaction.productID)
                isPremium = true
            } catch {
                print("Falha na verificação: \(error)")
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    enum StoreError: Error {
        case failedVerification
    }
}
