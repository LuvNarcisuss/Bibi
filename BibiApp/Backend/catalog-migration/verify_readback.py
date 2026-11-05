"""Compare every exported record and media object with saved remote readback."""
from datetime import datetime
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]

def load(name): return json.loads((OUT / name).read_text())
def indexed(rows): return {r["id"]: r for r in rows}
def instant(value): return datetime.fromisoformat(value.replace("Z", "+00:00"))

def main():
    source = load("catalog.json")
    media = load("media-manifest.json")["objects"]
    remote = {p.stem:json.loads(p.read_text()) for p in (OUT / "readback").glob("*.json")}
    receipts = indexed(load("media-upload-receipts.json")["objects"])
    assert set(indexed(source["content"])) == set(indexed(remote["content"]))
    assert {x["revision_id"] for x in source["content"]} == set(indexed(remote["revisions"]))
    content = indexed(remote["content"]); revisions = indexed(remote["revisions"])
    for row in source["content"]:
        actual = content[row["id"]]
        for key in ("id", "kind", "editorial_profile_id", "circle_id", "parent_id"):
            assert row.get(key) == actual.get(key), (row["id"], key)
        assert actual["owner_id"] is None and actual["editorial"] and not actual["withdrawn"] and not actual["removed"]
        assert actual["approved_revision"] == row["revision_id"] and actual["pending_revision"] is None
        assert instant(actual["created_at"]) == instant(row["created_at"])
        revision = revisions[row["revision_id"]]
        assert revision["status"] == "approved" and revision["content_id"] == row["id"]
        for key in ("title", "body", "media_id", "cover_media_id", "source_url", "credit", "collection_generation"):
            assert row.get(key) == revision.get(key), (row["id"], key)
    assert set(indexed(media)) == set(indexed(remote["media"])) == set(receipts)
    actual_media = indexed(remote["media"])
    actual_objects = {(r["bucket_id"],r["object_path"]):r for r in remote["objects"]}
    assert len(actual_objects) == len(media)
    for row in media:
        actual = actual_media[row["id"]]
        for key in ("id", "bucket_id", "object_path", "mime_type", "byte_count", "sha256", "duration_seconds"):
            assert row.get(key) == actual.get(key), (row["id"],key)
        assert actual["owner_id"] is None and actual["editorial"] and actual["status"] == "ready"
        for key in ("sha256", "byte_count", "mime_type"):
            assert receipts[row["id"]][key] == row[key]
        obj = actual_objects[(row["bucket_id"], row["object_path"])]
        assert obj["byte_count"] == row["byte_count"] and obj["mime_type"] == row["mime_type"]
        for path in row["source_paths"]:
            data = (ROOT / path).read_bytes()
            assert hashlib.sha256(data).hexdigest() == row["sha256"] and len(data) == row["byte_count"]
    for table in ("circles", "challenges", "editorial_profiles"):
        assert set(indexed(source[table])) == set(indexed(remote[table]))
        actual = indexed(remote[table])
        for row in source[table]:
            for key,value in row.items():
                if key == "artwork": assert actual[row["id"]].get(key) == ""
                elif key != "example_index": assert actual[row["id"]].get(key) == value, (table,row["id"],key)
    result={"project_ref":"yepycfnkkfrfmuwdekka","result":"Full export and remote readback match",
            "content":len(content),"videos":sum(r["kind"]=="video" for r in content.values()),
            "posts":sum(r["kind"]=="post" for r in content.values()),"replies":sum(r["kind"]=="reply" for r in content.values()),
            "circles":len(remote["circles"]),"challenges":len(remote["challenges"]),"editorial_profiles":len(remote["editorial_profiles"]),
            "media_objects":len(media),"media_bytes":sum(r["byte_count"] for r in media),
            "private_state_counts_at_readback":remote["private_state_counts"],
            "limitations":["Administrator catalog comparison does not verify fresh-user RLS or signed-URL renewal.","No app build, launch, simulator, playback, or runtime test was performed by this migration."]}
    (OUT/"verification.json").write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result))

if __name__ == "__main__": main()
