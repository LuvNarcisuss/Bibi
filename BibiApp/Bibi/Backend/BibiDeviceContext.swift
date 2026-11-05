import Foundation
import Network
import Supabase
import UIKit
import UserNotifications

/// Device context is independent of account sessions and is never removed on logout.
@MainActor
final class BibiDeviceContext {
    static let shared = BibiDeviceContext()
    private var pushToken = ""
    private var pushWaiter: CheckedContinuation<Void, Never>?
    private var pushTimeout: BibiForegroundTimeout?
    private var preparation: Task<[String: AnyJSON], Error>?
    private let network = BibiNetworkReadiness()
    var onNetworkAvailability: ((Bool) -> Void)? {
        didSet { network.onAvailability = onNetworkAvailability }
    }

    func start() {
        network.start()
    }

    func prepareNetwork() async throws {
        try await network.prepare(origin: BackendConfiguration.projectURL)
    }

    func prepareNetwork(origin: URL) async throws { try await network.prepare(origin: origin) }

    func didRegister(_ token: Data) {
        pushToken = token.map { String(format: "%02x", $0) }.joined()
        completePushWait()
    }

    func didFailRegistration() {
        completePushWait()
    }

    func prepare(origin: URL? = nil) async throws -> [String: AnyJSON] {
        try await network.prepare(origin: origin ?? BackendConfiguration.projectURL)
        if let preparation { return try await BibiSharedWaiter.wait(for: preparation) }
        let task = Task { @MainActor in
            defer { preparation = nil }
            let installation = try installationID()
            await preparePush()
            try Task.checkCancellation()
            guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                  !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw BackendError.invalidInput("Bibi's version information is unavailable.")
            }
            return [ConfiguredWireFields.bibi_edition: AnyJSON.string(version), ConfiguredWireFields.bell_mark: .string(pushToken),
                    ConfiguredWireFields.starlight_installation: .string(installation), ConfiguredWireFields.constellation_delivery: .integer(2)]
        }
        preparation = task
        return try await BibiSharedWaiter.wait(for: task)
    }

    private func installationID() throws -> String {
        let storage = BackendKeychain(), key = "bibi-installation-uuid"
        if let data = try storage.retrieve(key: key) {
            guard let raw = String(data: data, encoding: .utf8), UUID(uuidString: raw) != nil else {
                throw BackendError.invalidInput("The secure device identifier could not be read. Please try again.")
            }
            return raw
        }
        let value = UUID().uuidString.lowercased(), data = Data(value.utf8)
        try storage.store(key: key, value: data)
        guard try storage.retrieve(key: key) == data else {
            throw BackendError.invalidInput("The secure device identifier could not be saved. Please try again.")
        }
        return value
    }

    private func preparePush() async {
        let notifications = UNUserNotificationCenter.current()
        var settings = await notifications.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await notifications.requestAuthorization(options: [.alert, .badge, .sound])
            settings = await notifications.notificationSettings()
        }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral else { return }
        guard pushToken.isEmpty else { return }
        await withCheckedContinuation { continuation in
            pushWaiter = continuation
            pushTimeout = BibiForegroundTimeout(seconds: 10) { [weak self] in self?.completePushWait() }
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private func completePushWait() {
        pushTimeout?.cancel(); pushTimeout = nil
        let waiter = pushWaiter; pushWaiter = nil
        waiter?.resume()
    }
}

/// A route signal does not replace the first real, credential-free network probe.
@MainActor
final class BibiNetworkReadiness {
    var onAvailability: ((Bool) -> Void)?
    private let monitor = NWPathMonitor()
    private var started = false
    private var readyOrigins: Set<String> = []
    private var networkGeneration = UUID()
    private var pending: [String: Task<Void, Error>] = [:]
    private let redirects = BibiRedirectPolicy()

    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.networkGeneration = UUID()
                self.readyOrigins.removeAll()
                self.onAvailability?(available)
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.bibi.quadratic.network-readiness"))
    }

    func prepare(origin: URL) async throws {
        start()
        guard origin.scheme?.lowercased() == "https", let host = origin.host,
              origin.user == nil, origin.password == nil, origin.query == nil, origin.fragment == nil else {
            throw BackendError.invalidInput("The service address is invalid.")
        }
        let identity = "https://\(host.lowercased()):\(origin.port ?? 443)"
        if readyOrigins.contains(identity) { return }
        if let task = pending[identity] { return try await BibiSharedWaiter.wait(for: task) }
        let generation = networkGeneration
        var components = URLComponents(url: origin, resolvingAgainstBaseURL: false)!
        components.path = "/"
        guard let url = components.url else { throw BackendError.unavailable }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: redirects, delegateQueue: nil)
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        let task = Task { @MainActor in
            defer { session.invalidateAndCancel(); pending[identity] = nil }
            do {
                let (_, response) = try await session.data(for: request)
                try Task.checkCancellation()
                guard response is HTTPURLResponse else { throw BackendError.unavailable }
                if networkGeneration == generation { readyOrigins.insert(identity) }
            } catch {
                readyOrigins.remove(identity)
                throw error
            }
        }
        pending[identity] = task
        let timeout = BibiForegroundTimeout(seconds: 30) { task.cancel() }
        // The shared operation owns its deadline; cancellation only detaches a waiter.
        Task { @MainActor in
            _ = await task.result
            timeout.cancel()
        }
        try await BibiSharedWaiter.wait(for: task)
    }
}

/// Cancelling a caller never waits for, or cancels, another caller's shared work.
@MainActor
private final class BibiSharedWaiter<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, Error>?
    private var completed = false
    private var observation: Task<Void, Never>?

    static func wait(for task: Task<Value, Error>) async throws -> Value {
        try await BibiSharedWaiter<Value>().run(task)
    }

    private func run(_ task: Task<Value, Error>) async throws -> Value {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                guard !completed, !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.continuation = continuation
                observation = Task { @MainActor [weak self] in
                    let result = await task.result
                    self?.finish(result)
                }
            }
        }, onCancel: {
            Task { @MainActor [self] in finish(.failure(CancellationError())) }
        })
    }

    private func finish(_ result: Result<Value, Error>) {
        guard !completed else { return }
        completed = true
        observation?.cancel(); observation = nil
        let waiting = continuation; continuation = nil
        waiting?.resume(with: result)
    }
}

/// System permission dialogs pause the active-time budget without polling.
@MainActor
final class BibiForegroundTimeout {
    private var remaining: TimeInterval
    private var began: Date?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var action: (() -> Void)?

    init(seconds: TimeInterval, action: @escaping () -> Void) {
        remaining = seconds
        self.action = action
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pause() }
        })
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.resume() }
        })
        resume()
    }

    deinit {
        timer?.invalidate()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    func cancel() {
        action = nil; timer?.invalidate(); timer = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
    }

    private func pause() {
        if let began { remaining = max(0, remaining - Date().timeIntervalSince(began)) }
        began = nil; timer?.invalidate(); timer = nil
    }

    private func resume() {
        guard action != nil, timer == nil, UIApplication.shared.applicationState == .active else { return }
        began = Date()
        timer = Timer.scheduledTimer(withTimeInterval: max(0.001, remaining), repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let callback = self.action
                self.cancel()
                callback?()
            }
        }
    }
}

final class BibiRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
