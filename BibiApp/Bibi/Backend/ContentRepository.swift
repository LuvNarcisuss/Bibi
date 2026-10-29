import Foundation
import Supabase

@MainActor
final class ContentRepository {
    let services: BackendServices
    init(_ services: BackendServices) { self.services = services }

    func mutate(_ action: String, payload: [String: AnyJSON]) async throws -> [String: AnyJSON] {
        let account = try services.requireAccount(), generation = services.generation
        let cache = AccountCache.shared(account: account)
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let key = AccountCache.key(action: action, payload: try encoder.encode(payload))
        let operation = try await cache.operation(key: key)
        try services.check(generation)
        let response = try await services.command(action, operation: operation, payload: payload)
        // A failed acknowledgement write keeps the original ID for the next retry.
        try await cache.acknowledge(key: key, operation: operation)
        try services.check(generation)
        return response
    }

    func page(kind: String, before: Date? = nil, beforeID: UUID? = nil, limit: Int = 30) async throws -> [RemoteContent] {
        _ = try services.requireAccount(); let generation = services.generation
        var query = services.client.from("bibi_content").select().eq("kind", value: kind)
        if let before, let beforeID {
            let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let date = formatter.string(from: before)
            query = query.or("created_at.lt.\(date),and(created_at.eq.\(date),id.lt.\(beforeID.uuidString))")
        }
        let result: [RemoteContent] = try await query.order("created_at", ascending: false)
            .order("id", ascending: false).limit(min(max(limit, 1), 100)).execute().value
        try services.check(generation); return result
    }

    func counts(_ id: UUID) async throws -> RemoteCounts {
        struct Parameters: Encodable { let p_content: UUID }
        _ = try services.requireAccount(); let generation = services.generation
        let result: RemoteCounts = try await services.client.rpc("bibi_content_counts", params: Parameters(p_content: id)).execute().value
        try services.check(generation); return result
    }

    func publish(kind: String, title: String = "", body: String, circle: String? = nil,
                 parent: UUID? = nil, media: UUID? = nil, video: UUID? = nil, editing: UUID? = nil, challenge: String? = nil, replyingTo: UUID? = nil) async throws -> UUID {
        var payload: [String: AnyJSON] = ["kind": .string(kind), "title": .string(title), "body": .string(body)]
        payload["reply_to"] = replyingTo.map { .string($0.uuidString) }
        payload["challenge_id"] = challenge.map(AnyJSON.string)
        payload["circle_id"] = circle.map(AnyJSON.string)
        payload["parent_id"] = parent.map { .string($0.uuidString) }
        payload["media_id"] = media.map { .string($0.uuidString) }
        payload["video_id"] = video.map { .string($0.uuidString) }
        payload["target_id"] = editing.map { .string($0.uuidString) }
        let result = try await mutate("publish", payload: payload)
        guard let value = result["id"]?.stringValue, let id = UUID(uuidString: value) else { throw BackendError.unavailable }
        return id
    }
}
