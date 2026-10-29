# Bibi Supabase Backend Design

Date: October 27, 2026 (Asia/Shanghai)
Status: Proposed design; implementation and cutover are not complete.

## Confirmed decisions and infrastructure

The owner requested replacing Bibi's local simulated behavior with a real backend, selected a single cutover after all modules are complete, and selected email/password authentication. The owner subsequently selected an 18+ minimum age and authorized aligning registration eligibility and local agreement age clauses. The owner authorized creating Bibi in `LuvNarcisuss's Org` at the quoted project cost of $0 per month. That quote is not a commitment to unlimited usage or free third-party services.

- Organization: `gwnugmhdrcxecfbujcvr`
- Project: `yepycfnkkfrfmuwdekka`
- Dashboard: https://supabase.com/dashboard/project/yepycfnkkfrfmuwdekka
- API origin: https://yepycfnkkfrfmuwdekka.supabase.co
- Region: `ap-southeast-1` (Singapore), selected by the implementer as the initial deployment default.
- Creation and subsequent project lookup both returned `ACTIVE_HEALTHY`.
- Read-only discovery returned no public tables and no Edge Functions. The initial security advisor returned no findings; this is an empty-project baseline, not application security verification.

No application code, database schema, authentication settings, payment settings, or user data were changed during discovery. No build, typecheck, simulator launch, or runtime test was performed.

## Intent, scope, and constraints

Preserve Bibi's anime theme, UIKit screens, navigation, iPhone-only support, iOS 16 minimum, Swift 5 language mode, bundle ID `im.seex.sao2-neiku-30`, team `JPTS6M4T5B`, schemes, existing product identifiers, and five roots: Shorts, Circles, Challenges, Chats, Me. All authored project content remains English.

The completed online mode must use authenticated identities, durable cloud records, server-enforced access rules, and real message persistence. It must not generate fictional users, conversations, relationships, engagement counts, delivery receipts, review approvals, or transaction success.

Keep Live, Voice rooms, and Phrases retired. Supabase is not an audio/video calling service. Existing call controls must be unavailable with accurate messaging until a separately configured RTC service exists; RTC integration is outside this backend migration. Do not add a shop, creator payouts, or diamond tipping to Shorts. Existing circle gifts remain a paid effect/activity purchase, not a payout or transfer to a creator.

Existing source media and private device data must remain intact. Do not bulk upload local videos, messages, profiles, or local wallets on first sign-in. Do not change historical serialized keys just to rename local implementation terminology.

## Approaches

1. Staged cutover: ship authentication/community/chat before wallet integration, with distinct capability boundaries. This reduces each deployment's scope but creates a mixed service experience. This was proposed and not selected.
2. Single cutover: prepare all repositories, server operations, and screens behind one application mode; enable the online experience only after the complete release gate. This is the owner's selected approach. It requires SMTP, Apple integration, and authorized runtime verification before claiming a complete switch.

Implementation can proceed in dependency order while the release remains atomic. Do not expose per-module switches to product users. Do not automatically fall back from a failed online request to the fictional local catalog. Deployment of preparatory server resources does not itself switch the app.

## Current source seams

| Current source | Required change |
| --- | --- |
| `BibiApp/Bibi/App/AppStore.swift` | Replace consent-based session entry with authenticated session state; coordinate remote repositories and account-scoped caches. |
| `BibiApp/Bibi/App/BibiApplication.swift` | Add native sign-in, registration, verification, recovery, and authenticated root routing. |
| `BibiApp/Bibi/Data/LocalLibraryRepository.swift` | Preserve legacy data and atomic writes; separate remote account caches from the legacy device library. |
| `BibiApp/Bibi/Features/Circles/AppStore+Community.swift` | Use authoritative post, reply, membership, save, and challenge operations. |
| `BibiApp/Bibi/Features/Chats/ChatModels.swift` | Replace fictional catalog identities and messages with remote DTOs; keep old snapshots decodable. |
| `BibiApp/Bibi/Features/Shorts/ShortsInteractionStore.swift` | Remove authored counts/comments from online mode; read server totals and persist real interactions. |
| `BibiApp/Bibi/Features/Wallet/StoreKit1Purchasing.swift` | Replace local credit decisions with verified server transaction processing and durable acknowledgement. |
| `BibiApp/Bibi/Features/Wallet/WalletStore.swift` | Read authoritative balance/activity; perform idempotent atomic server spending. |
| `BibiApp/Bibi/Features/Safety/ContentSafety.swift` | Use stable account IDs, cloud blocks, report records, and truthful moderation status. |

The repository documentation includes an R2 migration record, but the inspected `project.yml` still references root `Assets` files. Treat current source/configuration as authoritative; do not silently include an unrelated asset-delivery migration.

## Client architecture and authentication

Use the official Supabase Swift SDK through Swift Package Manager, selecting and pinning a release compatible with the project's current toolchain and deployment target. Pin the resolved dependency graph. Use small service interfaces for authentication, community, media, relationships, chat, moderation, and wallet; the existing UIKit controllers consume `AppStore` state and retain their design system.

Store only the project origin and an enabled publishable key in the app. Never bundle service-role credentials, SMTP credentials, Apple signing keys, or administrative tokens. Store refresh credentials in Keychain with device-local protection and clear them on logout/deletion. Do not log passwords, tokens, receipt payloads, or message bodies.

Authentication includes email/password signup, email verification, sign-in, explicit resend, password reset, password update, session refresh, logout, and remote account deletion. Keep email confirmation enabled. Record agreement acceptance independently of authentication. A registration response without a session must display verification instructions, not open an authenticated session.

Registration requires an explicit 18+ eligibility declaration, with the selected
agreement version and declaration timestamp recorded for the authenticated
account before business access. This is a self-declaration, not verified age.
Do not collect a date of birth or introduce identity verification. Update the
bundled local agreement age clauses consistently; do not edit the remote source
Google documents without a separate instruction.

Proposed callback scheme: `bibi://auth/callback`, with an exact allowed callback configured in Supabase and the app. Use the SDK's documented PKCE handling; reject unexpected URLs and missing/invalid flow state. Test recovery and confirmation links separately, including cold launches and expired links. Do not add Apple login in this scope.

