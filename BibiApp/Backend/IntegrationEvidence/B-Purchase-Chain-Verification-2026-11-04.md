# iOS purchase chain offline verification — November 4, 2026

## Result and actual execution

The owner's requested offline validation completed: **31 tests passed, zero
failures and zero skips**, comprising 22 actual purchase-service chain tests and
the nine existing recovery checks. The latest source built, installed and
successfully launched on **Bibi UI Acceptance**, iPhone 17 Pro, iOS 26.0.1,
before XCTest execution. The process ID was checked against the running simulator
process list. The `BibiPurchaseValidation` scheme disables Apple's live product /
queue boundary only in the explicitly selected Debug host. Release behavior does
not read the validation environment flag. The production release gate stays false.

The tests invoke the original `StoreKit1Purchasing.purchase/purchaseFromSocket`
and `SKPaymentTransactionObserver` callbacks. They run real protected journal
files, receipt refresh-flight coordination, original recovery tasks, actual
`BibiSettlementClient` request encoding, URLSession response delivery, strict
reply parsing, delivery persistence, finish dispatch and removal/queue readback.
Apple objects/operations, account credentials and network responses are controlled
substitutes. Every request on the fixture URLSession is intercepted; unknown
routes fail closed. There is no real Apple purchase or live settlement call.

Reproduce with `BibiApp/scripts/verify_purchase_chain.sh <new-evidence-label>`
after reading current project rules. The simulator must exist and be booted.
The runner builds, installs, launches and checks the new process before running
the two selected test classes. It does not replace the Bundle ID, team, gate,
server settings or agreements, and never resets the simulator or user archive.

## Skill recovery matrix

| Required scenario | Executed chain evidence |
| --- | --- |
| Paid while offline; reconnect and make a second independent payment | `testPersistentOfflineThenReconnectAndSecondIndependentPayment` |
| Same SKU, old callback returned to new request, separate transaction ownership | `testSecondSameSKUPurchaseAndOldCallbackCannotStealOwnership` |
| Preparation/paid writes and restart around confirmation, delivery and finish | `testPreparationAndPaidWriteFailureRetainTransactionWithoutEarlyFinish`, `testRestartAtConfirmedDeliveryFinishAndRemovedWriteBoundaries`, `testRestartAfterSubmissionAndBeforeReceiptNeverRepays` |
| Lost successful response and concurrent recovery | `testLostResponseConcurrentRecoveryNeverRepaysOrCreditsTwice` |
| A later paid transaction cannot reuse an earlier receipt-refresh flight | `testLaterTransactionRequiresNewReceiptFlight` |
| Rejected evidence, unchanged refresh, refresh failure and ordinary network resume | `testRejectedUnchangedReceiptStopsUntilFreshExplicitRetry`, `testRejectedReceiptRefreshFailureAndNetworkResumeCannotReuseRejectedBytes` |
| Missing receipt, corrupt storage and failed writes | `testMissingOrFailedReceiptAndDeferredCancelLateApproval`, `testCorruptedJournalBuffersRealObserverUntilVerifiedFilesAreRestored`, preparation/paid-write test |
| Purchasing timeout, deferred approval, cancellation and late success | `testAppleInteractionTimeoutKeepsAssociationAndLatePaidCallbackCanRecover`, deferred/cancellation test |
| Logout/account switch and original identity restoration | `testAccountSwitchPausesOriginalButAllowsOtherAccountPurchase`, `testEntryExpiryDuringProductLookupInvalidatesUnsubmittedAuthorization` |
| Lost journal with trusted history, or unresolved unknown ownership | `testLostJournalUsesTrustedHistoryAndUnknownOrphanStaysUnresolved` |
| Finish-only replay and failed balance refresh | `testCompletedTransactionRedeliveryOnlyFinishesRealObjectAgain`, `testEachNewActualQueueObjectCanFinishAfterEarlierObjectsAreReleased`, `testHTTPAndBusinessErrorCategoriesAndBalanceRefreshFailure` |
| HTTP 401/429/503, configuration/ownership errors, malformed or unknown replies | HTTP/business-category test, `testUnavailableEnvironmentProductAndPermissionNeverEnqueuePayment`, existing strict reply tests |
| Socket SKU outside native catalog, absent order number, rejected upstream and unavailable adapter | `testBothSourcesTraverseReceiptHTTPDeliveryAndFinish`, `testSocketWithoutOrderAndRejectedConfirmationNeverBecomeNativeCredit`, `testUnavailableSettlementNeverSubmitsApplePayment` |

The nine existing checks additionally execute association constraints, delivery
monotonicity, checksum/replica recovery, duplicate transaction fencing and trusted
association restoration. They supplement the 22 service tests, rather than
substitute for the observer/network chain.

## Demonstrated defects and fixes

The first service run failed on paid-event storage recovery and repeated confirm
requests after a failed local confirmation write. Actual failed callbacks are now
buffered and replayed when storage becomes readable. Confirmation stops while
storage is unwritable; restored `awaitingConfirmation` first queries the original
server result. No new payment is submitted by recovery.

A failed removal-state write now retains the object and reconciles an already
delivered finish request against the current queue. Queue absence can complete
only a previously delivered transaction; a subsequent real redelivery still
finishes the real object without confirming or crediting again.

Fresh review found that a permanent set of bare object addresses could suppress
finish after address reuse. A dedicated repeated-object lifecycle test reproduced
the failure. Finish deduplication now uses weak live-object pointer identity;
released addresses cannot block a different real transaction. The final targeted
review found no additional P1/P2 in the changed paths.

Initial failing runs remain in `BibiApp/Design/RunEvidence/`; the successful
28-test intermediate run is retained separately from the final 31-test result.
Result bundles/logs are local ignored artifacts, not fresh-checkout downloads.
The repository JSON records include final test names, counts, source/log
hashes and device metadata: `b-purchase-chain-verification.json` and
`b-purchase-chain-xcresult-summary.json`.

## Remaining acceptance and actual capability gaps

- Resolve the physical-device signing/Bundle-ID and push-profile blockers.
- Confirm console import/save for AppID `48369038`; verify actual bootstrap /
  direct Auth, Socket, web transition, cold restoration, expiry and reconnect.
- Verify real Apple Sandbox products/receipts/callback timing, both sources,
  immediate post-payment disconnection, relaunch and actual source-specific
  authoritative balances. Record Production and refund/notification evidence
  separately. Offline injected Apple events are not Apple Sandbox acceptance.
- Verify original-service business event publishing, acknowledgement/replay,
  confirmation results and authoritative web entitlement display.
- Lost anonymous identities or unknown original purchase associations remain an
  unresolved recovery capability gap, potentially affecting that SKU. Passing
  the quarantine test does not restore ownership or release Apple's transaction.
- An ambiguously sent external confirmation still needs proven upstream
  idempotency/status support or manual reconciliation. It is never blindly resent.
- Native B settlement retains the owner's client-trust model. These tests do
  not add Apple server verification or establish fraud resistance.

UIKit visual/accessibility behavior, real Apple system UI and notification /
media prompts remain device acceptance. Restart tests discard the service and
reload actual files; they are not OS termination at every possible instruction.
No agreement, production financial record or deployed Edge source was changed.

Release verification: BibiAppStore unsigned Release simulator compilation passed.
The validation-host flag/method are absent from the binary; identity, iPhone-only
portrait settings, nine products, frozen PDFs and the disabled gate are preserved.
The Release artifact was not installed or launched.
