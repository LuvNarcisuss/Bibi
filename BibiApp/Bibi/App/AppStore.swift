import Combine
import Foundation
import UIKit
import Supabase

@MainActor
final class AppStore: ObservableObject {
  @Published private(set) var library = LocalLibrary()
  @Published private(set) var isLoaded = false
  @Published private(set) var loadError: String?
  @Published private(set) var busyMessage: String?
  @Published var notice: AppNotice?
  @Published private(set) var accountExitRevision = 0
  private var sessionActive = false
  var canUseGifts: Bool { false }
  var canEndSession: Bool {
    isLoaded && sessionActive && !isBusy && !shortsSocial.isSaving && !wallet.isBusy
  }
  private(set) var lastSaveError: String?
  private var ownerAvatarCache: UIImage?
  private var ownerAvatarStamp: Date?

  let online: OnlineState?
  var isOnline: Bool { BackendConfiguration.isEnabled }
  private var onlineObservation: AnyCancellable?
  let wallet = WalletStore()
  let shortsSocial: ShortsInteractionStore
  private var socialObservation: AnyCancellable?
  let storageRoot: URL
  @Published private var shortsVideoOrder: [UUID]
  private var watchedVideos: [UUID: Date] = [:]
  private let viewingHistory: VideoViewingHistory
  private var refreshingShorts = false
  private let repository: LocalLibraryRepository
  var isBusy: Bool { busyMessage != nil }
  var bundledVideos: [LocalVideo] {
    if isOnline { return [] }
    return AnimationCatalog.entries.map { entry in
      var video = entry.localVideo
      video.isSaved = library.savedDemoVideoIDs?.contains(video.id) == true
      return video
    }
  }
  var shortsDiscoveryVideos: [LocalVideo] { feed(orderedBy: shortsVideoOrder) }

  /// Only short videos enter discovery; pending local uploads stay private.
  private func feed(orderedBy order: [UUID]) -> [LocalVideo] {
    let bundled = bundledVideos.filter { $0.bundledClip?.surface == .shorts }
    let imported = library.videos.filter { $0.isDance == true }
    let candidates = (imported + bundled).filter {
      !pendingVideoIDs.contains($0.id) && !hidesVideo($0, live: false)
    }
    let lookup = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
    let known = Set(order)
    return candidates.filter { !known.contains($0.id) } + order.compactMap { lookup[$0] }
  }

  func recordVideoViewed(_ id: UUID) async {
    if isOnline { return }
    guard isLoaded, sessionActive, !isBusy else { return }
    let now = Date()
    guard now.timeIntervalSince(watchedVideos[id] ?? .distantPast) > 30 else { return }
    watchedVideos[id] = now
    // A storage failure leaves in-session recommendations working; never reset private data.
    try? await viewingHistory.record(id, at: now)
  }

  func refreshShortsRecommendations() async {
    if isOnline { do { try await refreshOnline() } catch { noteSaveError(error.localizedDescription) }; return }
    guard !refreshingShorts else { return }
    refreshingShorts = true
    defer { refreshingShorts = false }
    await Task.yield()
    guard !Task.isCancelled else { return }
    let candidates = shortsDiscoveryVideos.filter { $0.duration <= 180 }
    shortsVideoOrder = VideoRecommendations.orderedIDs(
      candidates, watched: watchedVideos, avoiding: candidates.first?.id)
  }

  var collectionVideos: [LocalVideo] {
    library.videos + bundledVideos.filter { $0.bundledClip?.surface == .shorts }
  }
  var likedVideos: [LocalVideo] {
    var seen: Set<UUID> = []
    return collectionVideos.filter { video in
      guard video.bundledClip?.surface != .live,
        shortsSocial.liked.contains(video.id), !pendingVideoIDs.contains(video.id),
        !hidesListedVideo(video), seen.insert(video.id).inserted
      else { return false }
      return true
    }
  }
  var savedVideos: [LocalVideo] {
    collectionVideos.filter {
      !pendingVideoIDs.contains($0.id) && $0.isSaved && !hidesListedVideo($0)
    }
  }

  init() {
    if BackendConfiguration.isEnabled, let services = try? BackendServices() { online = OnlineState(services: services) }
    else { online = nil }
    shortsVideoOrder = AnimationCatalog.shuffledDiscoveryIDs(for: .shorts)
    let root = URL.applicationSupportDirectory.appendingPathComponent("Bibi", isDirectory: true)
    storageRoot = root
    viewingHistory = VideoViewingHistory(root: root)
    repository = LocalLibraryRepository(root: root)
    shortsSocial = ShortsInteractionStore(root: root)
    socialObservation = shortsSocial.objectWillChange.sink { [weak self] _ in
      self?.objectWillChange.send()
    }
    if let online {
      shortsSocial.online = online
      wallet.configureOnline(online.wallet)
      onlineObservation = online.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
      online.services.onAccountExit = { [weak self] in self?.endOnlineSession() }
    }
  }

  // Records explicit consent; this does not authenticate an online account.
  func acceptUserAgreement() async -> Bool {
    if isOnline { return online?.services.phase == .signedIn }
    var updated = library
    updated.agreementAcceptance = AgreementAcceptance(
      version: BibiUserAgreement.version, acceptedAt: Date())
    guard await commit(updated, permitsEntry: true) else { return false }
    await viewingHistory.setRecordingEnabled(true)
    sessionActive = true
    shortsSocial.setSessionActive(true)
    return true
  }

  /// Ends only the local session. No online credentials or remote session exist.
  func logOut() async -> Bool {
    if let online {
      do { try await online.services.signOut(); endOnlineSession(); return true }
      catch { endOnlineSession(); noteSaveError(error.localizedDescription); return false }
    }
    guard canEndSession else { return false }
    busyMessage = "Signing out…"
    defer { busyMessage = nil }
    sessionActive = false
    shortsSocial.setSessionActive(false)
    await viewingHistory.setRecordingEnabled(false)
    notice = nil
    lastSaveError = nil
    accountExitRevision += 1
    return true
  }

