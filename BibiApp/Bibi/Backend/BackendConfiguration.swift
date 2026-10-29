import Foundation

/// One release gate: do not enable until every item in the backend release checklist passes.
enum BackendConfiguration {
    static let isEnabled = Bundle.main.object(forInfoDictionaryKey: "BibiBackendEnabled") as? Bool ?? false
    static let callbackURL = URL(string: "bibi://auth/callback")!
    static let recoveryURL = URL(string: "bibi://auth/recovery")!
    static let projectURL = URL(string: "https://yepycfnkkfrfmuwdekka.supabase.co")!
    static let publishableKey = "sb_publishable_dbqQ-uuTU6z0XcHLCpbwxg_wMQ4zE3p"
    static let environment = "Production"

    static func acceptsCallback(_ url: URL) -> Bool {
        url.scheme == callbackURL.scheme && url.host == callbackURL.host
            && [callbackURL.path, recoveryURL.path].contains(url.path) && url.user == nil && url.password == nil
            && url.port == nil && url.fragment == nil
    }
}

enum BackendError: LocalizedError {
    case unavailable, signedOut, accountChanged, invalidInput(String), invalidMedia, incompleteUpload
    var errorDescription: String? {
        switch self {
        case .unavailable: return "Online services are not available yet."
        case .signedOut: return "Sign in to continue."
        case .accountChanged: return "Your account changed. Please try again."
        case .invalidInput(let message): return message
        case .invalidMedia: return "Choose a supported image or a video up to three minutes and 50 MB."
        case .incompleteUpload: return "The upload has not finished. Your original file has been kept."
        }
    }
}
