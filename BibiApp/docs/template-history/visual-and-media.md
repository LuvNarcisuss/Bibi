# Historical template visuals, branding, resources, and licenses

This describes the Teto template, not Bibi's replacement artwork. See ../IMPLEMENTATION.md and ../../Design/ for current Bibi assets and provenance.

## Fresh Studio design system

| Token | Value | Use |
|---|---|---|
| background | #FAFBF7 | Warm off-white background |
| ink | #142620 | Primary text |
| emerald | #126B58 | Evergreen actions/headings |
| lime | #DDF4A6 | Buttons and selection |
| muted | #4F665C | Secondary text |
| soft | #F0F5EE | Soft cards |
| line | #DAE4DB | Dividers/outlines |
| pink | RGB(1,0.24,0.43) | Likes and destructive call-ending emphasis |

`StudioCanvas` draws a full-screen pale-green gradient and broad arcs. Drawing backgrounds does not permit redrawing app icons in code. Fill the window, keep white/translucent cards light, and avoid a conflicting biography background. Live/Shorts use soft black upper/lower gradients behind white text.

`TetoRhythm-Text.ttf` and `TetoRhythm-Display.ttf` provide body/display typography with UIFontMetrics. Preserve the corrected 6/8 glyph distinction and Info.plist registration; do not depend on machine-installed fonts.

`TetoIcon` loads transparent PNGs, including a transparent search ring with lime handle and distinct receiver/hang-up icons. Do not replace app icons with SF Symbols, emoji, or hand-drawn paths. Legacy symbol strings are compatibility fields only; verify they never render system icons. System pickers, keyboards, and share sheets are outside this replacement scope.

The selected logo is the original lime square Teto wordmark. Preserve its colors and shape. AppIcon is opaque 1024×1024; mark/wordmark are not tinted. Welcome uses 112 pt and loading 160 pt, with view-layer corner rounding. Paired-dancer illustration is for welcome/consent. Never use a historical screenshot as a page background with duplicated UI on top.

Controls have at least 44×44 pt hit targets. Cards usually use 16–24 pt radii; Create is 52 pt. Dock height is 66 pt, horizontal inset 16 pt, bottom-safe-area gap 6 pt, radius 30 pt. Selection geometry uses four divisions and valid indices. Preserve safe areas and distinguish screenshot pixels from points.

Search, Live/Shorts, and Voice categories use expandable/bubble interactions with Reduce Motion support. Long names cannot crowd Close/Send. Text wraps and supports Dynamic Type. Landscape action rails can scroll. Unknown portraits and empty groups use appropriate icons, never another person's photo.

## Original resource scope

The template contains 39 registered Pexels dance videos with matching JPG covers; see media-inventory.md and the original template Design/SourceMedia/manifest.json. Seven Phrases lesson videos are absent from both runtime and the template archive.

Portraits, room covers, and lifestyle images may show practice, breaks, or shoes. Unrelated videos must not be presented as dance feed content. A photographed person is not automatically an identified account, video author, or platform user. Keep attribution; unknown authors remain null.

Distinct characters have distinct portraits, consistent across screens. Group collages use up to nine members. Built-in room memberships do not overlap. Renaming duplicate assets does not create unique material. The source project reviewed representative frames and uniqueness for 46 videos on October 23, 2026; the template reused that evidence for its 39-video subset without claiming a new complete frame review.

Runtime media used HEVC/hvc1 while retaining dimensions, frames, timestamps, audio, and speed. Image compression preserved protected logo/icon decoded pixels. Original project size was not template size, and resource bytes were not IPA size. The template manifest records actual package bytes.

## Replacement and expansion rules

1. Inspect real video content at multiple representative timestamps, including beginning/middle/end and intermediate points in longer clips. For the original template, content had to show dancing. Inspect captions, watermarks, stickers, and prohibited copy. A cover is not video verification.
2. Record author, source/download URLs, license name/link, original path/hash, runtime mapping/hash, transformations, and inspection timestamps. Hosting on YouTube or TikTok does not itself grant redistribution rights.
3. Preserve aspect ratio and normal speed. Fill screens with proportional cropping, never stretching or acceleration. Extract independent matching covers.
4. Assign stable UUIDs and surfaces in DanceVideoCatalog and maintain collectionGeneration. Catalog, resources, references, and provenance must agree. Do not duplicate one clip under two surface IDs.
5. Removing unsuitable project-provided media includes runtime files, originals, covers, and references. Private device content is only filtered/classified or explicitly deleted by its owner. Preserve provenance/removal records.
6. The template includes runtime media and provenance only. Source Design originals remain in the original Teto project; originalPath is not a claim of an included file. Obtain lawful originals before reprocessing.

## Visual verification boundary

The template task inspected source, resources, and metadata only. After explicit runtime authorization, inspect small/large screens, landscape, Dynamic Type, VoiceOver, Reduce Motion, keyboard, safe areas, final-row scrolling, overlay recovery, and failure retry. HTML designs and PNG validation are not UIKit runtime captures.
