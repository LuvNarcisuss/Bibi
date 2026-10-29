# Typography run verification

> Historical verification: this report covers the October 26 Fredoka/Nunito
> revision. The October 27 Kalam/Comic Neue refresh has only static verification;
> these runtime results do not validate the new fonts. See IMPLEMENTATION.md.

Paths to application source, configuration, scripts and `Design/` evidence in this report are relative to `BibiApp/` unless explicitly prefixed. `docs/` and `Assets/` refer to repository-root directories.

Date: October 26, 2026. The owner authorized compilation, launch, five-page visual inspection, direct fixes and XCTest UI automation.

## Result

Xcode 26.0.1 compiled Bibi and both test targets successfully. `xcodebuild test` exited 0 with `TEST SUCCEEDED`. Four tests passed, zero failed and zero skipped. The ten original XCTest screenshots were exported and individually inspected. No typography defect requiring a visual fix was observed in the inspected states.

Environment: Bibi QA, iPhone 17 Pro simulator, iOS 26.0.1, portrait, 1206 × 2622 pixels. Device ID: `6AF30F68-29BB-4CFD-91FF-24CD39712A4A`. Application bundle: `im.seex.sao2-neiku-30`. Signing team remains `JPTS6M4T5B`. `CODE_SIGNING_ALLOWED=NO` applies only to this simulator invocation. The existing iPhone/iPad target setting is retained and now explicitly represented in project.yml.

## Automated coverage

| Test | Observed result |
| --- | --- |
| Runtime fonts | The real app resolves Fredoka and Nunito, with OpenType weight values 600 and 500. No system-font fallback in these checks. |
| Original title artwork | All five StudioTitle instances load visible original-rendering images and expose the corresponding accessible header name. |
| Default text UI | XCTest enters the existing local QA session, taps all five tabs, checks title labels and visible bounds, checks dock separation and attaches five screenshots. |
| Larger text UI | The same navigation and title checks pass with `UICTContentSizeCategoryXXXL`; five additional screenshots show larger text. |

The dedicated QA fixture's local agreement consent was previously authorized by the owner. Tests use the existing app entry flow and do not bypass it, send messages, purchase products or publish content.

## Visual review

All five wordmarks are complete, centered, proportional and separated from navigation buttons. The violet/white Shorts title remains legible over video. Fredoka display lettering and Nunito reading/control text are visible at both tested sizes. Circles and Challenges banner headings wrap cleanly. Me's profile text and buttons remain readable. Chat preview ellipses and partially visible horizontally scrolling chips are intentional existing behavior; moving Shorts comments can cross viewport edges.

| Page | Default text | Larger text |
| --- | --- | --- |
| Shorts | [Screenshot](../Assets/run-Typography-default-Shorts.png) | [Screenshot](../Assets/run-Typography-larger-Shorts.png) |
| Circles | [Screenshot](../Assets/run-Typography-default-Circles.png) | [Screenshot](../Assets/run-Typography-larger-Circles.png) |
| Challenges | [Screenshot](../Assets/run-Typography-default-Challenges.png) | [Screenshot](../Assets/run-Typography-larger-Challenges.png) |
| Chats | [Screenshot](../Assets/run-Typography-default-Chats.png) | [Screenshot](../Assets/run-Typography-larger-Chats.png) |
| Me | [Screenshot](../Assets/run-Typography-default-Me.png) | [Screenshot](../Assets/run-Typography-larger-Me.png) |

## Reproduction and evidence

In Xcode, select the Bibi scheme and the Bibi QA simulator, then Product > Test. The scheme includes BibiTypographyTests and BibiUITests. Stable `tab.*` and `page-title.*` accessibility identifiers support the UI checks without changing spoken labels.

The executed command was:

```sh
xcodebuild test -project BibiApp/Bibi.xcodeproj -scheme Bibi -configuration Debug \
  -destination 'platform=iOS Simulator,id=6AF30F68-29BB-4CFD-91FF-24CD39712A4A' \
  -derivedDataPath /private/tmp/BibiTypographyDerivedData \
  -resultBundlePath /private/tmp/BibiTypography-First.xcresult \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Use a new result-bundle path when repeating the command. Full result: `/private/tmp/BibiTypography-First.xcresult`. Build/test log: `/private/tmp/bibi-typography-first.log`. Durable exported summary and original attachment metadata are in `Assets/run-Typography-test-summary.json` and `attachment-manifest.json`.

The captured build/test log contains no matching `error:`, uncaught-exception or Auto Layout conflict signature. AppIntents extraction was skipped because there is no AppIntents dependency. XCTest reported animation-idle waits on Shorts and continued successfully; its scrolling comments were not disabled for testing.

## Limits

This verifies the five root screens in portrait on one simulator model at two text sizes. It does not establish physical-device rendering, landscape/iPad layouts, every accessibility size, spoken VoiceOver behavior, every scrolled state or deeper feature flows. Automated checks cover resources, names and geometry; the recorded visual inspection supplies the image-quality assessment.
