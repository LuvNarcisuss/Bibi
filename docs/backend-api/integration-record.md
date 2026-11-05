# Bibi backend integration record

## Scope and binding

On November 4, 2026 the owner requested B with application ID `48369038` and
external origin `https://bibi.byig.top`, then explicitly selected completion of
the missing A work before B. The existing Supabase project
`yepycfnkkfrfmuwdekka` is retained. No additional project or anonymous identity
is created at application launch merely to switch stages.

The app remains Bibi, `com.bibi.quadratic`, team `JPTS6M4T5B`, iOS 16+, Swift 5,
UIKit, iPhone-only and portrait-only. `BibiBackendEnabled=false` remains the
single release cutover gate. Implementation, deployment, activation and device
acceptance are separate facts.

## A: deployed data and media

The migration contains 56 approved records/revisions: ten Shorts, fourteen
fictional stories, four editorial prompts and twenty-eight replies. Seven
editorial profiles have no Auth accounts or private messaging capability.
Four circles and four challenges reference actual private Storage objects.
Every stable content ID, parent relationship, source/credit and authored field
was compared with the complete source export.

All 43 media objects (33 images, ten H.264 videos; 19,953,660 bytes) were uploaded
and downloaded with full SHA-256, size and MIME comparison. New authenticated
users subsequently downloaded all 43 objects with their own permissions;
video byte ranges, expired-signature denial and fresh signing passed.
The bounded migration endpoint was replaced with a deny-all revision returning
410; its temporary bearer and rendered deployment files were removed.

The production catalogs no longer contain bundled community payloads or
generated comments. Eighty-three business image entries and all bundled
business videos/catalog JSON were removed from application packaging; original
source assets and exact migration snapshots remain outside the app target.
Historical private library fields and actual user-written messages, drafts,
balances and rights were preserved. Historical chat identity metadata is used
only to resolve saved private activity; it does not populate the new directory.

Evidence: `../../BibiApp/Backend/catalog-migration/README.md`, its full export,
manifest, receipts, remote readback and production-retirement report.

## A: authentication and platform context

`bibi-begin` is deployed with JWT verification and live account/session checks.
A returns `{ "code": 0, "message": "ok", "data": {} }` after valid device context.
The client restores/enrolls the original Supabase identity before bootstrap,
keeps the login lock and button progress, and requires the completed content
session before constructing home.

Device UUID storage is separate from Auth and survives ordinary logout. Network
preparation uses a credential-free HTTPS HEAD, bounded active-time waiting and
redirect refusal. APNs success/failure callbacks, a finite token wait, push
capability/entitlement, three permission descriptions and the Release Bundle-ID
URL scheme are wired. An unsigned build does not validate provisioning,
notification authorization presentation or APNs delivery.

## A: business and permissions

Existing commands now provide server-backed cosmetic unlock/equip and atomic
100-diamond challenge admission/refund; repeated requests and replacements do
not debit twice. Video withdrawal/deletion removes associated entries and
returns only their original wallet's payment. New post gifts are rejected.
Profile report visibility restoration retains the underlying report.

Real API checks covered profile updates, circle join/leave, like/save add/remove,
content/profile reports and unhide, pending post publish/edit/withdraw with
cross-account revision denial, approved comments/replies, private image/video
upload/finalize, insufficient-balance rollback and successful Sandbox-only
spending/refunds. A single explicitly installed temporary Sandbox test balance
was used; no Apple payment, purchase credit, Production funding or merchant
transaction was fabricated. All isolated users, content, media, balances and
orphan conversations were removed and exact cleanup was read back.

The true Realtime check initially exposed a first-JOIN token timing problem in
the official JS client. Explicit session authentication before JOIN fixed it;
the Swift subscription helper also sets the current session explicitly before
subscribing. The successful targeted run verified bidirectional persistent
messages and real events, duplicate/conflicting operation IDs, reconnect/history
merge, nonmember/forged sender/read denial, invitation history boundaries,
membership removal and blocking. Publication covers six required tables.
Membership DELETE metadata now uses an opaque UUID primary key while preserving
the original conversation/user uniqueness.

Content and chat loading have separate failure states; unrelated chat refreshes
do not clear Shorts. Actual refresh failures remove old business snapshots.
Loading is distinguished from confirmed conversation revocation so drafts are
not discarded. Existing wallet/rights loading is independent of StoreKit
catalog availability. Editorial identities do not enter Auth-user relationship
operations; their individual works retain content reporting.

Evidence: `../../BibiApp/Backend/IntegrationEvidence/`. Initial failures and
corrected targeted runs are retained separately, rather than rewritten as one
successful run. iOS UI, live push, RTC, moderation staffing, Apple Sandbox and
production purchasing are not validated by these checks. The app has no AI
inference feature to migrate.

## Approvals and deployment

Automatic review initially rejected the financial migration and membership
primary-key change. The owner then explicitly approved their frozen SHA-256
versions. Both subsequently deployed successfully:

