import AVFoundation
import CryptoKit
import Foundation
import Supabase

@MainActor
final class MediaRepository {
    private let services: BackendServices
    private var preparing = false
    private let content: ContentRepository
    init(_ services: BackendServices) { self.services = services; content = ContentRepository(services) }

    func upload(file: URL, mime: String) async throws -> UUID {
        let account = try services.requireAccount(), generation = services.generation
        let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= (mime == "video/mp4" ? 50_000_000 : 1_000_000) else { throw BackendError.invalidMedia }
        // Hashing identifies retry attempts, not authorization; the server validates owner and bytes.
        let hash = try await Self.digest(file)
        try services.check(generation)
        let cache = AccountCache.shared(account: account)
        let key = "media:\(mime):\(hash)"
        let operation = try await cache.operation(key: key)
        let staged = try await services.command("stage_media", operation: operation, payload: ["mime_type": .string(mime)])
        guard let bucket = staged["bucket_id"]?.stringValue, let path = staged["object_path"]?.stringValue else {
            throw BackendError.incompleteUpload
        }
        try services.check(generation)
        // If a prior attempt finished uploading, finalize those immutable bytes first.
        struct Parameters: Encodable { let media_id: UUID }
        if let existing: RemoteMediaReceipt = try? await services.client.functions.invoke("media-finalize", options: .init(body: Parameters(media_id: operation))), existing.status == "ready" {
            try services.check(generation); return operation
        }
        try await services.client.storage.from(bucket).upload(path, fileURL: file, options: .init(contentType: mime, upsert: false))
        try services.check(generation)
        let receipt: RemoteMediaReceipt = try await services.client.functions.invoke("media-finalize", options: .init(body: Parameters(media_id: operation)))
        try services.check(generation)
        guard receipt.status == "ready", receipt.id == operation else { throw BackendError.incompleteUpload }
        // Keep this immutable content hash mapping so a retry never creates duplicate objects.
        return operation
    }

    func signedURL(_ media: RemoteMedia) async throws -> URL {
        _ = try services.requireAccount(); let generation = services.generation
        let url = try await services.client.storage.from(media.bucket_id).createSignedURL(path: media.object_path, expiresIn: 300)
        try services.check(generation); return url
    }

    func uploadVideoCopy(source: URL) async throws -> UUID {
        guard !preparing else { throw BackendError.invalidInput("Another video is being prepared. Please try again when it finishes.") }
        preparing = true; defer { preparing = false }
        let account = try services.requireAccount(), generation = services.generation
        let hash = try await Self.digest(source)
        try services.check(generation)
        let directory = URL.applicationSupportDirectory.appendingPathComponent("BibiOnline/" + account.uuidString.lowercased() + "/UploadCopies", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let prepared = directory.appendingPathComponent(hash + "-480-v1.mp4")
        if FileManager.default.fileExists(atPath: prepared.path) { return try await upload(file: prepared, mime: "video/mp4") }
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0, duration <= 180 else { throw BackendError.invalidMedia }
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset640x480) else { throw BackendError.invalidMedia }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        defer { try? FileManager.default.removeItem(at: temporary) }
        export.outputURL = temporary; export.outputFileType = .mp4; export.shouldOptimizeForNetworkUse = true
        export.fileLengthLimit = 49_000_000
        let cancellation = VideoExportCancellation(session: export)
        await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                export.exportAsynchronously { continuation.resume() }
            }
        }, onCancel: { Task { await cancellation.cancel() } })
        try services.check(generation)
        guard export.status == .completed else { throw export.error ?? BackendError.invalidMedia }
        try FileManager.default.moveItem(at: temporary, to: prepared)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: prepared.path)
        return try await upload(file: prepared, mime: "video/mp4")
    }

    private static func digest(_ file: URL) async throws -> String {
        try await Task.detached(priority: .utility) {
            let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }
            var hash = SHA256()
            while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
                try Task.checkCancellation(); hash.update(data: chunk)
            }
            return hash.finalize().map { String(format: "%02x", $0) }.joined()
        }.value
    }

    func uploadImage(_ bytes: Data) async throws -> UUID {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try bytes.write(to: temporary, options: [.atomic, .completeFileProtection])
        return try await upload(file: temporary, mime: "image/jpeg")
    }
}

/// Keeps AVFoundation cancellation on the actor that owns the export session.
@MainActor
private final class VideoExportCancellation {
    private let session: AVAssetExportSession
    init(session: AVAssetExportSession) { self.session = session }
    func cancel() { session.cancelExport() }
}
