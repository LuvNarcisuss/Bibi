# A backend completion review — November 4, 2026

Project: `yepycfnkkfrfmuwdekka`. Scope: existing business RPCs, wallet spending,
conversation authorization and Supabase Realtime invalidation. Agreements and
purchase verification were not edited. `BibiBackendEnabled` remains false.

## Deployment status

- Applied: `20261104015945 bibi_realtime_snapshot_invalidation`, sourced from
  `../realtime-invalidation.sql`. Adds only `bibi_content_revisions`,
  `bibi_conversations` and `bibi_profiles` to the existing publication.
- Applied: `20261104020757 complete_a_spending_and_retire_gifts`, from the
  owner-approved frozen `../online-spending.sql`, SHA-256
  `2f47bfe06d52ee6db9329157946e7ee4dd18f884be61d43014282874f17a0ee3`.
- Applied: `20261104020808 membership_event_privacy`, from the owner-approved
  frozen `../membership-event-privacy.sql`, SHA-256
  `1ebac202c557b93b4ce1a6b3392a688118621b2a3f0ee4b4e8a9705d9b3ecce1`.

Earlier automatic review rejected financial deployment because production wallet,
refund and SECURITY DEFINER changes were not explicitly approved, then rejected
an updated exact version and the independent membership-key change. The owner
subsequently approved BOTH frozen hashes explicitly. The parent agent then applied
both migrations with success receipts. A fresh migration inventory and definition,
constraint, RLS and trigger readback confirmed them. These earlier approval blocks
are resolved; no indirect execution bypass was used and frozen sources were not
changed after the precise approval.

## Initial deployed differences, now corrected

1. The initial deployed `bibi_private.command` implemented post gifts. The client
   and current local command sources reject them. Therefore a direct authenticated
   RPC could spend diamonds on a post. Deployed SQL now rejects this branch.
2. Initial `unhide_report` matched only a content ID. Local client behavior also
   permits unhiding a reported profile. Deployed SQL adds the matching
   owner-scoped profile branch without deleting the moderation report.
3. The initial challenge action created/replaced an entry without a diamond
   charge, while existing product UI quotes 100 diamonds and a withdrawal refund.
   Existing online cosmetic calls were unavailable. Deployed SQL adds the
   actual account-owned server authority; it does not create credits or simulate
   purchase results.

Read-only preconditions against the live command all matched: action dispatcher,
new-video challenge insertion, existing-video insertion, challenge withdrawal,
gift branch, content-only report unhide, and deployed comment `reply_to` support.
The applied patch preserves unrelated deployed command code and fails if its
expected fragments are missing.

## Deployed financial behavior and source review

- `bibi_cosmetics` has owner-only SELECT RLS, no client table writes, and a
  `(user_id, environment)` foreign key to the existing wallet. Ownership and
  equipment are isolated between Sandbox and Production.
- Prices come only from a private server catalog. All 16 ID/kind/price tuples
  exactly match `CosmeticCatalog`; the challenge fee matches its value of 100.
  A preexisting catalog price/category conflict aborts the migration.
- Unlocking an already owned item equips it without another charge. Equipping
  Classic is free. Equipping an unowned item or wrong category fails. Frozen or
  insufficient wallets cannot fund new unlocks/entries.
- The existing operation receipt and actor advisory lock serialize commands.
  Wallet rows are locked for debits. Mutation, charge, receipt and entitlement
  update share the original SQL transaction; an exception rolls back all of them.
- A private `(user_id, challenge_id)` payment proof records the original wallet
  environment. Replacements are free, cross-environment management is rejected,
  and only an existing payment proof can produce a refund.
- An entry DELETE trigger deletes the proof before crediting its recorded wallet.
  This makes explicit withdrawal and video-delete cascades refund at most once.
  Withdrawing/removing a source video deletes its challenge entries in the same
  transaction and triggers refunds. An account deletion does not recreate a wallet.
