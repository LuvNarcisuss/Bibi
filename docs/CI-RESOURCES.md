# CI resource restoration

The remote origin is now the public Supabase Storage bucket
`bibi-build-assets`. Codemagic restores pinned objects over HTTPS without a
credential. The bucket was created on October 29, 2026 and now contains all 319
build resources.

## Failure

The cloud checkout did not contain Assets/asset-catalog-index.json. Assets was
ignored except for the seven agreement files. git lfs pull only fetches objects
referenced by committed LFS pointers; it cannot recover arbitrary ignored local
files. Resource verification correctly stopped before signing or archiving.

## Current delivery contract

BibiApp/Configuration/CIResources.json pins every required file's flat name,
byte size, SHA-256 and source. Its 397 records are derived from the current asset
catalog index and the explicit Assets resource entries in project.yml.

- 309 unchanged resources are restored from the public Supabase Storage `bibi-build-assets` bucket, using the
  already-pinned URLs/hashes in RemoteAssets.json.
- 88 current files are Git-owned because they are new, changed, or have no matching
  remote revision. These include the asset index, current branding, newer media,
  fonts, metadata and bundled agreement PDFs. Narrow ignore exceptions expose
  these inputs for commit, without exposing the entire retained Assets directory.
- Existing agreement source/provenance exceptions remain. The resource snapshot
  does not turn the full local development asset archive into a build input.

The Codemagic order is LFS fetch, restore_ci_resources.py, verify_ci_resources.py,
then prepare_asset_catalog.py. The restore script checks all Git inputs before
network work, downloads only missing Supabase files, verifies size/hash, and uses the
existing atomic download helper. It rejects changed local files, symlinks and
unresolved LFS pointers rather than overwriting them or silently restoring older
branding. The separate checker then validates catalog/project reference coverage.

Commit and push the changed workflow, scripts, configuration, ignore rules and
all Git-owned Assets before retrying the cloud build. Merely editing .gitignore
or running LFS locally does not put files in a remote checkout. Keep signing
credentials out of the resource commit; this fix does not alter signing setup.

The November 5 agreement refresh retains Git ownership of both PDFs. Their
CIResources.json records must match the newly approved bundled PDF hashes in
agreement-source-provenance.json; do not restore the older build-bucket copies
or disable mismatch rejection to resolve a resource verification failure.

For future resource changes, refresh the CI snapshot's size/hash and source for
all changed/added project inputs. Select Supabase only when the approved remote manifest
has the exact same bytes; otherwise commit the current asset and its ignore
exception. Preserve the real branding, licenses, sources and user private media.

## Verification scope

Local inspection verifies all 397 files against the snapshot and catalog/project
references. An independent temporary CI-layout directory contains only the 88
Git-owned inputs plus the tracked configuration/scripts. The missing-Supabase state is
confirmed before restoration; subsequent real HTTPS restoration checks the
fresh-directory path, without reading the working Assets directory.

The result and execution limits are recorded in IMPLEMENTATION.md and STATIC-AUDIT.md.
Resource preparation and file inspection do not establish a successful Xcode
build, installed app, code signing, Codemagic job or App Store upload.
