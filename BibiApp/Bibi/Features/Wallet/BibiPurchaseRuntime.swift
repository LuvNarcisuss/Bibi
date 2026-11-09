import Foundation
import StoreKit
import UIKit

@MainActor
protocol BibiPurchaseSettlement: AnyObject {
    var accountID: UUID? { get }
    func purchaseAvailable(source: ConfiguredPurchaseSource, productID: String, environment: String, account: UUID) async throws -> Bool
    func purchaseStatus(transactionID: String, environment: String, account: UUID) async throws -> BibiSettlementReply
    func confirmPurchase(_ record: BibiPurchaseRecord) async throws -> BibiSettlementReply
    func refreshBalance() async throws
}

/// System operations surround the existing purchasing state machine; no second observer or ledger.
@MainActor
struct BibiPurchaseRuntime {
    var register: (SKPaymentTransactionObserver) -> [SKPaymentTransaction]
    var snapshot: () -> [SKPaymentTransaction]
    var submit: (SKPayment) -> Void
    var finish: (SKPaymentTransaction) -> Void
    var resolve: (String) async throws -> SKProduct?
    var canPay: () -> Bool
    var environment: () -> String
    var deviceContext: () throws -> (String, String)
    var isActive: () -> Bool
    var sleep: (UInt64) async throws -> Void
    var appleInteractionTimeoutNanoseconds: UInt64
    var catalogRequestsEnabled: Bool
    var lifecycleObservationEnabled: Bool

    static var live: Self {
        Self(register: { observer in
            SKPaymentQueue.default().add(observer)
            return SKPaymentQueue.default().transactions
        }, snapshot: { SKPaymentQueue.default().transactions }, submit: { SKPaymentQueue.default().add($0) },
             finish: { SKPaymentQueue.default().finishTransaction($0) },
             resolve: { try await BibiSingleProductQuery().resolve($0) },
             canPay: { SKPaymentQueue.canMakePayments() },
             environment: { BibiReceiptEvidence.environment },
             deviceContext: {
            guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                  let data = try BackendKeychain().retrieve(key: "bibi-installation-uuid"),
                  let device = String(data: data, encoding: .utf8) else { throw BackendError.unavailable }
            return (version, device)
        }, isActive: { UIApplication.shared.applicationState == .active },
             sleep: { try await Task.sleep(nanoseconds: $0) },
             appleInteractionTimeoutNanoseconds: 90_000_000_000, catalogRequestsEnabled: true, lifecycleObservationEnabled: true)
    }

    #if DEBUG
    /// The explicitly selected validation host fails closed and never contacts Apple.
    static var disabled: Self {
        Self(register: { _ in [] }, snapshot: { [] }, submit: { _ in preconditionFailure("Disabled Apple payment submission") },
             finish: { _ in preconditionFailure("Disabled Apple transaction finish") }, resolve: { _ in nil },
             canPay: { false }, environment: { "Unknown" }, deviceContext: { throw BackendError.unavailable },
             isActive: { false }, sleep: { try await Task.sleep(nanoseconds: $0) },
             appleInteractionTimeoutNanoseconds: 90_000_000_000, catalogRequestsEnabled: false, lifecycleObservationEnabled: false)
    }
    #endif
}
