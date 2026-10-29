# Static audit — Bibi

## Bundle identity replacement — October 29, 2026

The owner selected `com.bibi.quadratic`, superseding the automatically generated
identifier `im.seex.bibi.cdf0e231` and replacing
`im.seex.sao2-neiku-30`. The generation specification, Debug/Release project settings,
four test target identities, authentication URL type name, local Apple purchase
verification source and identity audit expectations use the new identifier.
The signing team `JPTS6M4T5B`, schemes, application name, nine product IDs and
`BibiBackendEnabled=false` are preserved.

The Keychain service string retains the previous namespace as a storage
compatibility identifier. The callback/recovery URL scheme remains `bibi`.
Historical acceptance reports retain the identity of the binary actually checked.
No installed app or private state was modified. A new Bundle ID uses a separate
application container; this change does not migrate existing device data or
guarantee access to the previous application's Keychain access group.

Apple registration, signing, store product availability and cloud redeployment
remain pending; see `BibiApp/Backend/RELEASE-CHECKLIST.md`. Verification for this
revision passed 543 static source/configuration/resource checks, plist/project
syntax inspection and whitespace inspection. No build,
typecheck, installation, launch, simulator, preview or runtime tests were run.


## Entry constraint hierarchy fix — October 29, 2026

543 static checks pass, including a new guard requiring the entry logo container
to join the stack before its cross-view constraints activate. Manual source review
covered 108 direct activation sites and shared pinning helpers; no additional
instance of the same ordering defect was found. Plist/project syntax and whitespace
inspection pass.

The final targeted simulator run passed five tests with zero failures on Bibi UI
Acceptance, using a build from the current workspace. The installed executable was
matched to that build; the four original private state files were restored and
verified after relaunch. This does not extend to every detail branch, real backend
or payment acceptance. See the
[runtime evidence](../BibiApp/Tests/Evidence/2026-10-29-layout-order/REPORT.md).

## Owner-provided logo and entry refresh — October 28, 2026

542 static checks pass with zero failures. New resource checks compare the app
icon's RGB pixels with the archived owner source, verify all current brand hashes,
confirm both in-app marks match, inspect the launch storyboard and its Info.plist
selection, and check the entry hero's source, square proportions and bounded width.
The asset catalog was regenerated, the launch storyboard is in the Xcode resource
phase, and plist/project syntax and whitespace inspection pass. Packaging retains
the approved logo source. This is static evidence only; compilation, typechecking,
installation, launch, simulator, preview and runtime tests were not performed.

## Nine diamond purchase tiers — October 28, 2026

The owner approved 16,800 diamonds at reference USD 29.99 and 42,700 diamonds at
reference USD 69.99, with two newly generated 16-letter lowercase product IDs.
The original seven IDs, quantities and prices are unchanged. WalletCatalog now
fills the existing three-column layout with three complete rows. Info.plist,
the local StoreKit fixture, the product preparation CSV and existing purchase UI
coverage reflect all nine tiers. Prices and availability still come from StoreKit;
an unavailable new product cannot start payment.

Static verification passed 536 source/configuration/resource checks. The original
seven mappings and fixture records were compared with the pre-change files.

The supplemental `BibiApp/Backend/wallet-products.sql` source is prepared but not
deployed. It adds only the two mappings and rejects conflicts without modifying
existing products, balances or transactions. App Store Connect creation is still
pending. `BibiBackendEnabled=false` is retained. This revision has no compilation,
typecheck, installation, simulator launch or runtime transaction verification.

## Guest authentication — October 28, 2026

The owner selected the Toti conversation's one-tap guest approach, replacing
email/password as the normal entry method. Bibi reuses its original illustrated
entry screen, one agreement checkbox and confirmation sheet. Online entry uses
`Log in`; the declaration explicitly includes 18+. Bibi's own agreement sources,
assets, identity, local data and empty-personal-account rules remain unchanged.

