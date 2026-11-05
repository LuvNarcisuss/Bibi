# Bibi implementation record

## Physical B entry with temporary identity — November 5, 2026

The owner authorized temporarily aligning all configuration and generated Bundle
IDs with `im.seex.sao2` for the physical iPhone. The latest workspace built with
`BibiOnlineAcceptance` / `OnlineAcceptance`, team `JPTS6M4T5B` and the matching
`iOS Team Provisioning Profile: im.seex.sao2`. The profile includes the target
phone and development APNs entitlement; strict signature verification passed
with access to the system trust store. The signed artifact was installed on the
owner-selected iPhone 12 (iOS 16.5.1), launched and left running after debugger
detach. A direct device screenshot confirmed the actual external B page
displaying Diamonds / Recharge content. No page URL or event was forced, no
account data was reset, and no TLS check or push capability was disabled.

After page verification, `project.yml` and the regenerated Xcode project were
restored to `com.bibi.quadratic` for every app configuration and test target.
Static readback confirms the original team, iPhone family and closed Debug /
Release defaults; the explicit OnlineAcceptance configuration remains enabled.
The phone retains the signed `im.seex.sao2` test installation. The restored
original identifier was not rebuilt or registered; its prior registration/profile
availability is not resolved by this temporary test.

No purchase was initiated by the agent. An existing Xcode StoreKit Test queue
reported payment-sheet error 907; real purchase, credit delivery and Apple
sandbox/store product availability remain unverified. No iOS test suite ran.
Evidence: `BibiApp/Backend/IntegrationEvidence/b-physical-online-2026-11-05.json`
and the adjacent device screenshot.

## Signed online B entry — November 5, 2026

The owner completed agreement consent/login on Bibi UI Acceptance. The first
online artifact was unsigned and the real system Keychain denied access with
OSStatus -34018 (missing application identity/access-group entitlements). The
application was rebuilt from the current workspace with simulator ad-hoc signing
(`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`), installed and launched again.
Its simulated application identifier is `JPTS6M4T5B.com.bibi.quadratic`. No secure
storage fallback, service-name change, credential deletion or account reset was
used. The signed run passed the Keychain gate and continued actual login.

Computer-use inspection confirmed the remote B web page rendering full-screen
with its promotional offer overlay. The existing real authentication / native
Socket page-event / WKWebView path was used; no URL or message was synthesized.
No offer purchase was initiated and real payment/refund acceptance remains
pending. Default Debug/Release backend gates remain false. Reproduce the online
run with `BibiApp/scripts/run_online_acceptance.sh` or the BibiOnlineAcceptance
Xcode scheme; do not disable signing for this interactive Keychain flow.

Evidence: `BibiApp/Backend/IntegrationEvidence/b-online-acceptance-2026-11-05.json`.


## Explicit online acceptance entry — November 5, 2026

The owner requested a latest-source build/install/launch on Bibi UI Acceptance
to view the actual B web application. BibiOnlineAcceptance uses the explicit
OnlineAcceptance Debug-type configuration and a generated plist derived from
the canonical Info.plist with its backend gate enabled. Debug/Release defaults
remain false; no origin/key value, Socket ticket or page URL is forced. Real
service responses still control the native/external branch. Build and interactive
entry results are recorded separately from the prior offline validation.


## Purchase recovery offline validation — November 4, 2026

The owner subsequently authorized the missing actual iOS purchase-chain offline
validation. The latest source built, installed and launched on Bibi UI Acceptance;
31 tests passed (22 service-chain tests and nine existing recovery checks), with
zero failures/skips. The tests inject only Apple/account/network boundaries and
execute the original observer, protected journal, receipt coordinator, actual
URLSession DTO/parser, recovery scheduler, delivery and finish/removal paths.

