# Bibi backend

Bound project: `yepycfnkkfrfmuwdekka`. Keep `BibiBackendEnabled=false` until
`RELEASE-CHECKLIST.md` is satisfied. The November 4 owner request completes A
before connecting external AppID `48369038` and origin `https://bibi.byig.top`.
See `../../docs/backend-api/integration-record.md` for current authoritative
stage/deployment/evidence records. Historical deployment files apply to their
named revisions; do not replay their migrations against this existing project.

## Current data and account boundary

A holds 56 community records, seven fictional/editorial profiles without Auth
identities, four circles, four challenges and 43 private media objects. New users
start without personal relationships, content, wallet grants or inbox messages.
Private objects require authorized reads and short-lived signed URLs. Original
source media and mapping/provenance remain in `catalog-migration/`; business
catalogs and media are absent from production bundle resources. The disabled
gate leaves the offline community catalog empty while retaining actual private
user data. Source assets are never a failed-request fallback.

Anonymous Auth with adult consent is the normal online entry. Supabase Swift
2.30.0 stores the session in device-only Keychain and binds asynchronous work to
account generations. Logout clears online memory; archives are not automatically
uploaded or credited. Per-item archive import requires explicit user activity.
Remote deletion does not erase original Photos or independent device archives.
No SMTP is needed unless optional email-link/recovery is actually exposed.

## Current database and functions

The existing baseline migrations are documented in `DEPLOYMENT.md`. November 4
adds the editorial/media mapping, required Realtime publications and the exact
owner-approved `online-spending.sql` / `membership-event-privacy.sql`. Cosmetics
and challenge charges/refunds use atomic server commands; new gifts are retired.
Membership events have an opaque UUID primary key and retain pair uniqueness.

B source `b-settlement.sql` is frozen, offline verified and deployed following
exact owner approval. It supplies all nine selected native product mappings,
a private source/owner settlement journal and service-only RPCs. Migration `20261104030119 bibi_dual_source_settlement` is applied;
`bibi-settlement` v1 and B `bibi-begin` v2 are ACTIVE with JWT verification.
Readback verifies exact source/settings, nine products and service-only grants.

| Function | Current role |
| --- | --- |
| `bibi-begin` | Authenticated B bootstrap with a fixed server preflight and returns the chosen origin/AppID without forwarding a ticket |
| `bibi-settlement` | Deployed: source-specific durable confirmation, local atomic credit or original-service forwarding |
| `media-finalize` | Session-authorized uploaded image/video validation |
| `delete-account` | Session-authorized deletion/cleanup with retained reconciliation evidence |
| `verify-purchase` | Retained legacy Apple-verification compatibility path; not the B purchase entry |
| `apple-notifications` | Retained signed Apple refund/revocation path; real configuration and delivery unverified |
| `bibi-catalog-transfer` | Retired migration endpoint, deny-all; never a production upload path |

B local purchases explicitly trust the client's purchase declaration and mark
`client_reported` provenance. They are not Apple server-verified purchases. No
new Apple verifier/p8 was added. Supabase is the only native diamond writer.
Socket orders use a distinct original-service web entitlement authority and do
not credit native diamonds. Sandbox and Production remain separate; Xcode and
Unknown cannot be submitted as B settlement environments. Existing Apple-server
keys apply only to the retained legacy verification/notification functions.

Ownership/source is immutable and transaction uniqueness spans users and both
sources. Unknown history cannot be guessed from SKU/current login. An external
confirmation that might have been sent remains `needsReconciliation` without
blind resend; upstream status-query/idempotency semantics were not supplied.
See `../../docs/backend-api/b-stage-decisions.md` for the exact recovery limits.

## Build assets

Codemagic uses the separate public `bibi-build-assets` bucket and pinned
size/SHA-256 downloads; no service key is shipped to the client or Codemagic.
Trusted operator upload remains separate from private user-media buckets.
Production resource policy retains interface assets and excludes retired
business media. CI execution/signing remain separate release operations.

## Media and moderation operations

Both buckets are private. Images are limited to 1,000,000 bytes and 1,200 pixels;
videos are MP4, at most 50,000,000 bytes and 180 seconds. App-owned compressed
copies are keyed by source hash for repeatable retries; original media is kept.
Signed reads expire after five minutes. The app refreshes URLs and requests a
fresh video URL before playback. It does not claim immediate revocation of a
URL already issued to an authorized reader.

New posts, videos and avatars wait for review. Owner previews show pending or
rejected state; approved revisions are the public version. Text replies and
comments are immediately persisted and remain reportable. A trusted operator
can inspect pending revisions and use `public.bibi_moderate(content_id,
revision_id, approve)` from a privileged server/SQL environment. Never expose
service-role credentials in the app. No automated moderation or human staffing
has been configured by this code deployment.

Realtime events trigger fresh authorized reads. Foreground refresh and an
active-app reconciliation interval also remove data whose membership changes
are no longer visible through Realtime. APNs device registration is wired, but real delivery remains unverified. There is no
peer calling, voice/video transport, fabricated online status, or delivered/read
receipt claim. Messages are marked saved only after the database acknowledges
persistence. Group invite recipients cannot read messages until accepting;
message history starts at their accepted join sequence.

## Verification record

November 4 A full authenticated media readback, isolated business operations,
real bidirectional persistent Realtime and Sandbox-only spending/refunds passed;
exact temporary fixtures were cleaned. Latest B source compiled successfully
without signing as a generic simulator artifact. Eleven offline SQL/Edge
scenario groups passed with controlled substitutes. B SQL/function deployment and exact readback completed after owner approval. No App/simulator launch, iOS tests, original Auth/Socket/
confirmation or actual Apple purchase ran in this task. Authored iOS recovery
tests are not executed evidence. See `IntegrationEvidence/` and the integration
record for precise scope, hashes and initial failures retained honestly.

### Subsequent iOS purchase-chain validation

The owner subsequently authorized the missing actual iOS service-chain checks.
Latest source built, installed and launched on Bibi UI Acceptance; 31 tests passed
with zero failures/skips. The original observer, protected journal, receipt
coordinator, actual URLSession DTO/parser and delivery/finish/recovery logic ran
with isolated system boundaries. This supersedes the earlier no-iOS-test status
for this bounded run. No real payment/live settlement was performed. See
`IntegrationEvidence/B-Purchase-Chain-Verification-2026-11-04.md` for demonstrated
fixes, matrix coverage and remaining device/online/capability limits.
