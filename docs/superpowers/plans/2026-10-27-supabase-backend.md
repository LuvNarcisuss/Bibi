# Bibi Supabase Backend Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task by task. The owner's instruction to continue authorizes implementation; do not repeat design approval. Repository restrictions override skill test/commit defaults.

**Goal:** Replace Bibi's local business behavior with authenticated Supabase services, preparing one complete cutover.

**Architecture:** Keep UIKit and existing feature screens. Add account-scoped service repositories backed by Postgres RLS, transactional RPC operations, private Storage, Realtime, and authenticated Edge Functions. Preserve the original device library separately; keep the release gate disabled until all acceptance criteria and external dependencies are satisfied.

**Tech Stack:** iOS 16+, Swift 5, UIKit, AVFoundation, Supabase Swift, PostgreSQL 17, Deno Edge Functions, StoreKit 2.

**Spec:** `docs/superpowers/specs/2026-10-27-supabase-backend-design.md`, approved by the owner's instruction to continue on October 27, 2026.

## Global Constraints

- Five roots: Shorts / Circles / Challenges / Chats / Me; Shorts is default.
- Bundle `im.seex.sao2-neiku-30`, team `JPTS6M4T5B`; iPhone only.
- English project content; Chinese conversation; retain stable serialized IDs.
- Email/password, explicit 18+ declaration, verification and recovery.
- No build, typecheck, simulator, app launch, or tests without explicit authorization.
- New online modules remain disabled until the complete release gate; no fake online fallback.
- Preserve the pre-existing StoreKit1Purchasing.swift error-message change.
- Only publishable API credentials in the client; secrets remain on the server.

## Review Focus

- Late responses after account switching cannot appear in another account's UI or cache (Tasks 3, 4).
- Membership changes and blocks must deny message access/sends even with stale subscriptions (Tasks 1, 5).
- Retrying after a lost acknowledgement must not duplicate charges, credits, messages, or publications (Tasks 1, 6).
- A failed deletion/upload must remain resumable without deleting private original files (Tasks 2, 4, 7).
- A disabled release gate must never initiate authentication, cloud uploads, or online purchases in the current local app (Tasks 3, 8).

## Task 1: Cloud schema and authorization

**Files:** `BibiApp/Backend/schema.sql`, `BibiApp/Backend/README.md`, `BibiApp/Backend/acceptance.sql`.

**Interfaces:** Auth UUID identifies actors; tables expose owner/member-scoped reads. RPC operations own multi-record mutations and idempotency. Edge-only administrative operations are inaccessible to authenticated clients.

- [ ] Write acceptance scenarios for unauthenticated denial, foreign-owner changes, chat first-contact races, blocked access, and duplicate operations; do not execute without authorization.
- [ ] Define profiles, eligibility, content/revisions/media, circles/memberships, challenges/entries, interactions, follows/blocks, conversations/memberships/messages/preferences, reports, wallet/ledger, and deletion state.
- [ ] Implement constraints, owner/member RLS, restrictive grants, private security helpers, transactional business operations, and private buckets.
- [ ] Inspect existing cloud schema immediately before deployment; apply versioned additive DDL through the Supabase connector. Record the returned migration identity and schema snapshot.
- [ ] Inspect table/policy/grant inventories and security advisors; do not represent this as a runtime authorization test.

## Task 2: Server functions

**Files:** `BibiApp/Backend/functions/{_shared,media-finalize,delete-account,verify-purchase,apple-notifications}/`, `BibiApp/Backend/config.toml`.

**Interfaces:** Authenticated functions verify the user with Auth, reject inactive accounts, and call edge-only database operations. Payment verification returns an authoritative wallet acknowledgement; deletion returns resumable status.

- [ ] Prepare tests for missing/invalid authorization, malformed bodies, forged account IDs, unsupported products, wrong Apple environment, and replay; defer execution.
- [ ] Implement staged object finalization using Storage metadata; fail closed on missing evidence.
- [ ] Implement deletion ordering, access revocation, Storage cleanup, and retry-safe Auth deletion.
- [ ] Implement Apple validation using pinned official server libraries, account binding, unique transaction processing, and refund handling. Missing secrets return explicit unavailable status.
- [ ] Deploy complete functions and record deployment metadata; leave secret-dependent release gates closed.