Actual failures exposed and fixed paid-callback replay after a storage error,
confirmation retries during unwritable storage, removal-state recovery and freed
object-address collisions in finish deduplication. Initial failures and the final
passing result are retained separately. The final read-only review found no
additional P1/P2 in these changes. No real payment/live settlement or agreement
change occurred; the backend gate remains false. This supersedes earlier
statements that the nine recovery tests and this iOS chain were unexecuted.
See BibiApp/Backend/IntegrationEvidence/B-Purchase-Chain-Verification-2026-11-04.md
and b-purchase-chain-verification.json for matrix coverage, source/log hashes and
remaining online/device checks and historical/upstream capability gaps.


## B code completion — November 4, 2026

The frozen two-route/fourteen-entry console contract is implemented through
bootstrap preflight, App direct authentication, the native Socket receiver,
full-screen web entry and dual-source StoreKit 1 recovery. Native local credits
have one Supabase writer using explicit client-reported trust; external orders
have a separate original-service authority. Unknown historical transaction
ownership and ambiguous upstream confirmation remain documented capability gaps.

The final B source compiled successfully as an unsigned Debug simulator artifact.
Eleven offline SQL/Edge scenario groups and final static/hash checks passed;
no app/simulator launch, iOS tests or real external/Apple transactions ran.
The owner approved the exact financial SQL after automatic review rejection;
the migration and both JWT-protected B functions deployed with exact source and
privilege readback. Online acceptance remains pending. The gate remains false and agreements
remain frozen. Current details and import files are in
`backend-api/integration-record.md`; entries below describe earlier revisions.


## Staged Supabase completion — November 4, 2026

The owner selected completion of A before the requested B integration. A now
has the complete 56-record community catalog, seven non-Auth editorial profiles
and 43 private cloud-media objects. Bundled business catalogs and media are
retired while original source assets and actual private state remain intact.
Authenticated bootstrap, device context, current business spending/refunds and
Realtime reconciliation are wired and deployed.

Full user-permission media/data readback, real bidirectional IM, business writes
and isolated Sandbox spending checks passed; exact fixtures were removed. The
latest unsigned Debug simulator build passed, and its resources/Info.plist were
inspected. No app/simulator launch or iOS tests ran. The gate remains false and
agreements remain frozen. B is requested for app ID `48369038` and origin
`https://bibi.byig.top`; see `backend-api/integration-record.md` for current stage
status, receipts, limits and subsequent B work. Earlier entries below are
historical evidence for their named revisions.


## Supabase build assets — October 29, 2026

Codemagic now restores the 397-file CI snapshot from the public
`bibi-build-assets` Storage bucket through `restore_ci_resources.py`. The workflow
does not require a Codemagic environment group or Supabase credential.
`upload_ci_resources.py` is the trusted one-time uploader; user-owned
`bibi-images` and `bibi-videos` remain separate. The bucket exists remotely and
contains all 319 build resources after the owner-authorized dashboard upload.
The cloud build remains pending.

## Original agreement URLs retained — October 29, 2026

The owner selected the original public URLs under
`bibi-agreements/2026-10-29/` as stable canonical destinations. Those two objects
are replaced in place with the reviewed English company PDFs, preserving
Chengdu Yuehui Xingyu Technology Co., Ltd. and trvahai996@icloud.com.
The app model, README, identity audit and source provenance use these original
URLs again. Matching bundled PDF bytes are unchanged; the content-derived consent
version follows the current URLs and PDF bytes. Older version-directory records
below are historical and do not define the current public links.

Anonymous public readback and byte comparison are recorded in
`BibiApp/Design/AgreementPDF/Original-Links/`. Static checks and plist/project
syntax inspection passed. No build, typecheck, app launch, simulator, preview
or runtime tests were run. The business backend gate remains false.


## Codemagic-managed signing files — October 29, 2026

The owner selected Code signing identities instead of CLI-managed signing.
The workflow now selects stored App Store signing files for com.bibi.quadratic
with environment.ios_signing. The bibi_signing environment group dependency,
CERTIFICATE_PRIVATE_KEY guard, CLI fetch/create and keychain setup/import steps
are removed. Profile application remains xcode-project use-profiles in BibiApp.
This supersedes the earlier Missing App Store profile handling approach.

