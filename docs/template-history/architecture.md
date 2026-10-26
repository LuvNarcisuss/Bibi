# Historical template architecture, data, and platform constraints

This English reference describes the October 23, 2026 Teto template. Bibi's current names, assets, configuration, and implementation are documented in ../IMPLEMENTATION.md.

## Project baseline

- Source: `Teto/`; project: `Teto.xcodeproj`; target/scheme/executable: `teto`; display name: Teto; bundle: `com.teto.dance`; Swift 5.0; iOS 16.0 minimum.
- `project.yml` is the configuration source: iPhone, no Mac Catalyst, portrait and both landscape orientations, UIRequiresFullScreen=true. Earlier signed artifacts containing iPad support do not establish a new tablet requirement.
- Programmatic UIKit, UIViewController/UINavigationController, Auto Layout, Combine observation of AppStore, AVFoundation playback/camera, single-selection PhotosUI imports, StoreKit 1, and WebKit agreements. Recorded local features require no third-party SDK or backend.
- No SwiftUI, SwiftUI previews, UIHostingController, or Objective-C source. Do not copy Nana branding, domains, accounts, products, or signing configuration.
- The template removes the original signing team and CI release configuration. It is not a signed IPA. Generating Xcode metadata is not building the app.

## Startup and state ownership

`TetoAppDelegate → TetoSceneDelegate → TetoCoordinator → EntryController → TetoTabController`. Install a real, nonempty root controller before loading and fill the window background. Loading completion and agreement acceptance are separate. Account logout increments a revision to rebuild the entry flow.

MainActor `AppStore` owns LocalLibrary, ShortsInteractionStore, WalletStore, and VideoViewingHistory. UIKit subscribes through Combine instead of recreating stores on render. Actor repositories centralize persistence. Publish UI success only after saving. Refreshes must not rebuild an active report form or player.

Each tab has an independent navigation stack. Child controllers use the complete containment lifecycle. Dock, comment overlays, and full-screen presentations have separate ownership. Popovers and child views are not new roots. Activate cross-view constraints only after both views share an ancestor; a previous welcome-art crash violated this rule.

## Identity and models

| Model/key | Required meaning |
|---|---|
| LocalVideo.id UUID | Stable across all entry points; never derived from position or title |
| DanceVideo.surface | Unique Live or Shorts assignment; 39 template items without sharing one catalog entry between feeds |
| LocalVideo.isDance: Bool? | nil means older unclassified private video; true is classification, not moderation approval |
| creatorID | Built-in `pexels:<creator>` and private `local-owner`; do not infer a real account from a photograph |
| CreatorLocalState | Follow state, creator drafts, and conversation records; optional for older libraries |
| ChatLocalState | Existing read/unread, pin/mute, hidden, drafts, sentMessages, followingOverrides, followerIDs, and groups fields |
| creator-chat:<creatorID> | Canonical creator conversation across routes; unknown incoming follow is false |
| ContentSafetyTarget | kind+contentID identifies content; creatorID identifies a block target; nickname is not identity |
| CreationSubmission | live/shortVideo and awaitingSubmission; only real services advance status |
| WalletLedger | diamonds, activity, creditedTransactionIDs; schemaVersion 1 and idempotent transactions |
| savedDemoVideoIDs | Preserve this legacy serialized key despite its name; never expose it in UI |

Small editorial statistics use fixed ID hashes so relaunches are stable. Do not randomize each refresh or present them as real online counts or source-platform metrics. Creator Likes/Saves sum shared work counts. The owner's Following uses actual local follows; Followers is zero without a source.

## Local storage

Default directory: `Application Support/Teto/`. Use `completeUntilFirstUserAuthentication` protection and atomic JSON writes.

