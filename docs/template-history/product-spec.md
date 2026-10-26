# Historical template page and feature specification

This is an English rendering of the original Teto dance-social specification. Bibi replaces its theme, branding, authored content, media, and configuration; current details are in ../IMPLEMENTATION.md. The original scope includes Live, Shorts, Voice, Chats, and supporting Me, with no Phrases, lessons, or beat editing. Local describes capability boundaries, not a requirement to cover every screen with explanatory labels.

## 1. Navigation, entry, and shared behavior

Use four bottom tabs: Live / Voice / Chats / Me, each with an independent UINavigationController and retained state. A bubble selector switches Live/Shorts inside Live; Shorts is not a fifth tab. Root pages show a floating dock around four icons/titles and a sliding selection bubble. Taps spring into place; dragging slightly stretches the bubble and switches selection. Pushed details, conversations, and settings hide the dock; returning to a root restores it. Switching to a tab already inside a detail keeps it hidden.

Backgrounds fill behind the status bar through the bottom edge. Content may scroll behind the dock, but the final item can scroll above it. Controls respect real safe areas. The keyboard moves input/content without shrinking video. Search expands from the magnifier at the top rather than duplicating a permanent search field; collapsing clears query, keyboard, and associated state.

Startup: native launch background → local loading mark/spinner → Welcome → local entry/consent → main tabs. Preserve Welcome on cold starts. Loading failures offer retry without deleting corrupt files. Do not draw fake clocks, battery/signal indicators, or home indicators.

## 2. Welcome, agreements, and account

- Original Fresh Studio welcome: selected logo, paired-dancer illustration, artistic English heading, lime Get started. Consent shares the style with Let's dance. Limit width and allow scrolling for small screens, landscape, and large text.
- Consent starts false. Reading links is not acceptance. Entering while unchecked presents confirmation; Agree and continue accepts. Persist consent version, content hash, and acceptedAt atomically before navigation. Failure retains the screen.
- Terms of Service and Privacy Policy are available here and in Settings. Historical online WKWebView/local fallback behavior is in services-and-wallet.md. Reading requires no authentication.
- Local entry opens the device library; it does not authenticate credentials or fabricate tokens. Earlier arbitrary-email entry is obsolete.
- Logout requires confirmation, retains data/media/interactions/drafts/wallet, stops active playback/tasks, and returns to entry.
- Delete account requires destructive confirmation and deletes only app-owned data. Pause/drain saves and payment observation before deletion. Failure is not success. Photos originals and remote accounts are not deleted.

## 3. Live discovery

- Top branding, Live/Shorts bubble selector, and search. A 52 pt lime camera/plus opens a dedicated creation form.
- Use a list/grid of rooms rather than a vertical Shorts feed. Cards have actual dance covers, photographic creator portraits, and titles. Portrait taps open the creator; the rest opens the room.
- Visible cards silently loop the first second; stop offscreen/on exit. No duration or play badge. Report-list cards are static.
- Search visible local titles, creators, and descriptions, routing results to Live rooms. Exclude pending submissions, reported content, and blocked creators. Clear/close restores the list.
- Pull-to-refresh reorders without reimporting: unseen first, newer collections first among unseen, older viewing time first among seen, randomized ties, and a different first item when possible. Viewing history is separate; repeat recording within 30 seconds may be throttled.
- Loading, no matches, no media, and unreadable files each have English feedback and recovery. Do not invent online counts.

## 4. Immersive Live rooms

### Playback and controls

- Stable AVPlayer/AVPlayerLayer ownership; no system controls. Enter at normal speed, auto-play, and loop. Aspect-fill covers the screen/status-bar background. Failure shows cover/retry. Exit/background stops or pauses observers/tasks.
- Compact upper creator capsule: round portrait, name, likes, Follow/Following. Close remains reachable. Use existing routes for profiles, room details, search, and More. Do not restore commerce cards, carts, coupons, galleries, or fake rankings.
- Lower input is left aligned with adjacent Send, plus like/gift/share. No separate speaker control crowding Live input. No permanent progress bar or central pause obstruction; taps reveal/toggle necessary playback controls.
- More includes report, block creator, and playback actions. Live can continue beneath supported profile/More/share/gift/search overlays. Actual exit, background, or failure must stop it; do not apply Shorts' pause-on-every-overlay policy indiscriminately.

### Comments and likes

