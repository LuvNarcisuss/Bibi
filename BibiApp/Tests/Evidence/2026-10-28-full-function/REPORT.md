# Bibi functional acceptance — October 28, 2026

## Outcome and scope

All **31 current XCTest methods** have a passing final recorded result across
focused runs: 12 hosted unit/resource tests, 13 UI scenarios and 6 StoreKit UI
scenarios. These were not one uninterrupted green suite. Earlier failures and
interrupted runs revealed stale assertions, fixture collisions and two real UI
issues; the affected paths were corrected and rerun.

The final source was built, installed and launched on **Bibi UI Acceptance**
(`0C3DC278-7663-4B7E-9FCD-10F2FF679569`), an iPhone 17 Pro with the iOS 26.0
simulator runtime. Xcode: 26.0.1 (17A400), Debug configuration. Bundle ID and team
remain `im.seex.sao2-neiku-30` / `JPTS6M4T5B`. The backend gate stayed false.

- Repository static audit: **528 passed**, no failures.
- Asset tooling: **5 flat-asset tests + 6 remote-cache tests passed**.
- Info.plist / Xcode project syntax and `git diff --check`: passed.
- Per-method outcomes, timings and evidence logs: `test-results.json`.
- Final source hashes: `source-manifest.json`.

## Functional coverage

| Area | Executed checks | Result |
| --- | --- | --- |
| Entry and navigation | Welcome, agreement confirmation, five tabs, default Shorts, foreground return, detail/sheet navigation | Passed |
| Orientation | Rotate the device and verify all five roots retain portrait geometry | Passed |
| Shorts | Vertical swipes, play/pause interaction, like/unlike and save/unsave state changes, comments, reply submission, share/safety entry, search and creator profile | Passed |
| Circles | Discover/Joined/Saved, empty search, card/detail navigation, join/leave interactions, post creation, attachment selection/removal, bookmark persistence, reply save/delete | Passed |
| Posts | Empty-body protection, save, reopen, bookmark after relaunch, unbookmark, cancel deletion and confirmed deletion | Passed |
| Challenges | Category filters, personal entries, detail/inspiration, four saved-video choices, 100-diamond entry, free replacement, withdrawal/refund | Passed |
| Chats | Search, All/Unread/Pinned/Drafts, input, draft recovery, local pending outbox, pin/unpin, mute/unmute, group creation and local group outbox | Passed |
| Safety | Post report saved locally, report listing/removal, block confirmation/cancel, block listing and unblock | Passed |
| Profile | Category strip horizontal scrolling and section replacement, edit/save name and persistence after relaunch, settings and wallet | Passed |
| Media upload | Missing permission-confirmation and missing-media validation, system Photos selection, actual file import, relaunch persistence, private playback, unavailable published-link sharing, cancel/remove submission | Passed |
| Account | Logout retains local outbox; confirmed local deletion clears it; return to account-entry screen; fresh wallet starts at zero | Passed |
| Purchases | All seven tiers credited once, native payment-sheet cancellation, app cancellation, StoreKit cancellation, relaunch balance retention | Passed with local StoreKit Test |
| Purchase failure states | Deferred approval and simulated failure leave balance unchanged | Passed with local StoreKit Test |
| Looks | Avatar frame, profile header, chat bubble, room and cover frame; ownership, re-equipping and persisted balance | Passed |
| Wallet boundaries | Repeat unlock/charge/refund, insufficient balance, failed persistence, JSON round trip, no spend before successful save | Passed |
| Resources and typography | 171 images, bundled colors/resources, 18 catalog videos/covers decode, custom fonts, root-title artwork, agreements, creator portfolio totals | Passed |
| Accessibility/layout subset | Default/XXXL text, five-root geometry, detail/keyboard screenshots and disabled-share accessibility state | Passed for covered checks |
| Disabled backend boundary | Online services remain uninitialized; callback validation and account-cache isolation | Passed |

The call-entry and scanner screens were exercised. This establishes local UI
behavior only, not a completed call, camera acquisition or QR-decoding acceptance.

## Changes made during QA

1. The owner selected **portrait-only main screens** after a landscape screenshot
   exposed clipped player controls and crowded floating comments. The orientation
   plist and static/UI regression checks now enforce that selection. The earlier
   landscape title/navigation-only pass is superseded and is not visual acceptance.
2. A comment action card appeared behind the software keyboard. Selecting a
   comment now ends editing before presenting Reply/safety actions. Both comment
   and reply submission subsequently passed.
3. A private upload's Share control already rejected touch/published-link sharing,
   but its accessibility state still appeared enabled. It now exposes UIKit's
   `notEnabled` trait; the player regression passed.
4. Updated the obsolete 16-video assertion to 18. Reconciled two current metadata
   hashes while preserving original migration hashes; agreement revision tests now
   honor their explicit revision records.
5. Hardened test navigation for keyboard dismissal, controls partially outside the
   viewport, repeated labels, account re-entry and the system Photos picker process.
   Created uploads are selected explicitly so older QA entries cannot be removed
   in place of the current test item.

## Fixture diagnosis

The original device wallet contained historical StoreKit Test transaction IDs
`0` through `3`. Resetting StoreKit Test reused those IDs; duplicate-credit
protection correctly prevented another credit. This was a fixture conflict,
not evidence of a failed real purchase. A fresh local QA account was created
through the app's deletion flow under a verified backup. All seven crediting,
spending, cancellation, deferred/failure and challenge refund checks then passed.
No real money was charged.

## Data and environment restoration

The original Documents and Library were backed up before state-changing tests.
After testing, they were restored to the current app container. **All 12 original
files in Documents, Application Support and Preferences matched their backup
hashes**. The original wallet balance (30) and four credited transaction IDs were
preserved. See `data-restoration.json`.

Reduce Motion was temporarily enabled with the owner's permission to avoid
continuous floating-comment animations holding XCTest idle waits. It was restored
to **off**, verified in Settings. Camera permission was reset to its original
undetermined state for Bibi only. One licensed fixture video remains in the
simulator Photos library; original Photos and project video sources were not
removed or modified.

The latest installed app launched successfully with the restored original data
and normal motion settings. `restored-launch.png` records its welcome screen.

## Remaining limits and observation

- SMTP/authentication, delivered/realtime messages, remote uploads/moderation, RTC,
  server-enforced social state, Apple Sandbox and production payments were not
  accepted. The release checklist is still incomplete and the backend gate is false.
- Physical-device camera/QR decoding, audio output quality, a full VoiceOver audit,
  every text-size/device combination, memory/performance profiling and exhaustive
  storage/network fault injection were not performed. The covered scenarios do
  not establish those outcomes.
- The existing licensed red-robe clip visibly contains a Chinese wedding character
  on a fan. This does not satisfy a literal English-only media-text requirement.
  It was retained during functional QA; a crop or replacement remains a content
  cleanup item. App-authored interface copy was not translated into Chinese.

## Evidence

`test-results.json` lists all 31 method results and their exact log files. A log
may include an earlier failed sibling case; the per-method final status is the
scope of the summary. Failed/interrupted diagnostic runs are not counted as
passed suites. Selected screenshots and result bundles are retained locally under
this evidence directory. Test results do not imply backend cutover or store release.
