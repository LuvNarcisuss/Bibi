# Static audit — Bibi

## Marketing version alignment - November 5, 2026

The owner selected marketing version `0.1.1` after App Store Connect rejected
build 25 because the approved `0.1.0` release train is closed. The XcodeGen
source and all three generated Xcode project configurations now use `0.1.1`.
Codemagic explicitly passes the same marketing version to Archive; its existing
build-number increment, signing, application identity and release gates are
unchanged. Validation is limited to static configuration and diff checks;
no build, app launch, cloud run or App Store Connect version creation was performed.

## Agreement resource snapshot alignment — November 5, 2026

The approved agreement update changed both Git-owned PDFs, while CIResources.json
still pinned their previous bytes. The resource restore step reproduced the two
Changed local resource errors and correctly refused overwrite. Only the two
manifest size/SHA-256 records were updated to match the approved PDF provenance;
PDF contents, public URLs, remote asset pins and strict integrity checks remain
unchanged. Resource restoration and required-resource verification pass with
zero downloads. No Xcode build, app launch or cloud rebuild was performed.

## P1 WebView media authorization source fix - November 5, 2026

The unconditional `.grant` is replaced by the actual request/frame/document/session/navigation policy. Both navigation decision handlers and popup opening enforce the frozen origin; teardown/replacement/failure/inactive paths stop camera and microphone capture. SDK headers and real call sites were inspected, and whitespace checks pass. Five regression methods are present but unexecuted; no compile, app launch, camera/iframe or simulator acceptance is claimed. See `WEBVIEW-MEDIA-PERMISSIONS.md` for the remaining runtime matrix. Previously published agreements remain frozen and unchanged.

## Agreement refresh evidence - November 5, 2026

Explicit owner approval covers both agreements and fixed-link in-place publication. Final canonical anonymous HTTP 200/application/pdf readbacks match the approved sources and bundled PDF bytes; embedded fonts and all nine rendered pages were checked. Current consent inputs derive `local-da6e1e00f32c`; an installed binary is not updated by Storage publication. The temporary publisher is now inert HTTP 410 with JWT verification retained. Five skill privacy checks and nineteen Python contract checks pass; Swift compilation was excluded. No Bibi build or runtime result is claimed. Operational retention, support readiness, full external-recipient verification and renewed-consent/runtime behavior remain limited as detailed in `AGREEMENT-UPDATE-2026-11-05.md`. Both agreements are frozen again.

## Verified App Store push signing repair — November 5, 2026

The owner requested restoration of the 15:00 baseline, commit `08acb96` from
14:57:20 +08:00. Later changes were backed up outside the repository at
`/private/tmp/bibi-before-1500-rollback-3b5ppdji`. The targeted repair retains
`com.bibi.quadratic` and team `93BX5X327N`; application code and backend gates
are unchanged from that baseline.

The supplied build-21 log identifies the original blocker: profile Bibi lacks
Push Notifications and aps-environment. The existing Bibi Codemagic API
integration enabled Push Notifications on the existing App ID and generated
Bibi App Store Push 2 using the existing distribution certificate. The profile
was verified for team, identifier, expiration, App Store type, usable signing
identity and production APNs, installed in Xcode's profile directory and fetched
into Codemagic as `bibi_app_store_push`. No certificate was created/revoked,
private key exported or unrelated App ID modified.

Cloud signing-validation build `6aec34e0004ce28f20ee1117` (index 3, source
`5258fcd`, Xcode 26.5 / 17F42) completed Archive and IPA export successfully in
4m 2s. The downloaded IPA passed deep/strict codesign verification; its team,
Bundle ID and production push entitlement match the profile. It remains
an iPhone-only Release artifact with the default backend gate disabled.
The validation workflow has no publishing actions. No App Store upload,
notification delivery, real purchase or iOS runtime test suite was performed.
Existing Swift 5 actor-isolation warnings in BibiReceiptEvidence.swift remain.

Evidence, artifact hashes and intermediate validation results:
`BibiApp/Backend/IntegrationEvidence/app-store-push-repair-2026-11-05.json`.

## Confirmed App Store signing team — November 5, 2026

The owner confirmed that `com.bibi.quadratic` belongs to Apple Developer team
`93BX5X327N`. The generator configuration, regenerated Xcode project, current
identity documentation and static identity assertions now use that team.
Codemagic pins `APPLE_TEAM_ID=93BX5X327N`, restricts profile application to App
Store profiles, sets export `teamID` and passes the same team to Archive.
Bundle ID, scheme, product mapping and backend gates are unchanged.

YAML/plist parsing, signing identity readback, shared scheme inspection, shell
syntax checks and whitespace checks were performed without compiling or running
the application. No cloud build, certificate/profile upload or publishing ran.
The Codemagic Bibi integration must retain access to the intended app and valid
matching distribution credentials with production push entitlement. Earlier
entries record the original team used for their specific historical runs;
they do not define the current signing configuration. A successful cloud
archive/export remains unverified; exit code 65 alone does not identify its cause.

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

The public `bibi-build-assets` bucket exists in Supabase. Resource URLs and
integrity metadata now target its public Supabase Storage endpoint; restoration
does not require a Codemagic secret. The bucket contains 319 objects matching
the build-resource count; cloud execution is not yet verified.

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

The workflow is configured for Bibi's project path, shared scheme, Bundle ID,
App Store Apple ID `6828253391`, integration `Bibi` and Xcode `26.5`. Publishing
uses `auth: integration` and leaves review submission disabled. Source resources
are checked before catalog preparation, signing and archiving. The template app
identity and resource directory have been replaced. Email notifications retain
the owner-selected recipient `2758057680@qq.com`, with both success and failure
notifications enabled. YAML parsing and publishing-setting assertions passed
after restoring this notification configuration.

Static validation passed: YAML parsing and required-setting assertions, Bash
syntax inspection for every workflow script, all 397 local source resource checks,
and `git diff --check`. These local resource checks do not establish availability
in a fresh remote checkout.

Cloud execution remains dependent on remote integration/signing configuration
and source asset delivery: most required `Assets/` files are ignored and not
tracked in Git. No build, typecheck, simulator, app launch, preview, runtime test,
Codemagic job or Apple upload was performed for this revision.

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
