"""Rebuild disposable Xcode metadata from the repository's flat asset sources."""
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "Assets"
DESTINATION = ROOT / "BibiApp/.generated/Assets.xcassets"
POLICY = ROOT / "BibiApp/Configuration/ProductionResourcePolicy.json"


def production_entries(assets=ASSETS):
    entries = json.loads((assets / "asset-catalog-index.json").read_text())
    prefixes = tuple(json.loads(POLICY.read_text())["excluded_catalog_prefixes"])
    return [entry for entry in entries if not entry["directory"].startswith(prefixes)]


def prepare_catalog(assets=ASSETS, destination=DESTINATION):
    entries = production_entries(assets)
    outputs = {}
    for entry in entries:
        directory = entry["directory"]
        if directory != "." and (Path(directory).name != directory or not directory.endswith(
                (".imageset", ".appiconset", ".colorset"))):
            raise ValueError(f"Invalid catalog directory: {directory}")
        metadata = assets / entry["metadata"]
        if metadata.parent != assets:
            raise ValueError("Catalog metadata must be a flat asset")
        data = metadata.read_bytes()
        content = json.loads(data)
        outputs[Path(directory) / "Contents.json"] = data
        expected = {image["filename"] for image in content.get("images", []) if "filename" in image}
        if expected != set(entry["images"]):
            raise ValueError(f"Catalog image mapping mismatch: {directory}")
        for filename, source_name in entry["images"].items():
            if Path(filename).name != filename or Path(source_name).name != source_name:
                raise ValueError("Image names must be flat filenames")
            source = assets / source_name
            if not source.is_file():
                raise FileNotFoundError(source)
            outputs[Path(directory) / filename] = source.resolve()

    # Validate the entire input before changing any generated file.
    destination.mkdir(parents=True, exist_ok=True)
    for relative, value in outputs.items():
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(value, bytes):
            if not target.is_file() or target.read_bytes() != value:
                target.write_bytes(value)
        else:
            link = os.path.relpath(value, target.parent.resolve())
            if not target.is_symlink() or os.readlink(target) != link:
                if target.is_symlink() or target.exists():
                    target.unlink()
                target.symlink_to(link)
    for path in sorted(destination.rglob("*"), key=lambda p: len(p.parts), reverse=True):
        if path.is_symlink() or path.is_file():
            if path.relative_to(destination) not in outputs:
                path.unlink()
        elif path.is_dir() and not any(path.iterdir()):
            path.rmdir()
    print(f"Prepared {len(entries)} asset catalog entries from {assets}")


if __name__ == "__main__":
    prepare_catalog()
