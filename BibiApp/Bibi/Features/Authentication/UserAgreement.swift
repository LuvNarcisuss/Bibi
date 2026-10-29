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
        let base = "https://yepycfnkkfrfmuwdekka.supabase.co/storage/v1/object/public/bibi-agreements/2026-10-29/"
        return URL(string: base + rawValue + ".pdf")!
    }
    var readerURL: URL { onlineURL }
    func allowsOnlineNavigation(to url: URL) -> Bool {
        url.scheme == "https" && url.host == onlineURL.host
            && url.port == nil && url.path == onlineURL.path
            && url.query == nil && url.user == nil && url.password == nil
    }
    var fileURL: URL? {
        Bundle.main.url(forResource: rawValue, withExtension: "pdf")
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
