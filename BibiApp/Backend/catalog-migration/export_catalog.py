"""Export the complete active editorial catalog without compiling application code.

This strict source reader accepts the current explicit Swift catalog syntax. It
fails on unrecognized or missing records instead of emitting a partial export.
Run this maintenance archive from any directory; it is outside the app target.
"""
import hashlib
import json
import mimetypes
from pathlib import Path
import re
from datetime import datetime, timezone
from uuid import UUID, uuid5, NAMESPACE_URL

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
SOURCE = OUT / "source/community-source.json"

def stable(value):
    return str(uuid5(NAMESPACE_URL, "bibi:catalog-v1:" + value))

def text(value):
    # Swift string literals here have the same escape syntax as JSON strings.
    return json.loads('"' + value + '"')

def field(block, key):
    hit = re.search(r'\b' + key + r':\s*"((?:[^"\\]|\\.)*)"', block)
    if not hit:
        raise ValueError("Missing string field " + key)
    return text(hit.group(1))

def blocks(source, name):
    # Constructors contain no nested parentheses outside quoted strings.
    pattern = name + r'\(((?:[^()"\[\]]|"(?:[^"\\]|\\.)*"|\[(?:[^\]"\[]|"(?:[^"\\]|\\.)*")*\])*)\)'
    return re.findall(pattern, source)

def stamp(seconds):
    return datetime.fromtimestamp(seconds, timezone.utc).isoformat().replace("+00:00", "Z")

