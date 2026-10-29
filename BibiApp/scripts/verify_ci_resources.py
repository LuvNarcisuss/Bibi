"""Check that a CI checkout contains Bibi's required source resources."""
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "Assets"
INDEX = ASSETS / "asset-catalog-index.json"
LFS_HEADER = b"version https://git-lfs.github.com/spec/v1"


def main():
    if not INDEX.is_file():
        sys.exit("ERROR: Assets/asset-catalog-index.json is missing. Commit the required "
                 "Assets sources; ignored local files are unavailable to Codemagic.")
    with INDEX.open("rb") as source:
        if source.read(len(LFS_HEADER)) == LFS_HEADER:
            sys.exit("ERROR: Download the asset catalog index with Git LFS first.")
    required = {INDEX}
    for entry in json.loads(INDEX.read_text()):
        required.add(ASSETS / entry["metadata"])
        required.update(ASSETS / name for name in entry["images"].values())
    specification = (ROOT / "BibiApp/project.yml").read_text()
    required.update(ASSETS / name for name in re.findall(
        r"^\s+- path: \.\./Assets/(.+)$", specification, re.MULTILINE))
    failures = []
    for path in sorted(required):
        if not path.is_file():
            failures.append(f"Missing resource: {path.relative_to(ROOT)}")
            continue
        with path.open("rb") as source:
            if source.read(len(LFS_HEADER)) == LFS_HEADER:
                failures.append(f"Unresolved Git LFS pointer: {path.relative_to(ROOT)}")
    if failures:
        sys.exit("\n".join(failures) + "\nERROR: Commit or restore the required source "
                 "resources before starting the Codemagic build.")
    print(f"Verified {len(required)} source resources for the CI checkout.")


if __name__ == "__main__":
    main()