- 152 shared authored English dance lines plus per-video discussions, mixing short reactions and longer exchanges. These are local content, not real online account events.
- Current UIKit scheduler adds 1–3 each second. Lower-left transparent bubbles have thin white outlines, lime names, and white bodies. Usually 5–7 visible, never over seven or roughly one-third screen height. Wrap to two/three lines and evict older bubbles instead of single-line truncation.
- Messages have stable UUIDs. Bubble refresh never recreates AVPlayer. Cancel loops on background/exit; follow controller-specific overlay/accessibility handling. Inspect Reduce Motion/VoiceOver branches without claiming device validation.
- Input is at most 50 English characters. Sending is local; failure preserves text. Long-press reporting removes the target from the current list after saving.
- Repeated Live likes trigger hearts and accumulate separate liveLikes. They have no Shorts-style selected state and never enter Me Liked. Migrate known historical Live likes separately; do not guess unknown imported IDs.

### Creation

Create a live session opens a form first: title, description, dance category, Choose a cover, content/usage-rights confirmation, Submit for review. Never immediately open Photos or fabricate broadcasting. Cover selection supports cancellation/read failure and is optional in current source; Live submissions do not use a Shorts file. Title is required up to 80 characters; description up to 500; both English. Successful local saves appear in Me Pending review as Waiting to submit, not approved or live.

## 5. Shorts

### Page and playback

- Enter inside Live. Vertical switching plays only the current video. Full-screen video extends behind top controls/dock with transparent floating actions; normal-speed auto-play/looping preserves aspect ratio.
- Borderless search at upper right; video/create entry opens its dedicated form. Lower-left layers are floating-comment input, creator name, and description/hashtags.
- Lower-right rail: portrait, Like, Comments, Save, Share, More. More includes report/block. Support landscape, large text, and safe areas.
- Tap to pause/resume; paused video shows a central play mark. Shorts retains progress/seeking. Switching videos, search, sheets, profiles, sharing, and loss of foreground pause according to Shorts policy. Eligible overlays resume after dismissal; exit removes observers.
- Refresh follows Live's unseen-first policy and avoids immediately repeating recent content. Discovery videos are at most three minutes. Saved/creator/private-library playback does not use that discovery-duration filter.

### Shared interactions

- A video UUID is the shared key across discovery, saved playback, creator works, and Me for likes/comments/replies/saves/share counts. Never use independent page copies.
- Stable editorial bases: likes/saves 10–29, shares 10–30, varying by clip. Private imports start at zero. These are not online statistics. Likes/saves update counts and selected red-heart/filled-star states.
- Queue writes so rapid taps are not swallowed. Failed saves are not successful interactions. Saves use the atomic library snapshot; interactions use a separate atomic file. Relaunch preserves comment IDs, parentID, replyToName, and avoids duplicating seeded comments.
- Comments use a continuous off-white background. Input fills available bottom width beside Send. The existing overlay scales video/expands comments and restores on close. On home Shorts it covers Create/dock and avoids the keyboard.
- Comments: 200 English characters, up to 500 persistent comments per video. Replies show author/quote and support cancellation. Failure keeps draft and target. Reporting hides the comment only.
- Floating comments: up to 80 English characters, attempts 1–5 per second, constant right-to-left 96 pt/s with safe lane spacing. Skip crowded lanes instead of overlapping. Inject sent text only after saving. Animation is independent of playback. Floating comments can be disabled; clean up on switch/pause/exit. Do not force moving text with Reduce Motion/VoiceOver.

### Creation and private media

- Create a short video asks for title, description, category, one Photos dance video, content/rights confirmation, and Submit for review.
- Maximum three minutes/250 MB. Copy provider temporary files into app temporary storage before owned Media import and atomic save. Failure cleans only new app-owned temporary copies. Preserve Photos originals; cancellation submits nothing.
- Only awaitingSubmission exists. Do not insert into published feeds/works automatically. Me Pending review supports viewing, playback, and removal.
- Older unclassified private videos remain manageable. Explicit Add to dance feed classifies them; isDance is a declaration, not AI moderation.
- Works allows renaming and explicit deletion of owned copies, never Photos originals. Unsaving keeps the current player alive until exit while list/counts reflect successful persistence.

## 6. Voice discovery

