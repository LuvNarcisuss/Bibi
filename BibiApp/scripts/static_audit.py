"""Read-only source/configuration/resource checks. Not a Swift build or runtime test."""
from pathlib import Path
import json,plistlib,hashlib,re,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1];SOURCE=ROOT/'Bibi';ASSETS=ROOT.parent/'Assets'
failures=[];checks=[]
def check(ok,label):
 (checks if ok else failures).append(label)
info=plistlib.loads((SOURCE/'Support/Info.plist').read_bytes())
check(info['CFBundleDisplayName']=='Bibi','Display name Bibi')
check(info.get('UISupportedInterfaceOrientations') == ['UIInterfaceOrientationPortrait'], 'Owner-selected portrait-only interface')
check(info['UIApplicationSceneManifest']['UISceneConfigurations']['UIWindowSceneSessionRoleApplication'][0]['UISceneDelegateClassName']=='$(PRODUCT_MODULE_NAME).BibiSceneDelegate','Scene delegate matches source')
check('NSMicrophoneUsageDescription' not in info,'No unused microphone capture permission')
expected_products = {
 '400': 'ldbsrbbhebevxdjf', '800': 'fxvrdbmlwopeasti',
 '2450': 'akafhhbydyymfpzk', '5150': 'ffzwgpuvsyyhaeeg',
 '10800': 'ofgjvlbwtzchgvbx', '29400': 'azacbzpzvvvpblzu',
 '63700': 'lghwqjsuuxivrdrf'
}
check(all(info.get('BibiDiamondProducts', {}).get(amount) == product for amount, product in expected_products.items()), 'Seven original product IDs remain unchanged')
additional_products = {'16800': 'fyongbrslseicxya', '42700': 'xutwylpejsdvkwpm'}
check(all(re.fullmatch(r'[a-z]{16}', product) for product in additional_products.values()), 'New product IDs contain sixteen lowercase letters')
expected_products.update(additional_products)
check(info.get('BibiDiamondProducts') == expected_products, 'Nine configured diamond product mappings')
check(len(set(expected_products.values())) == 9, 'Unique configured product IDs')
wallet_source=(SOURCE/'Features/Wallet/WalletModels.swift').read_text()
tier_source=wallet_source.split('private static let diamondTiers:')[1].split('static func packages')[0]
tiers=[(int(amount.replace('_','')), int(cents.replace('_',''))) for amount,cents in re.findall(r'\(([\d_]+),\s*([\d_]+)\)',tier_source)]
check(tiers == [(400,99),(800,199),(2450,499),(5150,999),(10800,1999),(16800,2999),(29400,4999),(42700,6999),(63700,9999)], 'Nine tier amounts and reference prices match approved catalog')
check({str(amount) for amount,_ in tiers} == set(info.get('BibiDiamondProducts',{})), 'Every offered tier has a configured product ID')

