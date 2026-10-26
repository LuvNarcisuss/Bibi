# Community revision run verification

Date: 2026-10-26 (Asia/Shanghai).

The owner explicitly authorized compilation, simulator launch, interactive checks of all five modules and direct fixes. The owner separately approved the bundled agreements for this simulator test only.

## Environment and result

- Xcode 26.0.1; Debug; scheme Bibi; iOS 26.0.1 / iPhone 17 Pro.
- Dedicated simulator: Bibi QA, `6AF30F68-29BB-4CFD-91FF-24CD39712A4A`.
- Bundle ID: `im.seex.sao2-neiku-30`; project signing team remains `JPTS6M4T5B`.
- Final build: `BUILD SUCCEEDED`, exit 0, with `CODE_SIGNING_ALLOWED=NO` for Simulator only. The sole build warning was skipped AppIntents metadata extraction because the app has no AppIntents dependency.
- Static audit: 426 checks passed, zero failures.
- Latest build installed and launched. Core flows across all five modules were exercised through Simulator UI and a device-specific browser mirror.
- Test content consists of local English QA text and the bundled Little Companion image/video. No remote messages, posts or challenge submissions were sent.

## Findings fixed and rechecked

1. A missing shared search component prevented compilation. Restored `ExpandingSearchBar` in its own DesignSystem file and regenerated project metadata. Subsequent builds succeeded; Shorts and Chats search were exercised.
2. Search remained over a conversation after selecting a result. Reproduced with a Maya search. Screens now immediately dismiss search when leaving. Retest showed no search field or overlay in the conversation; returning restored the unfiltered inbox. Switching from Shorts search to Chats also removed the overlay.
3. Uploaded videos displayed generic copy instead of their saved caption. The player now reads the associated submission caption, with the existing fallback for an empty caption. The saved QA caption appeared during challenge playback after reinstall/relaunch.
4. Video reaction counters exposed only number labels to accessibility. Each counter is now one named button with a value. Simulator accessibility exposed Like, Comments, Save and Share; opening Comments and saving a local comment succeeded.
5. A single discussion reply displayed `1 replies`. The label now uses `reply` for one and `replies` for other counts. This copy fix was source-checked and compiled.

A read-only reviewer checked the focused changes, identified item 2, and rechecked its fix without finding another concrete regression.

## Observed interaction coverage

| Module | Executed checks and observed results |
| --- | --- |
| Shorts | Moving video frames; like and save counts changed; comment sheet opened and closed without dock overlap; a local comment appeared and the count increased; search for Companion changed the result; switching tabs closed search. |
| Circles | Scrolled discovery, opened Animation Club, joined, composed an English post, imported the bundled image through Photos, saved the post, bookmarked it, saved a reply and followed the author route back. The detail list showed the post and one reply. Me's saved-post route showed the bookmark. |
| Challenges | Animation filter reduced the list; detail displayed the brief and local-only status; imported the bundled 16-second video, set title/caption and content declaration, saved an entry, played it and opened history from Me. Entry and caption survived relaunch. The local/unpublished share action did not open a share sheet. |
| Chats | Opened Maya, saved Local QA message, observed Pending and the updated inbox preview, relaunched and observed the saved preview. Searched Maya, opened the result, verified the search layer was gone, and returned to the complete inbox. |
| Me | Correct joined-circle/challenge counts, liked/saved counts, saved-post route, challenge history/manage route, and Uploads with saved title/caption and Waiting to submit. |
| Persistence | Terminated and installed newer builds without uninstalling. Re-entered the test session; community counts, bookmarks, like/save counts, challenge video and chat message remained available. |

## Evidence

Screenshots are flat files in the repository-root `Assets/` directory, named `run-Community-` followed by each filename below:

- `circle-discussion.png`: saved post, image and reply flow.
- `challenge-playback.png`: final uploaded caption and local/unpublished status.
- `chat-pending.png`: local message pending delivery.
- `chat-search-fixed.png`: unobstructed conversation after opening a search result.
- `me-history.png` and `me-uploads.png`: community counts and upload management.

Build log: `/private/tmp/bibi-community-final-build.log`. Simulator error capture: `/private/tmp/bibi-qa-final-errors.log`. No Bibi crash report or matching uncaught-exception / Auto Layout conflict signature was found in inspected evidence. Simulator system audio, haptic, text-input and signing diagnostics were present; this does not claim empty runtime logs.

## Limits

This is tool-driven manual UI verification on one simulator configuration, not an automated XCTest suite or exhaustive acceptance matrix. Payment, account deletion, remote services, real delivery/moderation, voice/video calls, storage-failure injection, all permission-denial paths, challenge withdrawal/replacement, profile editing, Dynamic Type and physical-device behavior were not validated. Local-only labels are intentional because no backend is configured.

Another task was using the original simulator window. A dedicated Bibi QA device and scoped mirror isolated this run. The mirror is stopped after verification; the installed app and dedicated simulator are retained for inspection.
