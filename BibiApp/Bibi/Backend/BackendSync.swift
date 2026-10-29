import Supabase
import UIKit

/// Realtime is an invalidation signal. Every update is reconciled through RLS reads.
@MainActor
final class BackendSync {
    private let services: BackendServices
    private var channel: RealtimeChannelV2?
    private var tasks: [Task<Void, Never>] = []
    init(_ services: BackendServices) { self.services = services }
    func start(reconcile: @escaping @MainActor () async -> Void) async {
        stop()
        guard let account = services.accountID else { return }
        let generation = services.generation
        let channel = services.client.channel("account:\(account.uuidString):\(generation.uuidString)")
        self.channel = channel
        for table in ["bibi_content", "bibi_messages", "bibi_conversation_members"] {
            let stream = channel.postgresChange(AnyAction.self, schema: "public", table: table)
            tasks.append(Task { [weak self] in
                for await _ in stream {
                    guard let self, !Task.isCancelled, self.services.generation == generation else { break }
                    await reconcile()
                }
            })
        }
        tasks.append(Task { [weak self] in
            for await status in channel.statusChange {
                guard let self, !Task.isCancelled, self.services.generation == generation else { break }
                if status == .subscribed { await reconcile() }
            }
        })
        // Periodic active-app reads also remove data whose access was revoked, which
        // may no longer produce an RLS-visible Realtime event for this account.
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { break }
                guard let self, self.services.generation == generation else { break }
                if UIApplication.shared.applicationState == .active { await reconcile() }
            }
        })
        await channel.subscribe()
    }
    func stop() {
        tasks.forEach { $0.cancel() }; tasks.removeAll()
        let old = channel; channel = nil
        if let old { Task { await services.client.removeChannel(old) } }
    }
}
