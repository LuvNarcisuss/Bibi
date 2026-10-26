"""Prepare licensed runtime excerpts. This processes media only; it never builds or runs the app."""
from pathlib import Path
import json,subprocess,uuid,hashlib,argparse
parser=argparse.ArgumentParser();parser.add_argument("--only");args=parser.parse_args()
ROOT=Path(__file__).resolve().parents[2]
DEST=ROOT/'Assets';DEST.mkdir(exist_ok=True)
SOURCES={
 'hero':{'url':'https://studio.blender.org/projects/hero/','download':'https://video.blender.org/object-storage/web_videos/6c79205c-bd3a-42b5-a8a2-ce7a2a166154-536.mp4','author':'Blender Foundation; directed by Daniel Martinez Lara','license':'CC BY 4.0','licenseURL':'https://creativecommons.org/licenses/by/4.0/','credit':'Hero © Blender Foundation · CC BY 4.0'},
 'spring':{'url':'https://studio.blender.org/projects/spring/pages/about/','download':'https://video.blender.org/object-storage/web_videos/3d95fb3d-c866-42c8-9db1-fe82f48ccb95-720.mp4','author':'Blender Foundation; directed by Andy Goralczyk','license':'CC BY-SA 4.0 for these adaptations','licenseURL':'https://creativecommons.org/licenses/by-sa/4.0/','credit':'Spring © Blender Foundation · CC BY-SA 4.0','licenseNote':'Project page specifies CC BY 4.0; official download host labels Attribution-ShareAlike. Adaptations and covers are offered under CC BY-SA 4.0.'}}
CLIPS=[
 ('hero',12,12,'amber-city','A city of amber','A little light can change an entire world. #Animation #Hero'),
 ('hero',28,12,'sky-chase','Beyond the rooftops','An adventure above the clouds. #Animation #Worldbuilding'),
 ('hero',44,12,'clockwork-streets','Clockwork streets','Every background has a story. #Animation #Hero'),
 ('hero',60,12,'paper-sky','A paper sky','Bold lines and impossible journeys. #Animation #Fantasy'),
 ('hero',76,12,'blue-horizon','The blue horizon','Between two worlds, a new story begins. #Hero #Animation'),
 ('hero',100,12,'quiet-return','The way back','Quiet moments can say the most. #Animation #Storytelling'),
 ('hero',116,12,'shared-light','A shared light','One spark, a thousand possibilities. #Animation #Hero'),
 ('hero',130,12,'green-world','Another world blooms','A world waiting to wake up. #Animation #Fantasy'),
 ('spring',26,14,'forest-path','Along the forest path','A journey into a forgotten forest. #Spring #Fantasy'),
 ('spring',44,16,'little-companion','A little companion','Every adventure needs a friend. #Animation #Spring'),
 ('spring',92,16,'forest-guardian','The forest listens','Some stories are older than words. #Fantasy #Spring'),
 ('spring',140,16,'ancient-roots','Among ancient roots','An impossible world, beautifully imagined. #Worldbuilding #Spring'),
 ('spring',182,16,'moonlit-mist','Beyond the mist','Light finds its way through. #Fantasy #Animation'),
 ('spring',218,16,'glowing-staff','A spark in the dark','A small spark against a vast world. #Spring #Fantasy'),
 ('spring',300,16,'dawn-promise','A promise of dawn','Some courage is quiet. #Animation #Spring'),
 ('spring',372,16,'spring-awakens','The world wakes up','A new season. A new beginning. #Spring #Fantasy')]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(args):subprocess.run(args,check=True,stdout=subprocess.DEVNULL)
entries=[];manifest=[]
for i,(film,start,length,slug,title,caption) in enumerate(CLIPS):
 source=DEST/f'original-{film}.mp4';name='bibi-'+slug;dest=DEST/(name+'.mp4')
 if not args.only or args.only == slug:
  run(['ffmpeg','-y','-hide_banner','-loglevel','error','-ss',str(start),'-i',str(source),'-t',str(length),'-vf','scale=960:-2','-c:v','libx264','-preset','fast','-crf','23','-pix_fmt','yuv420p','-c:a','aac','-b:a','96k','-movflags','+faststart',str(dest)])
 cover=DEST/(name+'.jpg')
 if not args.only or args.only == slug:
  run(['ffmpeg','-y','-hide_banner','-loglevel','error','-ss',str(length/2),'-i',str(dest),'-frames:v','1','-q:v','3',str(cover)])
 meta=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=codec_name,width,height,r_frame_rate','-of','json',str(dest)]))
 entry=dict(id=str(uuid.uuid5(uuid.NAMESPACE_URL,'https://bibi.local/catalog/'+name)),title=title,creator='Animation Club',assetName=name,duration=float(meta['format']['duration']),surface='live' if i%2==0 else 'shorts',sourceURL=SOURCES[film]['url'],collectionGeneration=1,caption=caption,credit=SOURCES[film]['credit'])
 entries.append(entry)
 manifest.append(dict(**entry,source=SOURCES[film],original=f'Assets/original-{film}.mp4',originalSHA256=sha(source),startSeconds=start,excerptSeconds=length,runtimeSHA256=sha(dest),coverSHA256=sha(cover),metadata=meta,changes='Time excerpt; proportional resize to width 960; H.264/AAC encoding; extracted midpoint cover. Original speed retained.'))
 print(name,entry['surface'],entry['duration'],flush=True)
(DEST/'animation-catalog.json').write_text(json.dumps(entries,indent=2))
(DEST/'media-provenance.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False))
