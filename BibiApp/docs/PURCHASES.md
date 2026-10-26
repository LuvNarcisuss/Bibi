# Bibi in-app purchases

Configuration date: October 26, 2026.

The owner supplied seven iOS consumable diamond product IDs in a screenshot. The IDs were transcribed and cross-checked with local OCR; lowercase characters were checked against the image. Payment/bank details from the screenshot are not required by StoreKit and are not stored in the app.

| Diamonds | Reference USD | Product ID |
|---:|---:|---|
| 400 | 0.99 | `ldbsrbbhebevxdjf` |
| 800 | 1.99 | `fxvrdbmlwopeasti` |
| 2,450 | 4.99 | `akafhhbydyymfpzk` |
| 5,150 | 9.99 | `ffzwgpuvsyyhaeeg` |
| 10,800 | 19.99 | `ofgjvlbwtzchgvbx` |
| 29,400 | 49.99 | `azacbzpzvvvpblzu` |
| 63,700 | 99.99 | `lghwqjsuuxivrdrf` |

## Configuration and purchase flow

`Bibi/Support/Info.plist` stores the mapping under `BibiDiamondProducts`, keyed by diamond quantity. `BibiConfiguration` reads the values; `WalletCatalog` supplies seven matching tiers. The 16,800 and 42,600 tiers have no supplied product IDs and are removed from the offered catalog. Existing balances and transaction history remain intact.

Wallet → tier selection → confirmation → StoreKit product lookup → Apple payment sheet → transaction callback → atomic local wallet save → finishTransaction. Actual prices use SKProduct.price and priceLocale; USD values above are references only. An unavailable product does not start payment or credit diamonds. Cancellation/failure adds no diamonds, deferred transactions wait for approval, and repeated transaction IDs are not credited twice. Save failure leaves a completed purchase unfinished for retry on a later launch. Gifts spend the same local balance.

## Store and service boundaries

The user changed the bundle identifier to `im.seex.sao2-neiku-30` and selected development team `JPTS6M4T5B`. Both the Xcode project and project.yml now preserve those values. The screenshot does not establish that the products are registered to this bundle or available in App Store Connect. Configure the same exact IDs as consumables for the intended application, with the appropriate signing identity and store account setup. No App Store Connect changes, real purchase, or financial account changes were performed.

The Bibi scheme now uses Configuration/BibiDiamonds.storekit for Xcode Run, following the local testing setup in Teto. It contains only Bibi's seven configured consumables. The BibiAppStore scheme has no local StoreKit configuration and uses Apple's catalog. The BibiPurchases scheme runs isolated StoreKit Test UI regression checks. Local fixture success does not establish App Store Connect product availability or a successful real-device sandbox purchase.

For an interactive local purchase run, select **Bibi** and **Bibi UI Acceptance** in Xcode, confirm **Edit Scheme > Run > Options > StoreKit Configuration > BibiDiamonds.storekit**, and use **Product > Run**. Keep the Xcode run session active while testing. Building with `xcodebuild` and then installing/launching with `simctl` does not apply the scheme's Run configuration to that launch. A successful app launch alone therefore does not verify the local catalog. Confirm that all seven offers show prices before starting a payment. XCTest uses its own explicit SKTestSession and is a separate verification path.

The existing StoreKit 1 implementation keeps a device-local ledger. It does not implement receipt validation or a server-authoritative wallet, refund reconciliation, cross-device balances, or remote gift delivery. This configuration change does not establish those services. Account deletion removes the local wallet but cannot delete Apple transaction history.

## Initial configuration verification (before runtime testing)

- 405 static source/configuration/resource checks passed, including exact product mappings, unique IDs, seven tier quantities/reference prices, and complete tier-to-product coverage.
- Xcode Debug simulator build succeeded. The built app's Info.plist contains the same seven product mappings and bundle identifier as source.
- Build log: /private/tmp/bibi-purchases-build.log. The only build warning concerns skipped App Intents metadata extraction; this app does not use AppIntents.framework.
- At this initial build-only stage, no payment was submitted and no wallet credit was generated. Build/configuration checks are not evidence of StoreKit catalog availability, receipt validation, or sandbox transaction success.


## Real-device catalog failure investigation

The supplied device captures show missing App Store prices followed by a package-unavailable alert. The old implementation collapsed network errors, timeouts, and invalid product responses into that one message. The captures alone cannot distinguish those causes. The owner could not confirm whether the seven products exist in App Store Connect for the selected bundle.

Confirmed local findings and changes:

- Xcode contained the owner's new bundle/team, while project.yml still contained the former development bundle and no team. The generator configuration is now synchronized. This prevents regeneration from reverting identity; it does not prove this caused the device failure.
- In-App Purchase capability metadata is recorded for the target. This does not create products or accept agreements in App Store Connect.
- Catalog state now distinguishes loading, complete/partial responses, unavailable products, request failures, and timeouts. Retry requests refresh missing products. Only packages with an App Store product/price can enter purchase confirmation.
- Product-fetcher instances are no longer shared globally. Requests carry generations, cancellation clears the request, and stale/duplicate callbacks are ignored. Timeout cancels the old request; ending a store session resumes outstanding waiters and prevents a delayed payment.
- Apple invalidProductIdentifiers and NSError domain/code chains are retained. Xcode logging uses category InAppPurchase. Debug builds offer Copy Store Diagnostics with bundle/version, requested/returned/invalid IDs, and error codes; no receipts, bank details, or account credentials are included.
- Successful product lookup continues into the existing SKPaymentQueue payment flow, with transaction deduplication and atomic credit-before-finish behavior. No Apple Pay merchant/card flow was added; diamonds use Apple In-App Purchase.

No physical device was available through devicectl during this investigation, and the browser automation transport could not connect to App Store Connect. Therefore no Apple account/product status or real-device catalog response was verified. No purchase or account setting change was performed during that real-device catalog investigation.

To complete Apple sandbox verification, confirm the selected app contains these exact seven consumable IDs, each with price/localization and availability, and that the account's Paid Apps Agreement is active. In a Debug device run, Retry App Store and copy Store Diagnostics if prices are missing. A product rejected for this app cannot be made purchasable by substituting a hardcoded price or a local StoreKit fixture.

References: [Apple TN3186](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox), [Configure In-App Purchases](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/).

The updated code compiled successfully and 407 static checks passed. `app-store-products.csv` provides the seven product definitions for manual comparison or entry in App Store Connect; it is a preparation sheet, not an Apple bulk-import format or evidence that products were created.


## Teto configuration comparison and local transaction verification

Bibi now follows Teto's Xcode StoreKit configuration pattern while retaining Bibi's own product mappings and request safeguards. The isolated XCTest catalog case passed for all seven purchases, application cancellation, StoreKit cancellation and balance persistence after relaunch. These were local StoreKit Test transactions with no real charge. See [Purchase runtime verification](PURCHASES-RUN-VERIFICATION.md) for schemes, evidence, reproduction and the remaining App Store Connect boundary.
