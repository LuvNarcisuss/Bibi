# Build and launch verification

Paths to application source, configuration, scripts and `Design/` evidence in this report are relative to `BibiApp/` unless explicitly prefixed. `docs/` and `Assets/` refer to repository-root directories.

Date: 2026-10-26 (Asia/Shanghai). The user explicitly requested running the application in Xcode, authorizing compilation and simulator launch after the initial static-only delivery.

- Xcode 26.0.1, build 17A400.
- Project opened in the Xcode application: Bibi.xcodeproj.
- Scheme Bibi, Debug, iOS Simulator; CODE_SIGNING_ALLOWED=NO.
- Device: iPhone 17 Pro, iOS 26.0.1; UUID 05FF5F0E-DA1F-4BFD-9D19-59887F2380FF.
- xcodebuild returned exit 0 and BUILD SUCCEEDED.
- The only warning reported was skipped AppIntents metadata extraction because the app does not depend on AppIntents.framework.
- simctl installed the built app and launched app.bibi.anime, PID 13741.
- Captured and visually inspected the actual simulator screenshot: Assets/run-welcome.png. The welcome art, title and Get started button appeared correctly.

Build output: /private/tmp/BibiDerivedData/Build/Products/Debug-iphonesimulator/Bibi.app. Build log: /private/tmp/bibi-xcode-build.log.

Scope: successful simulator build and welcome-screen launch. No automated test suite, complete feature walkthrough, StoreKit transaction, camera flow or backend integration was validated. The app is running in Simulator; no claim of an attached Xcode debugger is made.

## Agreement update — October 26, 2026

The user-provided Google Docs links now serve both consent and Settings. Complete English source text was mirrored into bundled fallback HTML; extracted HTML text matches the normalized source lines and both recorded hashes match. All 401 static checks pass after updating the URL policy assertions.

Xcode rebuilt the Debug iOS Simulator target successfully after this change, using the existing iPhone 17 Pro destination and /private/tmp/BibiDerivedData. Build log: /private/tmp/bibi-agreements-build.log. The only warning was skipped App Intents metadata extraction because this app has no AppIntents.framework dependency. Network success, timeout, access-denied handling, and offline fallback have not undergone an interactive simulator walkthrough. Connected-account document retrieval does not establish anonymous availability.

## Purchase configuration update — October 26, 2026

The owner's seven product IDs were connected through BibiDiamondProducts and the two unconfigured template tiers were removed. All 405 static checks passed. Xcode Debug simulator build succeeded; the compiled Info.plist matches every source product mapping. Log: /private/tmp/bibi-purchases-build.log. No transaction was submitted. App Store product availability and purchase behavior remain unverified; see PURCHASES.md.

## Store product diagnostics update — October 26, 2026

The current Xcode project uses the owner's selected bundle im.seex.sao2-neiku-30 and team JPTS6M4T5B; project.yml now matches. In-App Purchase target capability metadata is included. The updated catalog/error/retry flow compiled successfully for the iPhone 17 Pro simulator. The compiled Info.plist contains the selected bundle and all seven configured product IDs. All 407 static checks passed. Build log: /private/tmp/bibi-store-diagnostics-build.log. The only build warning concerns unused App Intents metadata extraction.

No connected physical device was available, and the browser automation connection failed before App Store Connect could be inspected. Device purchase/cancellation behavior and Apple product registration remain unverified. No payment was submitted, balance injected, StoreKit simulation catalog enabled, or Apple account configuration modified. The debug-only Copy Store Diagnostics action is intended to obtain the missing real-device catalog response on the owner's next run.
