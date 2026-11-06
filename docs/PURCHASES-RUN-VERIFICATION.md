# Purchase runtime verification

This is historical runtime evidence. Since November 6, 2026, only the Bibi
scheme remains. For current reproduction, use Bibi: select the local StoreKit
fixture or None under Run options, and explicitly enable BibiPurchaseUITests
under Test for an isolated purchase UI run. Earlier auxiliary scheme names below
describe the recorded run and are not current execution instructions.

Paths to application source, configuration, scripts and `Design/` evidence in this report are relative to `BibiApp/` unless explicitly prefixed. `docs/` and `Assets/` refer to repository-root directories.

Date: October 26, 2026 (Asia/Shanghai).

## Circle-post gift spending

Latest run: October 26, 2026, completed at 18:04 Asia/Shanghai. The current workspace was built, installed and launched by XCTest on Bibi UI Acceptance, iPhone 17 Pro, iOS 26.0.1, UDID `0C3DC278-7663-4B7E-9FCD-10F2FF679569`.

`testContentGiftsAndPersistence` passed: one executed case, zero failures, 200.093 seconds. This case uses local SKTestSession with dialogs disabled and preserves existing wallet data and transaction history.

- The initial balance was 1,540. A local StoreKit purchase added 400 diamonds.
- Shorts exposed no gift entry. A circle discussion opened the existing gift picker.
- Canceling a gift confirmation did not change the balance.
- One Sakura gift cost 10 diamonds; five Sakura gifts cost 50 diamonds. The resulting balance was 1,880.
- An unaffordable selection showed the insufficient-balance prompt; canceling it did not spend diamonds.
- Terminating and relaunching the app preserved the 1,880 balance and local gift history.
- Final screenshots were inspected. Gift cards separate names, amounts and units onto individual lines to prevent the price-unit truncation found during the first passing run.

Evidence: `Design/RunEvidence/Purchases/CircleGifts/test-summary.json`, `gift-prices.png`, `circle-gift.png` and `persisted-wallet.png`. Result bundle: `/private/tmp/BibiContentGifts-Final.xcresult`. Static audit: 436 checks passed, zero failures.

Gift spending and purchase credits now share one persistence queue. Records include optional content, gift and quantity metadata, preserving older wallet decoding. A target is rechecked before spending, and the saved balance is published only after persistence succeeds. Shorts tipping is explicitly excluded by project rules and the static audit.

This is a local gift animation and wallet record on an existing circle discussion. No gift or money is delivered to a creator. No new feature module or backend was added. This run does not establish Apple sandbox or production payment availability, and it does not repeat the full seven-product suite. Injected write failures, concurrent credit/debit stress, target moderation races and real creator delivery were not runtime-tested.

## Acceptance simulator follow-up

The owner reported that all seven offers were unavailable after a standalone simulator launch. That launch installed a current build but did not activate the local StoreKit configuration from the Xcode Run scheme. Xcode's scheme editor was checked directly: Bibi selects BibiDiamonds.storekit. Interactive local verification must use Product > Run; `simctl launch` alone is insufficient to activate this configuration.

After synchronizing the iPhone-only generator settings and regenerating the project, a fresh `xcodebuild test` built, installed and launched the current workspace on **Bibi UI Acceptance**, UDID `0C3DC278-7663-4B7E-9FCD-10F2FF679569`, iPhone 17 Pro, iOS 26.0.1. The installed Info.plist declares UIDeviceFamily `[1]`.

`testApplePaymentSheetCancellation` passed: one executed case, zero failures, 107.321 seconds. The local StoreKit catalog displayed all seven prices. XCTest verified SpringBoard's native payment sheet, the In-App Purchase text and $0.99 price, dismissed the sheet, observed the cancellation message, and verified that the balance remained zero. The saved system hierarchy also identifies 400 Diamonds and Xcode. No purchase was completed and no balance was reset. The seven-purchase crediting case was not rerun in this follow-up.

Evidence: `Design/RunEvidence/Purchases/Acceptance/test-summary.json`, `wallet-prices.png` and `payment-sheet-hierarchy.txt`. The result bundle is `/private/tmp/BibiAcceptance-PaymentSheet-20261026.xcresult`. The app-only screenshot attachment excluded the native overlay, so the system hierarchy and executed assertions are the payment-sheet evidence for this run.

The static audit previously rejected every StoreKit fixture, an obsolete rule from before local purchase integration. It now checks the two local schemes against the Bibi fixture, the separate Apple catalog scheme against the absence of a fixture, and all seven consumable IDs. All 434 static checks pass. These results establish local testing behavior only; Apple sandbox and production availability remain unverified.