The Codemagic team must hold a valid Apple Distribution certificate/private-key
package and matching App Store profile for team JPTS6M4T5B and this Bundle ID.
CODEMAGIC-SIGNING.md now documents certificate upload/fetch, profile creation/
fetch/upload and the required green certificate match. Missing remote files will
still fail the upfront selector; this source change does not provision them.
The Bibi API integration, resource restoration, notifications, build numbering
and disabled review submission are preserved.

YAML mode/dependency/identity/publishing assertions, all five Bash script syntax
checks and whitespace inspection passed. No credentials were changed, no remote
signing files were uploaded, and no build, simulator, runtime tests, Codemagic
job or App Store upload ran. Other existing agreement edits were preserved.


## Reproducible CI resource recovery — October 29, 2026

The missing asset-catalog-index.json error came from ignored/untracked Assets,
not Git LFS initialization. CIResources.json now pins all 397 current build
inputs: 309 exact matches to the existing Supabase manifest and 88 Git-owned current
files. Narrow ignore exceptions expose the latter for commit, including the
current index/branding/new media/fonts/PDFs. The retained asset archive remains
ignored. Codemagic restores missing pinned Supabase inputs before resource verification
and catalog preparation. Changed local bytes and unresolved LFS pointers fail
without overwrite; current branding is not replaced by older remote versions.

Verification used an independent temporary CI-layout directory containing only
the 88 Git-owned inputs and tracked scripts/configuration. Before restoration,
the checker reported missing remote files. Actual HTTPS downloads restored 309
Supabase resources, all 397 files matched the current workspace hashes, the checker
passed, and catalog preparation generated 174 entries. All Git-owned build inputs
are unignored. YAML/order/identity checks, five Bash syntax checks and whitespace
inspection passed. Evidence: BibiApp/Design/CI-Resources/verification.json.

The workflow, snapshot, scripts, ignore rules and newly exposed Assets still
need to be committed/pushed together to the cloud build branch. No app build,
typecheck, simulator, launch, preview, runtime tests, Codemagic job, signing
request or App Store upload was performed. See CI-RESOURCES.md for maintenance.


## Missing App Store profile handling — October 29, 2026

The reported com.bibi.quadratic/app_store failure came from the workflow's
upfront Code signing identities selector. The project and generator identity
already match. codemagic.yaml now uses CLI signing: initialize the keychain,
fetch IOS_APP_STORE files with --create for the exact Bundle ID, import
certificates and apply profiles. The previous ios_signing selector is removed.

The remote application must expose a bibi_signing environment group containing
the existing distribution certificate's CERTIFICATE_PRIVATE_KEY as a Secret.
The Bibi integration remains responsible for API authentication and must have
the intended team's provisioning permissions. App Store record/bundle matching
and remote resource delivery still require verification. See CODEMAGIC-SIGNING.md.

Static YAML, script order/identity/publishing assertions and all five Bash script
syntax checks passed, along with whitespace inspection. No signing request,
Apple resource creation, keychain operation, build, simulator, Codemagic job or
upload was executed. The original cloud error remains unverified after this
source correction.


## Codemagic distribution configuration — October 29, 2026

The root workflow now targets `BibiApp/Bibi.xcodeproj`, shared scheme `Bibi`,
Bundle ID `com.bibi.quadratic`, App Store Apple ID `6828253391` and integration
`Bibi`, with Xcode pinned to `26.5`. Resource restoration and preparation use
`Assets/` and Bibi's catalog script. Profile application runs from `BibiApp/`.
The build-number override uses `BIBI_BUILD_NUMBER`. IPA publishing retains
`app_store_connect.auth: integration`; automatic beta/store review is disabled.
The owner-selected address `2758057680@qq.com` receives both build success and
failure notifications.

`BibiApp/scripts/verify_ci_resources.py` reports missing resources and unresolved
LFS pointers before signing or archiving. Most source assets remain ignored and
untracked; their delivery to the remote checkout is required before cloud builds.
The local configuration does not provision the remote `Bibi` integration or Apple
signing credentials. Verification is static only; no cloud build or upload was run.

