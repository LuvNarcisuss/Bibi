"""Read-only source/configuration/resource checks. Not a Swift build or runtime test."""
from pathlib import Path
import json,plistlib,hashlib,re,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1];SOURCE=ROOT/'Bibi';ASSETS=ROOT.parent/'Assets'
failures=[];checks=[]
def check(ok,label):
 (checks if ok else failures).append(label)
info=plistlib.loads((SOURCE/'Support/Info.plist').read_bytes())
check(info['CFBundleDisplayName']=='Bibi','Display name Bibi')
check(info['UIApplicationSceneManifest']['UISceneConfigurations']['UIWindowSceneSessionRoleApplication'][0]['UISceneDelegateClassName']=='$(PRODUCT_MODULE_NAME).BibiSceneDelegate','Scene delegate matches source')
check('NSMicrophoneUsageDescription' not in info,'No unused microphone capture permission')
expected_products = {
 '400': 'ldbsrbbhebevxdjf', '800': 'fxvrdbmlwopeasti',
 '2450': 'akafhhbydyymfpzk', '5150': 'ffzwgpuvsyyhaeeg',
 '10800': 'ofgjvlbwtzchgvbx', '29400': 'azacbzpzvvvpblzu',
 '63700': 'lghwqjsuuxivrdrf'
}
check(info.get('BibiDiamondProducts') == expected_products, 'Seven owner-supplied diamond product mappings')
check(len(set(expected_products.values())) == 7, 'Unique configured product IDs')
wallet_source=(SOURCE/'Features/Wallet/WalletModels.swift').read_text()
tier_source=wallet_source.split('private static let diamondTiers:')[1].split('static func packages')[0]
tiers=[(int(amount.replace('_','')), int(cents.replace('_',''))) for amount,cents in re.findall(r'\(([\d_]+),\s*([\d_]+)\)',tier_source)]
check(tiers == [(400,99),(800,199),(2450,499),(5150,999),(10800,1999),(29400,4999),(63700,9999)], 'Seven tier amounts and reference prices match supplied catalog')
check({str(amount) for amount,_ in tiers} == set(info.get('BibiDiamondProducts',{})), 'Every offered tier has a configured product ID')

alltext='\n'.join(p.read_text() for p in SOURCE.rglob('*.swift'))
check(not re.search(r'import SwiftUI|UIHostingController|UIImage\(systemName:',alltext),'UIKit only; no app SF Symbols rendering')
check(not list(SOURCE.rglob('*.m')),'No Objective-C source')
check('savedDemoVideoIDs' in alltext and 'var isDance: Bool?' in alltext,'Legacy serialized fields retained')
agreement=(SOURCE/'Features/Authentication/UserAgreement.swift').read_text()
check(all(identifier in agreement for identifier in ['1Ht9y4vdWhBqBMEWh-TyDDkoelD4ovlfqnayIwr-b_4I','1tdj2Xd4VnOVLbFCgk-k65m8ONo3obRoFT1xddWTtY5c']) and 'var fileURL' in agreement,'User-provided Bibi agreement URLs and bundled fallback')
check(not re.search(r'hoewtkchclzkuruf|qbfuucwaccetjljs|com\.teto\.dance|18781461148|1PBHnF3UNjCBkEuzOyETCUOWgMEz4eiPfGj_PooGJM4c|1BGNLMpwOFa8_6Fz3S4zv9xkKELYTBEx3KXi3DLVBSj0',alltext),'No inherited account/product/protocol endpoints in Swift')
app=(SOURCE/'App/BibiApplication.swift').read_text()
check(all(name in app for name in ['ShortsHomeController', 'CirclesController', 'ChallengesController', 'ChatsController', 'MeController']), 'Five requested navigation roots')
check('CGFloat(pages.count)' in app and 'dock.bounds.width / 4' not in app, 'Dock geometry follows page count')
check('ChannelDiscoveryController' not in alltext and 'PartyRoomController' not in alltext and 'PartyCreationController' not in alltext, 'Retired discovery and room controllers removed')
feed=(SOURCE/'Features/Shorts/VideoFeedController.swift').read_text()
check('if live' not in feed and 'self.live' not in feed and 'LiveRoom' not in alltext, 'Shorts has no live playback mode')
check('var community: CommunityState?' in alltext, 'Optional community storage preserves old-library decoding')
check('updated.community?.removeVideo' in alltext, 'Video deletion updates community references')
check('class CircleComposerController' in alltext and 'class ChallengeDetailController' in alltext, 'Circle composition and challenge detail exist')
check('final class ExpandingSearchBar:' in alltext and 'ExpandingSearchBar.swift in Sources' in (ROOT/'Bibi.xcodeproj/project.pbxproj').read_text(), 'Shared search overlay retained and compiled')
check('PhraseController' not in alltext and 'Open phrase' not in alltext,'No Phrases route')
manifest=json.loads((ASSETS/'media-provenance.json').read_text());catalog=json.loads((ASSETS/'animation-catalog.json').read_text())
check(len(catalog)==16,'16 animation clips')
check(len({c['id'] for c in catalog})==16 and len({c['assetName'] for c in catalog})==16,'Unique stable IDs and media names')
check(sum(c['surface']=='live' for c in catalog)==8 and sum(c['surface']=='shorts' for c in catalog)==8,'8 active Shorts and 8 retained legacy catalog entries')
for clip,record in zip(catalog,manifest):
 check(clip['id']==record['id'] and clip['duration']<=180,'Catalog provenance '+clip['assetName'])
 for ext,key in [('mp4','runtimeSHA256'),('jpg','coverSHA256')]:
  p=ASSETS/(clip['assetName']+'.'+ext)
  check(p.exists() and hashlib.sha256(p.read_bytes()).hexdigest()==record[key],'Media hash '+p.name)