After XCTest completed, Bibi was built and launched again through Xcode Product > Run on Bibi UI Acceptance. Xcode reports the application running, and its console lists all seven returned product IDs with an empty invalid-ID list. The app is left at its welcome screen with the Xcode run session active. This interactive launch is separate from the completed SKTestSession case.

## Reference and changes

The Teto project uses StoreKit 1 and selects `Teto/Resources/TetoDiamonds.storekit` in its Xcode Run scheme. Its working local catalog does not establish App Store Connect registration. Bibi now applies that configuration pattern using its own seven product IDs, quantities and reference prices in `Configuration/BibiDiamonds.storekit`. No Teto product IDs or account identities were copied.

The existing Bibi purchase implementation retains request generations, timeout/cancellation handling, localized StoreKit prices, transaction deduplication and atomic wallet persistence before finishing a transaction. Stable wallet accessibility identifiers support XCTest without changing purchase authorization or crediting behavior.

| Xcode scheme | Purpose |
|---|---|
| Bibi | Run with the local StoreKit configuration |
| BibiAppStore | Run against Apple's catalog with no local fixture |
| BibiPurchases | Run the isolated XCTest UI purchase target |

The fixture is included in the UI test bundle only, not in Bibi.app. Bundle ID `im.seex.sao2-neiku-30` and team `JPTS6M4T5B` are preserved.

## Verified catalog and transaction flow

The XCTest case `testCatalogPurchasesCancellationAndPersistence` passed on the disposable Bibi Purchase QA iPhone 17 Pro simulator running iOS 26.0.1. The run took 248.585 seconds with zero failures.

- All seven products loaded with StoreKit prices and enabled purchase controls.
- Each product completed through StoreKit Test and credited its configured amount. Starting from a clean wallet, the seven purchases totaled 112,700 diamonds.
- Canceling Bibi's confirmation did not create a transaction or change the balance.
- A simulated StoreKit user-cancellation result displayed the cancellation message and did not credit diamonds.
- Terminating and relaunching Bibi preserved the credited balance.

This case uses SKTestSession with dialogs disabled to verify callbacks. It does not alone verify the native payment-sheet controls.

Evidence: `Design/RunEvidence/Purchases/catalog-summary.json` and the five catalog/transaction PNG attachments in the same folder. The original result bundle is `/private/tmp/BibiPurchases-Third.xcresult`.

## Native payment sheet verification

`testApplePaymentSheetCancellation` passed separately with dialogs enabled: one executed test, zero failures, 83.166 seconds. XCTest found SpringBoard's `payment-sheet` container and its `dismiss` button, verified the In-App Purchase label and $0.99 price, closed the sheet, observed Bibi's cancellation message and confirmed that the 112,700 balance remained unchanged.

Evidence: `Design/RunEvidence/Purchases/apple-storekit-payment-sheet.png` and `payment-sheet-summary.json`. The original result bundle is `/private/tmp/BibiPurchases-Sheet-Final.xcresult`. The screenshot was visually inspected. The system sheet identifies Xcode testing and explicitly states there is no charge. System button localization follows the simulator language; Bibi-authored content remains English.

The seven configured consumable IDs were also compared with the source and built Info.plist. All three scheme configurations and the absence of a storekit fixture in Bibi.app were verified.

## Reproduction

Use a disposable simulator and clean Bibi application data for the complete catalog case. Its fixture clears local test transactions, so it must not run against a personal wallet or production account. Uninstall only the test application's installation on that disposable simulator before starting a fresh complete run. Run the BibiPurchases scheme using Product > Test or xcodebuild test with the chosen simulator destination. Do not infer success from a zero-test result; inspect the executed case count.

Early harness runs failed because a synchronous expectation blocked asynchronous StoreKit Test work. The catalog test now awaits XCTWaiter.fulfillment. The initial native-sheet selector also looked in Bibi for a Cancel button; the actual iOS 26 sheet belongs to SpringBoard and exposes payment-sheet/dismiss identifiers. These harness failures were investigated separately from application behavior.

## Limits

No real payment, App Store Connect change or real-device sandbox purchase was performed. Apple product registration, availability and Paid Apps Agreement status remain unverified. The owner's earlier device screenshots cannot establish which of those conditions caused the unavailable catalog. Select BibiAppStore to investigate the genuine catalog, then use Retry App Store and Copy Store Diagnostics if products remain unavailable.

This work does not add server receipt verification, a server-authoritative balance, cross-device synchronization or refund reconciliation. Deferred approvals, injected persistence failures and recovery after interrupted delivery were not exercised by these runtime cases.

Apple explains that a local configuration is not uploaded to App Store Connect: [Setting up StoreKit Testing in Xcode](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode).
