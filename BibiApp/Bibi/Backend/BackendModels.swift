import Foundation

// Wire DTOs intentionally retain the database's English snake_case field names.
struct RemoteProfile: Codable, Identifiable {
    let id: UUID
    let display_name: String
    let biography: String
    let account_status: String
}
struct RemoteContent: Codable, Identifiable {
    let id: UUID
    let owner_id: UUID?
    let kind: String
    let circle_id: String?
    let parent_id: UUID?
    let reply_to: UUID?
    let approved_revision: UUID?
    let pending_revision: UUID?
    let editorial: Bool
    let withdrawn: Bool
    let removed: Bool
    let created_at: Date
}
struct RemoteRevision: Codable, Identifiable {
    let id: UUID
    let content_id: UUID
    let title: String
    let body: String
    let media_id: UUID?
    let video_id: UUID?
    let status: String
    let created_at: Date
}
struct RemoteMedia: Codable, Identifiable {
    let id: UUID
    let owner_id: UUID
    let bucket_id: String
    let object_path: String
    let mime_type: String
    let status: String
    let byte_count: Int64?
    let duration_seconds: Double?
}
struct RemoteRelationship: Codable {
    let user_id: UUID
    let target_id: UUID
}
struct RemoteSaved: Codable { let user_id: UUID; let content_id: UUID }
struct RemoteCircleMembership: Codable { let user_id: UUID; let circle_id: String }
struct RemoteCircle: Codable, Identifiable {
    let id: String; let title: String; let subtitle: String; let prompt: String; let artwork: String
}
struct RemoteChallenge: Codable, Identifiable {
    let id: String; let title: String; let category: String; let summary: String; let artwork: String; let steps: [String]
}
struct RemoteEntry: Codable, Identifiable {
    let id: UUID; let user_id: UUID; let challenge_id: String; let video_id: UUID; let created_at: Date
}
struct RemoteReport: Codable, Identifiable {
    let id: UUID; let user_id: UUID; let content_id: UUID?; let target_id: UUID?
    let reason: String; let details: String; let status: String; let created_at: Date; let hidden: Bool
}
struct RemoteConversation: Codable, Identifiable {
    let id: UUID; let kind: String; let owner_id: UUID?; let title: String; let created_at: Date
}
struct RemoteMember: Codable {
    let conversation_id: UUID; let user_id: UUID; let status: String; let joined_at: Date?
    let read_sequence: Int64; let pinned: Bool; let muted: Bool; let hidden: Bool
}
struct RemoteMessage: Codable, Identifiable {
    let id: UUID; let conversation_id: UUID; let sender_id: UUID?
    let body: String; let sequence: Int64; let created_at: Date
}
struct RemoteWallet: Codable {
    let user_id: UUID; let environment: String; let balance: Int64; let frozen: Bool
}
struct RemoteWalletActivity: Codable, Identifiable {
    let id: UUID; let user_id: UUID; let environment: String; let kind: String; let amount: Int64
    let transaction_id: String?; let post_id: UUID?; let gift_id: String?; let quantity: Int?; let created_at: Date
}
struct RemoteCounts: Codable {
    let likes: Int; let comments: Int; let saves: Int; let shares: Int
}
struct RemoteCredit: Decodable {
    let transaction_id: String; let balance: Int64; let environment: String
}
struct RemoteMediaReceipt: Decodable { let id: UUID; let status: String }
struct RemoteDeletionReceipt: Decodable { let status: String }

struct RemoteProfileCounts: Decodable { let following: Int; let followers: Int }
