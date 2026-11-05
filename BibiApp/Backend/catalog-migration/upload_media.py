"""Upload and hash-verify only the fixed editorial catalog objects.

The temporary maintenance token is read from a mode-0600 file, never printed or
passed on a command line. This script cannot modify database rows or agreements.
The server refuses objects outside its immutable deployment allowlist.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import urllib.request
import urllib.parse

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
ENDPOINT = "https://yepycfnkkfrfmuwdekka.supabase.co/functions/v1/bibi-catalog-transfer"

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--token-file", type=Path, required=True)
    args = parser.parse_args()
    if args.token_file.stat().st_mode & 0o077:
        raise SystemExit("The maintenance token file must have mode 0600.")
    token = args.token_file.read_text().strip()
    manifest = json.loads((OUT / "media-manifest.json").read_text())
    def upload(item):
        data = (ROOT / item["source_paths"][0]).read_bytes()
        if len(data) != item["byte_count"] or hashlib.sha256(data).hexdigest() != item["sha256"]:
            raise RuntimeError("Source integrity mismatch: " + item["id"])
        target = item["bucket_id"] + "/" + item["object_path"]
        url = ENDPOINT + "?" + urllib.parse.urlencode({"object":target})
        # Headers travel through stdin rather than process arguments or logs.
        config = 'header = "Authorization: Bearer ' + token + '"\n'
        command = ["/usr/bin/curl", "--config", "-", "--fail", "--silent", "--show-error",
                   "--proto", "=https", "--max-time", "60", "--connect-timeout", "15",
                   "--header", "Content-Type: " + item["mime_type"],
                   "--data-binary", "@" + str(ROOT / item["source_paths"][0]), url]
        result = subprocess.run(command, input=config, capture_output=True, text=True, timeout=65)
        if result.returncode:
            raise RuntimeError("Upload failed for " + item["id"] + ": " + result.stderr.strip())
        receipt = json.loads(result.stdout)
        if not receipt.get("verified") or any(receipt.get(k) != item[k] for k in ("sha256","byte_count","mime_type")):
            raise RuntimeError("Cloud integrity mismatch: " + item["id"])
        return {"id":item["id"],**receipt}
    with ThreadPoolExecutor(max_workers=3) as pool:
        receipts = list(pool.map(upload,manifest["objects"]))
    evidence={"project_ref":manifest["project_ref"],"checked_at":datetime.now(timezone.utc).isoformat(),
              "method":"Private Storage full-byte authenticated readback in bounded maintenance function",
              "object_count":len(receipts),"byte_count":sum(x["byte_count"] for x in receipts),"objects":receipts}
    (OUT / "media-upload-receipts.json").write_text(json.dumps(evidence,indent=2)+"\n")
    print(json.dumps({"verified_objects":len(receipts),"verified_bytes":evidence["byte_count"]}))

if __name__ == "__main__": main()
