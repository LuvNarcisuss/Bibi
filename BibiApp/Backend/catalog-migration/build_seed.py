"""Create an insert-only, repeatable publication transaction from the full export."""
from pathlib import Path
import json

OUT = Path(__file__).resolve().parent

def quote(value):
    if value is None: return "NULL"
    if isinstance(value, bool): return "true" if value else "false"
    if isinstance(value, (int, float)): return str(value)
    return "'" + str(value).replace("'", "''") + "'"

def insert(table, values):
    return "insert into public." + table + " (" + ",".join(values) + ") values (" + ",".join(quote(v) for v in values.values()) + ") on conflict (id) do nothing;"

def main():
    catalog = json.loads((OUT / "catalog.json").read_text())
    manifest = json.loads((OUT / "media-manifest.json").read_text())
    lines = ["-- Publish only after complete media-upload-receipts.json hash verification.",
             "-- No Auth users, private state, interactions, or purchases are imported.",
             "begin;", "set constraints all deferred;", "do $$ begin",
             "if exists (select 1 from public.bibi_content where id in (" +
             ",".join(quote(x["id"]) + "::uuid" for x in catalog["content"]) +
             ") and (owner_id is not null or not editorial)) then raise exception 'Catalog ID conflicts with real user content.'; end if;", "end $$;"]
    for item in manifest["objects"]:
        lines.append("do $$ begin if not exists (select 1 from storage.objects where bucket_id=" + quote(item["bucket_id"]) + " and name=" + quote(item["object_path"]) + " and (metadata->>'size')::bigint=" + quote(item["byte_count"]) + " and metadata->>'mimetype'=" + quote(item["mime_type"]) + ") then raise exception 'Verified catalog object missing.'; end if; end $$;")
        row = {k: item.get(k) for k in ("id", "bucket_id", "object_path", "mime_type", "sha256", "byte_count", "duration_seconds")}
        lines.append(insert("bibi_media", row | {"owner_id":None,"editorial":True,"status":"ready"}))
    for row in catalog["editorial_profiles"]:
        lines.append(insert("bibi_editorial_profiles", row))
    for table, collection in [("bibi_circles", "circles"), ("bibi_challenges", "challenges")]:
        for item in catalog[collection]:
            lines.append("update public." + table + " set artwork='', artwork_media_id=" + quote(item["artwork_media_id"]) + "::uuid where id=" + quote(item["id"]) + " and artwork_media_id is null;")
    for item in catalog["content"]:
        row = {"id":item["id"],"owner_id":None,"kind":item["kind"],"circle_id":item.get("circle_id"),"parent_id":item.get("parent_id"),"editorial":True,"editorial_profile_id":item["editorial_profile_id"],"created_at":item["created_at"]}
        lines.append(insert("bibi_content", row))
        row = {"id":item["revision_id"],"content_id":item["id"],"title":item["title"],"body":item["body"],"media_id":item.get("media_id"),"cover_media_id":item.get("cover_media_id"),"source_url":item.get("source_url"),"credit":item.get("credit"),"collection_generation":item.get("collection_generation"),"status":"approved","created_at":item["created_at"]}
        lines.append(insert("bibi_content_revisions", row))
        lines.append("update public.bibi_content set approved_revision=" + quote(item["revision_id"]) + "::uuid where id=" + quote(item["id"]) + "::uuid and approved_revision is null and owner_id is null and editorial;")
    lines.append("commit;")
    (OUT / "catalog-seed.sql").write_text("\n".join(lines) + "\n")
    print(json.dumps({"content_records":len(catalog["content"]),"media_records":len(manifest["objects"])}))

if __name__ == "__main__": main()
