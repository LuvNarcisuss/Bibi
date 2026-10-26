"""Mechanical atlas extraction and asset catalog packaging; no generated artwork is redrawn."""
from pathlib import Path
from PIL import Image
import json, shutil, plistlib
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'Design/Generated'
DEST=ROOT/'Bibi/Resources/Assets.xcassets'
# This directory contains bundled project artwork only, never user data.
if DEST.exists(): shutil.rmtree(DEST)
DEST.mkdir(parents=True)
(DEST/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}},indent=2))
def save_asset(name,image,opaque=False):
 folder=DEST/(name+'.imageset');folder.mkdir()
 image=image.convert('RGB' if opaque else 'RGBA')
 image.save(folder/'art.png')
 (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':'art.png','idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2))
def cells(filename,columns,rows):
 im=Image.open(SOURCE/filename).convert('RGBA'); w,h=im.size
 xs=[round(x*w/columns) for x in range(columns+1)]
 ys=[round(y*h/rows) for y in range(rows+1)]
 if 'atlas' in filename and filename!='rooms-atlas.png':
  # Generated gutters are not perfectly uniform. Transparent separators prevent clipped icons.
  alpha=im.getchannel('A')
  def separators(count,length,projection):
   result=[0]
   for i in range(1,count):
    lo=round((i-.32)*length/count);hi=round((i+.32)*length/count)
    minimum=min(projection[lo:hi])
    choices=[j for j in range(lo,hi) if projection[j]<=minimum+2]
    result.append(round(sum(choices)/len(choices)))
   return result+[length]
  xs=separators(columns,w,[sum(v>128 for v in alpha.crop((x,0,x+1,h)).get_flattened_data()) for x in range(w)])
  ys=separators(rows,h,[sum(v>128 for v in alpha.crop((0,y,w,y+1)).get_flattened_data()) for y in range(h)])
 return [im.crop((xs[x],ys[y],xs[x+1],ys[y+1])) for y in range(rows) for x in range(columns)]
navnames=['live','microphone','chats','me','search','plus','back','forward','close','check','more','settings','heart','star','share','gift','diamond','send','play','pause','speaker','muted','microphoneOff','photo','handset','phone','video','flip','personPlus','people','block','flag','trash','edit','link','bell']
icons=dict(zip(navnames,cells('navigation-atlas.png',6,6)))
extras=['heartOutline','heartFill','starOutline','starFill','bookmark','checkbox','checkboxOn','clock','filter','refresh','bellOff','info','grid','eye','logout','flower','balloon','music','crown','sparkle','cat','moon','wand','planet','comet']
icons.update(zip(extras,cells('states-gifts-atlas.png',5,5)))
# Semantic aliases reuse the same icon, rather than pretend to be unique generated assets.
aliases={'shorts':'play','voice':'microphone','phrases':'bookmark','comment':'chats','microphoneIvory':'microphone','microphoneOffIvory':'microphoneOff','speakerIvory':'speaker','mutedIvory':'muted','unreadBadge':'bell'}
for key,value in aliases.items():icons[key]=icons[value]
icons['star']=icons['starOutline']
for name,im in icons.items():
 # Alpha-bound the artwork and center at a consistent optical size.
 bbox=im.getchannel('A').point(lambda a: 255 if a>20 else 0).getbbox()
 if bbox: im=im.crop(bbox)
 im.thumbnail((216,216),Image.Resampling.LANCZOS)
 canvas=Image.new('RGBA',(256,256));canvas.alpha_composite(im,((256-im.width)//2,(256-im.height)//2))
 save_asset('BibiIcon-'+name,canvas)
portraits=cells('characters-01.png',4,4)+cells('characters-02.png',6,6)
for i,im in enumerate(portraits,1):
 im.thumbnail((384,384),Image.Resampling.LANCZOS)
 save_asset(f'Portrait{i}',im,True)
for i,im in enumerate(cells('rooms-atlas.png',4,2),1):
 im.thumbnail((640,640),Image.Resampling.LANCZOS)
 save_asset(f'BibiRoom{i}',im,True)
welcome=Image.open(SOURCE/'welcome.png');welcome.thumbnail((900,1350),Image.Resampling.LANCZOS);save_asset('BibiWelcome',welcome,True)
logo=Image.open(SOURCE/'app-icon.png').convert('RGB').resize((1024,1024),Image.Resampling.LANCZOS)
for name in ['BibiMark','BibiWordmark']:save_asset(name,logo.resize((256,256),Image.Resampling.LANCZOS),True)
folder=DEST/'AppIcon.appiconset';folder.mkdir();logo.save(folder/'AppIcon.png');(folder/'Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}},indent=2))
folder=DEST/'BibiLaunchBackground.colorset';folder.mkdir();(folder/'Contents.json').write_text(json.dumps({'colors':[{'idiom':'universal','color':{'color-space':'srgb','components':{'red':'0.973','green':'0.961','blue':'1.000','alpha':'1.000'}}}],'info':{'author':'xcode','version':1}},indent=2))
# Rounded system fonts are Bibi's own typographic choice; no prior brand font registrations.
p=ROOT/'Bibi/Support/Info.plist';info=plistlib.loads(p.read_bytes());info.pop('UIAppFonts',None);p.write_bytes(plistlib.dumps(info))
print(f'Packaged {len(icons)} icon names, {len(portraits)} characters, 8 rooms, welcome and app identity')