- Original Fresh Studio background/branding with top search. Categories: All / Hip-hop / K-pop / Jazz / Freestyle / Ballet / House.
- Two columns of photographic room cards, two-line titles, consistent hierarchy/radii/outlines. Large text uses one column. Portraits/covers are independent; built-in members do not appear in multiple rooms; each member remains visually consistent.
- Eight original rooms: Hip Hop Vibes, K-Pop Practice, Jazz Flow, Freestyle Circle, Studio Sessions, Ballet Flow, House Flow, Dance Break. Authored member counts: 4/6/3/5/8/4/7/10. These are rosters, not live presence or inflated popularity.
- Portrait taps open members; other card taps open rooms. Local category/title/description filtering excludes reports and rooms containing blocked hosts/members.
- Pull-to-refresh reorders. No separate refresh circle; retain a lower-right 52 pt Create. Loading/empty/retry states are English.
- Form: required Party name up to 60 characters, description up to 240, category, capacity 4/6/8, Save party. Save a local room draft shown in the list. Existing drafts support editing and confirmed deletion. No RTC or fabricated members.
- Earlier Filter/tool-card/all-party designs and unused PartyFilter types are not current UI requirements.

## 7. Voice room interior

- Top room identity/back/details/share. Seats show the owner plus first three members and an invite seat; allow horizontal scrolling on narrow screens. Every member, including the owner, opens the correct profile.
- Message region and keyboard-following input: speaker, microphone, quoted reply/input, Send, gift. Speaking/waveform/mute indicators are local state; toggles do not imply RTC capture/playback.
- 48 authored English lines; randomly add 1–3 every 1–2 seconds, looping with a 200-message history cap. Seed a few on entry. Stop on departure/background, restart only when visible/foreground, and pause appends while covered. Do not force-scroll readers of history; show New messages.
- Owner input is at most 200 English characters. Tapping a message selects a cancellable quote/reply. Local room messages are not persistent network IM; reentry may reset the sequence.
- Long-press reporting uses stable IDs. Details offer room report/host block. Successful persistence closes reported/blocked content.
- Invite lists local followed friends. Persist invitations as pending chat messages; do not add remote participants to seats or claim arrival on failure.
- Share uses the common panel. Gift is right of Send. Everyone/member selection is currently UI-only; actual behavior is local diamond spending plus effects, without remote receipt.

## 8. Shared sharing flow

Live/Shorts/Voice use one bottom panel with horizontal followed-friend portraits/names and Share link. Candidates are single-person conversations subject to blocks/send permission. Use sendChatMessage and report success only after saving. The one-message nonmutual allowance also applies to shares.

- Original internal URLs: `teto://live/{UUID}`, `teto://shorts/{UUID}`, `teto://party/{id}`.
- Share link copies to the clipboard. The template has no public HTTP pages, Universal Links, or OS-level URL scheme registration. Do not promise another device can open them. Private media is not uploaded.
- Chats recognizes Live/Shorts URLs and offers Open live/Watch video after rechecking existence, classification, nonpending/nonreported/nonblocked state, and matching surface. Invalid content gets an English unavailable state.
- Voice share/invite URLs are saved as text without an equivalent room-open parser. A shared panel does not imply this missing capability.
- Increase Shorts shares only after successful copying or atomic friend-message save. Cancel/failure adds nothing. Live/Voice do not alter Shorts counts. Clean up panels on departure.

## 9. Chats

### Inbox

- Branding, Chats title, upper-right search/plus. No coins or duplicate permanent search bar. All/Unread/Pinned/Drafts bubble filters. Horizontal friend updates open authored English dance posts.
- Rows show round personal portraits or rounded group collages, name, latest text/draft, time, unread count, pinned order, and mute icon. Swipe actions: Pin, Read/Unread, Mute, Delete. Opening one closes another; scrolling collapses actions. Delete hides but retains data.
- Search expands at the top, hides updates, and matches names/previews within the current filter. Cancel restores. Pin/read/mute/hide/drafts save atomically.
- Ten original conversations: Dance activity; Maya Chen, Leo Brooks, Zoe Park, Noah Rivera, Aria Wilson, Finn Taylor; After Class Crew, K-pop Practice Circle, Ballet & Balance. Times/unread/history are authored, not network messages.
- Canonical creator ID is `creator-chat:<creatorID>`. Different entry points share one record. Legacy drafts remain visible without a conversation record; clearing a draft does not delete the conversation.
- Group collages deduplicate up to nine real member portraits. Empty legacy groups use a group icon, not the owner's photo. Titles/sharing reuse the same rules.

### Sending permission

