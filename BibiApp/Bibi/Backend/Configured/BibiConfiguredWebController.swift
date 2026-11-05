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
    func permitsMedia(request: BibiWebOrigin?, frame: BibiWebOrigin?, pageID: String,
                      sessionGeneration: UUID, navigation: UUID, live: Bool, knownResource: Bool) -> Bool {
        guard !invalidated, live, knownResource, let entryOrigin,
              self.pageID == pageID, self.sessionGeneration == sessionGeneration,
              self.navigation == navigation, committedNavigation == navigation,
              documentOrigin == entryOrigin else { return false }
        return request == entryOrigin && frame == entryOrigin
    }
}

@MainActor
final class BibiConfiguredWebController: UIViewController, WKNavigationDelegate, WKUIDelegate {
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
    private var coverCommitted = false
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
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
    }
    private static func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = .nonPersistent()
        return WKWebView(frame: .zero, configuration: configuration)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = BibiPalette.background
        view.isOpaque = true; view.alpha = 1
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
        web.allowsBackForwardNavigationGestures = true
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        web.scrollView.contentInset = .zero; web.scrollView.scrollIndicatorInsets = .zero
        view.addSubview(web); web.pin(to: view)
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); onCoverCheck?() }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); onCoverCheck?() }

    func replace(url: URL, pageID: String) {
        policy.invalidate(); stopCapture()
        web.stopLoading(); web.navigationDelegate = nil; web.uiDelegate = nil
        web.removeFromSuperview()
        web = Self.makeWebView()
        self.url = url; self.pageID = pageID
        policy = BibiWebPagePolicy(url: url, pageID: pageID, sessionGeneration: sessionGeneration)
        if isViewLoaded { installWebView(); begin() } else { loadViewIfNeeded() }
    }
    func commitCover() { coverCommitted = true; settle() }
    func becameActive() { progress.resume(); onCoverCheck?(); settle() }
    func becameInactive() { progress.pause(); stopCapture() }
    func invalidateMedia() { policy.invalidate(); stopCapture() }

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
        prepareNavigation()
        navigation = web.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
        if navigation == nil { finish(success: false) }
    }
    private func prepareNavigation() {
        navigationID = UUID(); result = nil; responseValid = false
        awaitingDocumentStart = true
        policy.beginNavigation(navigationID); stopCapture()
        deadline?.cancel()
        if progress.superview == nil { view.addSubview(progress); progress.pin(to: view) }
        view.bringSubviewToFront(progress)
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
        let retry = actionButton("Try again", icon: .refresh) { [weak self] in self?.begin() }
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
        UIAccessibility.post(notification: .screenChanged, argument: message)
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard webView === web, sessionIsCurrent(sessionGeneration),
              let navigation, !rejected.contains(ObjectIdentifier(navigation)) else { return }
        if self.navigation !== navigation || !awaitingDocumentStart { prepareNavigation() }
        self.navigation = navigation; awaitingDocumentStart = false
    }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard webView === web, sessionIsCurrent(sessionGeneration), responseValid, !awaitingDocumentStart,
              let navigation, self.navigation === navigation,
              !rejected.contains(ObjectIdentifier(navigation)), let url = webView.url else { return }
        policy.commitDocument(url, navigation: navigationID)
    }
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        guard webView === web, let navigation, self.navigation === navigation else { return }
        responseValid = false; policy.beginNavigation(navigationID); stopCapture()
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === web, sessionIsCurrent(sessionGeneration),
              let navigation, self.navigation === navigation, !rejected.contains(ObjectIdentifier(navigation)) else { return }
        finish(success: responseValid)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(navigation) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(navigation) }
    private func failed(_ navigation: WKNavigation?) {
        guard let navigation, self.navigation === navigation, !rejected.contains(ObjectIdentifier(navigation)) else { return }
        finish(success: false)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard webView === web else { return }
        result = nil; finish(success: false)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard webView === web, sessionIsCurrent(sessionGeneration),
              let url = navigationResponse.response.url, policy.permitsDocument(url) else {
            decisionHandler(.cancel)
            if webView === web, navigationResponse.isForMainFrame { rejectMainNavigation() }
            return
        }
        guard navigationResponse.isForMainFrame else { decisionHandler(.allow); return }
        guard let response = navigationResponse.response as? HTTPURLResponse,
              (200..<400).contains(response.statusCode), navigationResponse.canShowMIMEType else {
            decisionHandler(.cancel); rejectMainNavigation(); return
        }
        responseValid = true; decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
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
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
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
        let allowed = policy.permitsMedia(request: BibiWebOrigin(securityOrigin: origin),
            frame: BibiWebOrigin(securityOrigin: frame.securityOrigin), pageID: pageID,
            sessionGeneration: sessionGeneration, navigation: navigationID,
            live: webView === web && frame.webView === web && isLivePage, knownResource: knownResource)
        decisionHandler(allowed ? .grant : .deny)
    }
    private var isLivePage: Bool {
        sessionIsCurrent(sessionGeneration) && UIApplication.shared.applicationState == .active
            && viewIfLoaded?.window != nil && !isBeingDismissed && result != false
    }
    private func permitsWindow(_ action: WKNavigationAction) -> Bool {
        guard let url = action.request.url, policy.permitsDocument(url) else { return false }
        let source = BibiWebOrigin(securityOrigin: action.sourceFrame.securityOrigin)
        return action.sourceFrame.webView === web && policy.permitsMedia(request: source, frame: source,
            pageID: pageID, sessionGeneration: sessionGeneration, navigation: navigationID,
            live: isLivePage, knownResource: true)
    }
    private func stopCapture() {
        web.setCameraCaptureState(.none, completionHandler: nil)
        web.setMicrophoneCaptureState(.none, completionHandler: nil)
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
