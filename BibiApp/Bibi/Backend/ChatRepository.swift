import Foundation
import Supabase

@MainActor
final class ChatRepository {
    let services: BackendServices
    private let content: ContentRepository
    private var channel: RealtimeChannelV2?
    private var changes: Task<Void, Never>?
    init(_ services: BackendServices) { self.services = services; content = ContentRepository(services) }
    deinit { changes?.cancel() }

    func messages(conversation: UUID, after: Int64 = 0) async throws -> [RemoteMessage] {
        _ = try services.requireAccount(); let generation = services.generation
        var result: [RemoteMessage] = [], cursor = after
        while true {
            let page: [RemoteMessage] = try await services.client.from("bibi_messages").select()
                .eq("conversation_id", value: conversation).gt("sequence", value: String(cursor))
                .order("sequence").limit(100).execute().value
            try services.check(generation); result.append(contentsOf: page)
            guard page.count == 100, let last = page.last else { return result }
            cursor = last.sequence
        }
    }

    func send(_ text: String, conversation: UUID) async throws {
        _ = try await content.mutate("send", payload: ["target_id": .string(conversation.uuidString), "body": .string(text)])
    }

    func openDirect(user: UUID) async throws -> UUID {
        let result = try await content.mutate("direct", payload: ["target_id": .string(user.uuidString)])
        guard let value = result["id"]?.stringValue, let id = UUID(uuidString: value) else { throw BackendError.unavailable }
        return id
    }

    func watch(conversation: UUID, reconcile: @escaping @MainActor () async -> Void) async throws {
        _ = try services.requireAccount(); let generation = services.generation
        stop()
        let next = services.client.channel("messages:\(conversation.uuidString):\(generation.uuidString)")
        let stream = next.postgresChange(AnyAction.self, schema: "public", table: "bibi_messages", filter: .eq("conversation_id", value: conversation.uuidString))
        channel = next
        changes = Task { [weak self] in
            for await _ in stream {
                guard let self, !Task.isCancelled, self.services.generation == generation else { break }
                await reconcile()
            }
        }
        await next.subscribe()
        try services.check(generation)
        await reconcile()
    }

    func stop() {
        changes?.cancel(); changes = nil
        let old = channel; channel = nil
        if let old { Task { await services.client.removeChannel(old) } }
    }
}
