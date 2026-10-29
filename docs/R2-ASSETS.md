# R2 resources and local agreements

Historical record: agreement delivery below was superseded on October 29, 2026.
Current agreements use public Supabase PDFs and matching bundled PDF fallback.
See IMPLEMENTATION.md for the active delivery and verification record.

Date: October 27, 2026. Repository paths below are relative to the root.

## Resource delivery

`BibiApp/Configuration/RemoteAssets.json` lists 420 source files with full URLs, sizes and SHA-256 hashes. The canonical origin is `https://pub-fcd7cf821fc64e12885b1422fb08d0f5.r2.dev`; for example, `AppIcon.png` resolves to `https://pub-fcd7cf821fc64e12885b1422fb08d0f5.r2.dev/AppIcon.png`.

The build subset contains 319 downloads: 141 native catalog metadata files, 139 images (138 runtime images and one app icon), two inventory/index files, and 37 loose runtime files. The catalog also supplies the launch color. Two generated inventories accompany the 37 loose files. Media, fonts and images continue to work from the compiled app bundle without runtime downloads.

| Directory | Contents | Source / Git treatment |
|---|---|---|
| `Assets/` | 425 retained flat source files | Ignored by `/Assets/`; all 425 files removed from the Git index only; no build or preparation tool reads them |
| `Agreements/` | `TermsOfService.html`, `PrivacyPolicy.html`, `provenance.json` | Authored local agreements; included in source control; two HTML files bundled |
| `BibiApp/Configuration/` | `RemoteAssets.json` | Tracked canonical resource names, URLs, hashes and build subset |
| `BibiApp/.generated/RemoteAssets/` | Verified remote downloads | Ignored disposable cache |
| `BibiApp/.generated/Assets.xcassets/` | Native catalog metadata and relative image links | Ignored generated Xcode input |
| `BibiApp/.generated/BundledResources/` | Runtime resource links and generated inventories | Ignored generated Xcode input |
| `BibiApp/.generated/ArtworkExports/`, `MediaExports/` | Optional processing outputs | Ignored; generated only when the respective tool runs |

`remote_assets.py` downloads missing or invalid cache entries to temporary files, verifies their exact size and SHA-256, and replaces the destination atomically. Valid downloaded cache entries can be reused offline. Download failures and integrity mismatches fail resource preparation; there is no fallback to retained root `Assets/` files. To refresh the build subset explicitly, run `python3 BibiApp/scripts/remote_assets.py --refresh`. Add `--all` for development originals and provenance. Review remote changes before updating manifest hashes.

XcodeGen runs preparation before metadata generation. Direct Xcode builds run the same preparation phase before copying resources and compiling the asset catalog. App identity, signing team, deployment target and iPhone-only destinations are unchanged.

## Git exclusion

After the successful tests and final source-export build, `/Assets/` was added to `.gitignore` and all 425 existing asset entries were removed with `git rm --cached -r -- Assets`. The local directory and every file remain unchanged. `git ls-files -- Assets` returns no entries, and `git check-ignore` identifies the root ignore rule. The new Agreements files are not ignored. These changes have not been committed or pushed; existing Git/GitHub history was not rewritten.

## Agreements

The owner selected local HTML under a new root directory. `Agreements/` is independent of retained source assets and R2 downloads. Its two English documents derive from the latest shared Google Docs read on October 27, 2026. Descriptions of online agreement requests and saved-copy fallback were adapted to the current local reader. Source revisions, source text hashes and final HTML hashes are in `Agreements/provenance.json`. The Google documents and R2 objects were not changed during this migration.

The app uses `loadFileURL` with read access limited to the selected file and permits navigation only to that bundled document. Inline CSS uses system fonts; HTML contains no remote scripts, images, frames, fonts or links. A restrictive content security policy blocks external loads. Acceptance versions hash both bundled HTML files. Content-process failures show a Retry control.

The five obsolete agreement files are excluded from the remote manifest: two HTML files, two source-text snapshots and their provenance JSON. The retained copies in `Assets/` are not loaded or overwritten. The local agreements retain the previously requested blank contact email and the unspecified operator identity; they remain drafts.

## Verification

The required workspace build, installation and launch succeeded on `Bibi UI Acceptance` (iPhone 17 Pro, iOS 26.0.1, UDID `0C3DC278-7663-4B7E-9FCD-10F2FF679569`). The explicitly launched process was 34855. Tests use the latest workspace source, not a previously installed app.

- Eleven Python resource regression tests passed, covering download integrity, cache repair, failure behavior, absent local fallback, manifest validation and generated resource consistency.
- The static audit passed 437 checks with no failures.
- Both local HTML hashes match their provenance records; neither contains external resource references.
- All 425 retained asset files match their pre-migration local SHA-256 hashes, including pre-existing uncommitted agreement edits.
- The full Bibi XCTest scheme passed all 17 tests (11 unit tests and 6 UI tests), with zero failures and zero skipped tests. Coverage includes bundled images, fonts, all 16 videos/covers, R2 byte receipts, local HTML and consent hashes, retry behavior, wallet persistence, five-page navigation at two text sizes, local agreement rendering, account controls and search/chat navigation.
- Both agreement screenshots were visually inspected: headings and English body text render without clipping in the captured viewport. The final direct source-export build passed without root Assets or pre-generated catalog inputs. Its cache started empty and all 319 files came from R2; two attempts stopped on transient TLS handshake timeouts, and the third completed using previously verified downloads plus the remaining R2 files. No retained Assets files or other local resource caches were copied into that export. Failed attempts are preserved in the evidence directory.

Evidence lives under `BibiApp/Design/RunEvidence/R2/20261027/`. The earlier online-reader XCTest run was interrupted when the owner changed the agreement requirement and is not counted as a successful final run.

This verification does not cover Apple sandbox/production purchases, backend services, physical devices or every OS version. The separate purchase UI scheme was not rerun for this resource migration. No commit, push, cloud upload or history rewrite was performed.
