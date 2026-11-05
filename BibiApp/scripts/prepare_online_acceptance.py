#!/usr/bin/env python3
"""Derive the explicit online acceptance plist without changing release defaults."""
import pathlib
import plistlib

root = pathlib.Path(__file__).resolve().parents[1]
source = root / 'Bibi/Support/Info.plist'
output = root / '.generated/OnlineAcceptance-Info.plist'
settings = plistlib.loads(source.read_bytes())
settings['BibiBackendEnabled'] = True
output.parent.mkdir(parents=True, exist_ok=True)
output.write_bytes(plistlib.dumps(settings, sort_keys=False))