| File/directory | Contents |
|---|---|
| library-v1.json | Profile, imported videos, saved IDs, room drafts, chats, creators, safety, consent, submissions |
| shorts-interactions-v1.json | Likes, comments/replies, completedShares, legacy bonusLikes, separate liveLikes |
| video-viewing-history.json | UUID to last-viewed time, capped at 2,000; separate actor reduces contention |
| wallet-v1.json | Diamond balance, activity, credited transaction IDs |
| Media/UUID.ext and UUID.jpg | App-owned imports, covers, and submission covers |
| Media/profile-avatar.jpg | Profile photo; a next temporary file and ordered saves support failure recovery |

Missing files may initialize empty state. Parsing failure, unsupported versions, duplicate IDs, invalid relationships, or invalid ledgers preserve originals and block writes rather than silently resetting. Corrupt viewing history must not trigger deletion of other data.

Migration within the same sandbox moves an old app directory only when exactly one readable, format-compatible library candidate exists. Multiple or unreadable candidates stop migration. Different bundle IDs have different containers; automatic cross-ID migration is not promised.

Copy provider files while temporary URLs are valid. Check video tracks, duration, and size. Write media before the library, and remove only newly created copies on failure. Orphan cleanup runs only after a successful library read, only inside app-owned Media, and only for UUID filenames with allowed extensions. Preserve avatar temporary files and media referenced by old private features. Never scan or delete Photos, external libraries, or arbitrary Design originals.

Read-only legacy Phrases models, catalog validation, and media-reference protection remain for compatibility. No creation/practice business logic, videos, or screens remain. Excluding Phrases must not erase private JSON fields, reports, or media. Old reports can be removed in Settings without restoring the feature.

## Text and input validation

Default localization is English: developmentLanguage, CFBundleDevelopmentRegion, CFBundleLocalizations=['en'], and permission descriptions. System keyboards, Photos, and share sheets follow the device language.

`CreationValidation.isEnglish` rejects non-ASCII letters while allowing digits and punctuation. It is not semantic language detection. Apply validation at UI and persistence boundaries with English errors. Preserve existing private data. Define explicit filtering for future service data.

| Input | Limit |
|---|---|
| Profile name / biography | 30 / 160 characters |
| Creation title / caption | Required title up to 80 / caption up to 500 |
| Voice title / description | Required title up to 60 / description up to 240; capacity 4/6/8 |
| Live input / Shorts floating comment | 50 / 80 English characters |
| Video comment / Voice message | 200 English characters; 500 persistent comments per Shorts video |
| Individual message/draft | 2,000 characters; recheck relationship and English on send |
| Report details | 500 characters |
| New Shorts submission | 180 seconds / 250 MB |
| Legacy private-video import | 30 minutes / 250 MB; not the new Shorts submission limit |
| Image import | 30 MB, decodable, downsampled with aspect ratio preserved |

## Media lifecycle

Stable objects own AVPlayer instances and observers. Use resizeAspectFill at normal speed without rewriting timestamps. Live may continue beneath permitted overlays; Shorts pauses beneath overlays; cards loop only the first second while visible. Stop tasks on departure, backgrounding, or failure. Cancelled callbacks cannot restart departed players. Prevent overlapping background audio.

Floating comments, hearts, speaking bars, and layout updates remain independent of playback. Use table/visible-card resource management and explicit history limits. Reduce Motion removes continuous drifting and spring effects. VoiceOver controls have English labels/values and alternative actions.

Request camera access only after user action on video-call or scanner screens. There is no microphone capture or invented microphone usage permission. PHPicker does not request whole-library access. Preserve camera flipping, authorization errors, interruptions, foreground recovery, and iOS 16 orientation fallback.

## Future service integration

Add adapters at existing state/repository boundaries for identity/profiles, paginated feeds, live playback/broadcasting, RTC, IM/relationships, moderation/reports, and wallet verification. Servers must authorize relationships, moderation status, and balances. Define migrations explicitly. A request for equivalent local functionality does not authorize cloud account creation, invented hosts, review submission, or CI execution.
