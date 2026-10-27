"""Resolve pinned public R2 resources without reading retained local asset files."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
from urllib.parse import quote, urlparse

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "BibiApp/Configuration/RemoteAssets.json"
CACHE = ROOT / "BibiApp/.generated/RemoteAssets"
ORIGIN = "https://pub-fcd7cf821fc64e12885b1422fb08d0f5.r2.dev"


def load_manifest(path=MANIFEST):
    manifest = json.loads(path.read_text())
    records = manifest["files"]
    names = set()
    for record in records:
        name = record["name"]
        if not name or Path(name).name != name or name in {".", ".."} or name.casefold() in names:
            raise ValueError(f"Invalid or duplicate remote asset name: {name}")
        names.add(name.casefold())
        expected = ORIGIN + "/" + quote(name, safe="")
        if record["url"] != expected or urlparse(record["url"]).scheme != "https":
            raise ValueError(f"Unexpected remote asset URL: {record['url']}")
        if not re.fullmatch(r"[0-9a-f]{64}", record["sha256"]) or record["size"] < 0:
            raise ValueError(f"Invalid integrity metadata: {name}")
    return manifest


def matches(path, record):
    if path.is_symlink() or not path.is_file() or path.stat().st_size != record["size"]:
        return False
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest() == record["sha256"]


def download(url, destination):
    result = subprocess.run([
        "/usr/bin/curl", "--fail", "--silent", "--show-error", "--location",
        "--proto", "=https", "--proto-redir", "=https", "--retry", "2",
        "--connect-timeout", "15", "--max-time", "180", "--output", str(destination), url
    ], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f"Could not download {url}: {result.stderr.strip()}")


def ensure_asset(record, cache=CACHE, downloader=download, refresh=False):
    cache.mkdir(parents=True, exist_ok=True)
    destination = cache / record["name"]
    if destination.parent != cache:
        raise ValueError("Remote asset names must be flat")
    if not refresh and matches(destination, record):
        return destination
    with tempfile.NamedTemporaryFile(prefix=".download-", dir=cache, delete=False) as stream:
        temporary = Path(stream.name)
    try:
        downloader(record["url"], temporary)
        if not matches(temporary, record):
            raise ValueError(f"R2 resource integrity mismatch: {record['url']}; update the reviewed manifest before using changed content")
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)
    return destination


def fetch_assets(names=None, cache=CACHE, manifest_path=MANIFEST, refresh=False):
    manifest = load_manifest(manifest_path)
    by_name = {record["name"]: record for record in manifest["files"]}
    selected = list(names) if names is not None else manifest["buildResources"]
    unknown = set(selected) - by_name.keys()
    if unknown:
        raise ValueError(f"Unregistered remote resources: {sorted(unknown)}")
    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(lambda name: ensure_asset(by_name[name], cache, refresh=refresh), selected))
    return cache


def asset_url(name):
    for record in load_manifest()["files"]:
        if record["name"] == name:
            return record["url"]
    raise ValueError(f"Unregistered remote resource: {name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="Verify every remote source, including development artwork")
    parser.add_argument("--refresh", action="store_true", help="Download and verify even valid cached resources")
    parser.add_argument("--cache", type=Path, default=CACHE)
    args = parser.parse_args()
    manifest = load_manifest()
    names = [record["name"] for record in manifest["files"]] if args.all else manifest["buildResources"]
    fetch_assets(names, args.cache, refresh=args.refresh)
    print(f"Verified {len(names)} R2 resources in {args.cache}")