def main():
    source = json.loads(SOURCE.read_text())["text"]
    source_hashes = {"BibiApp/Bibi/Features/Circles/CommunityModels.swift": hashlib.sha256(source.encode()).hexdigest()}
    index = json.loads((OUT / "source/asset-catalog-index.json").read_text())
    assets = {entry["directory"].removesuffix(".imageset"): list(entry["images"].values())[0]
              for entry in index if entry["directory"].endswith(".imageset") and entry["images"]}
    media = {}
    def resource(name, record_id, column, duration=None):
        filename = assets.get(name, name)
        path = ROOT / "Assets" / filename
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        mime = mimetypes.guess_type(filename)[0]
        assert mime in ("image/jpeg", "image/png", "video/mp4"), (name, mime)
        if mime == "video/mp4": assert data[4:8] == b"ftyp"
        elif mime == "image/png": assert data.startswith(b"\x89PNG\r\n\x1a\n")
        else: assert data.startswith(b"\xff\xd8\xff")
        bucket = "bibi-videos" if mime == "video/mp4" else "bibi-images"
        key = bucket + ":" + digest
        if key not in media:
            media[key] = {"id": stable("media:" + key), "bucket_id": bucket,
                "object_path": "catalog-v1/" + digest, "mime_type": mime,
                "sha256": digest, "byte_count": len(data), "duration_seconds": duration,
                "source_paths": [], "source_asset_names": [], "references": [],
                "upload_status": "pending"}
        row = media[key]
        if str(path.relative_to(ROOT)) not in row["source_paths"]: row["source_paths"].append(str(path.relative_to(ROOT)))
        if name not in row["source_asset_names"]: row["source_asset_names"].append(name)
        row["references"].append({"record_id":record_id,"field":column})
        return row["id"]
    circles = []
    for b in blocks(source, "InterestCircle"):
        row = {k:field(b,k) for k in ("id","title","subtitle","artwork","prompt")}
        row["artwork_media_id"] = resource(row["artwork"], row["id"], "bibi_circles.artwork_media_id")
        circles.append(row)
    challenges = []
    for b in blocks(source, "CreativeChallenge"):
        row = {k:field(b,k) for k in ("id","title","category","summary","artwork")}
        row["steps"] = [text(s) for s in re.findall(r'"((?:[^"\\]|\\.)*)"', re.search(r'steps:\s*\[(.*?)\]', b, re.S).group(1))]
        row["example_index"] = int(re.search(r'exampleIndex:\s*(\d+)', b).group(1))
        row["artwork_media_id"] = resource(row["artwork"], row["id"], "bibi_challenges.artwork_media_id")
        challenges.append(row)
    authors = []
    for b in blocks(source, "CreatorProfile"):
        if not re.search(r'id:\s*"bibi-(?:editor|story:)', b): continue
        row = {"id":field(b,"id"),"display_name":field(b,"name"),"biography":field(b,"biography")}
        row["avatar_media_id"] = resource(field(b,"avatarAsset"), row["id"], "bibi_editorial_profiles.avatar_media_id")
        authors.append(row)
    story_authors = [a for a in authors if a["id"].startswith("bibi-story:")]
    content = []
    def record(id, kind, author, title, body, when, **extra):
        row={"id":str(UUID(id)),"kind":kind,"editorial_profile_id":author,
             "title":title,"body":body,"created_at":stamp(when),
             "revision_id":stable("revision:" + str(UUID(id))),"editorial":True}
        row.update(extra)
        content.append(row)
        return row
    for i, c in enumerate(circles):
        record("CB110000-0000-4000-8000-00000000000"+str(i),"post","bibi-editor","",c["prompt"],1700000000,circle_id=c["id"],source_kind="editorial_prompt")
    credits = {}
    for name,credit,url,desc in re.findall(r'"([^"\n]+)": \("([^"\n]+)", "(https:[^"\n]+)", "([^"\n]+)"\)', source):
        credits[name] = {"credit":credit,"source_url":url,"description":desc}
    stories = blocks(source,"Story")
    for b in stories:
        n=int(re.search(r'id:\s*(\d+)',b).group(1)); author=int(re.search(r'author:\s*(\d+)',b).group(1))
        sid="CB120000-0000-4000-8000-%012d" % n
        when=1792929600+(13-n)*3600
        row=record(sid,"post",story_authors[author]["id"],"",field(b,"body"),when,circle_id=field(b,"circle"),source_kind="fictional_story")
        artwork=field(b,"artwork")
        row["media_id"]=resource(artwork,row["id"],"bibi_content_revisions.media_id")
        row.update(credits[artwork])
        replies=[text(s) for s in re.findall(r'"((?:[^"\\]|\\.)*)"',re.search(r'replies:\s*\[(.*?)\]',b,re.S).group(1))]
        for i,reply in enumerate(replies):
            record("CB130000-0000-4000-8000-%012d"%(n*10+i),"reply",story_authors[(author+i+1)%len(story_authors)]["id"],"",reply,when+(i+1)*300,parent_id=str(UUID(sid)),source_kind="fictional_story_reply")
    clips_path=OUT/"source/animation-catalog.json"
    source_hashes["Assets/animation-catalog.json"]=hashlib.sha256(clips_path.read_bytes()).hexdigest()
    clips=json.loads(clips_path.read_text())
    excluded=[]
    for index,clip in enumerate(clips):
        if clip["surface"]!="shorts":
            excluded.append({"id":clip["id"],"reason":"Retired Live surface", "source_asset":clip["assetName"]})
            continue
        row=record(clip["id"],"video",clip["curatorID"],clip["title"],clip["caption"],1792929600+clip["collectionGeneration"]*86400-index*60,source_url=clip["sourceURL"],credit=clip["credit"],collection_generation=clip["collectionGeneration"],source_kind="licensed_short")
        row["media_id"]=resource(clip["assetName"]+".mp4",row["id"],"bibi_content_revisions.media_id",clip["duration"])
        row["cover_media_id"]=resource(clip["assetName"]+".jpg",row["id"],"bibi_content_revisions.cover_media_id")
    assert (len(circles),len(challenges),len(authors),len(stories),len(content))==(4,4,7,14,56)
    assert len({r["id"] for r in content})==len(content)
    assert all(r["editorial_profile_id"] in {a["id"] for a in authors} for r in content)
    catalog={"project_ref":"yepycfnkkfrfmuwdekka","source_hashes":source_hashes,"circles":circles,"challenges":challenges,"editorial_profiles":authors,"content":content,"excluded":excluded,"exclusion_policy":"No fictional follows, likes, saves, online status, private messages, memberships, wallet balances, personal entries, or Auth users are migrated."}
    (OUT/"catalog.json").write_text(json.dumps(catalog,ensure_ascii=True,indent=2)+"\n")
    receipts_path=OUT/"media-upload-receipts.json"
    if receipts_path.exists():
        receipts={r["id"]:r for r in json.loads(receipts_path.read_text())["objects"]}
        for row in media.values():
            receipt=receipts.get(row["id"],{})
            if receipt.get("verified") and all(receipt.get(k)==row[k] for k in ("sha256","byte_count","mime_type")):
                row["upload_status"]="verified"
    manifest={"project_ref":"yepycfnkkfrfmuwdekka","objects":list(media.values()),"object_count":len(media),"byte_count":sum(m["byte_count"] for m in media.values())}
    (OUT/"media-manifest.json").write_text(json.dumps(manifest,ensure_ascii=True,indent=2)+"\n")
    print(json.dumps({"content":len(content),"videos":sum(r["kind"]=="video" for r in content),"posts":sum(r["kind"]=="post" for r in content),"replies":sum(r["kind"]=="reply" for r in content),"authors":len(authors),"objects":len(media),"bytes":manifest["byte_count"]}))

if __name__=="__main__":main()
