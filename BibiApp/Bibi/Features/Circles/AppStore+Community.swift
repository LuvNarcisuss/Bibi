import Foundation
import UIKit

extension AppStore {
  var community: CommunityState { library.community ?? CommunityState() }

  func circlePosts(in circleID: String? = nil, savedOnly: Bool = false) -> [CirclePost] {
    (community.posts + CommunityCatalog.prompts).filter {
      (circleID == nil || $0.circleID == circleID)
        && (!savedOnly || community.savedPostIDs.contains($0.id))
        && !isCreatorBlocked($0.author.id)
        && !isContentReported($0.id.uuidString, kind: .circlePost)
    }.sorted { $0.createdAt > $1.createdAt }
  }

  func circleReplies(for postID: UUID) -> [CircleReply] {
    community.replies.filter {
      $0.postID == postID && !isCreatorBlocked($0.author.id) && !isCommentReported($0.id.uuidString)
    }.sorted { $0.createdAt < $1.createdAt }
  }

  func communityVideo(_ id: UUID) -> LocalVideo? {
    collectionVideos.first {
      $0.id == id && $0.bundledClip?.surface != .live && !hidesVideo($0, live: false)
    }
  }

  var eligibleChallengeVideos: [LocalVideo] {
    library.videos.filter { $0.duration > 0 && $0.duration <= 180 && !hidesVideo($0, live: false) }
  }

  func toggleCircle(_ id: String) async -> Bool {
    guard CommunityCatalog.circles.contains(where: { $0.id == id }) else { return false }
    var state = community
    if !state.joinedCircleIDs.insert(id).inserted { state.joinedCircleIDs.remove(id) }
    return await saveCommunity(state)
  }

  func togglePostSaved(_ id: UUID) async -> Bool {
    guard circlePosts().contains(where: { $0.id == id }) else { return false }
    var state = community
    if !state.savedPostIDs.insert(id).inserted { state.savedPostIDs.remove(id) }
    return await saveCommunity(state)
  }

  func createCirclePost(circleID: String, body: String, photo: Data?, videoID: UUID?) async -> Bool
  {
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
        videoID: videoID), at: 0)
    return await saveCommunity(state)
  }

  func deleteCirclePost(_ id: UUID) async -> Bool {
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
    guard community.replies.contains(where: { $0.id == id && $0.author.isLocalOwner }) else {
      return false
    }
    var state = community
    state.replies.removeAll { $0.id == id }
    return await saveCommunity(state)
  }

  func enterChallenge(_ challengeID: String, videoID: UUID) async -> Bool {
    guard CommunityCatalog.challenges.contains(where: { $0.id == challengeID }),
      eligibleChallengeVideos.contains(where: { $0.id == videoID })
    else {
      noteSaveError("Choose one of your own videos, up to three minutes long.")
      return false
    }
    var state = community
    let existingID = state.entries.first { $0.challengeID == challengeID }?.id ?? UUID()
    state.entries.removeAll { $0.challengeID == challengeID }
    state.entries.insert(
      ChallengeEntry(id: existingID, challengeID: challengeID, videoID: videoID), at: 0)
    return await saveCommunity(state)
  }

  func withdrawChallenge(_ challengeID: String) async -> Bool {
    var state = community
    state.entries.removeAll { $0.challengeID == challengeID }
    return await saveCommunity(state)
  }

  private func saveCommunity(_ state: CommunityState) async -> Bool {
    var updated = library
    updated.community = state
    return await commit(updated)
  }
}
