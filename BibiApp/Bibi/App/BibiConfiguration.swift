import Foundation

/// User-provided product identifiers; App Store availability is resolved by StoreKit.
/// Missing configuration prevents a payment request for that tier.
enum BibiConfiguration {
  static func productID(for amount: Int) -> String {
    guard let values = Bundle.main.object(forInfoDictionaryKey: "BibiDiamondProducts") as? [String: String]
    else { return "" }
    return values[String(amount)]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }
}
