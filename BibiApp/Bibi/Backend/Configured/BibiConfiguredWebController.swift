import UIKit
import WebKit

struct BibiWebOrigin: Equatable {
    let scheme: String
    let host: String
    let port: Int

    init?(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = parts.scheme?.lowercased(), ["https", "http"].contains(scheme),
              parts.user == nil, parts.password == nil,
              let host = parts.url?.host?.lowercased(), !host.isEmpty,
              !host.contains("%"), !host.contains("{"), !host.contains("}"),
              parts.port == nil || (1...65535).contains(parts.port!) else { return nil }
        self.scheme = scheme; self.host = host
        port = parts.port ?? (scheme == "https" ? 443 : 80)
    }

    @MainActor
    init?(securityOrigin: WKSecurityOrigin) {
        guard !securityOrigin.host.isEmpty, (0...65535).contains(securityOrigin.port) else { return nil }
        var parts = URLComponents()
        parts.scheme = securityOrigin.protocol; parts.host = securityOrigin.host
        parts.port = securityOrigin.port == 0 ? nil : securityOrigin.port
        guard let url = parts.url else { return nil }
        self.init(url: url)
    }
}

struct BibiWebPagePolicy {
    private let entryOrigin: BibiWebOrigin?
    private let pageID: String
    private let sessionGeneration: UUID
    private var navigation: UUID?
    private var committedNavigation: UUID?
    private var documentOrigin: BibiWebOrigin?
    private var invalidated = false

    init(url: URL, pageID: String, sessionGeneration: UUID) {
        entryOrigin = BibiWebOrigin(url: url)
        self.pageID = pageID; self.sessionGeneration = sessionGeneration
    }
    func permitsDocument(_ url: URL) -> Bool {
        guard !invalidated, let entryOrigin else { return false }
        return BibiWebOrigin(url: url) == entryOrigin
    }
    func permitsHistory(_ url: URL?, canNavigate: Bool, live: Bool, checkoutActive: Bool) -> Bool {
        guard canNavigate, live, !checkoutActive, let url,
              !BibiWebInteractionPolicy.blocksPayment(url) else { return false }
        return permitsDocument(url)
    }
    mutating func beginNavigation(_ id: UUID) {
        navigation = id; committedNavigation = nil; documentOrigin = nil
    }
    mutating func commitDocument(_ url: URL, navigation id: UUID) {
        guard navigation == id else { return }
        documentOrigin = nil; committedNavigation = nil
        guard !invalidated, permitsDocument(url) else { return }
        documentOrigin = BibiWebOrigin(url: url); committedNavigation = id
    }
    mutating func invalidate() {
        invalidated = true; committedNavigation = nil; documentOrigin = nil
    }
    func permitsMedia(pageID: String, sessionGeneration: UUID, live: Bool, knownResource: Bool) -> Bool {
        !invalidated && entryOrigin != nil && live && knownResource
            && self.pageID == pageID && self.sessionGeneration == sessionGeneration
    }
    func permitsEmbeddedDocument(_ url: URL, pageID: String, sessionGeneration: UUID, live: Bool) -> Bool {
        let webDocument = BibiWebOrigin(url: url) != nil
        let inheritedDocument = ["about:blank", "about:srcdoc"].contains(url.absoluteString.lowercased())
        return (webDocument || inheritedDocument)
            && permitsMedia(pageID: pageID, sessionGeneration: sessionGeneration, live: live, knownResource: true)
    }
    func permitsWindow(source: BibiWebOrigin?, pageID: String,
                       sessionGeneration: UUID, navigation: UUID, live: Bool) -> Bool {
        guard !invalidated, live, let entryOrigin,
              self.pageID == pageID, self.sessionGeneration == sessionGeneration,
              self.navigation == navigation, committedNavigation == navigation,
              documentOrigin == entryOrigin else { return false }
        return source == entryOrigin
    }
}