- No legacy device balance or entitlement is imported. Existing server entries
  without a payment proof cannot mint a refund. Their first paid replacement uses
  the current fee. Purchase verification, Apple credits and revocations are unchanged.

The finite checks recorded below supplement source review. Sequential positive
and negative transaction paths were exercised; this is not a concurrency stress
or production load result. Production credits and Apple transactions were never
fabricated. A separate isolated Sandbox-only fixture is described below.

## IM implementation and limitations

The current client send path is `AppStore.sendChatMessage` → `remoteMutation`
→ `ContentRepository.mutate` → `BackendServices.command` → `bibi_command` →
`bibi_private.command('send')` → persistent `bibi_messages`.
The sender is derived from `active_actor()`, not accepted from client fields.
The operation UUID is the persistent message UUID; a changed payload for the same
operation is rejected. Direct first-contact limits and group membership are
enforced by the server. Message reads also require active membership, a live Auth
session, 18+ consent and block checks. Group history starts after `joined_sequence`.

The deployed Postgres Changes publication already included `bibi_messages`,
`bibi_content` and `bibi_conversation_members`. Message delivery uses this
publication rather than B's external Socket. The client registers listeners
before subscription and reconciles messages by persistent ID through RLS reads.
Client reconnection/error handling is being updated separately in this work.

All six published tables use DEFAULT replica identity. DELETE events do not have
ordinary row-level authorization filtering. Newly publishing follow/block tables
was deliberately avoided because their composite primary keys reveal relationship
edges. The initial membership DELETE metadata exposed the
`conversation_id/user_id` composite key during account-deletion cascades. Normal
leave/remove operations use UPDATE and retain RLS filtering. Removing that table
without a replacement would reduce membership invalidation behavior, so no such
change was silently applied. The applied narrow privacy migration assigns an
opaque UUID primary key while preserving UNIQUE `(conversation_id,user_id)`.
Live metadata inspection found no foreign keys referencing the old primary key.
Existing command upserts target `(conversation_id,user_id)` and remain supported;
the Swift member decoder ignores the new field, and pagination continues using
the same unique composite pair. This changes DELETE metadata to an opaque row
ID instead of a conversation/user relationship. It does not guarantee immediate
revocation of all metadata already known to previous members. The source includes
drift guards and requests a PostgREST schema reload. Fresh readback confirms
PRIMARY KEY `(id)` and UNIQUE `(conversation_id,user_id)`. Actual member-table
DELETE payload selection has not been directly captured in a transport check.

The platform's [Postgres Changes documentation](https://supabase.com/docs/guides/realtime/postgres-changes)
confirms that DELETE events do not apply normal RLS checks. Replica identity
FULL was deliberately avoided. Existing publication membership is preserved.

The owner authorized bounded remote API, media and real Realtime checks with
isolated users and cleanup. Evidence is retained separately:

- `a-api-im-verification.json`: first full run passed empty-personal state,
  bootstrap, all 56 catalog records, 7 editorial profiles and all 43 private media
  byte hashes/MIME/range/expiry checks, but the first message event timed out.
  Its three temporary users and exact orphan conversation were cleaned.
- `im-diagnostic-1.json`: the restricted-shell attempt failed DNS before creating
  any account. This is an environment failure, not a backend result.
- `im-diagnostic-2.json`: actual authenticated REST worked, but immediately before
  JOIN the SDK had a session token and no Realtime token. The channel reported
  SUBSCRIBED with a binding ID, then its Postgres extension explicitly failed:
  `invalid column for filter conversation_id`. Live `subscription_check_filters`
  checks the claims role's column privileges; anon has no SELECT on that column,
  authenticated does. The JS SDK 2.57.4 source postpones its first `setAuth` until
  after channel JOIN. This isolated the first-JOIN authentication timing defect.