- `20261104020757 complete_a_spending_and_retire_gifts`, source SHA-256
  `2f47bfe06d52ee6db9329157946e7ee4dd18f884be61d43014282874f17a0ee3`.
- `20261104020808 membership_event_privacy`, source SHA-256
  `1ebac202c557b93b4ce1a6b3392a688118621b2a3f0ee4b4e8a9705d9b3ecce1`.

No rejection was bypassed through another execution mechanism. Definitions,
RLS, triggers, publication and migration inventory were read back. Anonymous-
authentication advisor warnings remain attributable to the intentionally enabled
guest flow; metadata inspection is not a claim of device acceptance.

## Frozen agreements

The existing agreements remain frozen. Their source text, PDFs, public objects,
entry URLs and consent hash inputs were not modified. Anonymous GET returned
200/application/pdf and exact bundled byte matches for both:

- Terms: `https://yepycfnkkfrfmuwdekka.supabase.co/storage/v1/object/public/bibi-agreements/2026-10-29/TermsOfService.pdf`.
- Privacy: `https://yepycfnkkfrfmuwdekka.supabase.co/storage/v1/object/public/bibi-agreements/2026-10-29/PrivacyPolicy.pdf`.

Only a future explicit owner request authorizes agreement changes.

## A checkpoint

A implementation, deployment, full media/data readback and the authorized finite
backend checks are complete. The latest A source compiled successfully with
Xcode 26.0.1 as an unsigned Debug simulator artifact; compiled Info.plist and
resources preserve the identity, iPhone-only portrait settings, nine products,
frozen PDFs and disabled gate. No iOS app, simulator, Preview or iOS test has
been started. Device acceptance and release activation remain pending. The owner
has already authorized continuing into B after this checkpoint.

## B implementation and verification — November 4, 2026

The frozen contract targets application `48369038` at `https://bibi.byig.top`.
The two imports were generated before implementation and remain unchanged:
`generated/interface-template-48369038.json` and
`generated/configuration-template-48369038.json`. They contain exactly two
interfaces and fourteen entries: seven request aliases, three web aliases and
four event slots. `template-verification.json` records their hashes. English
filenames follow the owner's project language requirement.

The authenticated bootstrap performs one server-side original-authentication
preflight. Only an actual native result uses Supabase directly; an external
result has the App authenticate directly to the original origin. Key existence,
strict integer responses, bounded requests and account/scene generations govern
entry. The native Socket has one owner and full-message notification receiver;
four core events drive page readiness, purchase, session exit and external links.
Actual Supabase Postgres Changes feed the two theme invalidation handlers.
External theme publishing, business acknowledgements and replay support require
upstream acceptance and are not inferred from a generated template.

A stable root hosts the opaque loading/failure states and full-screen web view.
Cover completion and web didFinish are separate facts. Formal restoration uses a
matching account/origin/AppID marker, not a cached ticket or invented page URL.
A page/session failure invalidates unsubmitted purchase authorization while
preserving already submitted or paid transaction evidence.

StoreKit 1 now has one resident app-wide observer. Original account, source,
order, SKU, environment and transaction evidence are durably bound before
confirmation; paid transactions finish only after durable server delivery.
Receipt refresh is serialized per purchase generation. Background recovery does
not hold the Apple purchase UI lock and never guesses ownership from a SKU or
current login. Local purchases use Supabase as the single native balance writer.
Socket orders use the original service's independent web entitlement authority
and never credit native Bibi diamonds.

Local B settlement deliberately trusts the client's purchase declaration; it
is **not Apple server verification**. The server records `client_reported`
provenance, atomic credit and deduplication, but these do not establish proof of
payment. No new Apple verifier or p8 requirement was introduced. Existing legacy
Apple-verification/refund code remains a separate compatibility path. Lost
anonymous identities, unknown historical ownership/source and inaccessible
already-finished consumables cannot be safely reconstructed and remain a real
recovery capability gap. The original service has not supplied a status-query,
idempotency or machine-error contract: an ambiguously sent external confirmation
stays `needsReconciliation` and is never blindly resent.

The latest B source compiled successfully using Xcode 26.0.1, unsigned Debug,
generic iOS Simulator destination. Compiled Info.plist/resources preserve the
identity, iPhone-only portrait configuration, nine products, frozen PDFs and
`BibiBackendEnabled=false`; retired business catalogs/videos are absent.
`b-build-and-resources.json` records the source hashes separately from A's build.
That original B checkpoint did not launch the App/simulator or execute its nine
recovery tests. The subsequent owner-authorized validation below supersedes that
limit and contains the current source/evidence hashes.