## Task 3: Client infrastructure and authentication

**Files:** `BibiApp/Bibi/Backend/`, `BibiApp/project.yml`, `BibiApp/Bibi/Support/Info.plist`, generated project metadata.

**Interfaces:** `BackendConfiguration.isEnabled`, `BackendSession` (authenticated account/session generation), `BackendServices` (shared client and repositories), Keychain-backed Auth storage.

- [ ] Pin an SDK release compatible with the available toolchain; retain transitive resolution metadata when available without compilation.
- [ ] Add project origin/publishable key and a false global release gate. Validate configuration; never fall back to another project.
- [ ] Add native auth/recovery handling, exact callback routing, eligibility acceptance, session refresh, and logout.
- [ ] Add account-generation cancellation and account-scoped atomic caches; preserve legacy directories.
- [ ] Inspect client source/configuration and prepare auth/cache tests without executing them.

## Task 4: Content and social repositories

**Files:** `BibiApp/Bibi/Backend/ContentRepository.swift`, `MediaRepository.swift`, `SocialRepository.swift`; existing AppStore/community/Shorts/profile/creation controllers.

**Interfaces:** Typed server models with UUID identity; cursor-based queries; mutation operation UUIDs; pending/approved content revisions.

- [ ] Implement feeds, editorial catalogs, memberships, posting/replies, saves/likes, challenge replacement, profiles/follows/blocks/reports.
- [ ] Implement compressed app-owned upload copies below the configured 50 MB maximum; preserve source files and retry identities.
- [ ] Adapt existing controllers using the single mode gate. Remove authored counters and fictional identities from the online path.
- [ ] Add explicit empty/loading/failure states and preserve composed text on server failure.
- [ ] Prepare validation for private content visibility, ownership, stale signed URLs, revisions, and upload failure cleanup.

## Task 5: Real chat

**Files:** `BibiApp/Bibi/Backend/ChatRepository.swift`; existing chat models/controllers and AppStore chat methods.

**Interfaces:** Conversation membership, server message order, operation UUID, member read position; an account-bound Realtime stream triggers authoritative reconciliation.

- [ ] Implement real inbox/search, direct conversations, invitation acceptance, group membership, and the 50-member limit.
- [ ] Persist sends atomically, enforce first-contact rules server-side, and reconcile subscriptions after reconnect.
- [ ] Represent pending/failed/sent/read accurately; preserve draft text; do not expose retired call features as available.
- [ ] Prepare race/reconnect/member-removal tests and explicit foreign-account denial scenarios.

## Task 6: Authoritative wallet

**Files:** `BibiApp/Bibi/Backend/OnlineWallet.swift`; wallet controllers/models; server product/gift catalog and ledger operations.

**Interfaces:** `purchase(productID:)`, verified server credit acknowledgement, `spendGift(operationID:postID:giftID:quantity:)`; sandbox/production isolation.

- [ ] Preserve all existing product IDs and gift amounts; use server catalog values for credits/debits.
- [ ] Bind StoreKit 2 purchases to Auth UUID and finish only after server persistence acknowledgement.
- [ ] Reconcile transactions without importing local balances; isolate legacy ledger history.
- [ ] Prepare duplicate/refund/wrong-account/concurrent-spend acceptance scenarios; keep real purchasing unavailable until configured and verified.

## Task 7: Account lifecycle, agreements, and archive

**Files:** authentication/profile/settings controllers, `UserAgreement.swift`, bundled agreement HTML/provenance, `LegacyArchive.swift`.

- [ ] Provide native registration/recovery screens with explicit 18+ declaration and versioned consent.
- [ ] Synchronize bundled agreement age clauses; do not mutate remote Google documents.
- [ ] Provide read-only local archive and opt-in per-item import; remote deletion must never erase the unrelated archive.
- [ ] Wire resumable remote account deletion, cache cleanup, session exit, and accurate errors.