  /// Explicitly confirmed by the settings screen; never called on simple logout.
  func deleteLocalAccount() async -> Bool {
    if isOnline { noteSaveError("Confirm your password to delete your online account."); return false }
    guard canEndSession else { return false }
    busyMessage = "Deleting your data…"
    defer { busyMessage = nil }
    sessionActive = false
    shortsSocial.setSessionActive(false)
    await viewingHistory.setRecordingEnabled(false)
    await wallet.stopPayments()
    do {
      try await repository.deleteLocalAccount()
      await clearAccountMemory()
      try await shortsSocial.load()
      loadError = nil
      accountExitRevision += 1
      await wallet.startPayments()
      return true
    } catch {
      // A durable deletion marker makes load() finish cleanup before any reads.
      await clearAccountMemory()
      isLoaded = false
      loadError = message(for: error)
      accountExitRevision += 1
      return false
    }
  }

  private func clearAccountMemory() async {
    library = LocalLibrary()
    shortsSocial.clearAccountMemory()
    wallet.clearAccountMemory()
    watchedVideos = [:]
    await viewingHistory.clearMemory()
    shortsVideoOrder = AnimationCatalog.shuffledDiscoveryIDs(for: .shorts)
    notice = nil
    lastSaveError = nil
  }

  func load() async {
    if isOnline {
      guard let online else { loadError = BackendError.unavailable.localizedDescription; return }
      isLoaded = true
      if (try? await online.services.restore()) == true {
        do { try await completeOnlineSignIn() } catch { loadError = error.localizedDescription }
      }
      return
    }
    guard !isBusy, !isLoaded else { return }
    busyMessage = "Opening your library…"
    defer { busyMessage = nil }
    loadError = nil
    do {
      library = try await repository.load()
      try await shortsSocial.load()
      let ledger = try await repository.loadWallet()
      wallet.adopt(ledger)
      wallet.setPersist { [repository] ledger in
        do {
          try await repository.saveWallet(ledger)
          return true
        } catch {
          return false
        }
      }
      watchedVideos = (try? await viewingHistory.load()) ?? [:]
      shortsVideoOrder = VideoRecommendations.orderedIDs(
        shortsDiscoveryVideos.filter { $0.duration <= 180 }, watched: watchedVideos)
      await wallet.startPayments()
      isLoaded = true
    } catch {
      loadError = message(for: error)
    }
  }

  func videoURL(_ video: LocalVideo) -> URL {
    if let id = video.remoteMediaID { return online?.signedURLs[id] ?? storageRoot.appendingPathComponent("Unavailable") }
    if let clip = video.bundledClip { return clip.resourceURL(fileExtension: "mp4") }
    return storageRoot.appendingPathComponent("Media/\(video.id.uuidString).\(video.fileExtension)")
  }

  func coverURL(_ video: LocalVideo) -> URL {
    if video.remoteMediaID != nil { return storageRoot.appendingPathComponent("UnavailableCover") }
    if let clip = video.bundledClip { return clip.resourceURL(fileExtension: "jpg") }
    return storageRoot.appendingPathComponent("Media/\(video.id.uuidString).jpg")
  }

  var pendingSubmissions: [CreationSubmission] {
    (library.submissions ?? []).filter { $0.kind == .shortVideo }
  }
  var pendingVideoIDs: Set<UUID> { Set(pendingSubmissions.compactMap(\.videoID)) }
  var personalWorks: [LocalVideo] {
    library.videos.filter { (!isOnline || $0.remoteCreator?.isLocalOwner == true) && !pendingVideoIDs.contains($0.id) && !hidesListedVideo($0) }
  }

  func submissionCoverURL(_ submission: CreationSubmission) -> URL? {
    if submission.hasCover {
      return storageRoot.appendingPathComponent("Media/\(submission.id.uuidString).jpg")
    }
    if let id = submission.videoID, let video = library.videos.first(where: { $0.id == id }) {
      return coverURL(video)
    }
    return nil
  }

  /// Queue content atomically; never start streaming, publish, or manufacture review approval.
  func queueCreation(
    kind: CreationKind, title: String, caption: String, category: VideoCategory,
    videoURL: URL?, challengeID: String? = nil
  ) async -> UUID? {
    if let online, let videoURL {
      guard !isBusy, CreationValidation.valid(title: title, caption: caption) else { return nil }
      busyMessage = "Uploading your video…"; defer { busyMessage = nil }
      do {
        let asset = try await online.media.uploadVideoCopy(source: videoURL)
        let id = try await online.content.publish(kind: "video", title: title, body: caption, media: asset, challenge: challengeID)
        try? await refreshOnline(); return id
      } catch { noteSaveError(error.localizedDescription); return nil }
    }
    guard isLoaded, sessionActive, !isBusy,
      CreationValidation.valid(title: title, caption: caption),
      kind == .shortVideo, videoURL != nil,
      challengeID == nil || CommunityCatalog.challenges.contains(where: { $0.id == challengeID })
    else { return nil }
    let replacingChallenge = challengeID.map { id in
      library.community?.entries.contains { $0.challengeID == id } == true
    } ?? false
    if let challengeID, !replacingChallenge, let error = await wallet.payForChallenge(challengeID) {
      noteSaveError(error)
      return nil
    }
    busyMessage = "Preparing your content…"
    lastSaveError = nil
    defer { busyMessage = nil }
    var submission = CreationSubmission(
      kind: kind, title: title.trimmingCharacters(in: .whitespacesAndNewlines),
      caption: caption.trimmingCharacters(in: .whitespacesAndNewlines), category: category.title)
    submission.coverStyleID = wallet.snapshot.cosmetics.coverTemplateID
    var importedVideo: LocalVideo?
    do {
      if kind == .shortVideo, let videoURL {
        var video = try await repository.importVideo(from: videoURL)
        importedVideo = video
        guard video.duration <= 180 else { throw CreationError.shortTooLong }
        video.title = submission.title
        video.isDance = true
        importedVideo = video
        submission.videoID = video.id
      }
      try Task.checkCancellation()
      var updated = library
      if let importedVideo { updated.videos.insert(importedVideo, at: 0) }
      var submissions = updated.submissions ?? []
      submissions.insert(submission, at: 0)
      updated.submissions = submissions
      if let challengeID, let importedVideo {
        var state = updated.community ?? CommunityState()
        let entryID = state.entries.first { $0.challengeID == challengeID }?.id ?? UUID()
        state.entries.removeAll { $0.challengeID == challengeID }
        state.entries.insert(
          ChallengeEntry(id: entryID, challengeID: challengeID, videoID: importedVideo.id), at: 0)
        updated.community = state
      }
      try await repository.save(updated)
      library = updated
      return submission.id
    } catch {
      if let importedVideo { await repository.removeMedia(for: importedVideo) }
      await repository.removeSubmissionCover(submission.id)
      if let challengeID, !replacingChallenge { _ = await wallet.refundChallenge(challengeID) }
      lastSaveError =
        (error as? CreationError)?.errorDescription
        ?? (error as? LocalLibraryError)?.errorDescription
        ?? "Your content could not be saved. Please try again."
      return nil
    }
  }

