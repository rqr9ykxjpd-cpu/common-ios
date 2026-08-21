import Foundation
import StoreKit

/// StoreKit 2 katmanı: ürünleri yükler, satın alır, hakları takip eder.
///
/// Kademenin **tek doğru kaynağı burası değil**. Burası cihazın ne bildiğini
/// söylüyor; sınırları uygulayan sunucu, `subscriptions` tablosuna bakıyor ve
/// oraya yalnızca makbuzu doğrulayan sunucu tarafı yazabiliyor. İkisi ayrı
/// olmak zorunda: cihazın söylediğine güvenip sınırları ona göre uygulasaydık,
/// uygulamayı kurcalayan biri bedava Pro olurdu.
///
/// Bu sınıf yalnızca doğrulanmış (`.verified`) işlemleri kabul eder. Apple'ın
/// imzasını taşımayan bir işlem yok sayılır.
@MainActor
@Observable
final class SubscriptionStore {
    enum ProductID {
        static let plus = "com.campus.social.plus.weekly"
        static let pro = "com.campus.social.pro.weekly"
        static let all = [plus, pro]

        static func tier(for id: String) -> SubscriptionTier? {
            switch id {
            case plus: .plus
            case pro: .pro
            default: nil
            }
        }
    }

    /// Satın alma girişiminin sonucu. Arayüz buna göre ne söyleyeceğine karar
    /// veriyor; iptal ile hata aynı şey değil.
    enum PurchaseOutcome {
        case success(SubscriptionTier)
        case cancelled
        /// Aile onayı bekliyor gibi durumlar: para geçmedi, hak da gelmedi.
        case pending
        case failed(String)
    }

    /// App Store'dan gelen ürünler. Boşsa fiyat gösterilemez ve satın alma
    /// düğmesi açılmaz — fiyatı biz uydurmuyoruz, Apple kullanıcının ülkesine
    /// ve para birimine göre biçimlendiriyor.
    private(set) var products: [Product] = []

    /// Cihazın bildiği güncel kademe.
    private(set) var tier: SubscriptionTier = .free

    private(set) var isLoadingProducts = false
    private(set) var purchasingTier: SubscriptionTier?
    private(set) var isRestoring = false

    /// Ürünler hiç yüklenemediyse sebebi. Paywall'da düğme yerine bunu gösteriyoruz;
    /// dokununca hiçbir şey olmayan bir düğme, kullanıcıya uygulama bozuk dedirtir.
    private(set) var productLoadFailure: String?

    /// Kademe değiştiğinde çağrılır: doğrulanmış işlemi sunucuya bildirmek için.
    /// `AppState` bağlıyor.
    var onEntitlementChange: ((SubscriptionTier, VerifiedPurchase?) -> Void)?

    /// Sunucuya gönderilecek kadarı. JWS, Apple'ın imzaladığı işlem belgesi;
    /// sunucu bunu Apple'a doğrulatmadan kademeyi değiştirmiyor.
    struct VerifiedPurchase {
        let productID: String
        let transactionID: UInt64
        let originalTransactionID: UInt64
        let expiresAt: Date?
        let jws: String
    }

    /// Dinleyici uygulamanın ömrü boyunca açık kalıyor ve bilerek iptal
    /// edilmiyor: Apple, `Transaction.updates`'ın uygulama açılır açılmaz
    /// dinlenmeye başlanmasını ve hiç bırakılmamasını istiyor. Aksi halde
    /// uygulama kapalıyken onaylanan bir satın alma hiç görülmüyor.
    private var updatesTask: Task<Void, Never>?

