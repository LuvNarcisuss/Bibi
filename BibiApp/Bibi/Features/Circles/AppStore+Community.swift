import Foundation
import UIKit

extension AppStore {
  var community: CommunityState { library.community ?? CommunityState() }

  func circlePosts(in circleID: String? = nil, savedOnly: Bool = false) -> [CirclePost] {
    (community.posts + (isOnline ? [] : CommunityCatalog.prompts + CommunityCatalog.storyPosts)).filter {
      (circleID == nil || $0.circleID == circleID)
        && (!savedOnly || community.savedPostIDs.contains($0.id))
        && !isCreatorBlocked($0.author.id)
        && !isContentReported($0.id.uuidString, kind: .circlePost)
    }.sorted { $0.createdAt > $1.createdAt }
  }

  func creatorPosts(for creatorID: String) -> [CirclePost] {
    circlePosts().filter { $0.author.id == creatorID }
  }

  /// Authored story baselines are local fiction; real accounts use recorded counts.
  func circlePostCounts(for post: CirclePost) -> (likes: Int, saves: Int) {
    if let online {
      let counts = online.counts[post.id]
      return (counts?.likes ?? 0, counts?.saves ?? 0)
    }
    let seed = post.id.uuidString.utf8.reduce(UInt64(14695981039346656037)) {
      ($0 ^ UInt64($1)) &* 1099511628211
    }
    let isAuthored = post.isCharacterStory || post.isEditorial
    let likes = isAuthored ? 10 + Int(seed % 17) : 0
    let saves = isAuthored ? 8 + Int((seed >> 8) % 13) : 0
    return (likes, saves + (community.savedPostIDs.contains(post.id) ? 1 : 0))
  }

  func circleReplies(for postID: UUID) -> [CircleReply] {
    (community.replies + (isOnline ? [] : CommunityCatalog.storyReplies)).filter {
      $0.postID == postID && !isCreatorBlocked($0.author.id) && !isCommentReported($0.id.uuidString)
    }.sorted { $0.createdAt < $1.createdAt }
  }

  func communityVideo(_ id: UUID) -> LocalVideo? {
    collectionVideos.first {
      $0.id == id && $0.bundledClip?.surface != .live && !hidesVideo($0, live: false)
    }
  }

  var eligibleChallengeVideos: [LocalVideo] {
    library.videos.filter { (!isOnline || $0.remoteCreator?.isLocalOwner == true) && $0.duration > 0 && $0.duration <= 180 && !hidesVideo($0, live: false) }
  }

  func toggleCircle(_ id: String) async -> Bool {
    if isOnline { return await remoteMutation("circle", payload: ["circle_id": .string(id), "selected": .bool(!community.joinedCircleIDs.contains(id))]) }
    guard CommunityCatalog.circles.contains(where: { $0.id == id }) else { return false }
    var state = community
    if !state.joinedCircleIDs.insert(id).inserted { state.joinedCircleIDs.remove(id) }
    return await saveCommunity(state)
  }

  func togglePostSaved(_ id: UUID) async -> Bool {
    if isOnline { return await remoteMutation("save", payload: ["target_id": .string(id.uuidString), "selected": .bool(!community.savedPostIDs.contains(id))]) }
    guard circlePosts().contains(where: { $0.id == id }) else { return false }
    var state = community
    if !state.savedPostIDs.insert(id).inserted { state.savedPostIDs.remove(id) }
    return await saveCommunity(state)
  }

