#!/usr/bin/env python3
"""Restore DualSense Share and touchpad mappings in a selected Forever client's WTF folder."""
import argparse
import datetime
import json
from pathlib import Path
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('wtf_directory', type=Path, help='path to the client WTF directory')
args = parser.parse_args()
if not args.wtf_directory.is_dir():
    parser.error('WTF directory does not exist')
path = args.wtf_directory / 'GamePadConfig_ForeverTweaks.json'
data = json.loads(path.read_text()) if path.exists() else {'configVersion': 4, 'configs': []}
if data.get('configVersion') != 4:
    parser.error('unsupported controller configuration version')
for product_id in (3302, 3570):
    config = next((entry for entry in data['configs']
                   if entry.get('vendorID') == 1356 and entry.get('productID') == product_id), None)
    if config is None:
        config = {'vendorID': 1356, 'productID': product_id, 'rawButtonMappings': []}
        data['configs'].append(config)
    mappings = config.setdefault('rawButtonMappings', [])
    for index, button, comment in ((4, 'PADBACK', 'Share/Create menu action'),
                                    (21, 'PADPADDLE1', 'TouchPad left side'),
                                    (22, 'PAD6', 'TouchPad right side')):
        mappings[:] = [entry for entry in mappings if entry.get('rawIndex') != index]
        mappings.append({'rawIndex': index, 'button': button, 'comment': comment})
if path.exists():
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    shutil.copy2(path, path.with_suffix('.json.backup-' + stamp))
path.write_text(json.dumps(data, indent=4) + '\n')
print('Saved Share and touchpad mappings. Restart the client to load them.')