Session state is explicit: signed out, awaiting verification/recovery, restoring, signed in, expired, and deletion pending. Every remote result is tagged with an account/session generation so a late response cannot mutate the next account's UI. Cancel subscriptions, uploads, and requests during account exit. Cache directories are keyed by authenticated UUID; personal cache visibility ends on logout.

## Data and access model

Use UUIDs for accounts, user-generated content, conversations, and operations. Preserve stable editorial circle/challenge IDs and catalog video IDs where those records are explicitly published. Use server timestamps, foreign keys, uniqueness constraints, length/size checks, and indexes for foreign keys, owner filters, feed ordering, and membership lookups. Paginate with stable `(created_at, id)` cursors.

| Records | Authority and access |
| --- | --- |
| Profiles and agreement acceptances | Auth UUID is identity. Users update permitted own profile fields; email stays in Auth. Acceptance records belong to their user. Editorial authors are distinct from real accounts. |
| Circles, challenges, editorial content | Server-managed catalogs. Authenticated users read active entries; only administrative tooling changes editorial records. |
| Memberships and saved items | Unique per user/target; owner-scoped mutation and reads. |
| Videos and media assets | Owner-only while uploading/pending; published content visible to eligible signed-in users. Media status cannot be promoted by an arbitrary client write. |
| Posts, replies, video comments | Authors create/edit/delete their own records subject to membership, ownership, block, moderation, and length constraints. Parent visibility is required. |
| Challenge entries | One entry per `(user_id, challenge_id)`; only own eligible videos; replacement keeps the original video. |
| Likes and shares | Unique likes per user/video. Totals derive from actual records. Share counts mean recorded share actions, not proof that another person received anything. |
| Follows and blocks | Actor-owned edges; deny self relationships. Enforce blocks on both sides of direct interaction. Never derive incoming follows from local catalogs. |
| Conversations, memberships, messages | Only members can read. Atomic server membership and send operations enforce access and relationship limits. |
| Conversation preferences and read positions | Each member owns their pin/mute/hidden preferences and read position. |
| Reports and moderation actions | Reporter can submit/read own report status. Only server administration handles decisions; reporters cannot self-approve content. |
| Wallet, transaction ledger, gift activity | Owner-readable; no direct client credit/debit writes. Server verification and transactional spending are the only mutation routes. |
| Deletion jobs and account status | Server-managed, idempotent, private records used to resume cleanup and deny new operations. |

Enable RLS on every exposed table and explicitly grant only required privileges. UPDATE policies include both `USING` and `WITH CHECK`. Do not use user-editable metadata for authorization. Prefer invoker functions; necessary privileged helpers live in a private schema, use a fixed search path, validate actor/session/arguments, and revoke default public execution. Keep internal tables inaccessible through client APIs. Any exposed aggregate views must preserve RLS, including blocked or unpublished content visibility.

For mutations with multiple dependent records, use transactional server operations rather than client-side chains. Unique operation IDs make retries safe. Reusing an operation ID with a different payload is an error, not a successful replay. Serialize balance changes and first-contact chat limits so concurrent requests cannot bypass them.

## Content, media, and moderation

Keep the existing four editorial circles and four challenge briefs. Initial online content may include licensed Bibi editorial media with source/license provenance and stable IDs, but fictional human profiles, comments, follower counts, and conversations must not be imported as real activity. Editorial media must not masquerade as user uploads.

