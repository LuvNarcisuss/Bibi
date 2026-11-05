import Foundation

/// Transport callbacks publish whole messages. All business parsing lives in the receiver.
@MainActor
final class BibiConfiguredTransport {
    private(set) var client: ConfiguredRealtimeClient?
    private let notifications: BibiConfiguredNotifications
    init(notifications: BibiConfiguredNotifications) { self.notifications = notifications }

    func connect(ticket: ConfiguredRealtimeTicket, context: BibiConfiguredMessageContext,
                 services: BackendServices, ready: @escaping (Bool) -> Void,
                 state: @escaping (ConfiguredRealtimeClient.State) -> Void, failure: @escaping () -> Void) {
        stop()
        var callbacks = ConfiguredRealtimeClient.Callbacks()
        callbacks.onReady = ready
        callbacks.onState = state
        callbacks.onMessage = { [weak self] message in
            guard let self else { return }
            do { try self.notifications.post(message: message, context: context) }
            catch { failure() }
        }
        client = ConfiguredRealtimeClient(callbacks: callbacks, refresh: { completion in
            let task = Task { @MainActor in
                do {
                    try services.check(context.generation)
                    let result = try await BibiConfiguredAuth.authenticate(context.identity, services: services)
                    try services.check(context.generation)
                    guard let ticket = result.ticket else { throw BackendError.unavailable }
                    completion(.success(ticket))
                } catch { completion(.failure(BackendError.unavailable)) }
            }
            return { task.cancel() }
        })
        client?.connect(ticket: ticket)
    }

    func publish(_ event: ConfiguredOutboundEvent, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let client else { completion(.failure(BackendError.unavailable)); return }
        client.publish(name: event.name, data: event.data, completion: completion)
    }
    func stop() { client?.stop(); client = nil }
    func becameActive() { client?.applicationDidBecomeActive() }
    func networkChanged(available: Bool) {
        if available { client?.networkBecameAvailable() } else { client?.networkBecameUnavailable() }
    }
}