@MainActor
final class BibiWebCaptureReconciler {
    enum State: Equatable {
        case none, active, muted

        init(_ state: WKMediaCaptureState) {
            switch state {
            case .active: self = .active
            case .muted: self = .muted
            case .none: self = .none
            @unknown default: self = .none
            }
        }
        var webKitState: WKMediaCaptureState {
            switch self {
            case .none: return .none
            case .active: return .active
            case .muted: return .muted
            }
        }
    }
    private enum Intent: Equatable { case foreground, background, stopped }
    private let readState: () -> State
    private let setState: (State, @escaping () -> Void) -> Void
    private var intent: Intent = .foreground
    private var revision = 0
    private var pending: UUID?
    private var lastAttempt: (revision: Int, target: State)?
    private var suspendedByOwner = false
    private var stopSubmitted = false

    init(readState: @escaping () -> State,
         setState: @escaping (State, @escaping () -> Void) -> Void) {
        self.readState = readState; self.setState = setState
    }
    func suspend() {
        guard intent != .stopped else { return }
        intent = .background; revision += 1
        reconcile()
    }
    func resume() {
        guard intent != .stopped else { return }
        intent = .foreground; revision += 1
        reconcile()
    }
    func stop() {
        guard intent != .stopped else { return }
        intent = .stopped; revision += 1; suspendedByOwner = false
        reconcile()
    }
    private func reconcile() {
        guard pending == nil else { return }
        let current = readState()
        let target: State
        switch intent {
        case .stopped:
            guard !stopSubmitted else { return }
            stopSubmitted = true; target = .none
        case .background:
            guard current == .active else {
                if current == .none { suspendedByOwner = false }
                return
            }
            suspendedByOwner = true; target = .muted
        case .foreground:
            guard suspendedByOwner, current == .muted else {
                if current != .muted { suspendedByOwner = false }
                return
            }
            target = .active
        }
        if let lastAttempt, lastAttempt.revision == revision, lastAttempt.target == target { return }
        let operation = UUID()
        lastAttempt = (revision, target)
        pending = operation
        // Retain this owner until completion so terminal stop can follow an older setter.
        setState(target) { [self] in
            guard pending == operation else { return }
            pending = nil
            if target == .active, intent == .foreground, readState() == .active {
                suspendedByOwner = false
            }
            // Recheck the latest target after every completion; unchanged rejected commands are bounded.
            reconcile()
        }
    }
}

enum BibiWebInteractionPolicy {
    static func blocksPayment(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return ["paytmmp", "phonepe"].contains(scheme)
    }

