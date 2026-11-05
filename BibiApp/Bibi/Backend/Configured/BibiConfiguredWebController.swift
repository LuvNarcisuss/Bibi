import UIKit
import WebKit

@MainActor
final class BibiConfiguredWebController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let web: WKWebView
    private let progress = BibiWebProgress()
    private var errorPanel: UIView?
    private var navigation: WKNavigation?
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

    init(url: URL, pageID: String) {
        self.url = url; self.pageID = pageID
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = .nonPersistent()
        web = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
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
        web.navigationDelegate = self; web.uiDelegate = self
        web.isOpaque = false; web.backgroundColor = .clear; web.scrollView.backgroundColor = .clear
        web.allowsBackForwardNavigationGestures = true
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        web.scrollView.contentInset = .zero; web.scrollView.scrollIndicatorInsets = .zero
        view.addSubview(web); web.pin(to: view)
        begin()
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); onCoverCheck?() }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); onCoverCheck?() }

    func replace(url: URL, pageID: String) {
        self.url = url; self.pageID = pageID
        loadViewIfNeeded(); begin()
    }
    func commitCover() { coverCommitted = true; settle() }
    func becameActive() { progress.resume(); onCoverCheck?(); settle() }
    func becameInactive() { progress.pause() }

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
        navigationID = UUID(); deadline?.cancel(); deadline = nil
        web.stopLoading(); web.navigationDelegate = nil; web.uiDelegate = nil
        progress.pause(); progress.removeFromSuperview(); errorPanel?.removeFromSuperview()
        onCoverCheck = nil; onLoaded = nil; onBack = nil
    }

    private func begin() {
        if let navigation { rejected.insert(ObjectIdentifier(navigation)) }
        web.stopLoading()
        prepareNavigation()
        navigation = web.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
        if navigation == nil { finish(success: false) }
    }
    private func prepareNavigation() {
        navigationID = UUID(); result = nil; responseValid = false
        deadline?.cancel()
        if progress.superview == nil { view.addSubview(progress); progress.pin(to: view) }
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
        guard let navigation, !rejected.contains(ObjectIdentifier(navigation)) else { return }
        if self.navigation !== navigation { self.navigation = navigation; prepareNavigation() }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let navigation, self.navigation === navigation, !rejected.contains(ObjectIdentifier(navigation)) else { return }
        finish(success: responseValid)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(navigation) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(navigation) }
    private func failed(_ navigation: WKNavigation?) {
        guard let navigation, self.navigation === navigation, !rejected.contains(ObjectIdentifier(navigation)) else { return }
        finish(success: false)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        result = nil; finish(success: false)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard navigationResponse.isForMainFrame else { decisionHandler(.allow); return }
        guard let response = navigationResponse.response as? HTTPURLResponse,
              (200..<400).contains(response.statusCode), navigationResponse.canShowMIMEType else {
            decisionHandler(.cancel); finish(success: false); return
        }
        responseValid = true; decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if ["https", "http"].contains(url.scheme?.lowercased() ?? "") { decisionHandler(.allow) }
        else { decisionHandler(.cancel); UIApplication.shared.open(url) }
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
            UIApplication.shared.open(url)
        }
        return nil
    }
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) { decisionHandler(.grant) }
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
