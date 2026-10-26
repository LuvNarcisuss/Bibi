import CryptoKit
import Foundation

struct AgreementAcceptance: Codable {
    let version: String
    let acceptedAt: Date
}

enum AgreementDocument: String, Identifiable, CaseIterable {
    case terms = "TermsOfService"
    case privacy = "PrivacyPolicy"
    var id: String { rawValue }
    var title: String { self == .terms ? "Bibi - Terms of Service" : "Bibi - Privacy Policy" }
    var onlineURL: URL {
        let documentID = self == .terms
            ? "1Ht9y4vdWhBqBMEWh-TyDDkoelD4ovlfqnayIwr-b_4I"
            : "1tdj2Xd4VnOVLbFCgk-k65m8ONo3obRoFT1xddWTtY5c"
        return URL(string: "https://docs.google.com/document/d/\(documentID)")!
    }
    var readerURL: URL {
        var components = URLComponents(url: onlineURL.appendingPathComponent("preview"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "hl", value: "en")]
        return components.url!
    }
    func allowsOnlineNavigation(to url: URL) -> Bool {
        url.scheme == "https" && url.host == onlineURL.host
            && Array(url.pathComponents.prefix(4)) == onlineURL.pathComponents
    }
    var fileURL: URL? {
        Bundle.main.url(forResource: rawValue, withExtension: "html")
    }
}

enum BibiUserAgreement {
    // Version the configured sources and bundled snapshots. Remote edits require a new snapshot.
    static let version: String = {
        var content = Data()
        for document in AgreementDocument.allCases {
            guard let url = document.fileURL, let bytes = try? Data(contentsOf: url) else {
                return "unavailable"
            }
            content.append(contentsOf: document.rawValue.utf8)
            content.append(0)
            content.append(contentsOf: document.onlineURL.absoluteString.utf8)
            content.append(0)
            content.append(bytes)
        }
        let digest = SHA256.hash(data: content).map { String(format: "%02x", $0) }.joined()
        return "local-" + String(digest.prefix(12))
    }()
}
