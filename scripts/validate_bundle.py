#!/usr/bin/env python3
"""Validate generated simulator metadata; never converts a device binary to a simulator."""
import argparse, pathlib, plistlib, subprocess
p=argparse.ArgumentParser();p.add_argument('bundle');p.add_argument('--objdump',required=True);p.add_argument('--fix-metadata',action='store_true');a=p.parse_args()
b=pathlib.Path(a.bundle);info=b/'Info.plist';data=plistlib.loads(info.read_bytes())
exe=b/data['CFBundleExecutable']
headers=subprocess.check_output([a.objdump,'--macho','--private-headers',str(exe)],text=True)
assert 'platform iossimulator' in headers, 'Not an iOS simulator Mach-O'
if a.fix_metadata:
 data['CFBundleSupportedPlatforms']=['iPhoneSimulator'];data['UIUserInterfaceStyle']='Light'
 info.write_bytes(plistlib.dumps(data))
assert data['CFBundleSupportedPlatforms']==['iPhoneSimulator']
assert data.get('UIUserInterfaceStyle')=='Light'
assert float(data['MinimumOSVersion'])>=26
resources=list(b.rglob('Mermaid/index.html'))
assert resources, 'Missing bundled Mermaid document'
for page in resources:
 for filename in ['native.js','frame.js','mermaid.min.js','NOTICE.txt']:
  assert (page.parent/filename).is_file(),f'Missing {filename}'
links=subprocess.check_output([a.objdump,'--macho','--dylibs-used',str(exe)],text=True)
assert '/workspace/' not in '\n'.join(links.splitlines()[1:]), 'Development library path leaked into binary load commands'
print('PASS: ARM simulator platform, iOS26 minimum, light-mode metadata, renderer resources and library paths')
