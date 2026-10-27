"""Exercise remote download failures, integrity checks and cache isolation."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from remote_assets import ORIGIN, ensure_asset, load_manifest, matches


class RemoteAssetTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.cache = self.root / "cache"
        self.payload = b"Remote asset bytes"
        self.record = {"name": "Example.png", "url": ORIGIN + "/Example.png",
                       "sha256": hashlib.sha256(self.payload).hexdigest(), "size": len(self.payload)}

    def download(self, url, target):
        self.assertEqual(url, self.record["url"])
        target.write_bytes(self.payload)

    def test_valid_download_is_atomically_cached_and_reused(self):
        path = ensure_asset(self.record, self.cache, self.download)
        self.assertTrue(matches(path, self.record))
        ensure_asset(self.record, self.cache, lambda *_: self.fail("Valid cache must not download again"))
        self.assertEqual([p.name for p in self.cache.iterdir()], ["Example.png"])

    def test_corrupt_cache_is_replaced_from_remote(self):
        self.cache.mkdir()
        (self.cache / "Example.png").write_bytes(b"Corrupt")
        path = ensure_asset(self.record, self.cache, self.download)
        self.assertEqual(path.read_bytes(), self.payload)

    def test_hash_mismatch_cannot_replace_previous_cache(self):
        path = ensure_asset(self.record, self.cache, self.download)
        with self.assertRaisesRegex(ValueError, "integrity mismatch"):
            ensure_asset(self.record, self.cache, lambda _, target: target.write_bytes(b"Wrong remote bytes"), refresh=True)
        self.assertEqual(path.read_bytes(), self.payload)
        self.assertFalse(list(self.cache.glob(".download-*")))

    def test_failed_download_never_uses_retained_local_file(self):
        local = self.root / "Assets"
        local.mkdir()
        (local / "Example.png").write_bytes(self.payload)
        def failure(_, target):
            target.write_bytes(b"Partial response")
            raise RuntimeError("HTTP 404")
        with self.assertRaisesRegex(RuntimeError, "HTTP 404"):
            ensure_asset(self.record, self.cache, failure)
        self.assertFalse((self.cache / "Example.png").exists())
        self.assertFalse(list(self.cache.iterdir()))
        self.assertEqual((local / "Example.png").read_bytes(), self.payload)

    def test_cache_symlink_is_not_accepted_as_downloaded_content(self):
        retained = self.root / "Retained.png"
        retained.write_bytes(self.payload)
        self.cache.mkdir()
        (self.cache / "Example.png").symlink_to(retained)
        calls = []
        def download(url, target):
            calls.append(url)
            self.download(url, target)
        path = ensure_asset(self.record, self.cache, download)
        self.assertEqual(len(calls), 1)
        self.assertFalse(path.is_symlink())
        self.assertEqual(retained.read_bytes(), self.payload)

    def test_manifest_rejects_wrong_origins_nested_names_and_duplicates(self):
        variants = [
            [{**self.record, "url": "http://example.com/Example.png"}],
            [{**self.record, "name": "../Example.png"}],
            [self.record, self.record],
            [{**self.record, "sha256": "not-a-hash"}],
        ]
        manifest = self.root / "manifest.json"
        for records in variants:
            with self.subTest(records=records):
                manifest.write_text(json.dumps({"files": records}))
                with self.assertRaises(ValueError):
                    load_manifest(manifest)


if __name__ == "__main__":
    unittest.main()
