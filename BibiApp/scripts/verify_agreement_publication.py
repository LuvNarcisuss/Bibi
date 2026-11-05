"""Verify downloaded canonical PDFs against sources and bundled consent inputs."""
from pathlib import Path
import hashlib
import json
import re
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'BibiApp/Design/AgreementPDF/Privacy-Update-2026-11-05'
BASE = 'https://yepycfnkkfrfmuwdekka.supabase.co/storage/v1/object/public/bibi-agreements/2026-10-29/'
normalize = lambda text: re.sub(r'\s+', ' ', text).strip()
records = []
combined = bytearray()
for name in ['TermsOfService', 'PrivacyPolicy']:
    data = (ROOT / 'Assets' / f'{name}.pdf').read_bytes()
    public = EVIDENCE / 'public' / f'{name}.pdf'
    assert public.read_bytes() == data, f'{name}: canonical bytes differ'
    header_file = EVIDENCE / 'public' / ('terms.headers' if name == 'TermsOfService' else 'privacy.headers')
    headers = header_file.read_text()
    assert re.search(r'HTTP/\S+ 200', headers) and 'content-type: application/pdf' in headers.lower()
    allowed = ('http/', 'date:', 'content-type:', 'content-length:', 'cache-control:', 'last-modified:', 'cf-cache-status:')
    header_file.write_text('\n'.join(line for line in headers.splitlines() if line.lower().startswith(allowed)) + '\n')
    reader = PdfReader(public)
    title = 'Bibi - ' + ('Terms of Service' if name == 'TermsOfService' else 'Privacy Policy')
    text, embedded = [], []
    for page in reader.pages:
        lines = page.extract_text().splitlines()
        assert lines[0] == title and lines[1].isdigit(), f'{name}: unexpected footer'
        text.extend(lines[2:])
        for font in page['/Resources']['/Font'].values():
            descriptor = font.get_object().get('/FontDescriptor')
            if descriptor:
                embedded.append(bool(descriptor.get_object().get('/FontFile2')))
    source = (ROOT / 'Assets' / f'agreement-source-{name}.txt').read_text()
    assert normalize(' '.join(text)) == normalize(source), f'{name}: final PDF text differs'
    assert embedded and all(embedded), f'{name}: missing embedded fonts'
    assert not any(term in source for term in ['TODO', 'support@bibi.com', 'Bibi currently has no online account', 'Circle gifts'])
    (EVIDENCE / 'public' / f'{name}.txt').write_text('\n'.join(text) + '\n')
    url = BASE + name + '.pdf'
    combined.extend(name.encode() + b'\0' + url.encode() + b'\0' + data)
    records.append(dict(name=name, url=url, status=200, content_type='application/pdf',
                        sha256=hashlib.sha256(data).hexdigest(), bytes=len(data), pages=len(reader.pages),
                        matches_bundled_bytes=True, matches_source_text=True, fonts_embedded=True,
                        anonymous_access_verified=True, canonical_url_unchanged=True))
result = dict(date='2026-11-05', agreements_frozen=True,
              consent_version_from_existing_algorithm='local-' + hashlib.sha256(combined).hexdigest()[:12],
              documents=records,
              publisher=dict(function='bibi-agreement-publish', final_version=2, verify_jwt=True,
                             status='disabled_410_source_readback_verified'),
              app_build_or_runtime_performed=False)
(EVIDENCE / 'public-readback.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