## Agreement operator and support contact — October 29, 2026

The owner selected Chengdu Yuehui Xingyu Technology Co., Ltd. as the English
legal operator name and
trvahai996@icloud.com as the support/privacy contact. Both source documents,
retained HTML and bundled PDFs contain these values consistently; obsolete
missing-contact statements and the empty-field draft banner are removed.
No empty labeled fields remain. The policy still explicitly leaves support-mail
storage location and retention unspecified; no jurisdiction, retention promise
or legal approval was invented. Other service clauses were not rewritten.

New immutable public PDFs are under `bibi-agreements/2026-10-29-company/`.
The previous `2026-10-29/` PDFs remain historical. App URLs, README, publication
hashes and content-derived consent inputs now use the new revision. Anonymous
HTTPS readback returned 200/application/pdf and exact bundled byte matches.
All nine PDF pages were reviewed and full text matches source. Evidence is in
`BibiApp/Design/AgreementPDF/Company-Update/`.

555 static checks passed. No build, typecheck, simulator, app launch, preview
or runtime tests were performed. The business backend gate remains false.


## Supabase PDF agreements — October 29, 2026

Terms and Privacy now use versioned public PDFs in Supabase Storage bucket
`bibi-agreements`, under `2026-10-29/TermsOfService.pdf` and
`2026-10-29/PrivacyPolicy.pdf`. The owner explicitly authorized public access.
Both anonymous HTTPS downloads returned HTTP 200 and application/pdf; remote
bytes match the bundled files. The dedicated bucket accepts PDFs up to 2 MB.
Existing private media buckets and client write policies were not changed.

The shared consent/Settings reader references the Supabase PDF directly, accepts
only the selected HTTPS host/path and PDF responses, and uses the matching bundled
PDF after network failure. Online consent retains the existing bundled-first
behavior. Acceptance versions hash the versioned URLs and PDF bytes. Google
document URLs and preview/access-page detection are removed from runtime code.
XcodeGen regenerated the resource phase with the two PDFs instead of HTML.

The English source text, PDF files, retained HTML source copies and publication
provenance are tracked exceptions to the Assets ignore rule. The hosting/privacy
disclosures now identify Supabase. Other legal clauses were not substantively
revised; missing operator identity/contact details remain release dependencies.
The root Agreements directory and older Google/HTML delivery reports are
historical and do not describe current runtime delivery.

Verification: 553 static source/configuration/resource checks passed; complete
extracted PDF text matches the sources and all nine pages were visually inspected.
Public download receipts and a PDF contact sheet are in
`BibiApp/Design/AgreementPDF/`. No build, typecheck, app launch, simulator, preview
or runtime tests were run. The backend gate remains false.


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

The new logo container now joins the entry content stack before its cross-view
width constraint activates. This corrects the common-ancestor exception introduced
by the logo refresh. A review of 108 direct constraint-activation sites and shared
pinning helpers found no additional instance of this ordering defect.

543 static checks pass. The latest source was built, installed and launched on
Bibi UI Acceptance. All five targeted runtime tests pass: both entry stages at
three widths with repeated refresh, consent refresh/decline, all five roots at
default and XXXL text, and portrait geometry during rotation. Four original private
state files were restored and their hashes verified after relaunch. The installed
binary matches this build and the backend gate remains false. Earlier interrupted
runs and the corrected test-harness assertions are recorded in the
[acceptance report](../BibiApp/Tests/Evidence/2026-10-29-layout-order/REPORT.md).

## Owner-provided logo and entry refresh — October 28, 2026

The owner's supplied pink character and Hi speech bubble replace AppIcon,
BibiMark and BibiWordmark. The opaque 1024-pixel RGB app icon preserves the
source's RGB pixels and square composition. Source bytes, hashes and processing
are recorded in `Assets/brand-logo-provenance.json`; the artwork manifest and
packaging script now follow this approved source rather than the former logo.

