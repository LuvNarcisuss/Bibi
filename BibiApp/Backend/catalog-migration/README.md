# Editorial catalog migration

Project: `yepycfnkkfrfmuwdekka`. This maintenance archive is outside the application target. It does not create Auth accounts or import personal state.

## Deployed and checked on November 4, 2026

- Schema migrations: `20261104015639_editorial_catalog_media_identity` and `20261104020045_editorial_catalog_hash_integrity`.
- Published catalog: 10 active Shorts, 14 fictional stories, 4 editorial circle prompts and 28 authored replies; 56 approved content records and revisions. The 8 retired Live clips remain excluded.
- Identities: 6 fictional story curators and Bibi Editorial, stored in `bibi_editorial_profiles` without login capability. Existing author IDs, content UUIDs, parent relationships and source attribution are preserved. Fictional follow, follower, like and save baselines are excluded.
- Media: 33 images and 10 H.264 MP4 videos, 43 unique objects totaling 19,953,660 bytes. Covers, avatars, circle/challenge artwork and video files are included. Two post covers reuse the exact video-cover bytes. Bucket visibility remains private.
- All object bytes were uploaded through the Storage API and downloaded again by the bounded maintenance function. Every SHA-256, byte count and MIME type matches the local manifest. `media-upload-receipts.json` records each result; `readback/` and `verification.json` compare every published catalog field and object reference.
- The `artwork` compatibility columns in circles/challenges are empty. Online presentation resolves `artwork_media_id`; no old `BibiRoom` resource names remain in those fields.
- `collection_generation` preserves the existing `AnimationClip.collectionGeneration` discovery grouping (1 and 2). It is source content ordering metadata, not a new synchronization or dataset-version field.
- At catalog readback there were zero real profiles, follows, likes and messages. No wallet, consent, conversation, agreement, membership or personal entry was seeded.

## Temporary transfer lifecycle

`bibi-catalog-transfer` revision 1 failed to start because deployment placeholders were not fully substituted. Revision 2 authenticated a random 48-byte token, enforced a fixed 43-object hash/size/MIME allowlist, refused replacement of conflicting objects and expired after two hours. The token existed only in a mode-0600 temporary file and was never included in application configuration, command arguments or repository files. The function had its own authentication, so gateway JWT verification was disabled only for this temporary endpoint.

After the complete upload and catalog publication, revision 3 immediately replaced the transfer implementation with `transfer-disabled.ts`. A real unauthenticated HTTPS GET returned `410` and `Catalog transfer is disabled.`. All temporary token, digest and rendered deployment files were removed. Revision 3 contains no allowlist, secret or Storage capability. The retained function templates contain placeholders only.

## Reproduction and evidence

1. `export_catalog.py` exports the complete archived source catalog, validates stable IDs and inspects local file signatures. The JSON source archive retains the original Swift source and its hash; it is never read by the app.
2. `archive_provenance.py` retains the existing licensing/generation records matching the migrated assets. `source/media-provenance.json` records source file hashes and selected records; original credited names remain intact in escaped JSON.
3. `upload_media.py --token-file <mode-0600-file>` requires a deliberately deployed, bounded transfer function and the matching maintenance token. It never obtains a service key. It uploads exact local bytes without silent retries or overwrite.
4. `build_seed.py` regenerates the insert-only transaction. It rejects a catalog UUID already owned by a real user and refuses publication before all expected Storage object metadata exist. Existing approved revisions are not overwritten.
5. `verify_readback.py` compares the complete saved remote readback against all source records, references and verified bytes. `video-file-inspection.json` records static ffprobe inspection of all 10 H.264 files; this is not playback evidence.

Administrator readback and maintenance-function downloads do not replace a fresh anonymous user's RLS, private signed-URL renewal, video Range, or application-equivalent API checks. Those remain separate acceptance work. This migration did not build, typecheck, launch the app, start a simulator, execute a player or run runtime tests. It did not change `BibiBackendEnabled` or any frozen agreement content, object or URL.

## Production source retirement

After full cloud comparison, the production `AnimationCatalog` and `CommunityCatalog` collections were replaced with typed empty compatibility interfaces. The application no longer reads the bundled animation JSON or carries the authored community posts, replies, prompts or fictional profile payloads. `FandomDiscussion` and `FandomCommentScript` return no generated comments. Legacy artwork helpers use the Bibi mark; existing private serialization fields remain unchanged.

`source/retired-production-source.json` retains exact pre-retirement source text and hashes, including the application models, artwork helpers, packaging script and original CI resource inventory. The original full editorial export still reruns from its separate immutable source snapshots. No original asset bytes, device files or private user data were deleted or rewritten.

`ProductionResourcePolicy.json` excludes all 83 portrait, avatar, post-cover and challenge-cover entries from generated application resources. The 91 retained catalog entries are interface artwork: branding, icons, titles, colors, generated decorative room/welcome illustrations and existing cosmetic UI artwork. The Circles and Challenges overview banners now use the retained welcome illustration. Raw video/cover files, the old animation JSON and runtime asset inventory are removed from `project.yml`; the active CI input inventory contains 187 resources instead of 397. Original source media and remote CI archive objects remain available for maintenance, outside the application target.

Static preparation and source-resource inspection confirmed those counts, absence of excluded generated image sets, unchanged source-media hashes, and preserved APNs/signing identity settings. `production-retirement.json` records the result. Xcode project metadata regeneration is coordinated by the parent task. No build, typecheck, app, simulator or runtime test was executed here.

The cutover gate remains false. The retired local community catalog consequently stays empty until the verified online path is deliberately enabled; real user-owned local archive data is retained. Source retirement does not establish release activation or complete the remaining authenticated-service acceptance checks.