Use private Storage buckets for avatars, post images, and videos. Object paths include the owner's authenticated UUID and a unique asset ID. New uploads create owner-only staging records. A finalize operation verifies actual object metadata, type, size, and owner before attaching media. Clients cannot turn an arbitrary object path into a published asset. Signed URLs expire and are reissued only after visibility checks; document their bounded revocation window. Deletion and moderation withdraw visibility and remove/revoke media through Storage APIs.

Free-plan Storage allows a maximum file size of 50 MB. Proposed default: preserve the existing 250 MB local-import limit, create an app-owned compressed upload copy below 50 MB, retain the source, and fail clearly if the copy still exceeds the configured bucket/project limit. Keep challenge/Shorts duration at 180 seconds and circle-photo processing at 1,200 pixels and 1 MB. Do not upgrade the plan or move private uploads into a public R2 bucket without authorization. Video encoding performance and quality require runtime verification before cutover.

Publishing user media is an explicit action. Upload progress, failed transfer, pending review, and published are distinct states. Initial moderation is a real server review queue, operated through restricted administrative tools/Supabase Dashboard; it is not an automated review promise. Proposed review scope: videos, circle posts, and custom avatars require approval before public display. Profile display names/biographies, text comments/replies, and private messages become visible after server validation and authorization, with reporting and blocking available. Private messages are not held in the public-content review queue. A challenge entry becomes public only when its referenced video is approved. An actual operator and operating process are release dependencies. Reports are stored remotely and hide the reported content for the reporter immediately; global removal depends on a server decision.

Changes to approved videos, posts, or avatars create a pending revision while the last approved revision remains visible. Authors can withdraw the published version immediately. A moderator removal suppresses every public revision until an explicit subsequent approval. Store immutable revision identifiers and separate draft/approved references; a client edit must not overwrite an approved payload. New profiles use a bundled neutral avatar until a custom avatar is approved.

Local safety restrictions remain effective on legacy content. Online blocks and reports use authenticated identities and stable content references, including Shorts comments; display names must never serve as identity keys.

## Chat behavior

Only real users and memberships populate the online inbox. Preserve the current relationship rule: one first-contact message is allowed without mutual following; subsequent messages require mutual following. Apply it per sender/recipient pair across conversation recreation, in a locked server transaction. Both-direction blocks stop direct sending and new invitations.

For groups, the proposed default is to invite mutual followers, require acceptance before access, and permit members to leave. Group owners manage invitations/removal through authorized server operations; clients cannot insert arbitrary memberships. Membership establishes the visibility interval; joining does not expose history from before acceptance. Define and enforce a 50-member cap for the initial implementation.

Persist messages before publishing a successful send. Store a client operation UUID and server sequence/order key. `Pending`, `Failed`, and `Sent` reflect actual states. `Sent` means saved on the server; only explicit recipient read-position updates can establish read state. Do not show delivered receipts without a recipient acknowledgement mechanism.

Realtime is a notification channel, not the durable source of truth. Subscribe only to authorized records, deduplicate by stable message ID, and reconcile with paginated reads after reconnect or foregrounding. Revoke stale subscriptions on session expiry, logout, membership loss, or deletion. Recheck access on every fetch. Background push notifications and online-presence claims are outside this initial migration; foreground realtime and persisted catch-up are included.

## Wallet and Apple transactions

Preserve all seven existing product identifiers and diamond quantities in `Info.plist` and `WalletCatalog`, plus the existing nine gift identifiers/prices and quantities 1/5/10. The server owns the product-to-credit and gift-to-cost mappings. The client cannot provide an authoritative amount, user ID, price, balance, or verification result.

Use StoreKit 2 transaction evidence with `appAccountToken` bound to the authenticated UUID for new online purchases, while retaining a recovery path for legacy StoreKit 1 records. An Edge Function verifies Apple evidence using supported Apple verification facilities, validates certificate/signature or authoritative server response, bundle/product/environment, quantity, account binding, revocation, and transaction uniqueness before calling a private transactional credit operation. Sandbox and production ledgers are isolated; local Xcode StoreKit fixtures never credit production. Missing Apple configuration fails closed before starting a purchase.

Finish a successful StoreKit transaction only after a durable server acknowledgement. Retry timeouts with the same transaction identity. One Apple transaction can credit only one authenticated account once. Refund/revocation processing is idempotent; keep reversal entries and an auditable adjustment state. If spent funds make reversal impossible, freeze further spending for reconciliation rather than silently granting credits or allowing an invalid balance.

Circle gift spending atomically checks the authenticated balance, exact gift/quantity, current post visibility, block status, moderation state, and prohibition on self-gifting. It debits and creates one activity record in the same transaction; the client animates only after acknowledgement. No credit is paid to the post author.

