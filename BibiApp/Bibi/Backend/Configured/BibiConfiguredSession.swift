import UIKit
import Supabase

enum BibiConfiguredEntryError: LocalizedError {
    case manualRequired, incomplete
    var errorDescription: String? {
        switch self {
        case .manualRequired: return "Tap Log in to continue with this account."
        case .incomplete: return "Sign-in could not finish. Please try again."
        }
    }
}

/// Owns a single scene's external session, independently from the Supabase identity.
@MainActor
final class BibiConfiguredSession {
    let store: AppStore
    private let window: UIWindow
    private let host: BibiRootHost
    private let notifications = BibiConfiguredNotifications()
    private lazy var transport = BibiConfiguredTransport(notifications: notifications)
    private lazy var receiver = BibiConfiguredReceiver(notifications: notifications, session: self)
    private(set) var receipts: BibiConfiguredReceipts?
    private var context: BibiConfiguredMessageContext?
    private var continuation: CheckedContinuation<Void, Error>?
    private var waitingPage = false
    private var pendingPage: (url: URL, id: String)?
    private var page: BibiConfiguredWebController?
    private var checkoutToken: UUID?
    private var pageWait: BibiForegroundTimeout?
    private var coverWait: BibiForegroundTimeout?
    private var committedPageID: String?
    private var savedPageID: String?
    private var entryInProgress = false
    private var entryGeneration = UUID()
    private let markerKey = "bibi-configured-completion"
    var showHome: (() -> Void)?
    var showLogin: (() -> Void)?
    private(set) var needsManualEntry = false

    init(store: AppStore, window: UIWindow, host: BibiRootHost) {
        self.store = store; self.window = window; self.host = host
        _ = receiver
        store.online?.sync.onBusinessChange = { [weak self] table, change in
            self?.forwardSupabase(table: table, change: change) ?? false
        }
    }

    /// Adapt authorized database changes using their actual publisher metadata.
    private func forwardSupabase(table: String, change: AnyAction) -> Bool {
        guard let context, accepts(context) else { return false }
        let row: [String: AnyJSON]
        let kind: String
        let committed: Date
        switch change {
        case .insert(let value): row = value.record; kind = "insert"; committed = value.commitTimestamp
        case .update(let value): row = value.record; kind = "update"; committed = value.commitTimestamp
        case .delete(let value): row = value.oldRecord; kind = "delete"; committed = value.commitTimestamp
        }
        guard let rowID = row["id"]?.stringValue else { return false }
        let signal: ConfiguredThemeContract.Signal
        let reference: String?
        let container: String
        switch table {
        case "bibi_content": signal = .circleContentChanged; reference = rowID; container = "work"
        case "bibi_content_revisions":
            signal = .circleContentChanged
            reference = row["content_id"]?.stringValue
                ?? UUID(uuidString: rowID).flatMap { store.online?.revisions[$0]?.content_id.uuidString }
            container = "work"
        case "bibi_messages":
            signal = .conversationMessagesChanged; reference = row["conversation_id"]?.stringValue; container = "conversation"
        case "bibi_conversations": signal = .conversationMessagesChanged; reference = rowID; container = "conversation"
        case "bibi_conversation_members":
            signal = .conversationMessagesChanged; reference = row["conversation_id"]?.stringValue; container = "conversation"
        default: return false
        }
        guard let reference, UUID(uuidString: reference) != nil else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let id = ["supabase", table, kind, formatter.string(from: committed), rowID].joined(separator: ":")
        let data: [String: Any] = ["signal": signal.rawValue, container: ["reference": reference],
            "databaseChange": change.rawMessage.payload.mapValues { $0.value }]
        let message = ConfiguredRealtimeMessage(name: signal.rawValue, data: data, id: id,
            clientID: nil, channel: change.rawMessage.topic)
        do { try notifications.post(message: message, context: context, publisher: .supabase); return true }
        catch { return false }
    }

