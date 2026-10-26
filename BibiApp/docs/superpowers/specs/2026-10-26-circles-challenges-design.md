# Circles and Challenges

The owner authorized direct implementation of the recommended Circles + Challenges direction on October 26, 2026. Replace Live and Voice with five roots: Shorts, Circles, Challenges, Chats, Me. Retain UIKit, iOS 16+, the existing art direction, signing configuration, atomic storage, account deletion and safety controls.

Circles provides searchable themed communities, joined and saved filters, join/leave, text and optional photo/video posts, discussions, bookmarks, author profiles and local reporting. Original illustrative topic artwork is reused. Seed discussions are editorial prompts attributed to Bibi, not simulated real-time activity. Personal posts can be deleted.

Challenges provides evergreen creative briefs, theme filtering, instructions, example films, and one editable local entry per challenge. Owners can attach an existing personal short video or import a new one using the existing creation flow. Pending uploads remain local and clearly labeled. Entries can be watched or withdrawn. Me links to joined circles, saved posts and challenge entries.

No backend is configured. Nothing claims remote publication, delivery, rankings or review approval. Community state is an optional Codable member of the existing atomic library, preserving old snapshots and automatic account deletion. Photos are downsampled and bounded before inclusion. Removed room fields remain decode-compatible but have no active entry points.

Alternatives considered: watchlists and personal journals prioritize private organization. Circles and Challenges were selected because they connect short-video discovery, shared interests and creation.

Verification is static only. The workspace explicitly prohibits builds, typechecks, tests, simulator and previews without a further explicit request.
