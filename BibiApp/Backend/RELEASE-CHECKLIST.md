# Single-cutover release checklist

Keep `BibiBackendEnabled=false` until every applicable item below is satisfied.
The owner selected one cutover after all modules are complete and a minimum age
of 18. On October 28 the owner replaced the normal email/password entry with
one-tap anonymous sign-in, following Toti. SMTP is not required for this flow.
Apple server keys and the remaining release dependencies are still pending.

## External configuration

- [x] Enable anonymous Auth in the Bibi project; public settings confirm it.
- [ ] Verify real guest creation/enrollment, secure session restoration, isolation,
  logout warnings, and interrupted account deletion on Bibi UI Acceptance.
- [ ] Review anonymous-signup rate limits and abuse prevention before public release.
- [ ] If email account linking/recovery is exposed, configure SMTP and verify
  exact callback/recovery links before claiming that optional flow works.
- [ ] Configure Apple server Secrets without putting private keys in chat or
  source control. Validate all nine product IDs for this Bundle ID; preserve the
  original seven and register the two additions listed in `../../docs/PURCHASES.md`.
- [ ] Apply `wallet-products.sql` and read back all nine product/diamond mappings
  before online purchase acceptance. This supplemental catalog is not deployed.
- [ ] Register the signed Apple notification endpoint and verify Sandbox and
  Production isolation, refunds, revocations and transaction reconciliation.
- [ ] Assign moderation operators and a report/deletion escalation process.
  Database RPCs alone do not provide staffing or response-time guarantees.
- [ ] Review and publish the online service/privacy wording, legal operator
  identity and support contact. Existing bundled documents describe the local
  app; both currently state 18+, but they are not an approved description of
  the online backend. No Google document was changed by this integration.
  Refresh the bundled snapshots/provenance and consent version before enabling
  online registration. The online reader uses those exact bundled snapshots.

## Authorized verification

Checked items below record the October 27 baseline only. The October 28 guest
revision still needs a latest-source build/install/launch and runtime acceptance.


- [x] Obtain an explicit user request for builds/tests. Read current AGENTS.md
  and required project records immediately before executing them.
- [x] Resolve the pinned SDK/transitive dependencies, build the latest workspace
  sources, install that exact build, and successfully launch it on the simulator
  named **Bibi UI Acceptance**. A missing simulator or failed step blocks the
  entire run; do not substitute an old build or another simulator.
- [x] Run callback/cache boundary tests and verify that the disabled gate does
  not initialize online services. Three tests passed on October 27, 2026.
- [ ] Run the database and Edge scenarios documented in `acceptance.sql` using
  isolated test accounts and data.
- [ ] Exercise signup, verification, recovery, logout/relaunch, expired session,
  rapid callback/account changes, account lock and interrupted deletion.
- [ ] Verify cross-account RLS for every table and Storage object; verify that
  unauthenticated clients cannot execute any administrative RPC.
- [ ] Exercise upload interruption/retry, immutable paths, malformed media,
  expired signed URLs, pending/approved/rejected revisions and revisions while
  old approved content remains visible. Confirm original/archived media stays.
- [ ] Exercise follows, both-direction blocks, saved content, report/unhide,
  challenge replace/withdraw, comment replies, and real profile statistics.
- [ ] Exercise concurrent first-contact sends, group invite/accept/decline,
  owner remove/invite, member leave, old-history denial, reconnect and access
  loss while a conversation is open. No fabricated delivery receipts.
- [ ] Exercise duplicate/unknown-ack purchase and gift requests, wrong account,
  wrong environment, missing secrets, quantity/catalog mismatch, refund before
  credit, refund after spending, and account deletion during credit.
- [ ] Verify archived snapshots and balances remain separate across sign-in,
  logout and remote deletion. Test explicit per-item import and failure cleanup.
- [ ] Measure feed/inbox load with representative account sizes. Current reads
  use keyset pages but assemble the authorized snapshot; full-history memory,
  number of signed URL requests and aggregate RPCs require load acceptance.
- [ ] Check screen layout, keyboard, VoiceOver, empty/failure/review states,
  playback lifecycle and large text on the named iPhone simulator.
- [ ] Record each result separately: static inspection, build, local StoreKit
  Test, Apple Sandbox and production evidence must not be conflated.

The October 27 local run passed all 10 Bibi-scheme tests with zero failures:
resource/font checks, callback/cache/gate boundaries and five-tab navigation at
default/XXXL text sizes. See `docs/BACKEND-RUN-VERIFICATION.md`. This does not
complete the broader online, failure-state, keyboard or VoiceOver checks above.

## Cutover

- [ ] Reconcile all independent review findings and failed acceptance checks.
- [ ] Verify production environment, signing, bundle ID, iPhone-only settings,
  server secrets, operator readiness and current protocol version.
- [ ] Enable the single gate in a reviewed release configuration, regenerate
  project metadata, and repeat the authorized latest-build acceptance flow.
- [ ] Archive evidence and monitor operational errors/quotas with a named owner.
  No ongoing scheduled monitor was created by this task.

## October 27 safety and gift-retirement follow-up (not deployed)

- [ ] Create a new reviewed migration containing only the updated CREATE OR REPLACE
  command definition from comment-threading.sql; do not replay its existing ALTER.
  Keep schema.sql and atomic-client-commands.sql consistent for fresh setups.
- [ ] Verify new gift requests fail without changing wallets or activity. Previously
  acknowledged operation replay may return its historical result without a debit.
- [ ] Verify profile reports persist and reappear after refresh, and unhide_report
  only changes the caller's matching profile report visibility.
- [ ] Verify report/block actions for posts, replies, video comments, chat senders,
  group members and profiles, including blocked content disappearing immediately.

These source changes have no deployment receipt or database execution evidence.
The backend gate remains false. Historical gift-success acceptance is superseded
by gift-retirement acceptance; historical wallet records must remain readable.

## Bundle identity replacement — October 29, 2026

- [ ] Register `com.bibi.quadratic` with the selected Apple team and configure signing.
- [ ] Associate and validate the existing nine product IDs with the intended new
  App Store application; product identifiers in source remain unchanged.
- [ ] Redeploy functions that import `_shared/apple.ts` before enabling online
  purchases; local verification source now expects `com.bibi.quadratic`, while
  the deployed revision has not been updated by this identity change.
- [ ] Configure the matching Apple application ID and server credentials for the
  new application before purchase acceptance.

The backend gate remains disabled. No cloud configuration, Apple registration,
installed application or private data was changed during this replacement.