A dedicated UIKit launch storyboard displays the new mark and Bibi name on a
light lavender background. The account-loading screen uses the same logo size,
position, name and background, adding only its activity indicator. XcodeGen
regenerated metadata and included the storyboard in the app resource phase.

Welcome and login use a responsive square logo hero with rounded presentation,
the existing bundled fonts, revised English copy and purple primary actions.
The old entry illustration is retained as a resource but is no longer displayed.
Consent, agreement links, guest sign-in, private data and the disabled backend
gate are unchanged. In-app credits distinguish the owner-provided brand artwork.

Verification: 542 static source/configuration/resource checks, plist/project
syntax inspection and whitespace inspection passed. Logo RGB pixels and output
hashes were checked against the archived source. No build, typecheck, app launch,
simulator, preview or runtime tests were performed. Launch-screen rendering,
device layout and large-text behavior still require runtime acceptance.

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

## Chats filters follow friend availability — October 28, 2026

All, Unread, Pinned and Drafts are hidden when there are no eligible friends,
using the same relationship criteria as group creation. Adding a friend reveals
the filters on the next store refresh. Removing the last friend hides them and
resets the selected filter to All. The inbox and welcome content move up to the
safe-area top when the filters are hidden, leaving no reserved strip.
Verification is static only: 532 audit checks and whitespace inspection pass.
No compilation, typecheck, app launch or runtime verification was performed.

## Composed Chats empty state — October 28, 2026

The empty inbox now uses the existing starlight card artwork and an illustrated
chat, planet and sparkle composition. A primary Find a friend action opens the
existing ID lookup. Secondary cards open group creation and friend-code scanning;
online sessions show group invitations instead of scanning. A short safety cue
points to existing profile reporting and blocking. These controls do not create
friends, conversations, messages or unread activity automatically.

The welcome content scrolls above the dock and follows the keyboard guide. Native
labels support Dynamic Type, decorative artwork is excluded from VoiceOver, and
action cards expose accessible names, hints and press feedback. Search, Unread,
Pinned and Drafts have their own illustrated empty states with a reset action.
Switching between welcome and filtered panels resets the empty view's scroll
position. Existing conversation rows and their swipe actions remain unchanged.

Verification is static only: 532 audit checks and whitespace inspection pass.
No build, typecheck, launch, simulator or runtime visual verification was performed
for this UI revision. The installed binary has not been updated.

## Empty personal account and populated community — October 28, 2026

New local accounts have a neutral name, no authored biography and the Bibi mark
instead of a fictional persona portrait. Launch no longer copies the four practice
videos into the personal library. Works, likes, saves, circle memberships, challenge
entries and uploads start empty.

The community Shorts, posts, challenges and author profiles remain. Six directory
people remain discoverable, with no automatic friendship/follower relationships,
chat transcripts, unread counts, stories or groups. Inbox rows require a saved
conversation, user-written draft/outbox or explicitly created group. Legacy group
IDs can still resolve actual user-written records without restoring authored replies.
Chats uses the composed empty state described above.

The owner explicitly requested clearing personal and chat data on the acceptance
device. A full container backup was saved before the offline cleanup. Personal
collections, profile, social actions, reports, drafts, chats and app-owned media
copies were cleared. Wallet bytes and purchased looks were preserved; project
media and original Photos were untouched. See
`BibiApp/Tests/Evidence/2026-10-28-clean-account/cleanup.json`.

Verification for this revision is static only: 532 checks pass, JSON storage shapes
were compared with the prior Codable snapshot, and whitespace inspection passes.
A new-account regression was added but not run. Earlier UI/purchase acceptance
below describes the previous fixture-filled revision; tests relying on automatic
friends or practice videos now require explicit QA fixture setup. No build,
typecheck, app launch or XCTest was performed for this change. Install a build of
this source before reviewing the empty-account behavior; the older installed binary
still contains its earlier seeding and inbox logic.

