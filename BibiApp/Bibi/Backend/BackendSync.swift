import Supabase
import UIKit

/// Realtime is an invalidation signal. Every update is reconciled through RLS reads.
@MainActor
final class BackendSync {
    private let services: BackendServices
    private var channel: RealtimeChannelV2?
    private var tasks: [Task<Void, Never>] = []
    private var foregroundObserver: NSObjectProtocol?
    var onBusinessChange: ((String, AnyAction) -> Bool)?
    init(_ services: BackendServices) { self.services = services }
    func start(reconcile: @escaping @MainActor () async -> Void,
               reconcileChat: @escaping @MainActor () async -> Void,
               reconcileVisibility: @escaping @MainActor () async -> Void) async throws {
        stop()
        guard let account = services.accountID else { return }
        let generation = services.generation
        let channel = services.client.channel("account:\(account.uuidString):\(generation.uuidString)")
        self.channel = channel
        for table in ["bibi_content", "bibi_content_revisions", "bibi_messages", "bibi_conversations", "bibi_conversation_members", "bibi_profiles"] {
            let isChat = ["bibi_messages", "bibi_conversations", "bibi_conversation_members"].contains(table)
            let stream = channel.postgresChange(AnyAction.self, schema: "public", table: table)
            tasks.append(Task { [weak self] in
                for await change in stream {
                    guard let self, !Task.isCancelled, self.services.generation == generation else { break }
                    if self.onBusinessChange?(table, change) == true { continue }
                    if isChat { await reconcileChat() } else { await reconcile() }
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
                if UIApplication.shared.applicationState == .active {
                    await reconcileChat()
                    await reconcileVisibility()
                }
            }
        })
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in
                guard let self, self.services.generation == generation else { return }
                await reconcile()
            }
        }
        do { try await Self.subscribe(channel, services: services, generation: generation) }
        catch { stop(); throw error }
    }
    func stop() {
        tasks.forEach { $0.cancel() }; tasks.removeAll()
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
        foregroundObserver = nil
        let old = channel; channel = nil
        if let old { Task { await services.client.removeChannel(old) } }
    }

    /// SDK 2.30 has no throwing subscription API; check actual status within a finite attempt.
    static func subscribe(_ channel: RealtimeChannelV2, services: BackendServices, generation: UUID) async throws {
        let session = try await services.client.auth.session
        try services.check(generation)
        // Set the real session before the first JOIN instead of relying on Auth event timing.
        await services.client.realtimeV2.setAuth(session.accessToken)
        try services.check(generation)
        try await RealtimeJoinAttempt(channel: channel, services: services).run()
        try services.check(generation)
    }
}

/// Does not await an SDK retry task when a consumer's bounded attempt has ended.
@MainActor
private final class RealtimeJoinAttempt {
    private let channel: RealtimeChannelV2
    private let services: BackendServices
    private var continuation: CheckedContinuation<Void, Error>?
    private var tasks: [Task<Void, Never>] = []
    private var completed = false

    init(channel: RealtimeChannelV2, services: BackendServices) {
        self.channel = channel; self.services = services
    }

    func run() async throws {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                if completed {
                    self.continuation = nil
                    continuation.resume(throwing: CancellationError())
                    return
                }
                guard !Task.isCancelled else { finish(.failure(CancellationError())); return }
                let statuses = channel.statusChange
                tasks.append(Task { [self] in
                    for await status in statuses {
                        guard !Task.isCancelled else { return }
                        if status == .subscribed { finish(.success(())); return }
                    }
                })
                tasks.append(Task { [self] in
                    await channel.subscribe()
                    guard !Task.isCancelled else { return }
                    if channel.status == .subscribed { finish(.success(())) }
                    else { finish(.failure(BackendError.invalidInput("Live updates could not connect. Please try again."))) }
                })
                tasks.append(Task { [self] in
                    do { try await Task.sleep(nanoseconds: 15_000_000_000) }
                    catch { return }
                    finish(.failure(BackendError.invalidInput("Live updates timed out. Please try again.")))
                })
            }
        }, onCancel: { Task { @MainActor [self] in finish(.failure(CancellationError())) } })
    }

    private func finish(_ result: Result<Void, Error>) {
        guard !completed else { return }
        completed = true
        tasks.forEach { $0.cancel() }; tasks = []
        let waiting = continuation; continuation = nil
        if case .failure = result {
            let channel = channel, client = services.client
            Task { await client.removeChannel(channel) }
        }
        waiting?.resume(with: result)
    }
}
