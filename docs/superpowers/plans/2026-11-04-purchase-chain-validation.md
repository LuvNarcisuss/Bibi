# Purchase chain offline validation plan

**Goal:** Execute the skill's recovery matrix through Bibi's existing StoreKit 1 service, not a second purchasing implementation.

**Architecture:** Inject only the Apple queue/product boundary, receipt refresh operation, current-account authorization and URLSession transport. Preserve the real observer callbacks, purchase journal, receipt generation coordination, DTO encoder/parser, recovery scheduler, delivery and finish logic. Production keeps its single live observer. Debug-only validation hosts fail closed before any real Apple request.

**Authority:** The owner explicitly requested offline iOS purchase-chain validation. Project rules require the latest application build, installation and successful launch on `Bibi UI Acceptance` for each executed test run. No real purchase, live settlement, release activation or agreement change is authorized or needed.

## Tasks

- [x] Add a failing XCTest using the isolated service boundary and record the initial failure.
- [x] Introduce narrow system-boundary dependencies without changing production routing, accounts, products or trust policy.
- [x] Exercise local and Socket success, lost responses, concurrent retries, stale receipts, account changes, old transactions, deferred/cancelled payments, storage failures and restart checkpoints through the actual service.
- [x] Build/install/launch the current source on the designated simulator and run only the offline backend purchase tests with external requests intercepted.
- [x] Fix demonstrated recovery defects, rerun affected checks and obtain a fresh review.
- [x] Save exact results/source hashes, map the skill matrix to executed tests and report unresolved service capabilities separately from online acceptance.

## Review focus

- No fake success, real Apple payment or live Supabase/external request in fixtures.
- Paid facts survive account/UI changes and file-write failure.
- Observer callbacks and URLSession response parsing reach real delivery/finish code.
- Simulated process restart reloads real protected journal files rather than copying in-memory state.
- Validation host controls are Debug-only and absent from Release behavior.

Final result: 31 tests passed on Bibi UI Acceptance after latest-source build/install/launch. Initial recovery and object-lifetime failures were retained and fixed; no real payment or live settlement ran.
