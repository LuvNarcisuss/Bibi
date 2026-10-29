# Bibi backend

The backend is provisioned in `LuvNarcisuss's Org` as project
`yepycfnkkfrfmuwdekka`, region `ap-southeast-1`, at the owner's accepted
$0/month project quote. No paid upgrade was requested. Quotas and external
SMTP/Apple services are separate release considerations.

The application has one `BibiBackendEnabled` Info.plist gate, currently **false**.
Do not enable it until `RELEASE-CHECKLIST.md` is satisfied. The existing local
experience remains active. Deployment and static inspection are not evidence
that the iOS app compiles or that end-to-end operations work.

## Applied database sources

Apply these files in order when reconstructing an empty project. The connected
project already contains these migrations; do not replay them against it.

1. `schema.sql` — authoritative tables, scoped grants, RLS, command journal,
   Storage policies, wallet ledger, and service-only administrative RPCs.
2. `hardening.sql` — missing indexes, explicit private deny policies, editorial
   circle/challenge catalogs. There are no fabricated member accounts, messages,
   published media, engagement totals, or wallet credits.
3. `client-read-policies.sql` — recipient-visible invitation metadata,
   independently counted profile relationships, and reversible report hiding.
4. `atomic-client-commands.sql` — atomic group creation/invitations and combined
   video publication/challenge entry.
5. `refund-ordering.sql` — durable Apple revocation tombstones, including
   notifications that arrive before a purchase is first credited.
6. `comment-threading.sql` — real comment reply targets, preserving the previous
   command changes.

7. `guest-auth.sql` — anonymous account eligibility with adult consent and live
   session checks; preserves existing ownership policies.

Twenty public business tables and six private tables have RLS enabled. Clients
receive read access through RLS and scoped command RPCs; they cannot directly
write balances, moderation decisions, transactions, or other users' records.
An active session requires a genuine anonymous account or verified email,
explicit adult consent and a live Auth session. Command UUIDs are durable retry identities; a reused UUID with
changed parameters is rejected. The app's account-specific journal is separate
from the old local library.

## Pending wallet catalog extension

`wallet-products.sql` adds the owner-approved 16,800 and 42,700 diamond products.
Apply it after the seven existing SQL sources for both fresh and existing setups.
It is prepared but not deployed, preserves existing products and balances, and
rejects a conflicting mapping instead of overwriting it. Apple registration of
the new IDs remains required; see `../../docs/PURCHASES.md`. The backend gate
remains false.

## Edge Functions

| Function | Authentication | Behavior |
| --- | --- | --- |
| `media-finalize` | Supabase JWT plus current user/session checks | Validates immutable uploaded image/video bytes before marking media ready |
| `delete-account` | Supabase JWT and password confirmation | Locks business access, revokes sessions, removes account Storage, then deletes Auth identity |
| `verify-purchase` | Supabase JWT plus current user/session checks | Validates Apple evidence, queries Apple for current transaction state, then credits once |
| `apple-notifications` | Apple signed payload; Supabase JWT intentionally disabled | Records verified refunds/revocations and adjusts authoritative balances |

All four functions were returned ACTIVE, version 1, by the deployment inventory.
No function request, account flow, or purchase was runtime-tested. Deno imports
are pinned to `@supabase/supabase-js@2.57.4` and the official
`@apple/app-store-server-library@3.1.0`.

Required Apple server secrets (never ship these in the client):
`APPLE_PRIVATE_KEY`, `APPLE_KEY_ID`, `APPLE_ISSUER_ID`, `APPLE_APP_ID`,
`APPLE_ROOT_CA_BASE64_JSON`, and `APPLE_ALLOWED_ENVIRONMENTS`.
The certificate value is a JSON array of base64-encoded Apple root DER
certificates. Obtain certificates from Apple, validate their provenance, and
configure them directly in Supabase Secrets. The user has not supplied this
configuration. Missing or invalid configuration fails closed.

The iOS client currently selects `Production`. For authorized Apple Sandbox
acceptance, explicitly select `Sandbox` in `BackendConfiguration.environment`
and configure that server environment. Ledgers and transaction identities are
separated by environment. Local StoreKit configuration transactions are not
accepted as Apple-signed server evidence. Restore Production before distribution.
Never make production accept arbitrary environment values or local test receipts.

## Authentication and account lifecycle

The client pins Supabase Swift 2.30.0 and uses PKCE with device-only Keychain
storage. Allowlist exactly `bibi://auth/callback` and `bibi://auth/recovery` in
Supabase Auth, require email confirmation, and configure working SMTP before
public registration. Email links must be opened on the iPhone that initiated
the PKCE flow. This configuration has not been verified with real delivery.

Authentication requests are serialized and asynchronous results are bound to
an account generation. Account exit clears visible online state and cancels
subscriptions. The device archive is read without running legacy migrations
or cleanup; it is never uploaded or credited automatically. Per-video import
requires explicit confirmation. Remote deletion does not erase original Photos
files or the independent device archive.

If deletion fails after locking the account, the sign-in screen exposes Resume
account deletion with email/password. Operators must reconcile private
`deletion_jobs` against Auth/Storage after interrupted cleanup; a missing
`completed_at` alone is not proof that Auth deletion failed. Apple transaction
and revocation evidence is intentionally retained for reconciliation.

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
are no longer visible through Realtime. There is no APNs push integration,
peer calling, voice/video transport, fabricated online status, or delivered/read
receipt claim. Messages are marked saved only after the database acknowledges
persistence. Group invite recipients cannot read messages until accepting;
message history starts at their accepted join sequence.

## Verification record

See `DEPLOYMENT.md` for actual deployment receipts and
`../../docs/STATIC-AUDIT.md` for source/configuration evidence. Swift boundary
tests in `../Tests/Backend/` and scenarios in `acceptance.sql` are authored but
**not executed**. The owner has not authorized compilation, typechecking,
simulator use, or tests for this integration. Swift package resolution and
transitive lockfile generation remain part of the first authorized build.