  func removeSubmission(_ id: UUID) async -> Bool {
    if isOnline { return await remoteMutation("withdraw", payload: ["target_id": .string(id.uuidString)]) }
    guard let submission = pendingSubmissions.first(where: { $0.id == id }) else { return false }
    let video = library.videos.first { $0.id == submission.videoID }
    var updated = library
    updated.submissions?.removeAll { $0.id == id }
    if let video {
      updated.videos.removeAll { $0.id == video.id }
      updated.community?.removeVideo(video.id)
    }
    guard await commit(updated) else { return false }
    if let video { await repository.removeMedia(for: video) }
    if submission.hasCover { await repository.removeSubmissionCover(submission.id) }
    return true
  }

  func classifyForCommunity(_ id: UUID) async {
    if isOnline { return }
    var updated = library
    guard let index = updated.videos.firstIndex(where: { $0.id == id }) else { return }
    updated.videos[index].isDance = true
    if !(await commit(updated)) { showSaveFailure() }
  }

  func toggleSaved(_ id: UUID) async {
    if let online { _ = await remoteMutation("save", payload: ["target_id": .string(id.uuidString), "selected": .bool(!online.saves.contains(id))]); return }
    var updated = library
    if AnimationCatalog.entries.contains(where: { $0.id == id }) {
      var saved = updated.savedDemoVideoIDs ?? []
      if saved.contains(id) { saved.remove(id) } else { saved.insert(id) }
      updated.savedDemoVideoIDs = saved
      if !(await commit(updated)) { showSaveFailure() }
      return
    }
    guard let index = updated.videos.firstIndex(where: { $0.id == id }) else { return }
    updated.videos[index].isSaved.toggle()
    if !(await commit(updated)) { showSaveFailure() }
  }

  func renameVideo(_ id: UUID, title: String) async -> Bool {
    if let online, let item = online.records.first(where: { $0.id == id }), let revision = online.revision(item) {
      do { _ = try await online.content.publish(kind: "video", title: title, body: revision.body, media: revision.media_id, editing: id); try? await refreshOnline(); return true }
      catch { noteSaveError(error.localizedDescription); return false }
    }
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty, title.count <= 80 else { return false }
    var updated = library
    guard let index = updated.videos.firstIndex(where: { $0.id == id }) else { return false }
    updated.videos[index].title = title
    return await commit(updated)
  }

  func deleteVideo(_ id: UUID) async -> Bool {
    if isOnline { return await remoteMutation("withdraw", payload: ["target_id": .string(id.uuidString)]) }
    guard let video = library.videos.first(where: { $0.id == id }) else { return false }
    var updated = library
    updated.videos.removeAll { $0.id == id }
    updated.submissions?.removeAll { $0.videoID == id }
    updated.community?.removeVideo(id)
    guard await commit(updated) else {
      showSaveFailure()
      return false
    }
    await repository.removeMedia(for: video)
    return true
  }

  func saveProfile(_ profile: LocalProfile, avatarJPEG: Data? = nil) async -> Bool {
    if let online {
      do {
        if let avatarJPEG { let asset = try await online.media.uploadImage(avatarJPEG); _ = try await online.content.publish(kind: "avatar", body: "", media: asset) }
        return await remoteMutation("profile", payload: ["display_name": .string(profile.displayName), "biography": .string(profile.biography)])
      } catch { noteSaveError(error.localizedDescription); return false }
    }
    lastSaveError = nil
    var profile = profile
    profile.displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !profile.displayName.isEmpty, profile.displayName.count <= 30,
      profile.biography.count <= 160, CreationValidation.isEnglish(profile.displayName),
      CreationValidation.isEnglish(profile.biography)
    else { return false }
    if let avatarJPEG {
      do { try await repository.storeProfileAvatar(avatarJPEG) } catch {
        lastSaveError = message(for: error)
        return false
      }
      profile.hasCustomAvatar = true
    }
    var updated = library
    updated.profile = profile
    let saved = await commit(updated)
    guard avatarJPEG != nil else { return saved }
    if saved {
      do {
        try await repository.promoteProfileAvatar()
        ownerAvatarCache = nil
        ownerAvatarStamp = nil
        objectWillChange.send()
      } catch {
        lastSaveError = message(for: error)
        await repository.discardPendingProfileAvatar()
        return false
      }
    } else {
      await repository.discardPendingProfileAvatar()
    }
    return saved
  }

  /// The signed-in dancer's saved portrait, when one has been chosen on this device.
  func ownerAvatarImage() -> UIImage? {
    if isOnline { return nil }
    guard library.profile.hasCustomAvatar == true else { return nil }
    let url = storageRoot.appendingPathComponent("Media/profile-avatar.jpg")
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
      let modified = attrs[.modificationDate] as? Date
    else { return nil }
    if ownerAvatarStamp == modified, let ownerAvatarCache { return ownerAvatarCache }
    let image = UIImage(contentsOfFile: url.path)
    ownerAvatarCache = image
    ownerAvatarStamp = modified
    return image
  }

  func saveMessageDraft(_ text: String) async -> Bool {
    guard text.count <= 2_000 else { return false }
    var updated = library
    updated.messageDraft = text
    return await commit(updated)
  }

