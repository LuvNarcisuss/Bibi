"""Restore missing pinned Supabase build inputs; keep current app-specific files in Git."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import re

from remote_assets import ensure_asset, load_manifest, matches

ROOT = Path(__file__).resolve().parents[2]
LFS_HEADER = b"version https://git-lfs.github.com/spec/v1"


def restore(root):
    assets = root / "Assets"
    configuration = root / "BibiApp/Configuration"
    manifest = json.loads((configuration / "CIResources.json").read_text())
    if manifest.get("version") != 1:
        raise ValueError("Unsupported CI resource manifest version")
    remote = {item["name"]: item for item in load_manifest(configuration / "RemoteAssets.json")["files"]}
    names = set()
    downloads = []
    failures = []
    for record in manifest["files"]:
        name = record["name"]
        if (not name or Path(name).name != name or name in {".", ".."}
                or name.casefold() in names):
            raise ValueError(f"Invalid or duplicate CI resource name: {name}")
        names.add(name.casefold())
        if (record["source"] not in {"git", "supabase"}
                or not re.fullmatch(r"[0-9a-f]{64}", record["sha256"])
                or not isinstance(record["size"], int) or record["size"] < 0):
            raise ValueError(f"Invalid CI integrity metadata: {name}")
        if record["source"] == "supabase":
            pinned = remote.get(name)
            if not pinned or any(pinned[key] != record[key] for key in ("size", "sha256")):
                raise ValueError(f"CI/Supabase manifest mismatch: {name}")
        path = assets / name
        if path.exists() or path.is_symlink():
            if not matches(path, record):
                pointer = path.is_file() and path.read_bytes().startswith(LFS_HEADER)
                detail = "Unresolved Git LFS pointer" if pointer else "Changed local resource (not overwritten)"
                failures.append(f"{detail}: Assets/{name}")
        elif record["source"] == "git":
            failures.append(f"Missing Git-owned resource: Assets/{name}. Commit and push this file.")
        else:
            downloads.append(pinned)
    # Validate all committed inputs before any downloads or resource writes.
    if failures:
        raise ValueError("\n".join(failures))
    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(lambda record: ensure_asset(record, cache=assets), downloads))
    if not all(matches(assets / record["name"], record) for record in manifest["files"]):
        raise ValueError("CI resource integrity verification failed")
    print(f"Verified {len(manifest['files'])} pinned CI resources; restored {len(downloads)} missing Supabase files.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="Checkout root to restore")
    args = parser.parse_args()
    try:
        restore(args.root.resolve())
    except (ValueError, RuntimeError, OSError) as error:
        parser.exit(1, f"ERROR: {error}\n")
