"""Retain existing source and licensing evidence for every migrated media object."""
import hashlib
import json
from pathlib import Path

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]

def main():
    media=json.loads((OUT/'media-manifest.json').read_text())['objects']
    names={n for x in media for n in x['source_asset_names']}
    files={p for x in media for p in x['source_paths']}
    stems={Path(p).stem for p in files}
    records=[]
    sources=['avatar-photography-provenance.json','artwork-manifest.json','media-provenance.json',
             'cosplay-cover-provenance.json','post-cover-provenance.json','community-curation-provenance.json']
    def scan(value):
        if isinstance(value,list):
            for child in value: yield from scan(child)
        elif isinstance(value,dict):
            strings={v for v in value.values() if isinstance(v,str)}
            if strings & (names | files | stems): yield value
            else:
                for child in value.values(): yield from scan(child)
    for name in sources:
        path=ROOT/'Assets'/name
        value=json.loads(path.read_text())
        matches=list(scan(value))
        records.append({'source_file':str(path.relative_to(ROOT)),'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                        'matched_records':matches,'notes':value.get('notes') if isinstance(value,dict) else None,
                        'generator':value.get('generator') if isinstance(value,dict) else None})
    (OUT/'source/media-provenance.json').write_text(json.dumps(records,ensure_ascii=True,indent=2)+'\n')
    print(json.dumps({'provenance_sources':len(records),'matched_records':sum(len(r['matched_records']) for r in records)}))

if __name__=='__main__': main()