    static let paymentScript = #"""
    (() => {
        if (window.__bibiUnsupportedPaymentsInstalled) return;
        window.__bibiUnsupportedPaymentsInstalled = true;
        const names = new Set(['paytm', 'phonepe']);
        const schemes = new Set(['paytmmp:', 'phonepe:']);
        const normalized = value => String(value || '').toLowerCase().replace(/[\s\u200B-\u200D\uFEFF]/g, '');
        const labelAttributes = ['aria-label', 'title', 'alt', 'data-provider', 'data-payment-method'];
        const hasProviderLabel = element => labelAttributes.some(attribute => names.has(normalized(element.getAttribute(attribute))));
        const blockedURL = value => {
            if (!value) return false;
            try { return schemes.has(new URL(value, document.baseURI).protocol.toLowerCase()); }
            catch (_) { return false; }
        };
        const blocked = event => {
            const path = typeof event.composedPath === 'function' ? event.composedPath() : [event.target];
            return path.some(element => {
                if (!(element instanceof Element)) return false;
                if (blockedURL(element.getAttribute('href')) || blockedURL(element.getAttribute('action'))) return true;
                const labels = [element.textContent];
                if (element instanceof HTMLInputElement) labels.push(element.value);
                if (hasProviderLabel(element) || labels.some(value => names.has(normalized(value)))) return true;
                const control = element.closest('a, button, [role="button"], label, [data-provider], [data-payment-method]');
                return control !== null && Array.from(control.querySelectorAll('img[alt], [aria-label], [title], [data-provider], [data-payment-method]'))
                    .some(hasProviderLabel);
            });
        };
        const ignore = event => {
            if (!blocked(event)) return;
            event.preventDefault();
            event.stopImmediatePropagation();
        };
        for (const type of ['pointerdown', 'pointerup', 'touchstart', 'touchend', 'click', 'submit']) {
            window.addEventListener(type, ignore, { capture: true, passive: false });
        }
    })();
    """#

    static let viewportScript = #"""
    (() => {
        if (!document.querySelector('meta[name="viewport"]')) {
            const viewport = document.createElement('meta');
            viewport.name = 'viewport';
            viewport.content = 'width=device-width, initial-scale=1, viewport-fit=cover';
            (document.head || document.documentElement).appendChild(viewport);
        }
        if (document.getElementById('bibi-root-scroll-policy')) return;
        const style = document.createElement('style');
        style.id = 'bibi-root-scroll-policy';
        style.textContent = 'html, body { max-width: 100% !important; overflow-x: hidden !important; overscroll-behavior-x: none !important; }';
        (document.head || document.documentElement).appendChild(style);
    })();
    """#
}

private final class BibiWebHistoryPan: UIPanGestureRecognizer {
    let edge: UIRectEdge

    init(edge: UIRectEdge, target: Any?, action: Selector?) {
        self.edge = edge
        super.init(target: target, action: action)
        maximumNumberOfTouches = 1
    }

    func inwardDistance(_ horizontalDistance: CGFloat) -> CGFloat {
        edge == .left ? horizontalDistance : -horizontalDistance
    }
}

@MainActor
final class BibiConfiguredWebController: UIViewController, WKNavigationDelegate, WKUIDelegate, UIGestureRecognizerDelegate {
    private var web: WKWebView
    private var policy: BibiWebPagePolicy
    private let sessionGeneration: UUID
    private let sessionIsCurrent: (UUID) -> Bool
    private let progress = BibiWebProgress()
    private var errorPanel: UIView?
    private var navigation: WKNavigation?
    private var awaitingDocumentStart = false
    private var rejected: Set<ObjectIdentifier> = []
    private var navigationID = UUID()
    private var deadline: BibiForegroundTimeout?
    private var result: Bool?
    private var responseValid = false
    private var historyNavigationURL: URL?
    private var coverCommitted = false
    private var pendingPurchaseIssue: (message: String, diagnostics: String)?
    private var checkoutToken: UUID?
    private var checkoutOverlay: UIView?
    private var captureReconcilers: [BibiWebCaptureReconciler] = []
    private struct CommittedDocument {
        let policy: BibiWebPagePolicy
        let navigationID: UUID
        let navigation: WKNavigation?
        let responseValid: Bool
    }
    private var committedDocument: CommittedDocument?
    private var url: URL
    private(set) var pageID: String
    var onCoverCheck: (() -> Void)?
    var onLoaded: ((String) -> Void)?
    var onBack: (() -> Void)?

    init(url: URL, pageID: String, sessionGeneration: UUID,
         sessionIsCurrent: @escaping (UUID) -> Bool) {
        self.url = url; self.pageID = pageID
        self.sessionGeneration = sessionGeneration; self.sessionIsCurrent = sessionIsCurrent
        policy = BibiWebPagePolicy(url: url, pageID: pageID, sessionGeneration: sessionGeneration)
        web = Self.makeWebView()
        super.init(nibName: nil, bundle: nil)
        configureCaptureReconcilers()
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
    }
    private static func makeWebView(websiteDataStore: WKWebsiteDataStore? = nil) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = websiteDataStore ?? .nonPersistent()
        configuration.userContentController.addUserScript(WKUserScript(
            source: BibiWebInteractionPolicy.paymentScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        configuration.userContentController.addUserScript(WKUserScript(
            source: BibiWebInteractionPolicy.viewportScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        return WKWebView(frame: .zero, configuration: configuration)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = BibiPalette.background
        view.isOpaque = true; view.alpha = 1
        view.clipsToBounds = true
        view.accessibilityViewIsModal = true
        let backdrop = StarlightCanvas()
        backdrop.isUserInteractionEnabled = false
        view.addSubview(backdrop); backdrop.pin(to: view)
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        blur.isUserInteractionEnabled = false
        if UIAccessibility.isReduceTransparencyEnabled { blur.backgroundColor = BibiPalette.background }
        view.addSubview(blur); blur.pin(to: view)
        installWebView()
        begin()
    }
    private func installWebView() {
        web.navigationDelegate = self; web.uiDelegate = self
        web.isOpaque = false; web.backgroundColor = .clear; web.scrollView.backgroundColor = .clear
        web.underPageBackgroundColor = BibiPalette.background
        web.allowsBackForwardNavigationGestures = false
        web.clipsToBounds = true
        web.scrollView.bounces = false
        web.scrollView.alwaysBounceHorizontal = false
        web.scrollView.isDirectionalLockEnabled = true
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        web.scrollView.contentInset = .zero; web.scrollView.scrollIndicatorInsets = .zero
        view.addSubview(web); web.pin(to: view)
        for edge: UIRectEdge in [.left, .right] {
            let gesture = BibiWebHistoryPan(edge: edge, target: self, action: #selector(navigateHistory(_:)))
            gesture.delegate = self
            web.addGestureRecognizer(gesture)
            web.scrollView.panGestureRecognizer.require(toFail: gesture)
        }
        if checkoutToken != nil { installCheckoutOverlay() }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated); onCoverCheck?(); presentPurchaseIssueIfPossible()
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); onCoverCheck?() }

    func replace(url: URL, pageID: String, websiteDataStore: WKWebsiteDataStore? = nil) {
        policy.invalidate(); stopCapture()
        web.stopLoading(); web.navigationDelegate = nil; web.uiDelegate = nil
        web.removeFromSuperview()
        web = Self.makeWebView(websiteDataStore: websiteDataStore)
        configureCaptureReconcilers()
        navigation = nil; result = nil; committedDocument = nil; pendingPurchaseIssue = nil
        historyNavigationURL = nil
        self.url = url; self.pageID = pageID
        policy = BibiWebPagePolicy(url: url, pageID: pageID, sessionGeneration: sessionGeneration)
        if isViewLoaded { installWebView(); begin() } else { loadViewIfNeeded() }
    }
    func commitCover() { coverCommitted = true; settle() }
    func becameActive() {
        resumeCaptureIfPossible(); progress.resume(); onCoverCheck?(); settle(); presentPurchaseIssueIfPossible()
    }
    // Permission and purchase sheets can temporarily make the scene inactive.
    func becameInactive() { progress.pause() }
    func enteredBackground() { progress.pause(); suspendCapture() }
    func invalidateMedia() { policy.invalidate(); stopCapture() }

    func setCheckout(_ token: UUID?) {
        checkoutToken = token
        if token != nil { loadViewIfNeeded(); installCheckoutOverlay() }
        else {
            checkoutOverlay?.removeFromSuperview(); checkoutOverlay = nil
            UIAccessibility.post(notification: .layoutChanged, argument: web)
            presentPurchaseIssueIfPossible()
        }
    }
    private func installCheckoutOverlay() {
        guard checkoutOverlay == nil else { view.bringSubviewToFront(checkoutOverlay!); return }
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.58)
        overlay.accessibilityViewIsModal = true
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white; spinner.startAnimating()
        let message = label("Processing payment…", 17)
        message.textColor = .white; message.textAlignment = .center
        let content = stack([spinner, message], spacing: 18)
        overlay.addSubview(content); content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            content.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -24)])
        view.addSubview(overlay); overlay.pin(to: view); checkoutOverlay = overlay
        UIAccessibility.post(notification: .screenChanged, argument: message)
    }

    private func historyItem(for edge: UIRectEdge) -> WKBackForwardListItem? {
        edge == .left ? web.backForwardList.backItem : web.backForwardList.forwardItem
    }
    private func permitsHistory(for edge: UIRectEdge) -> Bool {
        let item = historyItem(for: edge)
        return presentedViewController == nil && progress.superview == nil && errorPanel == nil
            && UIApplication.shared.applicationState == .active
            && policy.permitsHistory(item?.url, canNavigate: edge == .left ? web.canGoBack : web.canGoForward,
                live: isLivePage, checkoutActive: checkoutToken != nil)
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let gesture = gestureRecognizer as? BibiWebHistoryPan, gesture.view === web,
              permitsHistory(for: gesture.edge) else { return false }
        let bounds = web.bounds
        let x = touch.location(in: web).x
        let edgeWidth = min(64, bounds.width / 5)
        let inset = gesture.edge == .left ? x - bounds.minX : bounds.maxX - x
        return inset >= 0 && inset <= edgeWidth
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let gesture = gestureRecognizer as? BibiWebHistoryPan, gesture.view === web,
              permitsHistory(for: gesture.edge) else { return false }
        let velocity = gesture.velocity(in: web)
        return gesture.inwardDistance(velocity.x) > abs(velocity.y)
    }
    @objc private func navigateHistory(_ gesture: BibiWebHistoryPan) {
        guard gesture.state == .ended, gesture.view === web, permitsHistory(for: gesture.edge),
              let item = historyItem(for: gesture.edge) else { return }
        let translation = gesture.translation(in: web)
        let distance = gesture.inwardDistance(translation.x)
        let speed = gesture.inwardDistance(gesture.velocity(in: web).x)
        guard distance > abs(translation.y), distance >= 32 || (distance >= 20 && speed >= 500) else { return }
        // SPA history may not start a new document load. Delegate callbacks own loading state.
        web.go(to: item)
    }

    func showPurchaseIssue(_ message: String, diagnostics: String) {
        pendingPurchaseIssue = (message, diagnostics)
        presentPurchaseIssueIfPossible()
    }
    private func presentPurchaseIssueIfPossible() {
        guard let issue = pendingPurchaseIssue, UIApplication.shared.applicationState == .active,
              sessionIsCurrent(sessionGeneration), viewIfLoaded?.window != nil,
              presentedViewController == nil, checkoutToken == nil, !isBeingDismissed else { return }
        pendingPurchaseIssue = nil
        let alert = UIAlertController(title: "Payment update", message: issue.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Copy diagnostics", style: .default) { _ in
            UIPasteboard.general.string = issue.diagnostics
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            DispatchQueue.main.async { self?.presentPurchaseIssueIfPossible() }
        })
        present(alert, animated: true)
    }

    func covers(_ window: UIWindow) -> Bool {
        guard isViewLoaded, view.window === window, !isBeingPresented, !isBeingDismissed,
              presentingViewController != nil, window.windowScene?.activationState == .foregroundActive,
              view.alpha == 1, view.isOpaque, view.backgroundColor?.cgColor.alpha == 1 else { return false }
        let actual = view.convert(view.bounds, to: window)
        let expected = window.bounds
        return actual.width > 0 && actual.height > 0 && abs(actual.minX - expected.minX) < 1
            && abs(actual.minY - expected.minY) < 1 && abs(actual.width - expected.width) < 1
            && abs(actual.height - expected.height) < 1 && window.rootViewController?.presentedViewController === self
    }

    func stop() {
        policy.invalidate(); stopCapture()
        checkoutToken = nil; checkoutOverlay?.removeFromSuperview(); checkoutOverlay = nil
        committedDocument = nil; pendingPurchaseIssue = nil
        historyNavigationURL = nil
        navigationID = UUID(); deadline?.cancel(); deadline = nil
        web.stopLoading(); web.navigationDelegate = nil; web.uiDelegate = nil
        progress.pause(); progress.removeFromSuperview(); errorPanel?.removeFromSuperview()
        onCoverCheck = nil; onLoaded = nil; onBack = nil
    }

    private func begin() {
        guard sessionIsCurrent(sessionGeneration), policy.permitsDocument(url) else {
            result = nil; finish(success: false); return
        }
        if let navigation { rejected.insert(ObjectIdentifier(navigation)) }
        web.stopLoading()
        historyNavigationURL = nil
        prepareNavigation()
        navigation = web.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
        if navigation == nil { finish(success: false) }
    }
    private func prepareNavigation() {
        if result == true {
            committedDocument = CommittedDocument(policy: policy, navigationID: navigationID,
                navigation: navigation, responseValid: responseValid)
        }
        navigationID = UUID(); result = nil; responseValid = false
        awaitingDocumentStart = true
        policy.beginNavigation(navigationID)
        deadline?.cancel()
        if progress.superview == nil { view.addSubview(progress); progress.pin(to: view) }
        view.bringSubviewToFront(progress)
        if let checkoutOverlay { view.bringSubviewToFront(checkoutOverlay) }
        progress.resume()
        errorPanel?.removeFromSuperview(); errorPanel = nil
        let id = navigationID
        deadline = BibiForegroundTimeout(seconds: 30) { [weak self] in
            guard let self, self.navigationID == id, self.result == nil else { return }
            self.web.stopLoading(); self.finish(success: false)
        }
    }
    private func finish(success: Bool) {
        guard result == nil else { return }
        result = success
        if !success { policy.beginNavigation(navigationID); stopCapture() }
        deadline?.cancel(); deadline = nil
        settle()
    }
    private func settle() {
        guard coverCommitted, let result else { return }
        if result {
            progress.pause(); progress.removeFromSuperview()
            errorPanel?.removeFromSuperview(); errorPanel = nil
            onLoaded?(pageID)
        } else {
            showError()
            progress.pause(); progress.removeFromSuperview()
        }
    }
    private func showError() {
        guard errorPanel == nil else { return }
        let surface = UIView(); surface.backgroundColor = BibiPalette.background; surface.isOpaque = true
        let retry = actionButton("Try again", icon: .refresh) { [weak self] in
            guard let self else { return }
            self.replace(url: self.url, pageID: self.pageID,
                websiteDataStore: self.web.configuration.websiteDataStore)
        }
        let back = actionButton("Return to Bibi", icon: .back) { [weak self] in self?.onBack?() }
        let message = label("This page could not load. Please check your connection and try again.", 17)
        message.textAlignment = .center
        let column = stack([message, retry, back], spacing: 18)
        surface.addSubview(column); column.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            column.centerYAnchor.constraint(equalTo: surface.centerYAnchor),
            column.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 28),
            column.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -28)])
        view.addSubview(surface); surface.pin(to: view); errorPanel = surface
        if let checkoutOverlay { view.bringSubviewToFront(checkoutOverlay) }
        UIAccessibility.post(notification: .screenChanged, argument: message)
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard webView === web, sessionIsCurrent(sessionGeneration),
              let navigation, !rejected.contains(ObjectIdentifier(navigation)) else { return }
        if self.navigation !== navigation || !awaitingDocumentStart { prepareNavigation() }
        self.navigation = navigation; awaitingDocumentStart = false
    }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard webView === web, sessionIsCurrent(sessionGeneration), !awaitingDocumentStart,
              let navigation, self.navigation === navigation,
              !rejected.contains(ObjectIdentifier(navigation)), let url = webView.url else { return }
        // Back/forward-cache restores may commit without another network response.
        guard responseValid || (historyNavigationURL == url && policy.permitsDocument(url)) else { return }
        responseValid = true; historyNavigationURL = nil
        policy.commitDocument(url, navigation: navigationID)
        committedDocument = nil
    }
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        guard webView === web, let navigation, self.navigation === navigation else { return }
        historyNavigationURL = nil
        responseValid = false; policy.beginNavigation(navigationID)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === web, sessionIsCurrent(sessionGeneration),
              let navigation, self.navigation === navigation, !rejected.contains(ObjectIdentifier(navigation)) else { return }
        finish(success: responseValid)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(navigation, error: error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(navigation, error: error) }
    private func failed(_ navigation: WKNavigation?, error: Error) {
        guard let navigation, self.navigation === navigation, !rejected.contains(ObjectIdentifier(navigation)) else { return }
        let failure = error as NSError
        if failure.domain == NSURLErrorDomain, failure.code == NSURLErrorCancelled, committedDocument != nil {
            restoreCommittedDocument(); return
        }
        finish(success: false)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard webView === web else { return }
        result = nil; finish(success: false)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let url = navigationResponse.response.url, BibiWebInteractionPolicy.blocksPayment(url) {
            decisionHandler(.cancel)
            if webView === web, navigationResponse.isForMainFrame { restoreCommittedDocument() }
            return
        }
        if !navigationResponse.isForMainFrame {
            let allowed = webView === web && sessionIsCurrent(sessionGeneration)
                && navigationResponse.response.url.map {
                    policy.permitsEmbeddedDocument($0, pageID: pageID,
                        sessionGeneration: sessionGeneration, live: isLivePage)
                } == true
            decisionHandler(allowed ? .allow : .cancel)
            return
        }
        guard webView === web, sessionIsCurrent(sessionGeneration),
              let url = navigationResponse.response.url, policy.permitsDocument(url) else {
            decisionHandler(.cancel)
            if webView === web, navigationResponse.isForMainFrame { rejectMainNavigation() }
            return
        }
        guard let response = navigationResponse.response as? HTTPURLResponse,
              (200..<400).contains(response.statusCode), navigationResponse.canShowMIMEType else {
            decisionHandler(.cancel); rejectMainNavigation(); return
        }
        responseValid = true; decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, BibiWebInteractionPolicy.blocksPayment(url) {
            decisionHandler(.cancel)
            if webView === web, navigationAction.targetFrame?.isMainFrame == true { restoreCommittedDocument() }
            return
        }
        if navigationAction.targetFrame?.isMainFrame == false {
            let allowed = webView === web && sessionIsCurrent(sessionGeneration)
                && navigationAction.request.url.map {
                    policy.permitsEmbeddedDocument($0, pageID: pageID,
                        sessionGeneration: sessionGeneration, live: isLivePage)
                } == true
            decisionHandler(allowed ? .allow : .cancel)
            return
        }
        guard webView === web, sessionIsCurrent(sessionGeneration),
              let url = navigationAction.request.url, policy.permitsDocument(url) else {
            decisionHandler(.cancel)
            if webView === web, navigationAction.targetFrame?.isMainFrame == true { rejectMainNavigation() }
            return
        }
        if navigationAction.targetFrame == nil {
            decisionHandler(permitsWindow(navigationAction) ? .allow : .cancel)
            return
        }
        // The current document remains same-origin until a provisional load starts.
        // Anchor/history actions may never start or commit a new document.
        historyNavigationURL = navigationAction.navigationType == .backForward ? url : nil
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, BibiWebInteractionPolicy.blocksPayment(url) { return nil }
        if webView === web, permitsWindow(navigationAction), let url = navigationAction.request.url {
            UIApplication.shared.open(url)
        }
        return nil
    }
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let knownResource: Bool
        switch type {
        case .camera, .microphone, .cameraAndMicrophone: knownResource = true
        @unknown default: knownResource = false
        }
        // The Socket-supplied page URL owns this WebView's grant scope, including its embedded frames.
        let allowed = policy.permitsMedia(pageID: pageID, sessionGeneration: sessionGeneration,
            live: webView === web && isLivePage, knownResource: knownResource)
        decisionHandler(allowed ? .grant : .deny)
    }
    private var isLivePage: Bool {
        sessionIsCurrent(sessionGeneration) && UIApplication.shared.applicationState != .background
            && viewIfLoaded?.window != nil && !isBeingDismissed && result != false
    }
    private func permitsWindow(_ action: WKNavigationAction) -> Bool {
        guard let url = action.request.url, policy.permitsDocument(url) else { return false }
        let source = BibiWebOrigin(securityOrigin: action.sourceFrame.securityOrigin)
        return action.sourceFrame.webView === web && policy.permitsWindow(source: source,
            pageID: pageID, sessionGeneration: sessionGeneration, navigation: navigationID,
            live: isLivePage)
    }
    private func restoreCommittedDocument() {
        guard let previous = committedDocument else { return }
        if let navigation { rejected.insert(ObjectIdentifier(navigation)) }
        policy = previous.policy; navigationID = previous.navigationID
        navigation = previous.navigation; responseValid = previous.responseValid
        awaitingDocumentStart = false; result = true; committedDocument = nil
        historyNavigationURL = nil
        deadline?.cancel(); deadline = nil
        progress.pause(); progress.removeFromSuperview()
        errorPanel?.removeFromSuperview(); errorPanel = nil
    }
    private func configureCaptureReconcilers() {
        let capturedWeb = web
        captureReconcilers = [
            BibiWebCaptureReconciler(readState: { .init(capturedWeb.cameraCaptureState) },
                setState: { state, completion in
                    capturedWeb.setCameraCaptureState(state.webKitState, completionHandler: completion)
                }),
            BibiWebCaptureReconciler(readState: { .init(capturedWeb.microphoneCaptureState) },
                setState: { state, completion in
                    capturedWeb.setMicrophoneCaptureState(state.webKitState, completionHandler: completion)
                })
        ]
    }
    private func stopCapture() { captureReconcilers.forEach { $0.stop() } }
    private func suspendCapture() { captureReconcilers.forEach { $0.suspend() } }
    private func resumeCaptureIfPossible() {
        guard UIApplication.shared.applicationState == .active, isLivePage else { return }
        captureReconcilers.forEach { $0.resume() }
    }
    private func rejectMainNavigation() {
        if let navigation { rejected.insert(ObjectIdentifier(navigation)) }
        navigationID = UUID(); policy.beginNavigation(navigationID)
        web.stopLoading(); result = nil; finish(success: false)
    }
}

@MainActor
private final class BibiWebProgress: UIView {
    private let mark = UIImageView(image: BibiIcon.appMark)
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = BibiPalette.background; isOpaque = true
        isAccessibilityElement = true; accessibilityLabel = "Loading page"
        mark.contentMode = .scaleAspectFit
        addSubview(mark); mark.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([mark.centerXAnchor.constraint(equalTo: centerXAnchor),
            mark.centerYAnchor.constraint(equalTo: centerYAnchor), mark.widthAnchor.constraint(equalToConstant: 84),
            mark.heightAnchor.constraint(equalToConstant: 84)])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func resume() {
        guard UIApplication.shared.applicationState == .active, !UIAccessibility.isReduceMotionEnabled,
              mark.layer.animation(forKey: "pagePulse") == nil else { return }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.35; pulse.toValue = 1; pulse.duration = 0.8
        pulse.autoreverses = true; pulse.repeatCount = .infinity
        mark.layer.add(pulse, forKey: "pagePulse")
    }
    func pause() { mark.layer.removeAnimation(forKey: "pagePulse") }
}