`BackendServices.signInAsGuest` verifies Keychain access before creating an
anonymous Supabase session, reuses an existing session when enrollment is retried,
and enters only after server enrollment and snapshot loading succeed. Existing
restore logic preserves the account across relaunch. Guest logout warns about
irrecoverable access loss. Guest deletion requires explicit confirmation without
a password and retains the session during interrupted media cleanup. Existing
email recovery links remain available for earlier email accounts.

Cloud evidence: `bibi_guest_auth` migration `20261028090404` is applied;
`delete-account`, `media-finalize`, and `verify-purchase` are ACTIVE version 2
with JWT verification retained. Auth settings returned
`external.anonymous_users=true`; email confirmation remains enabled for email
accounts. No accounts were created or deleted during this configuration work.

SQL readback confirms guest eligibility still checks live Auth sessions and adult
consent. All public Bibi tables retain RLS. The security advisor reports 27
anonymous-access warnings after enabling this intended authentication method;
they are not a clean-advisor result or proof of cross-account safety. The six
private-table policies were inspected and all retain `USING (false)`. Public and
Storage ownership policies still require live-session ownership/membership.
See [Supabase advisor guidance](https://supabase.com/docs/guides/database/database-advisors?queryGroups=lint&lint=0012_auth_allow_anonymous_sign_ins).

Verification: 532 static checks and whitespace inspection passed. A Keychain
round-trip regression was authored but not executed. This revision has not been
compiled, installed or runtime-tested; earlier runtime reports do not cover it.
Real guest creation, enrollment, relaunch, isolation and interrupted deletion
need end-to-end acceptance. Keep `BibiBackendEnabled=false`; the installed app
has not been switched to cloud login. SMTP is not a guest-login dependency.

## Conditional Chats filters — October 28, 2026

532 static audit checks and whitespace inspection pass. Source inspection confirms
filter visibility follows the existing group-eligible friend relationship, rather
than community directory size or conversation count. The hidden state resets All
and switches the inbox top constraint to the safe-area top. Store refreshes update
both directions. No compilation, typecheck, launch or runtime check was performed.

## Composed Chats empty state — October 28, 2026

532 static audit checks and whitespace inspection pass. Source inspection confirms
the welcome card uses existing bundled raster assets and calls the existing friend,
group and scanning/invitation screens. Empty search/filter states can restore the
All filter. Empty content has a fixed viewport width, scrollable height and a
keyboard/safe-area bottom boundary above the dock. No personal or community data
was added or changed for this UI revision. Dynamic Type, VoiceOver, card taps and
small-phone appearance still need runtime verification; no compilation, typecheck,
app launch or simulator execution was requested or performed.

## Empty personal account — October 28, 2026

532 static checks pass, including guards against launch-time personal video
installation, authored relationships and chat transcripts, and a fictional default
personal identity. Community catalogs remain populated. The acceptance device's
personal app data was backed up and cleared offline; wallet bytes were unchanged.
The new empty-account regression is unexecuted. Earlier 31-case runtime acceptance
is historical for this revision, and its seeded-data UI cases need explicit QA
fixtures. No compilation, typecheck, launch or runtime test was requested or run.
See the current entry in `IMPLEMENTATION.md` for scope and deployment limits.

## Full-function acceptance — October 28, 2026

528 static checks, both plist/project syntax checks and whitespace inspection pass.
All 11 Python asset-tooling tests pass. The latest recorded result for every one
of the 31 current XCTest methods is passing across focused runs on Bibi UI Acceptance.
Earlier failed and interrupted suites are diagnostic history; they are not counted
as passed suites. The final source received focused runtime regressions for the
portrait lock, comment keyboard obstruction and private-share accessibility state.

See [the acceptance report](../BibiApp/Tests/Evidence/2026-10-28-full-function/REPORT.md)
for exact case coverage, logs, screenshots, original-data restoration and the
remaining online/device/content limitations. Backend cutover remains disabled.

## Portrait-only interface — October 28, 2026

The owner selected portrait-only main screens. The Info.plist direction array
contains `UIInterfaceOrientationPortrait` only; a direct plist assertion passed.
Landscape title/navigation assertions from the earlier run are superseded: those
checks did not establish that the complete player layout fit. The updated runtime
test checks portrait geometry after device rotation and has passed for all five roots.

## Profile home categories — October 28, 2026

Profile looks stays on Edit profile, reached from Settings. Wallet remains on Me.
Joined circles and challenge entries are categories beside Liked and Saved.
Their labels are Circles and Challenges. Saved circle posts are listed in Saved
with saved videos, in the same two-column cover tiles. Works and other profiles
still list posts as full cards. The separate Saved circle posts button is gone. The category
bar scrolls with the page until it reaches the top, then stays there. Its
controls stay in that scrolling layout until the bar pins, so they are visible
the first time Me opens. Choosing a category replaces only the section below
the bar.

## Two-column circle and challenge home — October 28, 2026

Discover, Joined, and Saved on Circles, and the challenge list on Challenges,
place their cards in two equal columns. Covers stay square inside each card.
Titles and summaries use fewer lines, and card padding is tighter. Home-card
actions use a shorter 12-point button. Detail screens stay a single column. No compilation or simulator check was run for
this layout change.

## Photographic challenge and circle covers — October 28, 2026

Challenge list covers, the Challenges banner and the Circles banner now use licensed
Pexels cosplay photographs. Circle covers and all fourteen authored posts use the
same kind of photograph, including the three cosplay stills already in the catalog.
Generated room illustrations, film stills, sketch photographs and art-supply
photographs are no longer the covers or post images on these pages. Room
illustrations remain in the catalog for other existing references. Circle and
challenge list covers stay rounded and crop with aspect fill. Each list cover
is square, so its height matches its current width.

Post and reply text now describes the photograph on that post. Story IDs are
unchanged. Depicted people are credited in Settings and are not represented as
the fictional authors. Sources, hashes and dimensions are in
`Assets/cosplay-cover-provenance.json`. The local catalog is what the app shows
while the backend gate is false. The unpublished circle and challenge seed in
`BibiApp/Backend/hardening.sql` names the same assets and has not been deployed.

Static file inspection passed 527 checks, including the new catalog links and
image files. No Swift compilation, typecheck, simulator, app launch or runtime
visual verification was performed for this revision.

Four licensed Pexels clips are copied once into the personal library on launch
when their stable IDs are absent: Red robe and gold headdress, Gold kimono in
the smoke, Chainsaw mask at the expo, and Pink wig by the window. They are not
Shorts catalog entries. Sources are in `Assets/saved-shorts-provenance.json`.
The challenge picker lists them after the app is rebuilt and opened again.

## Safety, cosplay media and starlight surfaces — October 27, 2026

This revision supersedes earlier post-gifting behavior and earlier media counts.
Circle post cards and discussions no longer offer gifts. Compatibility wallet
entry points reject gift spending without mutating balances or historical activity.
StoreKit product identifiers, purchase crediting, account identity and saved data
are retained. No replacement charging rule has been introduced.

Posts, saved-post cards, profile works and replies expose Report or block. Creator
profiles, chat participants and online group members expose the same actions.
Short-video comments now hide blocked authors as well as reported comments.
Challenge inspiration exposes content reporting and creator blocking; Cosplay
briefs select cosplay references. Challenge definitions and circles are editorial
categories, not user-owned content. Personal challenge entries retain withdraw
controls; other creators' videos use the existing player safety actions.
Self-report/block actions are excluded. Successful local writes refresh the
visible content. Local reports remain on this device; no remote submission is
claimed while the backend gate is false.

Online profile-report mapping and report visibility restoration are updated in
source. The maintained SQL command definitions reject new post gifts and support
unhiding profile reports. These SQL changes have NOT been deployed or queried.
The disabled backend release checklist requires deployment and acceptance before
cutover; prior deployment receipts do not cover this revision.

Two licensed Pexels cosplay videos by TBD Tuyen add 18-second and 7-second excerpts
with matched covers. Both are silent, keep original speed and are proportionally
resized to width 540. Representative start/middle/end frames were inspected. The
second excerpt excludes the original opening leg-focused pan. Two related posts
bring the authored catalog to 14 posts and 28 replies, and active Shorts to 10.
Nova and Theo curate the additions; all existing IDs remain unchanged. A licensed
cottonbro studio cosplay portrait replaces Theo's illustration, giving five
photographic profiles and one illustrated profile. The final square image was
inspected for facial visibility. Credits distinguish fictional curators from
photographers and depicted people. Original source files stay out of app resources.

OpenAI image generation created Profile-StarlightCard and Filter-StarlightCapsule.
Profile headers and category/collection filters use the generated raster artwork;
text stays accessible UIKit text in the bundled custom fonts. Decorative images
use their container bounds so intrinsic raster dimensions cannot expand the layout.
The flat catalog, runtime inventory, Xcode project and generator source agree.
Source records: Assets/media-provenance.json, avatar-photography-provenance.json,
cosplay-review.json and starlight-theme-provenance.json.

Verification: 514 repository static source/configuration/resource checks passed;
Info.plist and project.pbxproj passed plutil; git diff --check passed. Media hashes,
image integrity and resource links were inspected. The obsolete gift-spending UI
scenario is replaced by a no-gift/safety/preserved-balance regression but was NOT
run. No Swift compilation, typecheck, simulator, app launch, XCTest, database
execution or runtime visual verification was performed. Earlier runtime reports
are historical and do not validate this revision.

### Diamond looks and challenge entries — October 28, 2026

Optional looks debit diamonds from the device wallet and are saved in the same
atomic ledger as the balance. Ownership is `CosmeticState` on `WalletLedger`.
Older wallet files still decode. A look is bought once, equipped immediately,
and can be switched back to Classic without another charge. Insufficient
balance and a failed save do not change the balance.

- Avatar frames: Sakura Ring and Ice Ring, 200; Violet Ring and Moon Ring, 500. Edited from Me and Edit profile.
- Profile headers: Sakura, Night and Ice, 800.
- Chat bubbles: Sakura, Ink and Ice, 300. Chat rooms: Paper and Dusk, 600. Edited from a conversation.
- Cover frames: Blossom, Night, Gold and Ice, 400. Chosen in the circle composer and the video publisher. The equipped frame is stored on the new post or submission.
- Joining a challenge costs 100 diamonds. Replacing that entry is free. Withdrawing the entry returns 100 diamonds. The charge is recorded before the entry is saved and is returned if that save fails.

Messages, ordinary posts, comments, reports and blocks stay free. Shorts and circle posts still have no gift button. The backend gate remains false, so these spends are on this device. Online spending is not connected. No compilation or simulator run was performed for this revision.

## Mixed photographic and illustrated avatars — October 27, 2026

Four of the six built-in story authors now use licensed Pexels photographs:
Luna uses a blue-wig cosplay portrait, Nova a steampunk cosplay portrait, Kai an
outdoor portrait with glasses, and Mira a casual cafe portrait. Rowan and Theo
retain their illustrations. The four 640-pixel JPEGs were individually inspected
for content and clarity. No text or watermark is visible in the selected images.

The same stable author IDs resolve these portraits across posts, Shorts, profiles
and conversation snapshots. Canonical fictional-persona artwork overrides stale
stored portrait names; private avatars and real remote account portraits retain
their existing ownership. Names, works, balances, relationships and saved content
are unchanged. Photography is attributed in Artwork & Credits; depicted people
are not represented as actual users or authors of the fictional posts.

Sources, photographers, license links, image hashes and processing details are in
`Assets/avatar-photography-provenance.json`. The flat asset index, runtime inventory
and disposable generated catalog are synchronized. See `avatar-photography-static.json`.
All 459 repository static checks, four image integrity/mapping checks and
`git diff --check` passed. No compilation, typecheck, simulator, app launch or
runtime visual verification was performed for this revision.


## Whole-card navigation and complete creator portfolios — October 27, 2026

Circle, challenge, circle-post, saved-post and profile-post cards now open their
corresponding detail from the image, text or card whitespace. The card tap delegate
excludes UIControl and UITextView descendants, so avatar navigation, Explore,
gifts and source-credit controls retain independent actions. Scrolling remains a
scroll gesture. Existing video tiles already navigate across their entire frame.

Eight active Shorts and twelve character posts are distributed across six existing
fictional profiles using stable curator IDs. All sixteen catalog UUIDs, asset names,
media files, film credits and source URLs are retained; eight legacy live clips stay
outside active collections. New optional curator metadata retains a legacy group ID
for old profile collections and blocking. Existing per-video likes/saves, wallet,
follow records, chat drafts and user uploads are not reset or reassigned. An old
follow of the editorial group does not automatically follow all six new curators.

Creator profiles offer All / Shorts / Posts under Works and count both forms.
The Me Works collection also includes the signed-in user's own posts. Authored
post baselines and existing short-video baselines feed the same profile totals;
local bookmarks and follows add to their corresponding figures. Fictional author
names, avatars and relationship baselines resolve consistently from the shared
catalog. Real personal accounts receive no seeded counts, and online counts use
server records only. The backend gate remains disabled. Character biographies
and film attribution continue to identify the nature and source of the content.

See `community-profiles-static.json` for the calculated initial portfolio totals
and `Assets/community-curation-provenance.json` for assignments. All 455 repository
static checks and git diff --check passed. Two hosted XCTest regressions were
added for author distribution and combined portfolio totals but were not run.
No build, typecheck, simulator, app launch or runtime interaction verification
was performed for this revision.


## Direct cover and avatar navigation — October 27, 2026

Circle and challenge list covers now share the same navigation actions as their
existing Explore buttons. Bundled, remote and personal-photo covers in a circle's
post list open that post's discussion. Source-credit links remain independent.
Circle authors' 44-point avatars now open the existing CreatorController from
post cards, saved-post summaries and post details. Local-owner profiles resolve
from the current account profile rather than stale post snapshots. Artwork on
an already-open detail page does not recursively open that same detail.

Navigation controls expose English accessibility labels and stable identifiers.
Layout dimensions, existing gift actions and storage remain unchanged. Static
inspection confirmed the destination wiring, weak controller captures and
separate credit actions. All 445 repository static checks and git diff --check
passed. No compilation, simulator, app launch or runtime tests were performed.


## Compact circle header artwork — October 27, 2026

The Explore circle detail header no longer lets the source image's intrinsic
height expand its banner. Decorative artwork now follows the banner bounds with
an autoresizing frame, preserving aspect-fill cropping, rounded clipping and the
existing full content width. Banner sizing follows its 176-point minimum and
accessible text content, approximately one quarter of the visible oversized
header in the supplied screenshot at standard text size. Larger text can still
increase the height to keep the copy readable. The shared banner fix also prevents
other headers using this component from expanding to source-image dimensions.

All 445 repository static checks and git diff --check passed. No compilation,
typechecking, simulator launch or runtime visual verification was performed.


## Default home on reopening — October 27, 2026

Fresh home construction already selected index zero (Shorts). Foreground entry
previously retained the currently selected root tab. Scene foreground entry now
asks the installed tab controller to return to Shorts when a root page is idle.
Open detail navigation, modal presentations and comment overlays remain in place
to avoid interrupting ongoing work. Merely dismissing a system overlay does not
trigger a tab reset because the hook uses sceneWillEnterForeground.

Existing UI automation now asserts that entering home selects Shorts and that
reopening after selecting Circles returns to Shorts. These assertions have been
added but not executed. All 445 repository static checks and git diff --check
passed. No build, typecheck, simulator or runtime verification was performed;
the owner's observed installed-app behavior has not been reproduced in this turn.


## Typography refresh — October 27, 2026

App-owned headings now use Kalam Bold; body text, controls and inputs use Comic
Neue Regular. Both are bundled unchanged under SIL OFL 1.1. Dynamic Type scaling
is retained, and the five generated root-title images are unchanged. The bundled
agreement reader receives a local-only font stylesheet at document end; original
agreement bytes and consent-version hashing are preserved. Remote documents and
system-owned interfaces retain their provider's presentation.

Font registration, Xcode resource references, generation configuration, runtime
inventory, attribution and the existing typography assertions are synchronized.
See `Assets/font-provenance.json` for sources, licenses and hashes, and
`typography-refresh-static.json` for verification scope. All 445 repository static
checks, plist/project syntax inspection and whitespace checks passed. The font
specimen in `BibiApp/Design/Typography-Refresh/font-specimen.png` was visually
inspected; it is not a UIKit screenshot. No build, typecheck, simulator, app launch
or runtime tests were performed for this revision. Device wrapping, clipping and
large-text behavior remain unverified. Earlier font runtime reports describe the
previous Fredoka/Nunito revision only.


## Unicode escape correction — October 27, 2026

The owner's compiler reported JSON-style Unicode escapes in eight cover-credit
strings. All eight `\u00b7` sequences in `CommunityModels.swift` were replaced
with the literal middle dot. The static audit now rejects JSON-style Unicode
escapes in Swift source. Its detector was checked against the reported invalid
form, a literal middle dot and Swift's valid braced form. All 445 static checks
pass; `git diff --check` passes. This correction has not been compiled or run.


## Post covers and compact gifts — October 27, 2026

The eight room-style post covers are replaced by six licensed Pexels reference
photos and two existing credited film stills, with corresponding text and source
links. Both circle gift entry points now present a single compact bottom sheet;
28-point icons and compact cards replace the previous large full-page layout.
See `CIRCLE-STORIES.md` and `Assets/post-cover-provenance.json` for current details.
Static resource/configuration checks passed (444 repository checks, no failures).
This revision has not been compiled or run; runtime presentation remains unverified.


## Circle stories — October 27, 2026

The local Circles feed now includes 12 posts, six fictional authors, eight
illustrated posts and 24 prewritten replies, with three posts in each existing
circle. Fictional content is labeled in the UI and is excluded from the online
feed. Existing bookmarks, replies, safety filters and gift confirmation are
reused; eligible cards now expose the existing gift picker directly. No private
data was reset. Shorts has no tipping and Challenges is unchanged.

See `CIRCLE-STORIES.md` for content, asset provenance and verification scope.
Static catalog/resource inspection and 438 repository audit checks passed; this
revision has not been compiled or run. Historical runtime results below do not
cover the new content or card layout.


## Backend code integration — October 27, 2026

The authorized Supabase migration is implemented behind the single disabled
`BibiBackendEnabled` gate. Six database migrations and four Edge Functions are
deployed to `yepycfnkkfrfmuwdekka`; 26 Bibi tables have RLS enabled. See
`BibiApp/Backend/DEPLOYMENT.md` for actual receipts and static evidence.

The online code covers email/password, verified email, PKCE recovery, explicit
18+ consent, Keychain sessions, account-specific retry journals, real content and
social operations, private uploads/revisions, group invitations/membership,
Realtime reconciliation, server-verified wallet credits/gifts/refunds, account
deletion, and a separate device archive. Legacy balances/media are not imported
automatically. All five existing tabs remain; no calling or new monetization
module was introduced. Supabase Swift is pinned to 2.30.0.

The owner confirmed that SMTP and Apple server keys are not ready and requested
code integration first. Those dependencies, moderation operations and online
protocol review remain listed in `BibiApp/Backend/RELEASE-CHECKLIST.md`. The
currently bundled Terms and Privacy both state 18+; their existing local-service
wording must be reviewed for the online release. This task did not edit the
owner's Google documents or replace their source snapshots.

The owner subsequently authorized compilation and runtime tests with the gate
remaining false. The latest source built, installed and launched successfully on
**Bibi UI Acceptance**; all 10 Bibi-scheme tests passed with zero failures.
See `BACKEND-RUN-VERIFICATION.md` for the current test
results, compiler fixes and exact scope. The deployment/security-advisor evidence
does not establish live backend acceptance. Older runtime reports below apply
only to the revisions they describe.


## Backend discovery update — October 27, 2026

Supabase project `yepycfnkkfrfmuwdekka` (`Bibi`, Singapore) returned
`ACTIVE_HEALTHY` after creation. Read-only inventory found zero public tables
and zero Edge Functions. The security advisor returned an empty findings list
for this empty project. This is a provisioning baseline only; no application
RLS, authentication flow, message delivery, upload, or transaction processing
has been implemented or validated by this result.

Source inspection identified consent-only local session entry, authored chat
and engagement catalogs, local community persistence, and device-only wallet
crediting as migration boundaries. The proposed backend design records the
owner's all-at-once cutover and email/password decisions. This update contains
no app build, typecheck, launch, or test result. Earlier evidence below applies
only to the revisions described there.

Paths to application source, configuration, scripts and `Design/` evidence in this report are relative to `BibiApp/` unless explicitly prefixed. `docs/` and `Assets/` refer to repository-root directories.

Date: 2026-10-26. Revision: Circle-post diamond gifts.

## Current evidence

- `python3 BibiApp/scripts/static_audit.py`: 436 source/configuration/resource checks passed, zero failures. Details: `static-audit.json`. The purchase follow-up replaces the obsolete blanket prohibition on StoreKit fixtures with explicit local-scheme, Apple-catalog-scheme and Bibi product checks.
- `plutil -lint Bibi/Support/Info.plist Bibi.xcodeproj/project.pbxproj`: both files passed.
- XcodeGen regenerated project metadata successfully. New community and Shorts sources are present in the source build phase; removed room controllers/stores are absent.
- The shared scheme XML is parsed by the static audit. The bundle ID remains `im.seex.sao2-neiku-30`, team `JPTS6M4T5B`, deployment target iOS 16 and Swift version 5.
- Five roots are wired in order: Shorts, Circles, Challenges, Chats, Me. Dock sizing and drag selection derive from the number of pages.
- All declared icon assets and referenced community artwork resolve. Media provenance hashes remain unchanged. Eight Shorts clips are active; eight legacy catalog entries remain retained resources with no Live route.
- Old snapshots decode community state as an optional field. Retired room/submission data is retained without active navigation. Community mutations use the existing atomic library commit.
- Source inspection traced video and pending-upload removal through challenge deletion and post attachment cleanup, creator blocking/reporting through new lists, and local account deletion through the common storage root.

## Independent source review

A read-only reviewer inspected the new models, controllers, navigation, creation and related routes. Three findings were verified against the source and corrected:

1. The Shorts creation button overlapped More. It is now in the navigation bar; the player rail has no overlay from the home screen.
2. Circle photo import loaded the whole source before checking its size. It now checks a file representation before URL-based ImageIO downsampling, and cancels the import Progress when the composer is released.
3. Pending challenge videos could generate unopenable published links. Their share control is disabled, the player displays local/unpublished status, and the share handler independently rejects pending uploads.

The reviewer found no remaining reachable Live/Voice room controllers or obvious new Swift API mismatch in the inspected source. This was static review, not compiler verification. A focused review during simulator QA found a search overlay that survived navigation into a chat. The issue was reproduced, fixed and rechecked in the simulator. The reviewer found no further concrete regression in the lifecycle fix.

## Runtime evidence and limits

The owner subsequently authorized runtime verification. A Debug simulator build and interactive checks of all five modules were completed; see `COMMUNITY-RUN-VERIFICATION.md`. These were tool-driven manual interactions, not an automated XCTest suite. Backend integration, StoreKit transactions, storage-failure injection and a full device/accessibility matrix were not run. Static checks alone do not prove runtime correctness.

`RUN-VERIFICATION.md` records an earlier revision's authorized build and welcome-screen launch. It is historical evidence, not validation of Circles and Challenges.

The circle-post gift follow-up passed one focused XCTest UI case on Bibi UI Acceptance using local StoreKit Test. It covers purchase crediting, gift spending, cancellation, insufficient balance and persistence. See `PURCHASES-RUN-VERIFICATION.md` for the current evidence and remaining limits. Shorts has no gift entry.

## Flat asset migration

All asset sources now live directly in the repository-root Assets directory. The audit reads the flat catalog metadata and verifies the same icon, artwork and media invariants. Generated Xcode catalog metadata links to these files; original films and design evidence are excluded from app resources. See ASSET-MIGRATION.md for migration-specific runtime verification.
