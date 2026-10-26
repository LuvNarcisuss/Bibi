"""Verify the flat source inventory and the disposable Xcode catalog."""
import hashlib
import json
from pathlib import Path
import unittest
import tempfile
from prepare_asset_catalog import prepare_catalog

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "Assets"


class FlatAssetTests(unittest.TestCase):
    def test_missing_input_leaves_existing_generated_catalog_intact(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            assets = root / "Assets"
            assets.mkdir()
            destination = root / "catalog"
            destination.mkdir()
            marker = destination / "keep.txt"
            marker.write_text("Previous valid output")
            (assets / "entry.json").write_text(json.dumps({"images": [{"filename": "art.png"}]}))
            (assets / "asset-catalog-index.json").write_text(json.dumps([
                {"directory": "Example.imageset", "metadata": "entry.json", "images": {"art.png": "missing.png"}}
            ]))
            with self.assertRaises(FileNotFoundError):
                prepare_catalog(assets, destination)
            self.assertEqual(marker.read_text(), "Previous valid output")

    def test_regeneration_is_idempotent_and_removes_stale_outputs(self):
        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder) / "catalog"
            prepare_catalog(ASSETS, destination)
            metadata = destination / "Contents.json"
            modified = metadata.stat().st_mtime_ns
            stale = destination / "Removed.imageset"
            stale.mkdir()
            (stale / "Contents.json").write_text("{}")
            prepare_catalog(ASSETS, destination)
            self.assertEqual(metadata.stat().st_mtime_ns, modified)
            self.assertFalse(stale.exists())
            self.assertEqual((destination / "Portrait1.imageset/art.png").resolve(), ASSETS / "Portrait1.png")

    def test_every_migrated_file_is_flat_and_preserved(self):
        self.assertTrue(ASSETS.is_dir(), "The repository-root Assets directory is missing")
        manifest = json.loads((ASSETS / "asset-migration.json").read_text())
        self.assertGreater(len(manifest["files"]), 300)
        self.assertFalse(any(p.is_dir() for p in ASSETS.iterdir()))
        names = [record["destination"] for record in manifest["files"]]
        self.assertEqual(len(names), len(set(name.casefold() for name in names)))
        for record in manifest["files"]:
            with self.subTest(source=record["source"]):
                path = ASSETS / record["destination"]
                self.assertEqual(path.parent, ASSETS)
                self.assertTrue(path.is_file())
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), record["sha256"])
                if path.suffix.lower() not in {".json", ".md", ".txt"}:
                    self.assertEqual(record["sha256"], record["originalSHA256"])
                if manifest.get("originalsRemoved"):
                    self.assertFalse((ROOT / record["source"]).exists(), "Original was not removed")

    def test_generated_catalog_resolves_every_image(self):
        catalog = ROOT / "BibiApp/.generated/Assets.xcassets"
        self.assertTrue(catalog.is_dir())
        count = 0
        for metadata in catalog.rglob("Contents.json"):
            content = json.loads(metadata.read_text())
            for item in content.get("images", []):
                if "filename" in item:
                    path = metadata.parent / item["filename"]
                    self.assertTrue(path.is_file(), str(path))
                    self.assertEqual(path.resolve().parent, ASSETS)
                    count += 1
        self.assertEqual(count, 139)
        self.assertTrue((catalog / "BibiLaunchBackground.colorset/Contents.json").is_file())

    def test_only_runtime_resources_are_in_project(self):
        project = (ROOT / "BibiApp/Bibi.xcodeproj/project.pbxproj").read_text()
        for filename in ["hero.mp4", "spring.mp4", "review-contact-1.jpg", "generated-welcome.png"]:
            self.assertNotIn(filename + " in Resources", project)
        for filename in ["animation-catalog.json", "Fredoka-Variable.ttf", "Nunito-Variable.ttf",
                         "TermsOfService.html", "PrivacyPolicy.html", "runtime-asset-inventory.json"]:
            self.assertIn(filename + " in Resources", project)
        self.assertNotIn("path = Agreements;", project)
        self.assertNotIn("path = AnimationMedia;", project)


if __name__ == "__main__":
    unittest.main()