check(not list(ASSETS.rglob('dance-*.mp4')),'No inherited dance video assets')
for entry in json.loads((ASSETS/'asset-catalog-index.json').read_text()):
 j=json.loads((ASSETS/entry['metadata']).read_text())
 for item in j.get('images',[]):
  if 'filename' in item:check((ASSETS/entry['images'][item['filename']]).exists(),'Asset file '+entry['directory'])
icons=(SOURCE/'DesignSystem/BibiIcons.swift').read_text();cases=[]
for line in icons.splitlines():
 if line.strip().startswith('case '):cases.extend(s.strip() for s in line.strip()[5:].split(','))
for name in cases:check((ASSETS/f'BibiIcon-{name}.png').exists(),'Icon '+name)
for name in set(re.findall(r'"(Portrait\d+|BibiRoom\d+|BibiWelcome|BibiMark|BibiWordmark)"',alltext)):
 check((ASSETS/(name+'.png')).exists(),'Artwork '+name)
from PIL import Image
for p in ASSETS.glob('BibiIcon-*.png'):
 im=Image.open(p);check(im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0,'Alpha '+p.name)
im=Image.open(ASSETS/'AppIcon.png');check(im.size==(1024,1024) and im.mode=='RGB','Opaque 1024px AppIcon')
for filename in ['TermsOfService','PrivacyPolicy']:
 s=(ASSETS/(filename+'.html')).read_text();check('Bibi' in s and 'Teto' not in s,'Agreement '+filename)
scheme_directory=ROOT/'Bibi.xcodeproj/xcshareddata/xcschemes'
for name in ['Bibi', 'BibiPurchases']:
 reference=ET.parse(scheme_directory/(name+'.xcscheme')).find('LaunchAction/StoreKitConfigurationFileReference')
 check(reference is not None and reference.get('identifier') == '../../Configuration/BibiDiamonds.storekit', name+' Run selects the Bibi local StoreKit fixture')
check(ET.parse(scheme_directory/'BibiAppStore.xcscheme').find('.//StoreKitConfigurationFileReference') is None, 'Apple catalog scheme has no local StoreKit fixture')
fixture=json.loads((ROOT/'Configuration/BibiDiamonds.storekit').read_text())['products']
check(len(fixture)==7 and {p['productID'] for p in fixture}==set(expected_products.values()) and all(p['type']=='Consumable' for p in fixture), 'Local fixture contains only the seven Bibi consumables')
pbx=(ROOT/'Bibi.xcodeproj/project.pbxproj').read_text()
check('im.seex.sao2-neiku-30' in pbx and 'IPHONEOS_DEPLOYMENT_TARGET = 16.0' in pbx,'User-selected project identity and deployment target')
check('DEVELOPMENT_TEAM = JPTS6M4T5B;' in pbx,'User-selected signing team retained')
spec=(ROOT/'project.yml').read_text()
check('PRODUCT_BUNDLE_IDENTIFIER: im.seex.sao2-neiku-30' in spec and 'DEVELOPMENT_TEAM: JPTS6M4T5B' in spec,'Generation configuration preserves user-selected identity')
check('com.apple.InAppPurchase' in pbx and 'com.apple.InAppPurchase' in spec,'In-App Purchase capability recorded in project and generator')
check('animation-catalog.json in Resources' in pbx,'Catalog is in resource build phase')
check('BibiConfiguration.swift in Sources' in pbx and 'ConstellationBanner.swift in Sources' in pbx,'Design components in source build phase')
for name in ['CommunityModels', 'AppStore+Community', 'CircleControllers', 'CircleComposerController', 'ChallengeControllers', 'ShortsHomeController', 'VideoGrid', 'VideoCategory']:
 check(name + '.swift in Sources' in pbx, 'Source phase includes ' + name)
for name in ['PartyControllers', 'PartyDiscoveryStore', 'VoiceRoomChatScript', 'LiveRoomStore', 'LiveRoomPlayback', 'VideoDiscoveryController']:
 check(name + '.swift' not in pbx, 'Project excludes retired ' + name)
result={'scope':'Static file/config/resource inspection only. No Swift compiler, typecheck, tests, simulator or app execution.','passed':len(checks),'failed':failures,'checks':checks}
(ROOT/'docs/static-audit.json').write_text(json.dumps(result,indent=2))
print(json.dumps({'passed':len(checks),'failures':failures},indent=2))
raise SystemExit(bool(failures))
