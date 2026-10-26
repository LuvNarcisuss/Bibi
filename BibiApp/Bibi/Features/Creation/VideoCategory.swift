import Foundation

enum VideoCategory: String, CaseIterable, Identifiable {
    case anime, cosplay, manga, chill, fantasy, music
    var id: String { rawValue }
    var title: String {
        switch self {
        case .anime: return "Anime"; case .cosplay: return "Cosplay"; case .manga: return "Manga"
        case .chill: return "Chill"; case .fantasy: return "Fantasy"; case .music: return "Music"
        }
    }
    var asset: String { "VideoCategory-\(rawValue)" }
    var symbol: String {
        switch self {
        case .anime: return "waveform"; case .cosplay: return "star.fill"; case .manga: return "music.note"
        case .chill: return "figure.dance"; case .fantasy: return "sparkles"; case .music: return "opticaldisc"
        }
    }
}