## Full-function acceptance — October 28, 2026

The latest recorded result for each of the 31 current XCTest methods is passing
across focused simulator runs. This includes 12 hosted unit/resource tests,
13 UI scenarios and 6 local StoreKit UI scenarios. The static audit passes 528
checks, and all 11 Python asset-tooling tests pass. Each runtime run built the
workspace source and installed/launched it on Bibi UI Acceptance.

The original app data was restored and 12 state files matched their backup
hashes. Reduce Motion was restored to off. Live backend, RTC, Apple Sandbox and
production purchases remain outside this acceptance. The existing red-robe clip
has a non-English prop inscription that remains a content-cleanup finding.
See [the acceptance report](../BibiApp/Tests/Evidence/2026-10-28-full-function/REPORT.md)
for method results, screenshots, corrections, restoration evidence and limits.

## Portrait-only interface — October 28, 2026

The owner selected portrait-only main screens during the full-function acceptance
run. `UISupportedInterfaceOrientations` now contains portrait only. The previous
landscape title/navigation assertions did not detect clipped player actions or
crowded floating comments and must not be treated as visual layout acceptance.
The rotation regression now requires all five roots to retain portrait geometry
when the physical device orientation changes. All five roots passed that runtime regression.

## Comment action keyboard obstruction — October 28, 2026

Full-function QA reproduced a comment action card behind the software keyboard.
Selecting a comment now ends editing before showing its Reply/safety actions.
The latest simulator build successfully saved both a comment and a reply after
the fix. The complete local safety/account flow subsequently passed as well.

## Private upload share accessibility — October 28, 2026

The private-upload player already rejected published-link sharing and disabled
touch handling. Its custom Share control now also exposes the UIKit `notEnabled`
accessibility trait. QA previously read the control as enabled even though its
touch action was disabled. The pending-upload label, ownership and publishing
gate are unchanged. The system-media upload, relaunch, playback and removal regression passed.

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


## Backend provisioning update — October 27, 2026

The owner authorized creating the Supabase project `Bibi` in `LuvNarcisuss's Org`
at the returned $0/month project quote. Project `yepycfnkkfrfmuwdekka` was created
in Singapore (`ap-southeast-1`) and a subsequent lookup returned
`ACTIVE_HEALTHY`. Read-only discovery found no public business tables or Edge
Functions. This creates infrastructure only: the application still uses its
existing local implementation and has not switched to online services.

The owner selected a single cutover after all modules are complete and
email/password authentication. The proposed design is
`docs/superpowers/specs/2026-10-27-supabase-backend-design.md`. It records cloud
access rules, legacy data preservation, media limits, chat semantics, and Apple
verification requirements. Public email delivery, Apple server configuration,
and a real moderation workflow remain external release dependencies. No app
build, typecheck, launch, or runtime test was performed for this update.

The historical implementation account below describes the existing local app;
statements that no cloud project had been created are superseded by this update.

Paths to application source, configuration, scripts and `Design/` evidence in this report are relative to `BibiApp/` unless explicitly prefixed. `docs/` and `Assets/` refer to repository-root directories.

Date: 2026-10-26 (Asia/Shanghai).

The owner authorized removing Live and Voice rooms and adding Circles and Challenges. The native UIKit application now has five roots: Shorts, Circles, Challenges, Chats and Me. The existing signing configuration is preserved in project.yml and the generated Xcode project.

## Current feature paths