  func createCirclePost(circleID: String, body: String, photo: Data?, videoID: UUID?) async -> Bool
  {
    if let online {
      do {
        let mediaID: UUID?
        if let photo { mediaID = try await online.media.uploadImage(photo) } else { mediaID = nil }
        _ = try await online.content.publish(kind: "post", body: body, circle: circleID, media: mediaID, video: videoID)
        try? await refreshOnline(); return true
      } catch { noteSaveError(error.localizedDescription); return false }
    }
    let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard community.joinedCircleIDs.contains(circleID),
      CommunityCatalog.circles.contains(where: { $0.id == circleID })
    else {
      noteSaveError("Join this circle before adding a post.")
      return false
    }
    guard !text.isEmpty, text.count <= 1000, CreationValidation.isEnglish(text) else {
      noteSaveError("Write a post in English using 1–1,000 characters.")
      return false
    }
    guard community.posts.count < 100,
      photo == nil || (photo!.count <= 1_000_000 && UIImage(data: photo!) != nil)
    else {
      noteSaveError("Keep up to 100 posts and choose a smaller photo.")
      return false
    }
    guard videoID == nil || communityVideo(videoID!) != nil else {
      noteSaveError("This video is no longer available. Choose another video.")
      return false
    }
    var state = community
    state.posts.insert(
      CirclePost(
        circleID: circleID, author: .signedIn(library.profile), body: text, photo: photo,
        videoID: videoID, coverStyleID: wallet.snapshot.cosmetics.coverTemplateID), at: 0)
    return await saveCommunity(state)
  }

  func deleteCirclePost(_ id: UUID) async -> Bool {
    if isOnline { return await remoteMutation("withdraw", payload: ["target_id": .string(id.uuidString)]) }
    guard community.posts.contains(where: { $0.id == id && $0.author.isLocalOwner }) else {
      return false
    }
    var state = community
    state.posts.removeAll { $0.id == id }
    state.replies.removeAll { $0.postID == id }
    state.savedPostIDs.remove(id)
    return await saveCommunity(state)
  }

  func addCircleReply(postID: UUID, text: String) async -> Bool {
    if let online {
      do { _ = try await online.content.publish(kind: "reply", body: text, parent: postID); try? await refreshOnline(); return true }
      catch { noteSaveError(error.localizedDescription); return false }
    }
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, text.count <= 500, CreationValidation.isEnglish(text) else {
      noteSaveError("Write a reply in English using 1–500 characters.")
      return false
    }
    guard circlePosts().contains(where: { $0.id == postID }), community.replies.count < 2000 else {
      noteSaveError("This discussion is unavailable or your local reply limit has been reached.")
      return false
    }
    var state = community
    state.replies.append(
      CircleReply(postID: postID, author: .signedIn(library.profile), text: text))
    return await saveCommunity(state)
  }

  func deleteCircleReply(_ id: UUID) async -> Bool {
    if isOnline { return await remoteMutation("withdraw", payload: ["target_id": .string(id.uuidString)]) }
    guard community.replies.contains(where: { $0.id == id && $0.author.isLocalOwner }) else {
      return false
    }
    var state = community
    state.replies.removeAll { $0.id == id }
    return await saveCommunity(state)
  }

  func enterChallenge(_ challengeID: String, videoID: UUID) async -> Bool {
    if isOnline { return await remoteMutation("challenge", payload: ["target_id": .string(videoID.uuidString), "challenge_id": .string(challengeID)]) }
    guard CommunityCatalog.challenges.contains(where: { $0.id == challengeID }),
      eligibleChallengeVideos.contains(where: { $0.id == videoID })
    else {
      noteSaveError("Choose one of your own videos, up to three minutes long.")
      return false
    }
    let alreadyEntered = community.entries.contains { $0.challengeID == challengeID }
    if !alreadyEntered, let error = await wallet.payForChallenge(challengeID) {
      noteSaveError(error)
      return false
    }
    var state = community
    let existingID = state.entries.first { $0.challengeID == challengeID }?.id ?? UUID()
    state.entries.removeAll { $0.challengeID == challengeID }
    state.entries.insert(
      ChallengeEntry(id: existingID, challengeID: challengeID, videoID: videoID), at: 0)
    let saved = await saveCommunity(state)
    if !saved, !alreadyEntered { _ = await wallet.refundChallenge(challengeID) }
    return saved
  }

  func withdrawChallenge(_ challengeID: String) async -> Bool {
    if isOnline { return await remoteMutation("challenge", payload: ["challenge_id": .string(challengeID), "selected": .bool(false)]) }
    var state = community
    state.entries.removeAll { $0.challengeID == challengeID }
    guard await saveCommunity(state) else { return false }
    if let error = await wallet.refundChallenge(challengeID) { noteSaveError(error) }
    return true
  }

  private func saveCommunity(_ state: CommunityState) async -> Bool {
    var updated = library
    updated.community = state
    return await commit(updated)
  }
}