- `im-diagnostic-3.json`: the single change `await realtime.setAuth(session.access_token)`
  before JOIN produced actual `system/postgres_changes status=ok` and authenticated
  subscriptions containing a session_id. Bidirectional real message events and
  persistence, duplicate/conflicting operation behavior, reconnect catchup/history
  races, nonmember and sender/read-state forgery denial, real read progress,
  invitation history boundaries, removal read/send denial, private PNG upload /
  finalize / owner-only signing, and block revocation all passed. The post-removal
  no-new-event observation was bounded to 900 ms; this is not a universal delivery
  or latency guarantee. Three users were deleted via `delete-account`, two exact
  orphan conversations were deleted through the authorized admin connector, and
  subsequent users/rooms/messages/media counts for those fixtures were all zero.
- `business-verification.json`: a separate business-only run passed profile
  save/public readback; circle join/leave; owner-scoped save/like add/remove;
  content/profile reports and unhide preserving the report; pending post
  publish/edit/withdraw with nonowner content/revision denial; approved comment
  and reply publish/edit/withdraw with cross-user readback; an actual own MP4
  upload/finalization and pending visibility; zero-balance unlock, challenge and
  combined publication failures with no balance, entitlement, activity, entry or
  partial-content mutation. The run exited zero with all three accounts deleted;
  scoped Auth/content/media/Storage cleanup counts were then all zero.
- `spending-verification.json`: one new isolated anonymous account, with both
  wallets initially zero and profile `Acceptance Sandbox Spending`, uploaded a
  hash-checked licensed catalog MP4 into its own private path and finalized it.
  A guarded administrator UPDATE installed 1,200 temporary test units only in
  this exact account's Sandbox wallet. It required the matching temporary name,
  recent anonymous Auth creation, baseline zero, unchanged Production zero and
  no wallet activity. This fixture is not an Apple credit or purchase result.
  Real server operations then passed one-time 200-unit unlock, owned/retried
  unlock without a second debit, free Classic/owned equip, 100-unit challenge
  debit, free replacement/retry, cross-environment refund denial, exactly-once
  withdrawal refund, source-video withdrawal refund, and hard-delete cascade
  refund. The latter deleted only the exact temporary video owned by this exact
  temporary account. Final activity contained three challenge debits and three
  refunds, with no credit/gift/reversal activity and Production still zero.
  The account was immediately deleted through the real deletion function;
  scoped Auth/profile/wallet/activity/cosmetic/payment/content/media/Storage and
  Apple-transaction counts all read back zero. No funding fixture remains.

The parent applies the same explicit token-before-JOIN ordering to the locked
Swift SDK. Backend evidence does not establish iOS UI or device acceptance.
No purchase, fabricated wallet credit, RTC, Presence or push result is claimed.

## Checks actually performed

- Read live function definitions, RLS policies, publication members, replica
  identities, message constraints and migration inventory.
- Confirmed all seven precise command-patch preconditions using SELECT only.
- Compared all 16 cosmetic catalog tuples and the challenge fee against Swift
  with a static text comparison; they matched.
- Inspected persistence, consent, send authorization, retired gifts and account
  deletion call chains. No secrets, full tokens or private messages were exported.
- `git diff --check` reported no whitespace errors at the time of review.

Remote checks above were actually executed under the owner's explicit bounded
backend authorization. This agent did not build or launch an iOS application,
simulator, Preview or iOS tests. Parent build evidence is recorded separately.
Positive spending was exercised only with isolated Sandbox test units as above;
Apple Sandbox purchases, production purchases and live product availability
remain unverified. No real purchase or verified Apple credit was claimed.
Security advisors returned only anonymous-sign-in policy warnings, including
private false policies; these are not a clean-advisor result. Policies and grants
remain scoped to actual guest accounts, live sessions and ownership. See
[anonymous sign-in advisory guidance](https://supabase.com/docs/guides/database/database-advisors?queryGroups=lint&lint=0012_auth_allow_anonymous_sign_ins).