| Area | Source path | Capability boundary |
|---|---|---|
| Navigation | BibiTabController → five independent navigation stacks | Dock geometry derives from page count |
| Shorts | ShortsHomeController → VideoFeedController | Local media, search, social state and outbox creation |
| Circles | CirclesController → CircleDetailController → CirclePostController / CircleComposerController | Four editorial themes; local join, post, photo, attachment, reply, save and delete |
| Challenges | ChallengesController → ChallengeDetailController → video picker / CreationController | Four evergreen briefs; one replaceable local entry per challenge |
| Personal activity | Me → joined circles / saved posts / ChallengeEntriesController | Reads the same shared state |
| Chats | Conversation → relationship checks → atomic outbox | No delivered receipts; only Shorts shared links open |
| Creation | Form → permission declaration → media import → atomic submission and optional challenge entry | No automatic public release or review approval |
| Safety | Circle/video/comment report or creator block → persist → hide; Settings reversal | No server moderation submission |
| Wallet | StoreKit request/callback → idempotent ledger → finish after save | Local StoreKit Test purchases verified; App Store catalog and real-device sandbox unverified |
| Calls | Voice controls; local camera with permission/flip/lifecycle | No peer connection or microphone recording |
| Account | Consent, logout preserves, local account deletion removes storage root | No external account deletion |

## Diamond gifts on existing content

Circle discussions now open the existing gift picker. Shorts remains free and has no gift entry. No new root, store, currency, subscription, or decoration system is introduced. The nine existing gifts and 1/5/10 quantities remain available. Owned posts do not offer gifting; unavailable or moderated content is rechecked before spending.

The current deliverable is a local gift effect and durable activity record for the selected content, not a transfer to a creator. Both the picker and its cost confirmation disclose this boundary. Basic messages, posts and challenge entries remain free. Chats have no gift-delivery service, and challenge entries remain local, so neither receives a paid delivery control.

The wallet stores content kind, stable content ID, creator ID, title, gift ID and quantity with the debit in the same atomic wallet file. New fields are optional for older ledger compatibility. Gift debits share the StoreKit transaction queue with credits, and the wallet/picker reject overlapping user requests. Insufficient funds, cancellation, unavailable content and failed persistence do not publish a debit or play the gift animation. Account exit waits for wallet work already in progress.

## Typography and illustrated navigation

The typography revision bundles unmodified Fredoka and Nunito variable fonts with their SIL Open Font License texts. BibiPalette selects Fredoka at weight 600 for display text and Nunito at weight 500 for reading and controls, retaining UIFontMetrics scaling. UIAppFonts and the Xcode Resources phase register and ship both fonts. project.yml explicitly includes the font files from the repository-root Assets directory.

StudioTitle displays original generated transparent wordmarks for Shorts, Circles, Challenges, Chats and Me. Each title retains its English VoiceOver header name and aspect ratio. Secondary titles remain live Fredoka text. The flat Assets directory contains the typography- prefixed originals, manifest and exact prompts. The owner subsequently authorized a build and XCTest UI automation. Four tests passed on the Bibi QA iPhone 17 Pro simulator: runtime font families/weights, original title artwork and five-page navigation at default and larger text sizes. Ten original screenshots were visually reviewed without a title rendering defect. See TYPOGRAPHY-RUN-VERIFICATION.md for evidence and limits.

## Storage and ownership

CommunityState is optional in LocalLibrary, so older snapshots remain decodable. Mutations use AppStore.commit and the existing atomic, file-protected snapshot repository. A failed write never adopts the proposed state. The UI preserves post and reply text on failure. No separate community directory can escape account deletion.

Circle photos are downsampled to 1,200 pixels, encoded as JPEG and limited to 1 MB. A local library supports up to 100 authored posts and 2,000 replies. Only the local owner can remove authored posts/replies. Seed prompts are explicitly attributed to Bibi Editorial.

Challenge selection accepts only personal videos up to 180 seconds. New imports retain the existing 250 MB validation and local pending status. The video, submission and challenge entry commit together; a failed import/write removes only the new app-owned copy. Replacing an entry keeps the previous video. Withdrawing an entry leaves its video untouched. Removing a video or pending upload removes its entries and detaches circle references in the same snapshot update.

All attached-media routes re-check video existence and safety state. Existing private media is never converted into a remote upload. Reported posts and blocked authors disappear from both circle and saved-post lists. Local reporting does not imply server processing.

## Retired functionality

