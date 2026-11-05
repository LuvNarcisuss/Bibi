import Foundation
import StoreKit
import UIKit

struct BibiReceiptSnapshot {
    let data: Data
    let startedAt: Date
    let obtainedAt: Date
}

/// A refresh started before a newly observed transaction cannot supply its first evidence.
@MainActor
final class BibiReceiptEvidence {
    private var flight: (id: UUID, began: Date, task: Task<BibiReceiptSnapshot, Error>)?

    private let refreshOperation: () async throws -> Data
    private let isActive: () -> Bool

    init(refresh: (() async throws -> Data)? = nil,
         isActive: @escaping () -> Bool = { UIApplication.shared.applicationState == .active }) {
        self.isActive = isActive
        refreshOperation = refresh ?? {
            let request = BibiReceiptRefreshRequest()
            try await request.refresh()
            guard let url = Bundle.main.appStoreReceiptURL else { throw BackendError.unavailable }
            return try Data(contentsOf: url, options: .mappedIfSafe)
        }
    }

    static func covers(observedAt: Date, refreshStartedAt: Date) -> Bool { refreshStartedAt >= observedAt }

    func refreshed(after observedAt: Date) async throws -> BibiReceiptSnapshot {
        if let current = flight {
            if Self.covers(observedAt: observedAt, refreshStartedAt: current.began) { return try await current.task.value }
            _ = try? await current.task.value
        }
        guard isActive() else {
            throw BackendError.invalidInput("Open Bibi to obtain evidence for your paid purchase.")
        }
        // Another waiter may have installed a sufficiently new refresh after the await.
        if let current = flight, Self.covers(observedAt: observedAt, refreshStartedAt: current.began) { return try await current.task.value }
        let id = UUID(), began = Date()
        let task = Task { @MainActor in
            let data = try await self.refreshOperation()
            guard !data.isEmpty, data.count <= 3_145_728 else { throw BackendError.invalidInput("Apple purchase evidence is not available yet.") }
            return BibiReceiptSnapshot(data: data, startedAt: began, obtainedAt: Date())
        }
        flight = (id, began, task)
        do {
            let result = try await task.value
            if flight?.id == id { flight = nil }
            return result
        } catch {
            if flight?.id == id { flight = nil }
            throw error
        }
    }

    nonisolated static var environment: String {
        guard let url = Bundle.main.appStoreReceiptURL else { return "Unknown" }
        if url.lastPathComponent == "sandboxReceipt" { return "Sandbox" }
        #if targetEnvironment(simulator)
        return "Xcode"
        #else
        return url.lastPathComponent == "receipt" ? "Production" : "Unknown"
        #endif
    }
}

@MainActor
private final class BibiReceiptRefreshRequest: NSObject, SKRequestDelegate {
    private var request: SKReceiptRefreshRequest?
    private var waiter: CheckedContinuation<Void, Error>?
    private var timeout: Task<Void, Never>?

    func refresh() async throws {
        try await withCheckedThrowingContinuation { continuation in
            waiter = continuation
            let next = SKReceiptRefreshRequest(receiptProperties: nil)
            request = next; next.delegate = self; next.start()
            timeout = Task { @MainActor [weak self] in
                do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { return }
                self?.complete(.failure(BackendError.invalidInput("Apple purchase evidence timed out. Your paid transaction has been kept.")))
            }
        }
    }

    private func complete(_ result: Result<Void, Error>) {
        guard let waiter else { return }
        self.waiter = nil; timeout?.cancel(); timeout = nil
        request?.delegate = nil; request?.cancel(); request = nil
        waiter.resume(with: result)
    }
    nonisolated func requestDidFinish(_ request: SKRequest) {
        Task { @MainActor in guard request === self.request else { return }; self.complete(.success(())) }
    }
    nonisolated func request(_ request: SKRequest, didFailWithError error: Error) {
        Task { @MainActor in guard request === self.request else { return }; self.complete(.failure(error)) }
    }
}