  var chatConversations: [CommunityConversation] {
    if let online { return online.inbox }
    let state = library.creatorState ?? CreatorLocalState()
    var records = state.conversations ?? [:]
    // Surface existing drafts from versions that did not store inbox entries.
    for id in state.messageDrafts.keys where records[id] == nil {
      let creator = resolvedCreator(id: id, stored: nil)
      records[id] = CreatorConversationRecord(creator: creator, updatedAt: nil)
    }
    let creators = records.values.filter { !isCreatorBlocked($0.creator.id) }.sorted {
      let left = $0.updatedAt ?? .distantPast
      let right = $1.updatedAt ?? .distantPast
      return left == right ? $0.creator.id < $1.creator.id : left > right
    }.map { record in
      let creator = resolvedCreator(id: record.creator.id, stored: record.creator)
      let time =
        record.updatedAt.map { date in
          Calendar.current.isDateInToday(date)
            ? date.formatted(.dateTime.hour().minute().locale(Locale(identifier: "en_US")))
            : date.formatted(
              .dateTime.month(.abbreviated).day().locale(Locale(identifier: "en_US")))
        } ?? ""
      return CommunityConversation(
        id: "creator-chat:\(creator.id)", name: creator.name,
        avatars: [creator.avatarAsset ?? CommunityArtwork.creatorAvatar(for: creator.id)],
        kind: .person, time: time, initialUnread: 0, initiallyPinned: false,
        story: nil, messages: library.chatState?.sentMessages?["creator-chat:\(creator.id)"] ?? [],
        creator: creator)
    }
    let authored = (CommunityChatCatalog.conversations + CommunityChatCatalog.legacyGroups).filter { conversation in
      let chats = library.chatState
      return !(chats?.sentMessages?[conversation.id] ?? []).isEmpty
        || !(chats?.drafts[conversation.id] ?? "").isEmpty
    }.map { conversation in
      let additions = library.chatState?.sentMessages?[conversation.id] ?? []
      return CommunityConversation(
        id: conversation.id, name: conversation.name, avatars: conversation.avatars,
        kind: conversation.kind, time: additions.last?.time ?? conversation.time,
        initialUnread: 0, initiallyPinned: false,
        story: nil, messages: additions)
    }
    let groups = (library.chatState?.createdGroups ?? []).sorted { $0.createdAt > $1.createdAt }.map
    {
      group in
      let additions = library.chatState?.sentMessages?[group.id] ?? []
      return CommunityConversation(
        id: group.id, name: group.name,
        avatars: group.avatarAssets,
        kind: .group,
        time: additions.last?.time ?? "Now", initialUnread: 0, initiallyPinned: false,
        story: nil, messages: additions)
    }
    let hidden = library.chatState?.hiddenChatIDs ?? []
    let ordered =
      groups
      + (creators + authored).sorted { left, right in
        let a = library.chatState?.sentMessages?[left.id]?.last?.createdAt ?? .distantPast
        let b = library.chatState?.sentMessages?[right.id]?.last?.createdAt ?? .distantPast
        if a == b { return false }
        return a > b
      }
    return ordered.filter { conversation in
      if hidden.contains(conversation.id) { return false }
      if isCreatorBlocked(conversation.id) { return false }
      if let creatorID = conversation.creator?.id, isCreatorBlocked(creatorID) { return false }
      return true
    }
  }