alltext='\n'.join(p.read_text() for p in SOURCE.rglob('*.swift'))
check(not re.search(r'(?<!\\)\\u(?!\{)[0-9a-fA-F]{4}', alltext), 'Swift source excludes JSON-style Unicode escapes')
check(not re.search(r'import SwiftUI|UIHostingController|UIImage\(systemName:',alltext),'UIKit only; no app SF Symbols rendering')
check(not list(SOURCE.rglob('*.m')),'No Objective-C source')
check('savedDemoVideoIDs' in alltext and 'var isDance: Bool?' in alltext,'Legacy serialized fields retained')
agreement=(SOURCE/'Features/Authentication/UserAgreement.swift').read_text()
check('https://yepycfnkkfrfmuwdekka.supabase.co/storage/v1/object/public/bibi-agreements/2026-10-29/' in agreement and 'withExtension: "pdf"' in agreement and 'docs.google.com' not in agreement, 'Supabase PDF agreement URLs and bundled PDF fallback')
check(not re.search(r'hoewtkchclzkuruf|qbfuucwaccetjljs|com\.teto\.dance|18781461148|1PBHnF3UNjCBkEuzOyETCUOWgMEz4eiPfGj_PooGJM4c|1BGNLMpwOFa8_6Fz3S4zv9xkKELYTBEx3KXi3DLVBSj0',alltext),'No inherited account/product/protocol endpoints in Swift')
app=(SOURCE/'App/BibiApplication.swift').read_text()
account_chat_source=(SOURCE/'Features/Chats/ChatModels.swift').read_text()
check('static let initialMutualIDs: Set<String> = []' in account_chat_source and 'static let initialFollowerIDs: Set<String> = []' in account_chat_source, 'New accounts have no authored relationships')
check('lines:' not in account_chat_source and 'initialUnread: 0' in account_chat_source, 'Community directory carries no authored chat transcript or unread activity')
check('installSavedPracticeShorts' not in (SOURCE/'Data/LocalLibraryRepository.swift').read_text(), 'Launch does not install videos into the personal library')
check('var biography = ""' in (SOURCE/'Domain/LocalLibrary.swift').read_text() and '"local-owner": "BibiMark"' in (SOURCE/'Domain/CharacterDirectory.swift').read_text(), 'New profile has no authored biography or persona portrait')
check(all(name in app for name in ['ShortsHomeController', 'CirclesController', 'ChallengesController', 'ChatsController', 'MeController']), 'Five requested navigation roots')
check('CGFloat(pages.count)' in app and 'dock.bounds.width / 4' not in app, 'Dock geometry follows page count')
check('ChannelDiscoveryController' not in alltext and 'PartyRoomController' not in alltext and 'PartyCreationController' not in alltext, 'Retired discovery and room controllers removed')
feed=(SOURCE/'Features/Shorts/VideoFeedController.swift').read_text()
check('if live' not in feed and 'self.live' not in feed and 'LiveRoom' not in alltext, 'Shorts has no live playback mode')
check('GiftsController' not in feed and 'shorts.gift' not in feed, 'Shorts has no diamond tipping entry')
circle_source=(SOURCE/'Features/Circles/CircleControllers.swift').read_text()
check('circle.gift' not in circle_source and 'presentGifts(for:' not in circle_source, 'Circle posts have no gift entry')
check('next.diamonds -= cost' not in (SOURCE/'Features/Wallet/StoreKit1Purchasing.swift').read_text(), 'Retired local gift debit removed')
check('content.mutate("gift"' not in (SOURCE/'Backend/OnlineWallet.swift').read_text(), 'Retired online gift command disabled')
check('case profile = "Profile"' in alltext and 'Report or block' in circle_source, 'Profiles and circle content expose safety actions')
check('var community: CommunityState?' in alltext, 'Optional community storage preserves old-library decoding')
check('updated.community?.removeVideo' in alltext, 'Video deletion updates community references')
check('class CircleComposerController' in alltext and 'class ChallengeDetailController' in alltext, 'Circle composition and challenge detail exist')
check('final class ExpandingSearchBar:' in alltext and 'ExpandingSearchBar.swift in Sources' in (ROOT/'Bibi.xcodeproj/project.pbxproj').read_text(), 'Shared search overlay retained and compiled')
check('PhraseController' not in alltext and 'Open phrase' not in alltext,'No Phrases route')
manifest=json.loads((ASSETS/'media-provenance.json').read_text());catalog=json.loads((ASSETS/'animation-catalog.json').read_text())
check(len(catalog)==18 and len(manifest)==18,'18 credited media clips and provenance records')
check(len({c['id'] for c in catalog})==18 and len({c['assetName'] for c in catalog})==18,'Unique stable IDs and media names')
check(sum(c['surface']=='live' for c in catalog)==8 and sum(c['surface']=='shorts' for c in catalog)==10,'10 active Shorts and 8 retained legacy catalog entries')
for clip,record in zip(catalog,manifest):
 check(clip['id']==record['id'] and clip['duration']<=180,'Catalog provenance '+clip['assetName'])
 for ext,key in [('mp4','runtimeSHA256'),('jpg','coverSHA256')]:
  p=ASSETS/(clip['assetName']+'.'+ext)
  check(p.exists() and hashlib.sha256(p.read_bytes()).hexdigest()==record[key],'Media hash '+p.name)