Live discovery, player branches, live creation, room store/playback and chat deep links are removed. Voice-room screens, discovery store, seating and message scripts are removed. Shared category values now live in VideoCategory. Legacy room drafts, report kinds, submission kinds and catalog surface markers remain only for data compatibility and attribution. Hidden archived submissions are retained without destructive migration.

## Verification boundary

The owner subsequently authorized compilation, simulator launch, interaction checks and direct fixes for this revision. The Debug build and core flows across all five modules passed on the Bibi QA iPhone 17 Pro simulator. See `COMMUNITY-RUN-VERIFICATION.md` for exact coverage and evidence. Storage-failure injection, device-matrix testing, real services and transactions remain unverified.

## Resource provenance

The `Assets/generated-` prefixed files preserve the seven image-model outputs. `scripts/package_artwork.py` extracts the atlases using alpha gutters, writes named flat images and native asset metadata and preserves transparency. Fifty-two different character drawings map to fifty named members, the local owner and the fictional Animation Club curator. Source filmmakers are credited separately, and no portrait claims to depict them.

`Assets/original-hero.mp4` and `Assets/original-spring.mp4` preserve the downloaded full original videos. `Assets/media-provenance.json` records download/source/credit/license, original and runtime SHA-256, exact intervals, output metadata and cover hashes. `scripts/prepare_media.py` produces sixteen nonoverlapping excerpts at original speed, proportionally resized to 960px width, H.264/AAC encoded. The app's aspect-fill viewport may crop the frame; no stretched source was produced. They are sixteen excerpts from two films, not sixteen independently produced films.

Hero: Blender Foundation, Daniel Martinez Lara, CC BY 4.0. Spring: Blender Foundation, Andy Goralczyk. Its project release specifies CC BY 4.0 while its official video-host metadata says Attribution–ShareAlike; these Spring derivatives and covers are distributed under CC BY-SA 4.0. Source/licensing links are shipped in Settings. No endorsement is implied.

`docs/template-history/` records the inherited specifications only; counts, identities and old URLs there are not the Bibi configuration.

## Configuration before public distribution

No public backend or merchant account was created. The product owner must supply a unique registered bundle identifier if different, signing team, authenticated services, server-authoritative balances/relationships/moderation, registered diamond products, receipt verification, operator identity and support contact, and reviewed public agreements. Existing local capability text must be updated only when actual integrations exist.

Native layout, playback lifecycle, keyboard behavior, Dynamic Type, VoiceOver, camera permissions, persistence failures and real App Store transactions remain outside the verified purchase scope. Local StoreKit Test coverage is recorded in PURCHASES-RUN-VERIFICATION.md. No statement in this record substitutes static inspection for those checks.

## Agreement links supplied on October 26, 2026

Welcome/consent and Settings share AgreementDocument and AgreementController. Terms uses https://docs.google.com/document/d/1Ht9y4vdWhBqBMEWh-TyDDkoelD4ovlfqnayIwr-b_4I and Privacy uses https://docs.google.com/document/d/1tdj2Xd4VnOVLbFCgk-k65m8ONo3obRoFT1xddWTtY5c. The reader requests Google's English preview in a nonpersistent WKWebView and restricts top-level navigation to the selected document.

The user-supplied documents were read through the connected Google Drive account. Their text is retained in Assets/agreement-source-PrivacyPolicy.txt and Assets/agreement-source-TermsOfService.txt with hashes and retrieval provenance. Bundled HTML preserves that wording with local reader formatting. No cloud document or sharing permission was modified. Anonymous access has not been verified; a failed web lookup is not proof that the documents are private.

Network errors, HTTP failures, authentication redirects, a 15-second loading deadline, and recognized English access-denied pages switch to the bundled version, labeled Saved copy. Acceptance versions include source URLs and bundled content hashes. Later cloud edits require refreshing these snapshots; the app does not claim to hash mutable remote content at acceptance time.

The provided Terms specify age 18+, while the Privacy Policy specifies 17+. These source statements are preserved rather than silently reconciled. The documents' service descriptions do not establish implementation of remote services; capability boundaries above still apply.
