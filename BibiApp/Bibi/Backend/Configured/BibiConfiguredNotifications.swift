import Foundation

struct BibiConfiguredMessageContext: Equatable {
    let requestID: UUID
    let generation: UUID
    let sceneID: String
    let identity: BibiConfiguredIdentity
}

enum BibiConfiguredPublisher: Equatable { case socket, supabase }

struct BibiConfiguredMessageEnvelope {
    let message: ConfiguredRealtimeMessage
    let context: BibiConfiguredMessageContext
    let publisher: BibiConfiguredPublisher
}

/// The raw business payload never shares storage with diagnostics or routing fields.
@MainActor
final class BibiConfiguredNotifications {
    static let message = Notification.Name("BibiConfiguredBusinessMessage")
    let center = NotificationCenter()
    let source = NSObject()
    private(set) var receiverReady = false
    func setReceiverReady(_ ready: Bool) { receiverReady = ready }

    func post(message: ConfiguredRealtimeMessage, context: BibiConfiguredMessageContext,
              publisher: BibiConfiguredPublisher = .socket) throws {
        guard receiverReady else { throw BackendError.unavailable }
        let snapshot: Any
        if let text = message.data as? String { snapshot = String(text) }
        else if let data = message.data as? Data { snapshot = Data(data) }
        else {
            let data = try JSONSerialization.data(withJSONObject: message.data, options: [.fragmentsAllowed])
            guard data.count <= ConfiguredRealtimeJSON.maximumBytes else { throw BackendError.unavailable }
            snapshot = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        }
        let copy = ConfiguredRealtimeMessage(name: message.name, data: snapshot, id: message.id,
            clientID: message.clientID, channel: message.channel)
        center.post(name: Self.message, object: source,
            userInfo: ["envelope": BibiConfiguredMessageEnvelope(message: copy, context: context, publisher: publisher)])
    }
}