community_source = (SOURCE/'Features/Circles/CommunityModels.swift').read_text()
authors = re.findall(r'CreatorProfile\(id: "(bibi-story:[^"]+)", name: "([^"]+)"', community_source)
stories = re.findall(r'Story\(id: (\d+), circle: "[^"]+", author: (\d+)', community_source)
check(len(authors) == 6 and len({c.get('curatorID') for c in catalog if c['surface'] == 'shorts'}) == 6, 'Active Shorts are shared across six fictional authors')
check(all((c.get('curatorID'), c['creator']) in authors for c in catalog), 'Catalog author names and stable IDs match story profiles')
for index, (author_id, name) in enumerate(authors):
 check(any(c['surface'] == 'shorts' and c.get('curatorID') == author_id for c in catalog) and any(int(a) == index for _, a in stories), name + ' has posts and active Shorts')
card_source = (SOURCE/'Features/Circles/CircleControllers.swift').read_text()
check('view is UIControl || view is UITextView' in card_source and 'tap.delegate = self' in card_source, 'Whole-card navigation excludes nested controls')
check('store.creatorPosts(for: creator.id)' in (SOURCE/'Features/Profile/ProfileControllers.swift').read_text(), 'Creator profiles include authored posts')
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
brand_record=json.loads((ASSETS/'brand-logo-provenance.json').read_text())
brand_source=Image.open(ASSETS/Path(brand_record['archivedSource']).name).convert('RGB')
check(im.tobytes()==brand_source.tobytes(),'App icon preserves owner-provided logo pixels')
check(all(hashlib.sha256((ASSETS/Path(item['path']).name).read_bytes()).hexdigest()==item['sha256'] for item in brand_record['outputs']),'Current brand output hashes match provenance')
check(all(Image.open(ASSETS/name).convert('RGB').tobytes()==im.tobytes() for name in ['BibiMark.png','BibiWordmark.png']),'In-app brand artwork matches the app icon')
launch=ET.parse(SOURCE/'Support/LaunchScreen.storyboard').getroot()
check(info.get('UILaunchStoryboardName')=='LaunchScreen' and 'UILaunchScreen' not in info and launch.get('launchScreen')=='YES','System launch uses the dedicated launch storyboard')
check(launch.find('.//imageView').get('image')=='BibiMark' and launch.find('.//namedColor').get('name')=='BibiLaunchBackground','Launch storyboard uses current brand artwork and background')
entry_source=app.split('final class EntryController:')[1].split('final class AgreementController:')[0]
check('BibiIcon.appMark' in entry_source and 'BibiWelcome' not in entry_source,'Entry hero uses the new logo instead of retired welcome artwork')
check('logo.heightAnchor.constraint(equalTo: logo.widthAnchor)' in entry_source and 'logo.widthAnchor.constraint(lessThanOrEqualToConstant: 272)' in entry_source,'Entry logo retains square proportions with a bounded width')
entry_refresh=entry_source.split('override func refresh()')[1]
check(entry_refresh.index('content.addArrangedSubview(mark)') < entry_refresh.index('NSLayoutConstraint.activate(['),'Entry logo joins the content hierarchy before cross-view constraint activation')
for filename in ['TermsOfService','PrivacyPolicy']:
 s=(ASSETS/(filename+'.html')).read_text();check('Bibi' in s and 'Teto' not in s,'Agreement '+filename)
 check((ASSETS/(filename+'.pdf')).read_bytes().startswith(b'%PDF-'), 'Bundled PDF header '+filename)
 record=next(item for item in json.loads((ASSETS/'agreement-source-provenance.json').read_text()) if item['document']==filename)
 check(hashlib.sha256((ASSETS/(filename+'.pdf')).read_bytes()).hexdigest()==record['bundledPDFSHA256'], 'Bundled PDF matches publication hash '+filename)
 check(hashlib.sha256((ASSETS/('agreement-source-'+filename+'.txt')).read_bytes()).hexdigest()==record['sourceTextSHA256'], 'Agreement source matches provenance '+filename)
 check(filename+'.pdf in Resources' in (ROOT/'Bibi.xcodeproj/project.pbxproj').read_text(), 'Agreement PDF included in resource phase '+filename)
 source_text=(ASSETS/('agreement-source-'+filename+'.txt')).read_text()
 check('Operator legal name: Chengdu Yuehui Xingyu Technology Co., Ltd.' in source_text and 'Contact email: trvahai996@icloud.com' in source_text and not re.search(r'^.+:\s*$',source_text,re.M), 'Owner contact and operator filled without empty fields '+filename)
