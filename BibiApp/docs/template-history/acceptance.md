# Historical template acceptance and known limits

This is an English rendering of the Teto template snapshot dated October 23, 2026. It is historical reference, not Bibi's current acceptance record. Bibi's current implementation and verification are documented in the parent directory.

The template task allowed static inspection only: read files, parse JSON/plist/XML, compare source references and hashes, and inspect configuration. XcodeGen metadata generation was not a build. Compilation, typechecking, app/simulator/preview execution, and unit/integration/UI tests required explicit authorization.

## Static delivery checklist

- [ ] Skill frontmatter and references exist; archive SHA-256 and per-file manifest match; videos are not LFS pointers.
- [ ] Four tabs: Live/Voice/Chats/Me; Shorts is inside Live. Dock divisions and indices use four items. No Phrases pages, profile entry, or chat open action.
- [ ] iOS 16, Swift 5, UIKit/AVFoundation; no SwiftUI, hosting controllers, or Objective-C source. project.yml agrees with pbxproj.
- [ ] 39 dance videos and matching covers; catalog IDs/assets/surfaces are unique. No Phrases videos or unrelated video themes.
- [ ] New copy, default data, permissions, accessibility text, agreements, and visible resource text satisfy the English and prohibited-word rules. Review API names and compatibility fields separately.
- [ ] Live uses a list-to-room flow, first-second card loops, full-screen normal-speed looping, and no progress bar. Shorts has independent playback, comment, and sharing behavior.
- [ ] UIKit Live adds 1–3 comments per second, accepts 50 characters, and shows at most seven bubbles. Shorts attempts 1–5 per second at 96 pt/s with 80-character input. Voice adds 1–3 every 1–2 seconds and caps history at 200.
- [ ] Likes/saves/comments/replies share stable video IDs across Shorts, saved videos, creators, and Me. Live likes do not enter Liked. Counts and displayed lists use the same source.
- [ ] Failed saves preserve drafts and reply targets. Reports hide only their targets. No false success. List refreshes do not recreate players.
- [ ] Live/Shorts/Voice offer friend sharing and internal URL copying. Chat video opening revalidates surface, classification, blocks, and submission state. Internal URLs are not public links.
- [ ] Mutual follows allow unlimited local messages; other individual chats allow one greeting; groups are exempt, activity is read-only, and blocked recipients cannot receive messages. Nonmutual profiles hide Message; existing conversations remain accessible.
- [ ] Group avatars use member collages. Individual portraits remain consistent and unique; built-in Voice membership does not overlap between rooms.
- [ ] Creation opens a form before media selection. Submissions appear in Me. Shorts limits are three minutes and 250 MB. No fabricated broadcasting or approval.
- [ ] Settings has profile editing, both agreements, blocks, reports, logout, and deletion. Corrupt files are not overwritten. Photos originals are retained.
- [ ] Nine StoreKit tiers map correctly. Wallet starts at zero, credits transactions idempotently, and finishes only after saving. Insufficient funds leave balance unchanged; gifts only deduct locally and show effects. No coins or message fees.
- [ ] Camera is limited to video-call and scanner screens; preserve iOS 16 orientation fallback, permission recovery, and background/exit shutdown. No fabricated RTC/IM or microphone capture.
- [ ] Consent starts unchecked; reading a link is not acceptance. Navigation follows successful saving. Network agreement failure can fall back locally; historical private URLs are not claimed public.
- [ ] Fonts, logo, transparent icons, resources, and source references are complete. Shared scheme is included; no signing credentials or personal CI notification accounts.
- [ ] Delivery distinguishes implemented source, static evidence, missing services, and unperformed runtime validation. No release-readiness claim.

## Known limits

1. No backend exists for broadcasting, RTC, IM delivery, remote relationships/profiles, publication, moderation, or reports.
2. StoreKit source exists, but product availability, signing, real transactions, and ledger failure recovery were not runtime-verified.
3. Voice gift-recipient selection does not reach a ledger or remote service. Voice shared URLs lack the video chat open action.
4. Single-chat call buttons have no additional mutual-follow authorization. A Tati formatting example must not be treated as Teto call behavior.
5. English validation checks character ranges rather than language semantics. Dance classification is a user declaration rather than visual moderation.
6. Historical Google agreements require public-access confirmation; HTTP 200 permission pages may evade fallback detection.
7. Static assets and earlier representative-frame reviews do not prove current playback, layout, gestures, camera behavior, Dynamic Type, or memory performance.
8. The four-tab template after Phrases removal had only static reference/resource inspection, not a build or device run.

## Runtime scenarios after explicit authorization

Verify first-launch consent, offline fallback, corrupt data, Live navigation/backgrounding, Shorts replies/sharing/saves/rapid likes/relaunch, Voice seats/input/replies/invites, nonmutual message limits, follow changes, group collages, scanner denial, report removal, photo cancellation/failure, StoreKit success/cancellation/deferred/duplicates/save failure, and account deletion with Photos originals preserved. Record actual results; running a command alone is not a passing result.