  /// Saves a group on this device. The other people are not notified.
  func createChatGroup(with people: [CommunityConversation]) async -> CommunityConversation? {
    if let online {
      do {
        let peers = people.compactMap { $0.creator?.id }.sorted()
        let result = try await online.content.mutate("group", payload: [
          "title": .string(String(people.map(\.name).joined(separator: ", ").prefix(80))),
          "members": .array(peers.map(AnyJSON.string))])
        guard let id = result["id"]?.stringValue else { return nil }
        try? await refreshOnline()
        return chatConversations.first { $0.id.lowercased() == id.lowercased() }
          ?? CommunityConversation(id: UUID(uuidString: id)?.uuidString ?? id, name: String(people.map(\.name).joined(separator: ", ").prefix(80)), avatars: ["BibiMark"], kind: .group, time: "", initialUnread: 0, initiallyPinned: false, story: nil, messages: [])
      } catch { noteSaveError(error.localizedDescription); return nil }
    }
    guard isLoaded, !isBusy, people.count >= 2 else { return nil }
    let names = people.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }.filter {
      !$0.isEmpty
    }
    guard names.count >= 2, CreationValidation.isEnglish(names.joined(separator: ", ")) else {
      lastSaveError = "Choose at least two friends."
      return nil
    }
    var title = names.joined(separator: ", ")
    if title.count > 48 { title = String(title.prefix(45)) + "..." }
    let group = LocalChatGroup(
      id: "group-" + UUID().uuidString, name: title,
      avatarAssets: people.map { person in
        if let asset = person.avatars.first { return asset }
        if let creator = person.creator { return CommunityArtwork.creatorAvatar(for: creator.id) }
        return CharacterDirectory.asset(forName: person.name)
      }, createdAt: Date())
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    var groups = state.createdGroups ?? []
    groups.insert(group, at: 0)
    state.createdGroups = groups
    updated.chatState = state
    guard await commit(updated) else { return nil }
    return chatConversations.first { $0.id == group.id }
  }

  func messages(for conversation: CommunityConversation) -> [ChatMessage] {
    if isCreatorBlocked(conversation.creator?.id ?? conversation.id) { return [] }
    let visible = chatConversations.first { $0.id == conversation.id }?.messages
      ?? (isOnline ? [] : conversation.messages)
    return visible.filter { message in
      if message.isOwn { return true }
      if let online, let roomID = UUID(uuidString: conversation.id),
         let author = online.messages[roomID]?.first(where: { $0.id.uuidString == message.id })?.sender_id {
        return !isCreatorBlocked(author.uuidString)
      }
      if conversation.kind == .group,
         let person = CommunityChatCatalog.people.first(where: { $0.name == message.author }) {
        return !isCreatorBlocked(person.creator?.id ?? person.id)
      }
      return true
    }
  }

  func followsChatPartner(_ conversation: CommunityConversation) -> Bool {
    if let online { return online.follows.contains { $0.user_id == online.services.accountID && $0.target_id.uuidString == conversation.creator?.id } }
    if let creator = conversation.creator { return isFollowingCreator(creator.id) }
    return library.chatState?.followingOverrides?[conversation.id]
      ?? CommunityChatCatalog.initialMutualIDs.contains(conversation.id)
  }

  /// Catalog friends follow the chat relationship. Video creators follow the creator list.
  func followsProfile(_ creator: CreatorProfile) -> Bool {
    if let person = CommunityChatCatalog.people.first(where: { $0.id == creator.id }) {
      return followsChatPartner(person)
    }
    return isFollowingCreator(creator.id)
  }

  /// Use the same incoming relationship IDs as Chats; following alone is not mutual.
  func isMutualProfile(_ creator: CreatorProfile) -> Bool {
    if let online { return online.follows.contains { $0.user_id == online.services.accountID && $0.target_id.uuidString == creator.id }
      && online.follows.contains { $0.target_id == online.services.accountID && $0.user_id.uuidString == creator.id } }
    guard !creator.isLocalOwner, !isCreatorBlocked(creator.id) else { return false }
    if let person = CommunityChatCatalog.people.first(where: { $0.id == creator.id }) {
      return isMutualChat(person)
    }
    return isFollowingCreator(creator.id)
      && (library.chatState?.followerIDs ?? []).contains("creator-chat:\(creator.id)")
  }

  func toggleProfileFollow(_ creator: CreatorProfile) async {
    guard !isCreatorBlocked(creator.id) else { return }
    if let person = CommunityChatCatalog.people.first(where: { $0.id == creator.id }) {
      await toggleChatFollow(person)
      return
    }
    await toggleCreatorFollow(creator.id)
  }

  func chatPartnerFollowsMe(_ conversation: CommunityConversation) -> Bool {
    if let online { return online.follows.contains { $0.target_id == online.services.accountID && $0.user_id.uuidString == conversation.creator?.id } }
    // Unknown creator relationships remain false until an authoritative service updates them.
    let followers = library.chatState?.followerIDs ?? CommunityChatCatalog.initialFollowerIDs
    return followers.contains(conversation.id)
  }

  func isMutualChat(_ conversation: CommunityConversation) -> Bool {
    followsChatPartner(conversation) && chatPartnerFollowsMe(conversation)
  }

  func canSendChatMessage(_ conversation: CommunityConversation) -> Bool {
    if let online, let id = UUID(uuidString: conversation.id) {
      guard online.members.contains(where: { $0.conversation_id == id && $0.user_id == online.services.accountID && $0.status == "active" }) else { return false }
      return conversation.kind == .group || isMutualChat(conversation) || !(online.messages[id] ?? []).contains { $0.sender_id == online.services.accountID }
    }
    if conversation.kind == .activity { return false }
    if isCreatorBlocked(conversation.id) { return false }
    if let creator = conversation.creator, isCreatorBlocked(creator.id) { return false }
    if conversation.kind == .group || conversation.creator?.isLocalOwner == true
      || isMutualChat(conversation)
    {
      return true
    }
    return (library.chatState?.sentMessages?[conversation.id] ?? []).isEmpty
  }

  func toggleChatFollow(_ conversation: CommunityConversation) async {
    if let creator = conversation.creator {
      await toggleCreatorFollow(creator.id)
      return
    }
    guard isLoaded, !isBusy, conversation.kind == .person, !isCreatorBlocked(conversation.id) else {
      return
    }
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    var overrides = state.followingOverrides ?? [:]
    overrides[conversation.id] = !followsChatPartner(conversation)
    state.followingOverrides = overrides
    updated.chatState = state
    if !(await commit(updated)) { showSaveFailure() }
  }

  /// Local outbox only: persistence does not imply remote delivery or a read receipt.
  func sendChatMessage(_ text: String, to conversation: CommunityConversation) async -> Bool {
    if let online, let account = online.services.accountID {
      let saved = await remoteMutation("send", payload: ["target_id": .string(conversation.id), "body": .string(text)])
      if saved { try? await AccountCache.shared(account: account).saveDraft("", conversation: conversation.id) }
      return saved
    }
    guard isLoaded, !isBusy else { return false }
    lastSaveError = nil
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, text.count <= 2_000, CreationValidation.isEnglish(text) else {
      lastSaveError = "Write a message of up to 2,000 characters in English."
      return false
    }
    guard canSendChatMessage(conversation) else {
      let blocked =
        isCreatorBlocked(conversation.id)
        || conversation.creator.map { isCreatorBlocked($0.id) } == true
      lastSaveError =
        blocked
        ? "Unblock this person to chat."
        : "You can send another message once you follow each other."
      return false
    }
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    var outbox = state.sentMessages ?? [:]
    let now = Date()
    let message = ChatMessage(
      id: UUID().uuidString, author: "You", text: text,
      time: now.formatted(.dateTime.hour().minute().locale(Locale(identifier: "en_US"))),
      isOwn: true, createdAt: now, isPending: true)
    outbox[conversation.id, default: []].append(message)
    state.sentMessages = outbox
    state.drafts.removeValue(forKey: conversation.id)
    state.readIDs.insert(conversation.id)
    var marks = state.unreadMarks ?? [:]
    marks[conversation.id] = nil
    state.unreadMarks = marks.isEmpty ? nil : marks
    updated.chatState = state
    if let creator = conversation.creator {
      var creators = updated.creatorState ?? CreatorLocalState()
      creators.messageDrafts.removeValue(forKey: creator.id)
      var records = creators.conversations ?? [:]
      records[creator.id] = CreatorConversationRecord(creator: creator, updatedAt: now)
      creators.conversations = records
      updated.creatorState = creators
    }
    return await commit(updated)
  }

  func chatDraft(for conversation: CommunityConversation) -> String? {
    if let online { return online.drafts[conversation.id] }
    if let creator = conversation.creator { return library.creatorState?.messageDrafts[creator.id] }
    return library.chatState?.drafts[conversation.id]
  }

  private func resolvedCreator(id: String, stored: CreatorProfile?) -> CreatorProfile {
    if let video = collectionVideos.first(where: { $0.creatorID == id }) {
      return .from(video: video, profile: library.profile, coverURL: coverURL(video))
    }
    if id == "local-owner" {
      return CreatorProfile(
        id: id, name: library.profile.displayName, biography: library.profile.biography,
        avatarSymbol: library.profile.avatarSymbol, isLocalOwner: true)
    }
    return stored ?? CreatorProfile(id: id, name: "Community creator", biography: "")
  }

  @discardableResult
  func openCreatorConversation(_ creator: CreatorProfile) async -> Bool {
    if isOnline { return await remoteMutation("direct", payload: ["target_id": .string(creator.id)]) }
    guard !isCreatorBlocked(creator.id) else { return false }
    var updated = library
    var state = updated.creatorState ?? CreatorLocalState()
    var records = state.conversations ?? [:]
    records[creator.id] = CreatorConversationRecord(creator: creator, updatedAt: Date())
    state.conversations = records
    updated.creatorState = state
    return await commit(updated)
  }

  func chatUnreadCount(_ conversation: CommunityConversation) -> Int {
    if let online { return online.inbox.first { $0.id == conversation.id }?.initialUnread ?? 0 }
    if let marked = library.chatState?.unreadMarks?[conversation.id] { return marked }
    if library.chatState?.readIDs.contains(conversation.id) == true { return 0 }
    return conversation.initialUnread
  }

  func isChatPinned(_ conversation: CommunityConversation) -> Bool {
    if let online { return online.members.first { $0.conversation_id.uuidString == conversation.id && $0.user_id == online.services.accountID }?.pinned ?? false }
    return library.chatState?.pinOverrides[conversation.id] ?? conversation.initiallyPinned
  }

  func isChatMuted(_ conversation: CommunityConversation) -> Bool {
    if let online { return online.members.first { $0.conversation_id.uuidString == conversation.id && $0.user_id == online.services.accountID }?.muted ?? false }
    return library.chatState?.mutedIDs?.contains(conversation.id) == true
  }

  func markChatRead(_ id: String? = nil) async {
    if let online {
      for room in online.conversations where id == nil || room.id.uuidString == id {
        let sequence = online.messages[room.id]?.last?.sequence ?? 0
        _ = await remoteMutation("chat_preferences", payload: ["target_id": .string(room.id.uuidString), "read_sequence": .integer(Int(sequence))])
      }
      return
    }
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    let ids = id.map { Set([$0]) } ?? Set(chatConversations.map(\.id))
    var marks = state.unreadMarks ?? [:]
    let hadMark = ids.contains { marks[$0] != nil }
    guard hadMark || !ids.isSubset(of: state.readIDs) else { return }
    for item in ids { marks[item] = nil }
    state.unreadMarks = marks.isEmpty ? nil : marks
    state.readIDs.formUnion(ids)
    updated.chatState = state
    if !(await commit(updated)) { showSaveFailure() }
  }

  /// Forces a local unread count of 1. This does not deliver a message.
  func markChatUnread(_ conversation: CommunityConversation) async {
    if isOnline { noteSaveError("Read receipts cannot be undone."); return }
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    var marks = state.unreadMarks ?? [:]
    marks[conversation.id] = 1
    state.unreadMarks = marks
    state.readIDs.remove(conversation.id)
    updated.chatState = state
    if !(await commit(updated)) { showSaveFailure() }
  }

  func toggleChatPin(_ conversation: CommunityConversation) async {
    if isOnline { _ = await remoteMutation("chat_preferences", payload: ["target_id": .string(conversation.id), "pinned": .bool(!isChatPinned(conversation))]); return }
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    state.pinOverrides[conversation.id] = !isChatPinned(conversation)
    updated.chatState = state
    if !(await commit(updated)) { showSaveFailure() }
  }

  func toggleChatMute(_ conversation: CommunityConversation) async {
    if isOnline { _ = await remoteMutation("chat_preferences", payload: ["target_id": .string(conversation.id), "muted": .bool(!isChatMuted(conversation))]); return }
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    var muted = state.mutedIDs ?? []
    if muted.contains(conversation.id) {
      muted.remove(conversation.id)
    } else {
      muted.insert(conversation.id)
    }
    state.mutedIDs = muted
    updated.chatState = state
    if !(await commit(updated)) { showSaveFailure() }
  }

  /// Hides the row on this device. The conversation is not removed from another account.
  func hideChat(_ conversation: CommunityConversation) async {
    if isOnline { _ = await remoteMutation("chat_preferences", payload: ["target_id": .string(conversation.id), "hidden": .bool(true)]); return }
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    var hidden = state.hiddenChatIDs ?? []
    guard !hidden.contains(conversation.id) else { return }
    hidden.insert(conversation.id)
    state.hiddenChatIDs = hidden
    updated.chatState = state
    if !(await commit(updated)) { showSaveFailure() }
  }

  func saveChatDraft(_ text: String, conversationID: String) async -> Bool {
    if let online, let account = online.services.accountID {
      do { try await AccountCache.shared(account: account).saveDraft(text, conversation: conversationID); return true }
      catch { noteSaveError(error.localizedDescription); return false }
    }
    let known =
      CommunityChatCatalog.conversations.contains { $0.id == conversationID }
      || CommunityChatCatalog.legacyGroups.contains { $0.id == conversationID }
      || (library.chatState?.createdGroups ?? []).contains { $0.id == conversationID }
    guard text.count <= 2_000, known else { return false }
    var updated = library
    var state = updated.chatState ?? ChatLocalState()
    if text.isEmpty {
      state.drafts[conversationID] = nil
    } else {
      state.drafts[conversationID] = text
    }
    updated.chatState = state
    return await commit(updated)
  }

  /// The profile grid and totals share the complete catalog, independent of feed order.
  /// Pending submissions are private queue entries, not published works.
  func creatorWorks(for creatorID: String) -> [LocalVideo] {
    collectionVideos.filter {
      ($0.creatorID == creatorID || $0.bundledClip?.legacyCuratorID == creatorID)
        && !pendingVideoIDs.contains($0.id) && !hidesListedVideo($0)
    }
  }

  func statistics(for creator: CreatorProfile) -> CreatorStatistics {
    if let online {
      let works = online.records.filter { $0.owner_id?.uuidString == creator.id && ($0.kind == "video" || $0.kind == "post") }
      return CreatorStatistics(likes: works.reduce(0) { $0 + (online.counts[$1.id]?.likes ?? 0) },
        saves: works.reduce(0) { $0 + (online.counts[$1.id]?.saves ?? 0) },
        following: UUID(uuidString: creator.id).flatMap { online.profileCounts[$0]?.following } ?? 0,
        followers: UUID(uuidString: creator.id).flatMap { online.profileCounts[$0]?.followers } ?? 0)
    }
    var totals = creatorWorks(for: creator.id).reduce(into: (likes: 0, saves: 0)) { total, video in
      let counts = shortsSocial.counts(for: video)
      total.likes += counts.likes
      total.saves += counts.saves
    }
    for post in creatorPosts(for: creator.id) {
      let counts = circlePostCounts(for: post)
      totals.likes += counts.likes
      totals.saves += counts.saves
    }
    if creator.isLocalOwner {
      let creatorFollows = library.creatorState?.followedIDs.count ?? 0
      let chatFollows = CommunityChatCatalog.conversations.filter {
        $0.kind == .person && followsChatPartner($0)
      }.count
      return CreatorStatistics(
        likes: totals.likes, saves: totals.saves,
        following: creatorFollows + chatFollows, followers: 0)
    }
    let relationships = (CommunityCatalog.storyAuthor(id: creator.id) ?? creator).relationshipStatistics
    return CreatorStatistics(
      likes: totals.likes, saves: totals.saves,
      following: relationships.following,
      followers: relationships.followers + (isFollowingCreator(creator.id) ? 1 : 0))
  }

  func isFollowingCreator(_ id: String) -> Bool {
    library.creatorState?.followedIDs.contains(id) == true
  }

  func toggleCreatorFollow(_ id: String) async {
    if isOnline { _ = await remoteMutation("follow", payload: ["target_id": .string(id), "selected": .bool(!isFollowingCreator(id))]); return }
    guard isLoaded, !isBusy, !isCreatorBlocked(id) else { return }
    var updated = library
    var state = updated.creatorState ?? CreatorLocalState()
    if state.followedIDs.contains(id) {
      state.followedIDs.remove(id)
    } else {
      state.followedIDs.insert(id)
    }
    updated.creatorState = state
    if !(await commit(updated)) { showSaveFailure() }
  }

  func saveCreatorMessageDraft(_ text: String, creator: CreatorProfile) async -> Bool {
    if let online, let room = online.inbox.first(where: { $0.creator?.id == creator.id }) { return await saveChatDraft(text, conversationID: room.id) }
    guard !isCreatorBlocked(creator.id), text.count <= 2_000 else { return false }
    var updated = library
    var state = updated.creatorState ?? CreatorLocalState()
    state.messageDrafts[creator.id] = text.isEmpty ? nil : text
    var records = state.conversations ?? [:]
    records[creator.id] = CreatorConversationRecord(creator: creator, updatedAt: Date())
    state.conversations = records
    updated.creatorState = state
    return await commit(updated)
  }

  func isCreatorBlocked(_ id: String) -> Bool {
    library.contentSafety?.blockedCreators[id] != nil
  }

  func isContentReported(_ id: String, kind: ContentSafetyTarget.Kind) -> Bool {
    library.contentSafety?.reports.contains { $0.contentID == id && $0.kind == kind } == true
  }

  /// A report hides that film on its own surface. A block hides every film from that creator.
  func hidesVideo(_ video: LocalVideo, live: Bool) -> Bool {
    if isCreatorBlocked(video.creatorID) { return true }
    if let legacyID = video.bundledClip?.legacyCuratorID, isCreatorBlocked(legacyID) { return true }
    return isContentReported(video.id.uuidString, kind: live ? .live : .shortVideo)
  }

  private func hidesListedVideo(_ video: LocalVideo) -> Bool {
    hidesVideo(video, live: video.bundledClip?.surface == .live)
  }

  func isCommentReported(_ id: String) -> Bool {
    isContentReported(id, kind: .comment)
  }

  /// Latest reason for each video, comment, or room, newest first.
  func reportedContent() -> [ReportedContentItem] {
    var latest: [String: LocalContentReport] = [:]
    for report in library.contentSafety?.reports ?? [] {
      let key = report.kind.rawValue + ":" + report.contentID
      if let current = latest[key], current.savedAt >= report.savedAt { continue }
      latest[key] = report
    }
    return latest.values.map {
      ReportedContentItem(
        contentID: $0.contentID, kind: $0.kind, title: $0.title,
        creatorName: $0.creatorName, reason: $0.reason, savedAt: $0.savedAt)
    }
    .sorted { $0.savedAt > $1.savedAt }
  }

  /// Removes every saved reason for one item so it can appear again. Media stays on device.
  func removeReports(contentID: String, kind: ContentSafetyTarget.Kind) async -> Bool {
    if isOnline { return await remoteMutation("unhide_report", payload: [(kind == .profile ? "user_id" : "target_id"): .string(contentID)]) }
    var updated = library
    var safety = updated.contentSafety ?? ContentSafetyState()
    let before = safety.reports.count
    safety.reports.removeAll { $0.contentID == contentID && $0.kind == kind }
    guard safety.reports.count != before else { return true }
    updated.contentSafety = safety
    return await commit(updated)
  }

  func blockCreator(_ creator: CreatorProfile) async -> Bool {
    guard !creator.isLocalOwner,
      creator.id.lowercased() != CreatorProfile.signedIn(library.profile).id.lowercased() else { return false }
    if isOnline { return await remoteMutation("block", payload: ["target_id": .string(creator.id), "selected": .bool(true)]) }
    guard !creator.isLocalOwner, !isBusy else { return false }
    var updated = library
    var safety = updated.contentSafety ?? ContentSafetyState()
    safety.blockedCreators[creator.id] = creator
    updated.contentSafety = safety
    updated.creatorState?.followedIDs.remove(creator.id)
    var chat = updated.chatState ?? ChatLocalState()
    var overrides = chat.followingOverrides ?? [:]
    overrides[creator.id] = false
    chat.followingOverrides = overrides
    updated.chatState = chat
    return await commit(updated)
  }

  func unblockCreator(_ id: String) async -> Bool {
    if isOnline { return await remoteMutation("block", payload: ["target_id": .string(id), "selected": .bool(false)]) }
    var updated = library
    var safety = updated.contentSafety ?? ContentSafetyState()
    safety.blockedCreators[id] = nil
    updated.contentSafety = safety
    return await commit(updated)
  }

  func saveContentReport(
    _ target: ContentSafetyTarget, reason: ContentReportReason, details: String
  ) async -> Bool {
    guard !target.creator.isLocalOwner,
      target.creator.id.lowercased() != CreatorProfile.signedIn(library.profile).id.lowercased() else { return false }
    if isOnline {
      let key = target.kind == .profile ? "user_id" : "target_id"
      return await remoteMutation("report", payload: [key: .string(target.id), "reason": .string(reason.rawValue), "details": .string(details)])
    }
    let text = details.trimmingCharacters(in: .whitespacesAndNewlines)
    lastSaveError = nil
    guard text.count <= 500,
      !text.unicodeScalars.contains(where: { $0.properties.isAlphabetic && !$0.isASCII })
    else {
      lastSaveError = "Use up to 500 characters in English."
      return false
    }
    var updated = library
    var safety = updated.contentSafety ?? ContentSafetyState()
    let existing = safety.reports.first {
      $0.contentID == target.id && $0.kind == target.kind && $0.reason == reason
    }
    let report = LocalContentReport(
      id: existing?.id ?? UUID(), contentID: target.id, title: target.title,
      kind: target.kind, creatorID: target.creator.id, creatorName: target.creator.name,
      reason: reason, details: text, savedAt: Date())
    if let index = safety.reports.firstIndex(where: { $0.id == report.id }) {
      safety.reports[index] = report
    } else {
      safety.reports.append(report)
    }
    updated.contentSafety = safety
    let saved = await commit(updated)
    if !saved, lastSaveError == nil {
      lastSaveError = "Your report could not be saved. Please try again."
    }
    return saved
  }

  func noteSaveError(_ message: String?) {
    lastSaveError = message
  }

  /// Copy new files first, commit their references atomically, then release unused app-owned copies.
  func commit(_ updated: LocalLibrary, permitsEntry: Bool = false) async -> Bool {
    if isOnline { noteSaveError("This action requires an online service operation."); return false }
    guard isLoaded, !isBusy, sessionActive || permitsEntry else { return false }
    lastSaveError = nil
    busyMessage = "Saving…"
    defer { busyMessage = nil }
    do {
      try await repository.save(updated)
      library = updated
      return true
    } catch {
      lastSaveError = message(for: error)
      return false
    }
  }

  func completeOnlineSignIn() async throws {
    guard let online else { throw BackendError.unavailable }
    let generation = online.services.generation
    try await refreshOnline()
    try online.services.check(generation)
    sessionActive = true; isLoaded = true; loadError = nil
    Task { [weak self] in
      await online.sync.start { [weak self] in try? await self?.refreshOnline() }
    }
    await online.wallet.start()
    try online.services.check(generation)
    _ = try online.services.requireAccount()
  }

  func refreshOnline() async throws {
    guard let online else { throw BackendError.unavailable }
    try await online.refresh()
    library = online.projectLibrary()
    shortsSocial.adoptRemote(online)
  }

  func endOnlineSession(notify: Bool = true) {
    online?.clear(); library = LocalLibrary(); sessionActive = false
    shortsSocial.clearAccountMemory(); wallet.clearAccountMemory()
    if notify { accountExitRevision += 1 }
  }

  func remoteMutation(_ action: String, payload: [String: AnyJSON]) async -> Bool {
    guard let online, !isBusy else { return false }
    busyMessage = "Saving online…"; defer { busyMessage = nil }
    do {
      _ = try await online.content.mutate(action, payload: payload)
      do { try await refreshOnline() } catch { notice = AppNotice(title: "Saved online", message: "Refresh to update this view.") }
      return true
    } catch { noteSaveError(error.localizedDescription); return false }
  }

  func preparedVideoURL(_ video: LocalVideo) async throws -> URL {
    guard let id = video.remoteMediaID, let online, let asset = online.assets[id] else { return videoURL(video) }
    return try await online.media.signedURL(asset)
  }

  var chatDirectory: [CommunityConversation] {
    guard let online else {
      var seen = Set<String>()
      return (CommunityChatCatalog.people + chatConversations.filter { $0.kind == .person })
        .filter { seen.insert($0.id).inserted && !isCreatorBlocked($0.creator?.id ?? $0.id) }
    }
    return online.profiles.values.filter { $0.id != online.services.accountID }.map {
      CommunityConversation(id: $0.id.uuidString, name: $0.display_name, avatars: ["BibiMark"], kind: .person,
        time: "", initialUnread: 0, initiallyPinned: false, story: nil, messages: [], creator: online.creator($0.id))
    }
  }

  var availableCircles: [InterestCircle] {
    guard let online else { return CommunityCatalog.circles }
    return online.circles.map { InterestCircle(id: $0.id, title: $0.title, subtitle: $0.subtitle, artwork: $0.artwork, prompt: $0.prompt) }
  }
  var availableChallenges: [CreativeChallenge] {
    guard let online else { return CommunityCatalog.challenges }
    return online.challenges.map { CreativeChallenge(id: $0.id, title: $0.title, category: $0.category, summary: $0.summary, artwork: $0.artwork, steps: $0.steps, exampleIndex: 0) }
  }

  private func showSaveFailure() {
    if let lastSaveError {
      notice = AppNotice(title: "Changes were not saved", message: lastSaveError)
    }
  }

  private func message(for error: Error) -> String {
    (error as? LocalLibraryError)?.errorDescription
      ?? LocalLibraryError.storageUnavailable.localizedDescription
  }
}