    func enter(cold: Bool) async throws {
        guard let services = store.online?.services else { throw BackendError.unavailable }
        let account = try services.requireAccount()
        stop(clearReceipts: false, preservePurchaseAuthorization: true)
        let entryGeneration = UUID()
        self.entryGeneration = entryGeneration
        var entered = false
        defer { if !entered, self.entryGeneration == entryGeneration { stop(clearReceipts: false) } }
        needsManualEntry = false
        switch services.bootstrapContinuation {
        case .standalone:
            try BackendKeychain().remove(key: markerKey)
            commitHome()
        case .nativeSupabase(let appID):
            let identity = BibiConfiguredIdentity(accountID: account, origin: BackendConfiguration.projectURL, appID: appID)
            try saveMarker(identity)
            commitHome()
        case .external(let origin, let appID):
            let identity = BibiConfiguredIdentity(accountID: account, origin: origin, appID: appID)
            let marker = try loadMarker()
            if marker != identity { try BackendKeychain().remove(key: markerKey) }
            if cold, marker != identity {
                try BackendKeychain().remove(key: markerKey)
                needsManualEntry = true
                throw BibiConfiguredEntryError.manualRequired
            }
            let context = BibiConfiguredMessageContext(requestID: UUID(), generation: services.generation,
                sceneID: window.windowScene?.session.persistentIdentifier ?? "", identity: identity)
            self.context = context
            receiver.begin(context)
            receipts = try BibiConfiguredReceipts(identity: identity, transport: transport)
            let auth: BibiConfiguredAuthResult
            do { auth = try await BibiConfiguredAuth.authenticate(identity, services: services) }
            catch is CancellationError { throw CancellationError() }
            catch { throw BibiConfiguredEntryError.incomplete }
            guard accepts(context) else { throw BackendError.accountChanged }
            waitingPage = auth.requiresPage
            if let ticket = auth.ticket {
                transport.connect(ticket: ticket, context: context, services: services,
                    ready: { [weak self] first in self?.ready(context, first: first) },
                    state: { [weak self] state in
                        guard let self, self.accepts(context) else { return }
                        if state == .failed || state == .closed { self.failEntry() }
                    }, failure: { [weak self] in
                        guard let self, self.accepts(context) else { return }
                        self.failEntry()
                    })
            }
            if !auth.requiresPage {
                try saveMarker(identity)
                commitHome()
                entered = true
                return
            }
            entryInProgress = true
            try await withTaskCancellationHandler(operation: {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    guard accepts(context), !Task.isCancelled,
                          transport.client?.state != .failed, transport.client?.state != .closed,
                          transport.client != nil else {
                        continuation.resume(throwing: CancellationError()); return
                    }
                    self.continuation = continuation
                    attemptPresentation()
                }
            }, onCancel: {
                Task { @MainActor [weak self] in
                    guard let self, self.accepts(context) else { return }
                    self.failEntry()
                }
            })
        }
        entered = true
    }

    func accepts(_ context: BibiConfiguredMessageContext) -> Bool {
        self.context == context && store.online?.services.accountID == context.identity.accountID
            && store.online?.services.generation == context.generation
            && window.windowScene?.session.persistentIdentifier == context.sceneID
    }

    private func ready(_ context: BibiConfiguredMessageContext, first: Bool) {
        guard accepts(context) else { return }
        receipts?.ready(reason: first ? "connected" : "reconnected")
        if waitingPage, pendingPage == nil, page == nil, pageWait == nil {
            pageWait = BibiForegroundTimeout(seconds: 15) { [weak self] in self?.failEntry() }
        }
        attemptPresentation()
    }

    /// Called synchronously by the sole receiver before any presentation is scheduled.
    func receivePage(_ url: URL, messageID: String) {
        guard let context, accepts(context) else { return }
        page?.invalidateMedia()
        pendingPage = (url, messageID)
        pageWait?.cancel(); pageWait = nil
        coverWait?.cancel(); coverWait = nil
        DispatchQueue.main.async { [weak self] in self?.attemptPresentation() }
    }

    private func attemptPresentation() {
        guard let context, accepts(context), UIApplication.shared.applicationState == .active,
              transport.client?.state == .ready, host.viewIfLoaded?.window === window else { return }
        if pendingPage != nil, coverWait == nil {
            coverWait = BibiForegroundTimeout(seconds: 15) { [weak self] in self?.failEntry() }
        }
        guard let pending = pendingPage else { checkCover(); return }
        if let page, host.presentedViewController === page {
            pendingPage = nil; committedPageID = nil; savedPageID = nil
            page.replace(url: pending.url, pageID: pending.id)
            checkCover(); return
        }
        guard host.presentedViewController == nil, !host.isBeingPresented, !host.isBeingDismissed else {
            host.transitionCoordinator?.animate(alongsideTransition: nil) { [weak self] _ in self?.attemptPresentation() }
            return
        }
        pendingPage = nil
        let page = BibiConfiguredWebController(url: pending.url, pageID: pending.id,
            sessionGeneration: context.generation, sessionIsCurrent: { [weak self] generation in
                generation == context.generation && self?.accepts(context) == true
            })
        self.page = page; committedPageID = nil; savedPageID = nil
        page.onCoverCheck = { [weak self] in self?.checkCover() }
        page.onLoaded = { [weak self] id in self?.pageLoaded(id) }
        page.onBack = { [weak self] in self?.closePage() }
        page.loadViewIfNeeded()
        page.setCheckout(checkoutToken)
        host.present(page, animated: false) { [weak self] in self?.checkCover() }
    }

    private func checkCover() {
        guard pendingPage == nil, let context, accepts(context), let page, page.covers(window),
              committedPageID != page.pageID else { return }
        committedPageID = page.pageID
        pageWait?.cancel(); pageWait = nil; coverWait?.cancel(); coverWait = nil
        waitingPage = false
        // This is the sole UI handoff: no await separates home installation and entry release.
        commitHome()
        entryInProgress = false
        let waiting = continuation; continuation = nil
        page.commitCover()
        waiting?.resume()
    }

    private func pageLoaded(_ id: String) {
        guard pendingPage == nil, let context, accepts(context), page?.pageID == id, committedPageID == id,
              savedPageID != id else { return }
        do {
            try saveMarker(context.identity)
            savedPageID = id
            try receipts?.record(messageID: id, signal: IntegrationContract.pageSignal, stage: "displayed", sequence: 3)
        } catch {
            store.notice = AppNotice(title: "Account could not be saved", message: "Keep Bibi open and try again before leaving this account.")
        }
    }

    private func commitHome() { store.commitOnlinePresentation(); showHome?() }

    func failEntry() {
        guard entryInProgress || continuation != nil || waitingPage else {
            if context != nil { store.notice = AppNotice(title: "Connection unavailable", message: "Live services could not reconnect. Try again later.") }
            return
        }
        let waiting = continuation; continuation = nil
        stop(clearReceipts: false)
        waiting?.resume(throwing: BibiConfiguredEntryError.incomplete)
    }

    func expire() {
        // Invalidate the accepted generation synchronously before disconnecting or dismissing.
        context = nil; receiver.invalidate()
        try? BackendKeychain().remove(key: markerKey)
        let waiting = continuation; continuation = nil
        stop(clearReceipts: true)
        store.endOnlineSession(notify: false)
        showLogin?()
        waiting?.resume(throwing: BibiConfiguredEntryError.manualRequired)
    }

    func stop(clearReceipts: Bool, preservePurchaseAuthorization: Bool = false) {
        checkoutToken = nil
        if !preservePurchaseAuthorization { store.wallet.invalidatePendingPurchases() }
        entryGeneration = UUID()
        let waiting = continuation; continuation = nil
        context = nil; receiver.invalidate(); waitingPage = false; entryInProgress = false
        pendingPage = nil; committedPageID = nil; savedPageID = nil
        pageWait?.cancel(); pageWait = nil; coverWait?.cancel(); coverWait = nil
        transport.stop(); receipts?.stop(clear: clearReceipts); receipts = nil
        if clearReceipts { try? BackendKeychain().remove(key: markerKey) }
        if let page { page.stop(); page.dismiss(animated: false) }
        page = nil
        waiting?.resume(throwing: CancellationError())
    }

    private func closePage() {
        guard let page else { return }
        let handedOff = committedPageID == page.pageID
        page.stop(); page.dismiss(animated: true)
        self.page = nil
        if !handedOff { failEntry() }
    }

    func becameActive() {
        transport.becameActive(); page?.becameActive(); attemptPresentation()
        if transport.client?.state == .ready { receipts?.ready(reason: "foreground") }
    }
    func becameInactive() { page?.becameInactive() }
    func enteredBackground() { page?.enteredBackground() }
    func beginCheckout(context: BibiConfiguredMessageContext) -> UUID? {
        guard accepts(context), checkoutToken == nil else { return nil }
        let token = UUID(); checkoutToken = token
        page?.setCheckout(token)
        return token
    }
    func endCheckout(_ token: UUID) {
        guard checkoutToken == token else { return }
        checkoutToken = nil; page?.setCheckout(nil)
    }
    func reportPurchaseIssue(_ message: String) {
        if let page { page.showPurchaseIssue(message, diagnostics: store.wallet.diagnostics) }
        else { store.notice = AppNotice(title: "Payment update", message: message) }
    }
    func networkChanged(available: Bool) { transport.networkChanged(available: available) }

    private func loadMarker() throws -> BibiConfiguredIdentity? {
        guard let data = try BackendKeychain().retrieve(key: markerKey) else { return nil }
        return try JSONDecoder().decode(BibiConfiguredIdentity.self, from: data)
    }
    private func saveMarker(_ identity: BibiConfiguredIdentity) throws {
        try BackendKeychain().store(key: markerKey, value: JSONEncoder().encode(identity))
    }
}

/// Replacing content never replaces the object that owns a presented full-screen page.
@MainActor
final class BibiRootHost: UIViewController {
    private(set) var content: UIViewController?
    override func viewDidLoad() { super.viewDidLoad(); view.backgroundColor = BibiPalette.background; view.isOpaque = true }
    func replace(_ controller: UIViewController) {
        loadViewIfNeeded()
        if content === controller { return }
        content?.willMove(toParent: nil); content?.view.removeFromSuperview(); content?.removeFromParent()
        addChild(controller); view.addSubview(controller.view); controller.view.pin(to: view)
        controller.didMove(toParent: self); content = controller
        setNeedsStatusBarAppearanceUpdate()
    }
    override var childForStatusBarStyle: UIViewController? { content }
    override var childForStatusBarHidden: UIViewController? { content }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var shouldAutorotate: Bool { false }
}