check('url.path == onlineURL.path' in agreement and 'url.query == nil' in agreement, 'Agreement reader restricts exact versioned PDF navigation')
check('response.response.mimeType?.lowercased() != "application/pdf"' in app, 'Agreement reader rejects non-PDF responses')

scheme_directory=ROOT/'Bibi.xcodeproj/xcshareddata/xcschemes'
for name in ['Bibi', 'BibiPurchases']:
 reference=ET.parse(scheme_directory/(name+'.xcscheme')).find('LaunchAction/StoreKitConfigurationFileReference')
 check(reference is not None and reference.get('identifier') == '../../Configuration/BibiDiamonds.storekit', name+' Run selects the Bibi local StoreKit fixture')
check(ET.parse(scheme_directory/'BibiAppStore.xcscheme').find('.//StoreKitConfigurationFileReference') is None, 'Apple catalog scheme has no local StoreKit fixture')
fixture=json.loads((ROOT/'Configuration/BibiDiamonds.storekit').read_text())['products']
check(len(fixture)==9 and {p['productID'] for p in fixture}==set(expected_products.values()) and all(p['type']=='Consumable' for p in fixture), 'Local fixture contains only the nine Bibi consumables')
fixture_prices = {p['productID']: p['displayPrice'] for p in fixture}
check(all(fixture_prices.get(expected_products[str(amount)]) == f'{cents // 100}.{cents % 100:02d}' for amount, cents in tiers), 'Local StoreKit prices match all nine reference tiers')
product_sql = (ROOT/'Backend/schema.sql').read_text() + (ROOT/'Backend/wallet-products.sql').read_text()
server_products = {product: int(amount) for product, amount in re.findall(r"\('([a-z]+)',\s*(\d+)\)", product_sql)}
check(all(server_products.get(product) == int(amount) for amount, product in expected_products.items()), 'Backend SQL sources cover all nine product quantities')
pbx=(ROOT/'Bibi.xcodeproj/project.pbxproj').read_text()
check('com.bibi.quadratic' in pbx and 'IPHONEOS_DEPLOYMENT_TARGET = 16.0' in pbx,'User-selected project identity and deployment target')
check('DEVELOPMENT_TEAM = 93BX5X327N;' in pbx,'User-selected signing team retained')
spec=(ROOT/'project.yml').read_text()
check('PRODUCT_BUNDLE_IDENTIFIER: com.bibi.quadratic' in spec and 'DEVELOPMENT_TEAM: 93BX5X327N' in spec,'Generation configuration preserves user-selected identity')
check('com.apple.InAppPurchase' in pbx and 'com.apple.InAppPurchase' in spec,'In-App Purchase capability recorded in project and generator')
check('animation-catalog.json in Resources' in pbx,'Catalog is in resource build phase')
for clip in catalog:
 for ext in ['jpg','mp4']:
  name = clip['assetName'] + '.' + ext
  check(name + ' in Resources' in pbx and '../Assets/' + name in spec, 'Media resource configured ' + name)
for name in ['Profile-StarlightCard','Filter-StarlightCapsule','Avatar-TheoCosplay','PostCover-CosplayConvention','PostCover-CosplayGarden']:
 check(name in json.loads((ASSETS/'runtime-asset-inventory.json').read_text())['images'], 'Runtime theme/media inventory ' + name)

check('BibiConfiguration.swift in Sources' in pbx and 'ConstellationBanner.swift in Sources' in pbx,'Design components in source build phase')
for name in ['CommunityModels', 'AppStore+Community', 'CircleControllers', 'CircleComposerController', 'ChallengeControllers', 'ShortsHomeController', 'VideoGrid', 'VideoCategory']:
 check(name + '.swift in Sources' in pbx, 'Source phase includes ' + name)
for name in ['PartyControllers', 'PartyDiscoveryStore', 'VoiceRoomChatScript', 'LiveRoomStore', 'LiveRoomPlayback', 'VideoDiscoveryController']:
 check(name + '.swift' not in pbx, 'Project excludes retired ' + name)
result={'scope':'Static file/config/resource inspection only. No Swift compiler, typecheck, tests, simulator or app execution.','passed':len(checks),'failed':failures,'checks':checks}
(ROOT.parent/'docs/static-audit.json').write_text(json.dumps(result,indent=2))
print(json.dumps({'passed':len(checks),'failures':failures},indent=2))
raise SystemExit(bool(failures))