Keep the legacy wallet unchanged and locally readable as historical activity. A new cloud wallet begins from independently verified server credits. Do not infer a cloud entitlement from a local JSON balance or blindly re-credit old transaction IDs. Legacy balance reconciliation requires authenticated Apple evidence and review of historical spending; unresolved entries remain a separate archive without becoming spendable online credits.

Apple App Store Server API credentials and server notification configuration are external prerequisites. Store private keys as server secrets, never in this repository or chat. Implement what does not depend on credentials first, but keep the global cutover closed until the complete wallet path is configured and verified.

## Legacy data and account deletion

Create a durable, versioned preservation record before online cutover. Retain the existing device library and wallet in place or an atomically created archive; never overwrite unreadable data. Provide a read-only legacy archive from existing Settings, including original media and historical balances. It is device-private and does not automatically belong to any newly signed-in account.

Importing eligible old content is opt-in per item and uses the regular publish/upload path with the same stable source identifiers and idempotency checks. Do not import fictional social activity or submit old pending messages. Online cache/schema changes never reset or delete the archive. Remote account deletion must not remove the unrelated legacy archive; an explicit local-data deletion remains separately labeled and confirmed.

Remote account deletion requires recent authentication, creates an idempotent deletion job, denies further service access, revokes refresh sessions, and removes profile/content/memberships/media/auth identity with resumable cleanup. Sensitive operations must reject the account status even if an old JWT has not expired. Storage cleanup precedes Auth deletion where required; retries resume after partial failures. Other participants see tombstones rather than leaked deleted-profile data. Financial evidence retention and operator policy need explicit documentation before public release; do not promise immediate deletion of records that must be retained.

## External dependencies and release gate

1. Configure production-capable SMTP, a verified sender, and the exact Auth redirect allowlist. Supabase's default sender is restricted to project-team addresses and is not suitable for public email registration. Do not disable confirmation to bypass this limitation.
2. Supply Apple server-side credentials/configuration and verify the unchanged products against the actual app. No credentials should be pasted into committed files.
3. Assign the moderation operator/process and finalize user-facing privacy/terms for real uploads, messaging, cloud retention, deletion, and purchases. Existing draft operator/contact gaps are not solved by creating a backend.
   The owner resolved the source agreements' age conflict by selecting 18+.
   Synchronize local age clauses and registration eligibility with this decision.
4. Keep app release mode unchanged until authentication, every online module, media permissions, deletion, and wallet verification pass the agreed checks.
5. Request runtime-verification authorization separately. Current authorization covers creation and backend implementation, not app builds or tests. Every authorized test run must build current workspace source, install it on `Bibi UI Acceptance`, and successfully launch it there, as required by repository rules.

## Planned verification (not executed)

Static checks: configuration alignment, English copy, secret exclusion, RLS/grant/privileged-function review, indexed policy filters, foreign keys and uniqueness, immutable identifiers, dependency pinning, removal of online catalog fallbacks, and Supabase security/performance advisors.

After test authorization: use separate real test identities to check email verification/recovery, cross-account cache isolation, unauthenticated/foreign-account denial, forged ownership and moderation fields, block and membership enforcement, expired sessions, concurrent first messages, retry deduplication, media ownership and upload failure recovery, account deletion resumption, reconnect catch-up, and all five screens on the required simulator.

Payment verification must separately report local StoreKit Test, Apple sandbox, and production evidence. Include duplicate callbacks, wrong bundle/product/account/environment, invalid signatures, pending/cancelled/failed purchases, concurrent spends, insufficient funds, lost acknowledgements, and refund reversal. Never count a static review or historical test run as a passed runtime check.

## Decisions left to implementation

The implementer may choose internal DTO names, repository decomposition, compatible pinned SDK version, indexes, cursor sizes, backoff limits, Keychain wrapper, upload transport, and private SQL helper structure. Changes to cost, product scope, identity/signing configuration, all-at-once cutover, email/password authentication, or legacy-data preservation require returning to the owner.

The group invitation/history cap, compressed upload copy, manual moderation workflow, legacy archive access, and StoreKit 2 integration above are proposed implementation decisions for review, not historical owner requirements.

## Independent design review

A read-only engineering review identified two material questions: moderation
scope/revision visibility and the conflicting minimum ages in the agreements.
The moderation scope and revision behavior are now explicit proposed defaults
above. The owner answered the age question with 18+, now recorded in this design.
This review evaluated planning completeness, not code correctness or runtime
behavior.

## References

- https://supabase.com/docs/guides/auth/passwords
- https://supabase.com/docs/guides/auth/auth-smtp
- https://supabase.com/docs/guides/storage/uploads/file-limits
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/realtime/postgres-changes

These references were consulted during design. SDK/API and Apple verification details must be checked against current primary documentation before implementation.
