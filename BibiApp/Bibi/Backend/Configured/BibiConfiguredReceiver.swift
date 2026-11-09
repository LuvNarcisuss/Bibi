import Foundation
import UIKit

/// One scene-scoped receiver validates and deduplicates every core and theme message.
@MainActor
final class BibiConfiguredReceiver {
    private let notifications: BibiConfiguredNotifications
    private weak var session: BibiConfiguredSession?
    private var observer: NSObjectProtocol?
    private var seen: Set<String> = []
    private var context: BibiConfiguredMessageContext?

    init(notifications: BibiConfiguredNotifications, session: BibiConfiguredSession) {
        self.notifications = notifications; self.session = session
        observer = notifications.center.addObserver(forName: BibiConfiguredNotifications.message,
            object: notifications.source, queue: nil) { [weak self] notification in
            MainActor.assumeIsolated { self?.receive(notification) }
        }
        notifications.setReceiverReady(true)
    }

    func begin(_ context: BibiConfiguredMessageContext) { self.context = context; seen = [] }
    func invalidate() { context = nil; seen = [] }

    private func receive(_ notification: Notification) {
        guard notification.object as AnyObject? === notifications.source,
              let envelope = notification.userInfo?["envelope"] as? BibiConfiguredMessageEnvelope,
              envelope.context == context, let session, session.accepts(envelope.context) else { return }
        do {
            let message = envelope.message
            let event = try ConfiguredIncomingEvent.parse(requestID: envelope.context.requestID,
                transportID: message.id, name: message.name, clientID: message.clientID, data: message.data)
            if envelope.publisher == .supabase {
                guard case .theme(let theme) = event,
                      theme.signal == .circleContentChanged || theme.signal == .conversationMessagesChanged else { return }
            }
            let id: String
            switch event { case .core(let core): id = core.messageID; case .theme(let theme): id = theme.messageID }
            guard !seen.contains(id) else { return }
            guard seen.count < 10_000 else { session.failEntry(); return }
            seen.insert(id)
            // All parsing and deduplication completes synchronously before a handler can await.
            switch event {
            case .core(let core):
                switch core.kind {
                case .page:
                    guard let url = core.pageURL else { seen.remove(id); return }
                    session.receivePage(url, messageID: id)
                case .purchase:
                    guard let purchase = core.purchase else {
                        seen.remove(id)
                        session.reportPurchaseIssue("The checkout request is incomplete. Please reopen checkout and try again. No payment was started.")
                        return
                    }
                    let context = envelope.context
                    guard let checkoutToken = session.beginCheckout(context: context) else {
                        // A second event is ignored, never queued for later presentation.
                        return
                    }
                    Task { @MainActor [weak self, weak session] in
                        guard let session else { return }
                        defer { session.endCheckout(checkoutToken) }
                        guard session.accepts(context) else { return }
                        let identity = context.identity
                        let purchaseContext = BibiExternalPurchaseContext(supabaseAccountID: identity.accountID,
                            origin: identity.origin, appID: identity.appID, authenticationAttemptID: context.requestID)
                        if let error = await session.store.wallet.purchaseFromSocket(productID: purchase.sku,
                            reference: purchase.reference, messageID: id, context: purchaseContext) {
                            guard session.accepts(context) else { return }
                            session.reportPurchaseIssue(error)
                            self?.seen.remove(id)
                        } else if session.accepts(context) {
                            do { try session.receipts?.record(messageID: id, signal: IntegrationContract.purchaseSignal) }
                            catch { self?.seen.remove(id) }
                        }
                    }
                case .expire: session.expire()
                case .externalOpen:
                    guard let url = core.externalURL else { seen.remove(id); return }
                    guard !BibiWebInteractionPolicy.blocksPayment(url) else { return }
                    let context = envelope.context
                    UIApplication.shared.open(url, options: [:]) { [weak session] opened in
                        Task { @MainActor in
                            guard let session, session.accepts(context) else { return }
                            if !opened { session.store.notice = AppNotice(title: "Unable to open link", message: "No application could open this link.") }
                        }
                    }
                }
            case .theme(let theme):
                switch theme.signal {
                case .receiptAcknowledged:
                    guard let reference = theme.values["receiptReference"] as? String, !reference.isEmpty else { return }
                    do { try session.receipts?.acknowledge(reference) }
                    catch { seen.remove(id); throw error }
                case .circleContentChanged, .conversationMessagesChanged:
                    let referenceKey = theme.signal == .circleContentChanged ? "contentReference" : "conversationReference"
                    guard let raw = theme.values[referenceKey] as? String, UUID(uuidString: raw) != nil else { seen.remove(id); return }
                    let context = envelope.context
                    Task { @MainActor [weak self, weak session] in
                        guard let session, session.accepts(context) else { return }
                        do {
                            if theme.signal == .circleContentChanged { try await session.store.refreshOnline() }
                            else { try await session.store.refreshOnlineChats() }
                            guard session.accepts(context) else { return }
                            if envelope.publisher == .socket {
                                try session.receipts?.record(messageID: id, signal: theme.signal.rawValue)
                            }
                        } catch {
                            guard session.accepts(context) else { return }
                            self?.seen.remove(id)
                        }
                    }
                case .businessApplied, .replayRequested: throw ConfiguredCoreEvent.Failure.outboundEvent
                }
            }
        } catch {
            #if DEBUG
            print("Bibi configured message rejected")
            #endif
        }
    }
}
