"""Upload the reviewed CI resource snapshot to private Supabase Storage.

Run this one-time maintenance command only from a trusted environment with
SUPABASE_BUILD_ASSETS_SERVICE_ROLE_KEY set. The key is never written to the
repository or passed to Codemagic artifacts.
"""
import json
import mimetypes
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "Assets"
CONFIGURATION = ROOT / "BibiApp/Configuration"
ENDPOINT = "https://yepycfnkkfrfmuwdekka.supabase.co/storage/v1/object/bibi-build-assets"
KEY_ENV = "SUPABASE_BUILD_ASSETS_SERVICE_ROLE_KEY"


def upload(record, key):
    source = ASSETS / record["name"]
    if not source.is_file() or source.stat().st_size != record["size"]:
        raise RuntimeError(f"Missing or unexpected local resource: {source}")
    content_type = mimetypes.guess_type(source.name)[0] or "application/octet-stream"
    url = ENDPOINT + "/" + quote(record["name"], safe="")
    with tempfile.NamedTemporaryFile(prefix="bibi-upload-", delete=False) as stream:
        temporary = Path(stream.name)
    try:
        result = subprocess.run([
            "/usr/bin/curl", "--fail", "--silent", "--show-error", "--location",
            "--proto", "=https", "--proto-redir", "=https", "--retry", "2",
            "--connect-timeout", "15", "--max-time", "300",
            "--header", f"apikey: {key}",
            "--header", f"Authorization: Bearer {key}",
            "--header", f"Content-Type: {content_type}",
            "--header", "x-upsert: true",
            "--data-binary", f"@{source}", "--output", str(temporary),
            "--write-out", "%{http_code}", url,
        ], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(f"Upload failed for {record['name']}: {result.stderr.strip()}")
        if result.stdout[-3:] not in {"200", "201"}:
            raise RuntimeError(f"Unexpected upload response for {record['name']}: {result.stdout[-3:]}")
    finally:
        temporary.unlink(missing_ok=True)


def main():
    key = os.environ.get(KEY_ENV)
    if not key:
        sys.exit(f"ERROR: set {KEY_ENV} in a trusted environment before uploading.")
    manifest = json.loads((CONFIGURATION / "RemoteAssets.json").read_text())
    records = {record["name"]: record for record in manifest["files"]
               if record["name"] in set(manifest["buildResources"])}
    for record in records.values():
        upload(record, key)
    print(f"Uploaded {len(records)} reviewed build resources to private Supabase Storage.")


if __name__ == "__main__":
    main()