Actual frozen SQL and Edge sources passed eleven offline PostgreSQL/PLpgSQL and
Edge scenario groups, including atomic rollback, owner/source fencing, legacy
recovery, strict response decoding, forwarding whitelist, lease CAS and ambiguous
confirmation recovery. These checks used PGlite and controlled network substitutes;
they are not live external or concurrency/load acceptance. See
`../../BibiApp/Backend/IntegrationEvidence/b-server-offline-verification.json`
and `B-Server-Review-2026-11-04.md`. Fresh read-only review found no remaining
P1/P2 in the final targeted native fixes. Static whitespace and template/source
hash checks passed.

### B deployment checkpoint

The owner explicitly approved the exact B SQL SHA and both companion functions
after automatic review rejected the earlier unapproved attempt. No rejection was
bypassed. The approved unchanged `../../BibiApp/Backend/b-settlement.sql` SHA-256 is
`2b65b5e3e607838d35e18af24927748c858a7b78a297fd809d77b7484313f5f9`.
Deployment completed in the required order:

- Migration `20261104030119 bibi_dual_source_settlement` applied successfully.
- `bibi-settlement` version 1 is ACTIVE with JWT verification enabled.
- `bibi-begin` version 2 is ACTIVE with JWT verification enabled.

All deployed source files and shared settings match the local frozen versions
byte-for-byte. Readback confirms all nine product mappings, RLS, transaction
uniqueness across users/sources, the credit-source guard and service-role-only
RPC/table privileges. The new settlement table is empty; no purchase record or
wallet credit was fabricated to establish deployment. Receipt:
`../../BibiApp/Backend/IntegrationEvidence/b-deployment-readback.json`.
B code/deployment are complete; online/device/payment acceptance remains pending.
The release gate remains false.

### Console import and online acceptance

Select the same console AppID `48369038`. Import the interface file in interface
management and the configuration file in configuration management, validate each
and save both. Then perform owner-authorized original Auth, native Socket,
full-screen web, media permissions, expiry/reconnect, actual Apple Sandbox and
purchase-recovery acceptance. No real external Auth/Socket/confirmation request
or Apple purchase was executed by this task. Do not treat static availability,
compilation, offline fixtures or deployment inventory as online acceptance.
Keep the release gate false until the release checklist is satisfied.

## Subsequent actual iOS purchase-chain validation

The owner explicitly authorized completion of the missing offline service chain.
The latest source was built, installed and successfully launched on the designated
Bibi UI Acceptance iPhone simulator before XCTest. **31 tests passed, zero failures
and skips**: 22 service-chain tests and all nine existing recovery checks.
The actual SK1 observer/service, journal, receipt coordinator, request encoder /
URLSession reply parser, recovery scheduler, delivery/finish and removal/queue
reconciliation ran with controlled Apple/account/network system boundaries.
No real payment, Supabase settlement or original-service request was sent.

Failure-first runs exposed paid-callback loss after failed persistence, redundant
confirmation attempts during storage failure, missing removal-state recovery and
freed-address collisions in finish deduplication. All were corrected and covered
by the final passing run; a fresh final targeted review reported no new P1/P2.
The exact matrix and source/log hashes are in
`../../BibiApp/Backend/IntegrationEvidence/B-Purchase-Chain-Verification-2026-11-04.md`,
`b-purchase-chain-verification.json` and `b-purchase-chain-xcresult-summary.json`.
The reusable command is `BibiApp/scripts/verify_purchase_chain.sh <new-label>`.
Server sources, frozen templates and agreements are unchanged; no redeployment
was necessary. The gate remains false.

Remaining acceptance: physical signing/Bundle-ID/push profile; console import /
save; real bootstrap/direct Auth/Socket/web/cold restoration and reconnect;
Apple Sandbox catalog/receipts/callbacks for both purchase sources, immediate
post-payment disconnection/relaunch and actual authoritative balance display;
original-service business events/ack/replay; Production/refund/notification
validation recorded separately. UIKit visual/system permission behavior is not
established by these service tests.

Unresolved capabilities remain distinct: lost anonymous identity or original
purchase association may leave an orphan affecting the SKU, and ambiguous sent
external confirmation requires proven upstream query/idempotency support or
manual reconciliation. The tests verify safe retention, not recovery of unknown
ownership or a guarantee that Apple will create a new transaction. Native B
settlement still uses the selected client-trust model, not Apple server verification.

## Real online entry attempt — November 5, 2026

The explicit BibiOnlineAcceptance / OnlineAcceptance configuration built from
current source, installed and launched on Bibi UI Acceptance. The compiled
backend gate is true only for this configuration; canonical Debug/Release
defaults remain false. The external origin returned HTTP 200 and the actual
authentication route rejected empty input with HTTP 400, establishing reachability
without claiming authentication success.

The actual online login page is visible. The owner chose to handle adult consent
and agreement acceptance/login manually. At handoff, the checkbox remains
unselected; real bootstrap, Socket and external-page success are not yet
verified. Continue observing that actual session after the owner's action; do
not synthesize consent, tokens, Socket events or a page URL. Evidence:
`../../BibiApp/Backend/IntegrationEvidence/b-online-acceptance-2026-11-05.json`.

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