    init() {
        // Uygulama kapalıyken tamamlanan satın almalar (aile onayı, ödeme
        // sorununun çözülmesi, başka cihazdan yenileme) buradan geliyor.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.handle(update)
            }
        }
    }

    // MARK: - Ürünler

    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let yuklenen = try await Product.products(for: ProductID.all)
            // Ucuzdan pahalıya: Plus üstte, Pro altta görünsün.
            products = yuklenen.sorted { $0.price < $1.price }
            productLoadFailure = yuklenen.isEmpty
                ? "Abonelikler şu an yüklenemedi. İnternetini kontrol edip tekrar dener misin?"
                : nil
        } catch {
            products = []
            productLoadFailure = "Abonelikler şu an yüklenemedi. İnternetini kontrol edip tekrar dener misin?"
        }
    }

    func product(for tier: SubscriptionTier) -> Product? {
        switch tier {
        case .plus: products.first { $0.id == ProductID.plus }
        case .pro: products.first { $0.id == ProductID.pro }
        case .free: nil
        }
    }

    /// Apple'ın biçimlendirdiği fiyat. Ürün yüklenmediyse nil — yer tutucu bir
    /// fiyat göstermek, kullanıcıya yanlış rakam söylemek olurdu.
    func displayPrice(for tier: SubscriptionTier) -> String? {
        product(for: tier)?.displayPrice
    }

    // MARK: - Satın alma

    func purchase(_ tier: SubscriptionTier) async -> PurchaseOutcome {
        guard let product = product(for: tier) else {
            return .failed("Bu abonelik şu an alınamıyor.")
        }
        guard purchasingTier == nil else { return .cancelled }
        purchasingTier = tier
        defer { purchasingTier = nil }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard let islem = try? checkVerified(verification) else {
                    return .failed("Satın alma doğrulanamadı.")
                }
                await islem.finish()
                await refreshEntitlements(latest: verification)
                return .success(ProductID.tier(for: islem.productID) ?? .free)
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Satın alma tamamlanamadı.")
            }
        } catch {
            return .failed(UserFacingError.message(error, fallback: "Satın alma tamamlanamadı."))
        }
    }

    /// "Satın alımları geri yükle". Apple bunu abonelik satan her uygulamada
    /// şart koşuyor: cihaz değiştiren ya da uygulamayı silip kuran kullanıcı
    /// hakkını buradan geri alıyor.
    func restore() async -> String? {
        guard !isRestoring else { return nil }
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return tier == .free ? "Bu Apple hesabında etkin bir abonelik bulunamadı." : nil
        } catch {
            return UserFacingError.message(error, fallback: "Satın alımlar geri yüklenemedi.")
        }
    }

    // MARK: - Haklar

    /// Cihazdaki etkin abonelikleri okur. En yüksek kademe kazanır: Plus'tan
    /// Pro'ya geçen kullanıcıda ikisi birden bir süre etkin görünebiliyor.
    func refreshEntitlements(latest: VerificationResult<Transaction>? = nil,
                             forceSync: Bool = false) async {
        var enYuksek: SubscriptionTier = .free
        var kaynak: VerificationResult<Transaction>? = latest

        for await result in Transaction.currentEntitlements {
            guard let islem = try? checkVerified(result),
                  let kademe = ProductID.tier(for: islem.productID) else { continue }
            // Süresi geçmiş ya da iade edilmiş işlemler hak vermez.
            if let bitis = islem.expirationDate, bitis <= .now { continue }
            if islem.revocationDate != nil { continue }
            if kademe > enYuksek {
                enYuksek = kademe
                kaynak = result
            }
        }

        let degisti = enYuksek != tier
        tier = enYuksek
        if degisti || latest != nil || forceSync {
            onEntitlementChange?(enYuksek, kaynak.flatMap(verifiedPurchase))
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard let islem = try? checkVerified(result) else { return }
        await islem.finish()
        await refreshEntitlements(latest: result)
    }

    private func checkVerified(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .verified(let islem): islem
        case .unverified: throw StoreError.unverified
        }
    }

    private func verifiedPurchase(_ result: VerificationResult<Transaction>) -> VerifiedPurchase? {
        guard let islem = try? checkVerified(result) else { return nil }
        return VerifiedPurchase(
            productID: islem.productID,
            transactionID: islem.id,
            originalTransactionID: islem.originalID,
            expiresAt: islem.expirationDate,
            jws: result.jwsRepresentation
        )
    }

    enum StoreError: LocalizedError {
        case unverified
        var errorDescription: String? { "Satın alma Apple tarafından doğrulanamadı." }
    }
}
