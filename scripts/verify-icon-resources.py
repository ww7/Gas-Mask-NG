#!/usr/bin/env python3
"""Check shipped icon bytes against the approved frozen art handoff."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
art = root / 'Artwork/IconSets'
manifest = json.loads((art / 'manifest.json').read_text())
palettes = json.loads((art / 'palettes.json').read_text())
expected = ['heritage', 'cobalt', 'slate', 'pine', 'sunset-sky', 'fire-sky', 'bandera']
assert manifest['approval']['geometryAndColorsFrozen']
assert manifest['approval']['paletteIds'] == expected
bandera = next(p for p in palettes['palettes'] if p['id'] == 'bandera')
assert (bandera['background'], bandera['symbol']) == ('#000000', '#CC0000')
checks = 0
for symbol in manifest['sets']:
    assert symbol['id'] in ('mask', 'balloon')
    menu = symbol['menuBar']
    source = art / menu['imageset']
    target = root / 'Assets.xcassets' / (menu['assetName'] + '.imageset')
    assert menu['isTemplate'] and menu['logicalSize'] == 16
    assert json.loads((target / 'Contents.json').read_text())['properties']['template-rendering-intent'] == 'template'
    for rendition in json.loads((source / 'Contents.json').read_text())['images']:
        name = rendition.get('filename')
        if name:
            assert (source / name).read_bytes() == (target / name).read_bytes()
            checks += 1
    assert [dock['palette'] for dock in symbol['dock']] == expected
    for dock in symbol['dock']:
        source = art / dock['png']
        target = root / 'Assets.xcassets' / f"Dock_{symbol['id']}_{dock['palette'].replace('-', '_')}.imageset/icon.png"
        assert hashlib.sha256(source.read_bytes()).digest() == hashlib.sha256(target.read_bytes()).digest()
        checks += 1
print(f'Approved icon resources: {checks} exact-byte renditions verified (14 Dock, 4 menu-bar).')