1. Mutual individual follows allow repeated local messages, each up to 2,000 English characters. One-way follow is not unlimited.
2. Nonmutual chats allow one lifetime owner greeting, not a daily/relaunch allowance. Seeded history does not count; saved owner messages/shares do. Unfollowing retains history.
3. Groups are exempt, activity is read-only, and blocked recipients cannot receive messages. Unknown incoming follow is false. Follow never fabricates follow-back.
4. Check permissions both at entry and immediately before atomic saving. Failure consumes no allowance and preserves drafts. Messages are local Pending/outbox with no fabricated remote receipts or replies.
5. Existing conversations remain accessible even when the profile Message button is hidden. Profiles show Message only for mutual relationships.

### Conversations and contacts

- Left/right bubbles distinguish other/owner messages with times and local Pending. Auto-scroll only when already near the bottom. Input follows the keyboard; debounce draft saving and retain on departure.
- Single-chat actions: Voice call, Video call, Profile. Use a tilted receiver for Voice call and a separate hang-up icon for End. Groups use collage titles, without invented group calls.
- Plus menu: Create a group, Add a friend, Scan.
- Add a friend searches known local dancer/conversation IDs with Add/Added follow toggling, not a global account directory.
- Group creation lists Face to face and followed individuals. At least two selected friends are required for Create now. Save the owner/member roster and open the local conversation without claiming remote group creation.
- Face to face accurately states nearby matching is unavailable and returns to regular selection. No Bluetooth/Wi-Fi matching exists.
- Scan uses the real camera and accepts only `teto://friend/` or known local IDs. It is not a browser and does not open arbitrary URLs. Handle denied/no-camera/unrecognized states and stop capture on exit.

## 10. Call screens

Only individual chats show calls. Current source adds no mutual-follow gate to opening a call screen; message permissions must not be described as existing call authentication. Voice layout centers the other portrait/name, with Microphone, End, Speaker. Microphone/speaker change local states; End returns. No capture, signaling, connected timer, or real remote peer exists.

Video uses a real front AVCaptureSession and supports flipping. Include Microphone/End/Speaker, Flip camera, and Camera options. Request permission after explicit user action. Denied access offers Settings; loading/restricted/unavailable/interrupted/failed states are accurate English. Preserve iOS 16 orientation fallback. Stop on departure/background/interruption; resume only when active. No recording, upload, or hidden microphone. Local camera preview is not remote video calling.

## 11. Creators and Me

Profiles open from Live portraits/hosts, Shorts names/portraits, Voice portraits/seats, and chat Profile. Show a round portrait/name, Likes/Saves/Following/Followers, biography, IP label, action row, and work grid. No old wide cover. Unknown IP is Not shared; do not infer location from photos or device.

- Likes/Saves sum the same filtered creatorWorks collection, excluding pending/reported/blocked items, without another random base. Relationships use existing local rules; the owner has no invented remote followers.
- Nonmutual layout: expanded Follow/Following and Block at one-quarter width. Mutual layout: Following/Message/Block at one-quarter/one-half/one-quarter. Message rechecks mutual state.
- Follow state is shared. Block requires confirmation and successful saving before returning. The owner cannot block themselves. Works plays full-screen then returns without endlessly stacking profiles. Owner portrait changes propagate.
- Me includes portrait/name/biography, Wallet, Works(n)/Liked(n)/Saved(n)/Pending review(n)/About, without duplicate biography statistics. Counts and grids derive from the same arrays; Liked excludes Live.
- About exposes creation and existing room drafts. Pending review lists waiting submissions with play/remove actions. Edit profile belongs in Settings.
- Editing: one PHPicker image up to 30 MB, name up to 30, biography up to 160 English characters. Cancel retains the old photo; read failure permits reselection; save failure retains input. Store photos only in app-owned Media.

## 12. Safety and settings

Report targets: Live, Shorts, Voice, comments. Reasons: Spam or misleading content / Harassment or bullying / Hate or discrimination / Sexual content / Violence / Dangerous activity / Other. Details are up to 500 English characters.

After atomic report saving, close the form, show Report saved for about three seconds, leave the reported room/video, and refresh underlying lists; home Shorts removes the current item. Comment reporting hides only that comment. Failure retains the form. No server report/moderation service exists.

Blocks store stable creatorID and filter videos, Voice rooms containing that member, and chats without physically deleting private saves/comments/drafts. Settings Blocked lists portraits/names with long-press or VoiceOver Unblock. Reported uses static two-column cards, one column for large text; multiple reasons for one target merge into one card and comments use text cards. Long-press/accessibility Remove report restores visibility.

Every state-changing entry handles busy, cancellation, save failure, and missing content. Never fabricate online results, payments, authentication, or message delivery to improve an empty state.
