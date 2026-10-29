# Circle stories

## Current revision — October 28, 2026

Circle covers, the Circles banner and every authored post image are licensed
cosplay photographs. Sketch, watercolor, film-still and sewing-table images are
no longer used on these cards. Three earlier cosplay stills remain. See
`Assets/cosplay-cover-provenance.json`. The October 27 notes below describe the
previous cover set.


## Current revision — October 27, 2026

Post tipping is removed. Cards, discussions and replies offer Report or block.
The catalog now has 14 posts, 28 replies and 10 active Shorts across the same six
fictional profiles. Nova and Theo each gained one cosplay short and one post;
Theo now uses licensed cosplay photography. Five author avatars are photographic
and Rowan remains illustrated. See IMPLEMENTATION.md for current verification.
The numeric portfolio table below is a prior snapshot, not current totals.


## Current avatar mix — October 27, 2026

Luna and Nova use licensed cosplay photography; Kai and Mira use licensed everyday
portraits. Rowan retains an illustration; Theo now uses cosplay photography. The six personas remain fictional.
See `Assets/avatar-photography-provenance.json` for attribution and
`avatar-photography-static.json` for static verification. Older descriptions of
six illustrated author avatars are superseded by this mixed selection.


## Earlier portfolio snapshot — October 27, 2026

Whole-card navigation now preserves nested avatar, safety and credit actions.
Creator portfolios combine posts and Shorts. The current editorial distribution
is recorded below; older verification sections describe their original revision.
Initial figures are authored local content, not live analytics. User interactions
can change displayed totals. No runtime verification was performed for this revision.

| Author | Shorts | Posts | Works | Likes | Saves | Following | Followers |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Luna Frames | 2 | 1 | 3 | 53 | 64 | 18 | 23 |
| Kai Orbit | 2 | 2 | 4 | 71 | 67 | 24 | 17 |
| Mira Ink | 1 | 2 | 3 | 54 | 50 | 16 | 28 |
| Rowan Tales | 1 | 2 | 3 | 64 | 40 | 21 | 19 |
| Nova Stitch | 1 | 2 | 3 | 55 | 45 | 14 | 26 |
| Theo Lantern | 1 | 3 | 4 | 88 | 54 | 27 | 22 |

Media rights and original film credits are unchanged. See `community-profiles-static.json` and `Assets/community-curation-provenance.json`.


Date: October 27, 2026.

## Content and navigation

The local Circles feed includes 14 authored posts by six fictional characters,
with ten image posts and 28 prewritten replies. Animation and Sketchbook each
have three posts; Characters and Cosplay each have four, plus editorial prompts. Posts are labeled
`Bibi Stories · Fictional character`; detail pages explicitly identify the
prewritten conversation. Character biographies disclose their fictional identity.
No online status, delivery receipt or invented follower count is introduced.

Open `Circles > Explore circle` to browse the cards. `Read discussion` opens the
full post and replies. Report or block is available for other authors on cards,
details and replies. Owned content retains deletion controls. Posts and Shorts
have no tipping. Existing wallet balances and historical gift records are retained.

## Source and preservation

The catalog lives in
`BibiApp/Bibi/Features/Circles/CommunityModels.swift`. Story IDs use fixed
`CB120000` UUID prefixes and reply IDs use `CB130000`. Preserve the numeric story
IDs when revising or reordering content; saved posts, reports and gift records
refer to these identities. Dates are fixed editorial ordering metadata.

`AppStore+Community.swift` merges this catalog at read time only when `isOnline`
is false. Existing account data and the four `CB110000` editorial prompt IDs are
unchanged. No content is written into the user's library on launch or uploaded
to Supabase. User-authored replies and bookmarks continue through existing atomic
persistence. Both seeded and authored content use existing block/report filters.
`CirclePost.bundledArtwork` is optional for old snapshot compatibility.

## Asset provenance

The ten current covers include six licensed reference photographs, two existing
film stills and two extracted cosplay video frames. Post bodies and
prewritten replies now discuss the actual depicted subjects. These are reference
images for fictional conversations, not claims that the photographed people own
Bibi accounts or endorse the app. Every cover has an accessible description and a
source link, and Settings > Artwork & Credits lists the photo sources.

| Circle | Cover subjects | Sources |
|---|---|---|
| Animation Club | Hero city composition; Spring mountain atmosphere | Existing Blender Foundation film covers, under their recorded CC licenses |
| Character Corner | Expressive face sketches; a pencil drawing session | Hatice Baran and Vitaly Gariev, Pexels |
| Sketchbook Society | Watercolor flowers; a palette and color study | Greta Hoffman and Vitaly Gariev, Pexels |
| Cosplay Studio | Steampunk costume details; paper patterns on fabric | Vika Glitter and Pavel Danilyuk, Pexels |

`Assets/post-cover-provenance.json` records each file, source page, photographer,
license URL, download URL, dimensions and SHA-256. Pexels images were downloaded
at width 1000 from its image endpoint. No generative edits or local retouching
were applied. Movie covers reuse the exact existing files and retain the
provenance in `Assets/media-provenance.json`. All eight images were visually
inspected. A rejected candidate with non-English writing was not imported.

The ten `PostCover-*` assets are registered in the flat catalog index and runtime
inventory; `prepare_asset_catalog.py` recreates their Xcode catalog links. No
project regeneration is needed because the existing asset catalog is already in
the resource build phase. Five author portraits now use licensed photographs; Rowan retains Portrait4.
Older generated portraits remain available for compatible snapshots.

## Circles home covers

The Circles home banner now uses `PostCover-PaintPalette`. Local discovery and
joined-circle cards use `PostCover-AnimationCity`, `PostCover-CharacterLines`,
`PostCover-WatercolorFlowers` and `PostCover-SteampunkCostume` respectively.
Circle detail banners share those catalog references. The existing photo and
film credits remain available in Settings and in their related posts. No source
image was changed, and the Challenges covers are outside this revision's scope.
All five image references and generated catalog links were statically checked;
this home-cover revision has not been compiled or run.

## Historical compact gift presentation (retired)

The previous post-card and detail gift actions presented one UIKit bottom sheet instead
of pushing a full-page controller. The sole custom detent is capped at 480 points
and 62% of the available detent height. It has a grabber, a Close gifts button,
rounded corners and internal scrolling; scrolling does not expand it to a large
detent. Compact-height presentations attach to the bottom edge.

The existing nine gifts remain in three columns. Icons are 28 points instead of
44, and cards use compact padding, 12-point themed labels and 10-point section
spacing. The header combines balance and a small Add button. Quantities, pricing,
confirmation, insufficient-funds handling and atomic spending are preserved.
Dismissal is blocked while a wallet operation is active. The wallet can still be
opened inside the sheet for top-up and navigated back to the picker.

## Verification

The original content pass validated 12 unique posts, six fictional authors,
24 replies and three posts per circle; its evidence is retained in
`circle-stories-static.json` and predates the cover replacement.

The cover/sheet follow-up validated 12 preserved story IDs, eight unique cover
hashes, generated asset links, both sheet entry points and the unchanged disabled
backend gate. The repository static audit passed 444 checks with no failures.
`git diff --check` passed. Current evidence:
`post-covers-gift-sheet-static.json` and `static-audit.json`.

No Swift build, typecheck, simulator launch or XCTest was executed for this
revision. Runtime acceptance remains pending for image framing, sheet size,
scrolling, larger text, rotation, top-up return, close/swipe behavior, purchase
confirmation and wallet persistence. Historical runtime results do not validate
the new covers or bottom-sheet layout.