## Task 8: Integration, review, and release readiness

**Files:** current implementation/audit docs, `BibiApp/Backend/RELEASE-CHECKLIST.md`, relevant existing sources/configuration.

- [ ] Connect all repositories to the existing five roots while keeping the global gate false.
- [ ] Review all active local-only capability strings and update only the online equivalents supported by implementation.
- [ ] Perform static source/config/resource review, metadata generation if safe, and a fresh independent code review.
- [ ] Fix concrete findings; record what remains unverified and external SMTP/Apple/moderation dependencies.
- [ ] After explicit test authorization only: build latest source, install and launch on `Bibi UI Acceptance`, then execute the recorded acceptance checks.
- [ ] Enable the single release gate only after all modules, credentials, policies, and authorized verification satisfy the design.

## Execution ledger

- Design approved by the owner's instruction to continue.
- Ruling: implement in the current conversation; do not ask again for permission to perform already-authorized backend work. Preserve unrelated changes. Do not commit/push or run test helpers automatically.
- Ruling: repository test prohibition overrides skill RED/GREEN execution defaults. Tests may be authored, but unexecuted checks remain explicitly pending.
- Initial state: public schema empty; project healthy; publishable key available. No business functionality deployed yet.


## Execution update — October 27, 2026

Tasks 1–7 have source implementations and the deployment receipts listed in
`BibiApp/Backend/DEPLOYMENT.md`. Their runtime acceptance criteria remain open;
unchecked original boxes are not claims that tests passed. Task 8 has metadata
and independent static review evidence, but build/runtime acceptance and cutover
are intentionally pending. The single release gate remains false.

- Auth/client: native login/verification/recovery, serialized account requests,
  generation checks, exact callback routing, Keychain, account cache, SDK pin.
- Data/UI: keyset pages, transactional publishing/challenge entry, immutable
  upload retry copies, moderation revision states, comments/replies, real counts,
  approved avatars, reports/unhide, and existing five-tab adapters.
- Chat: persisted messages, real directory, atomic group invitations, recipient
  acceptance, owner management/member leave, account sync and lost-access cleanup.
- Wallet: official Apple server verification, account binding, idempotent credit,
  gift ledger, isolated environments, durable refund tombstones.
- Lifecycle: password-confirmed resumable deletion and opt-in archived-video
  import without touching the original local library or transferring balances.
- Ruling: existing bundled agreements were concurrently updated outside this
  integration and already state 18+. Preserve them and their provenance. Online
  service wording/operator review is an explicit gate rather than silently
  treating local terms as approved online terms.
- Ruling: no independent build/test authorization exists for this backend work.
  The two XCTest boundaries and SQL acceptance scenarios remain unexecuted.
  Keep package resolution/lockfile work with the first authorized latest build.
- Final static review: addressed all eight actionable finding classes (refund
  ordering, stale messages, auth races, pagination, group retry, avatars, group
  management, capability copy). No deferred minor finding was reported. Fixes
  are source-inspected; there is no RED/GREEN or runtime verification claim.
- External release gates: SMTP, Apple secrets/configuration, moderation staffing,
  reviewed online protocols/operator contact, authorized end-to-end acceptance.


## Authorized local verification update — October 27, 2026

The owner subsequently requested a latest-source build, installation, launch and
tests on **Bibi UI Acceptance**, direct fixes, and retention of the disabled gate.
This supersedes the earlier no-test-authorization ruling for this run.

The build/install/launch requirement is complete. Compilation exposed a chat
cursor SDK type mismatch and an export cancellation concurrency warning; both
were corrected and the rebuilt app launched successfully. The resolved Swift
package graph is retained. Callback/cache and disabled-gate tests passed; see
`docs/BACKEND-RUN-VERIFICATION.md` for the full results and evidence. Database,
Edge and live online acceptance remain open. The single gate remains false.
