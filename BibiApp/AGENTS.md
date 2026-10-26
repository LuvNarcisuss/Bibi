# Bibi engineering constraints

The latest user request is the authority: maintain an anime-themed native iOS app focused on Shorts, Circles, Challenges, Chats and Me.

- iOS 16+, Swift 5, UIKit and AVFoundation. No SwiftUI, Objective-C or hybrid frameworks.
- Five tabs: Shorts / Circles / Challenges / Chats / Me. Shorts is the default root. Live and Voice rooms are retired; retain old serialized fields only for compatibility. No Phrases feature.
- All authored project content must be English: application text, identifiers, filenames, code comments, explanations, documentation, scripts, asset text, and commit messages. Only conversational replies to the user use Chinese. This rule also applies to copied reference documents; historical language exceptions do not apply.
- Do not label the product as a demo or mock.
- Original generated raster icons and fictional anime artwork. Palette and composition live in Bibi/DesignSystem.
- Product/scheme: Bibi. The user selected bundle im.seex.sao2-neiku-30 and team JPTS6M4T5B on October 26, 2026. Preserve these values and keep project.yml aligned with the Xcode project. Never replace user-selected account configuration with template values.
- Preserve atomic persistence, stable IDs, moderation, relationship limits and private-media ownership. Legacy Codable keys are compatibility details.
- No backend is configured. Do not claim real streaming, RTC, IM delivery, moderation or store availability.
- No build, typecheck, app launch, simulator, preview or tests without an explicit user request. Static file/config/resource inspection is permitted. XcodeGen may regenerate metadata.
- docs/IMPLEMENTATION.md and docs/STATIC-AUDIT.md are current; docs/template-history is historical reference only.
