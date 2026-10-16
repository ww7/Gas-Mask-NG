# Gas Mask NG icon sets

Final owner-approved artwork, 16 October 2026: **Mask** and **Balloon**, each with
all seven palettes listed below and a monochrome menu-bar template. Geometry,
colors and gradient stops are approved and frozen. These are the only final
sets and palettes to use for Settings integration.
This is a prepared artwork package; the application still uses its existing
assets. Settings integration is described in
[ICON-SETS-HANDOFF.md](../../docs/ICON-SETS-HANDOFF.md).

## Final visual reference

Open the [approved icon gallery](gallery.html) to see all fourteen Dock icons
(both sets in all seven palettes) and both menu-bar templates at 16/32 px in
normal and inverse appearances. This is the final gallery accepted in the design
session, including `bandera` red `#CC0000` on black `#000000`.

`gallery.html` is a self-contained standalone page with embedded images and styles;
it can be opened locally without a server or network connection. Its editable
source is [gallery.fragment.html](gallery.fragment.html). Use this saved project
gallery as the visual reference for the next session, alongside the canonical
`manifest.json`, `palettes.json` and SVG masters. Older conversation previews and
rejected studies do not supersede this gallery. Any future approved artwork
change must update the gallery to match the canonical exports.

When exporting the fragment again, preserve the embedded assets and omit unused
external tooltip/icon-library scripts so the standalone page remains offline.

## Inventory

| Palette ID | Name | Background | Symbol | Review |
| --- | --- | --- | --- | --- |
| `heritage` | Yellow / blue | `#0057B7` | `#FFD700` | Approved |
| `cobalt` | Muted yellow / blue | `#234E70` | `#F3D46A` | Approved |
| `slate` | Slate | `#34495E` | `#E7E0CC` | Approved |
| `pine` | Pine | `#2D514B` | `#D9E5CE` | Approved |
| `sunset-sky` | Sunset sky | Blue to pink gradient | `#FFE24A` | Approved |
| `fire-sky` | Fire below | Dark blue to crimson/red/orange | `#FFDF35` | Approved |
| `bandera` | Bandera | `#000000` | `#CC0000` | Approved |

`palettes.json` is the exact color/gradient source and approval allowlist;
`manifest.json` lists every set and export and carries the same approval record.
Both explicitly record the approved set/palette IDs and rejected palette IDs.
No default palette has been selected by this package. The four original palettes
are retained byte-for-byte. `sunset-sky` keeps the blue-to-pink sky. `fire-sky`
replaces the rejected `sunrise-sky` with a dark blue field and crimson, red and
orange rising from the lower edge. Both use vivid yellow symbols. No blur,
outline or extra shape is added. The seventh palette, `bandera`, uses a pure
black background and a solid red symbol. The exact `bandera` colors were sampled
from the owner's definitive sRGB reference on 16 October 2026: red `#CC0000`,
black `#000000`. This supersedes the earlier approximate red `#E31E24` and the
earlier reference-image estimates `#E41E2A` / `#090303`. The same colors apply
to both silhouettes.

`backgroundGradient` is an optional top-to-bottom list of `{offset, color}` stops
in `palettes.json`; `background` is its solid-color fallback. Use the exported
SVG/PNG/ICNS to retain the actual gradient.

## Final selection and rejected history

Use only `mask/symbol.svg` and `balloon/symbol.svg` as geometry masters, with
their exports listed in `manifest.json`. Both silhouettes provide all seven Dock
palettes (fourteen variants total). `MenuMask` and `MenuBalloon` are the two
monochrome menu-bar choices; Dock palette selection does not recolor the menu bar.

| Final master | SHA-256 |
| --- | --- |
| `mask/symbol.svg` | `71c479059ec18a72a08d0dd997a1001c59ee99841f9b1a96c0ebc8e2dfc47b84` |
| `balloon/symbol.svg` | `07925c67ae4c2d4b4f30677b217088f12541b84e7c88d74f8a004c95d2be7d75` |

The palette IDs `sunset`, `fantasy-sunset`, `sunrise` and `sunrise-sky` are
rejected and must not be imported, offered in Settings or restored as defaults.
`sunset-sky` is the approved blue/pink sunset; `fire-sky` is the approved dark
sky with fire below that replaced the rejected sunrise.

Earlier globe, eye-free silhouette, panel/seam, suspension, flame and basket
studies are history, not final alternatives. Do not choose assets from
`Artwork/Studies`, `build/`, old conversation previews or the traced production
icon in place of the packaged masters. The two exact study paths recorded in
`manifest.json` are retained regeneration inputs, not permission to select
other studies. Any further geometry or palette redesign needs a new owner
request. No default menu-bar/Dock selection has been chosen by this approval.

```text
mask/ or balloon/
  symbol.svg                       accepted source, byte-for-byte copy
  menubar/
    template.svg                   square viewport, transparent black symbol
    MenuMask.imageset/             or MenuBalloon.imageset
      menuIcon.png                 16 × 16 px, 1×
      menuIcon@2x.png               32 × 32 px, 2×
      Contents.json                template rendering intent
  dock/<palette>/
    icon.svg                       editable 1024 × 1024 master
    icon.png                       transparent 1024 × 1024 export
    icon.icns                      macOS icon with all standard sizes
    AppIcon.appiconset/             ten macOS slots, 16–1024 physical pixels
```

The menu-bar image has a 16-point logical size; the 32 px image is its Retina
representation. The square viewport `-1 -2 34 34` preserves aspect ratio without
moving individual parts. The small flame is intentionally preserved; it becomes
subpixel at 16 px. Inspect actual-size rendering during application integration
before proposing any separate optical adjustment.

The Dock masters preserve the study placement: 860 px rounded tile at `(82,82)`,
190 px corner radius, and symbol transform `translate(205 205) scale(19.1875)`.
No contour, eye, cut, basket or flame changes are made between palettes.

## Regeneration

Requires macOS (`iconutil`), Node.js and `sharp` 0.35.5. Make `sharp` available
through Node's module resolution or `NODE_PATH`, then run from the repository:

```sh
node scripts/generate-icon-sets.cjs
```

The exporter reads the two accepted study SVGs and `palettes.json`. It writes only
this package and uses a temporary directory for ICNS assembly. It does not write
the application's `Assets.xcassets`. Renderer versions and source checksums are
recorded in `manifest.json`; `SHA256SUMS` covers generated assets and palette data.

```sh
cd Artwork/IconSets
shasum -a 256 -c SHA256SUMS
```

Each `AppIcon.appiconset` is a standalone alternative. Do not import all fourteen
under the same name. Runtime selection requires uniquely named bundled images;
the handoff specifies the integration boundaries.

## Package verification — 16 October 2026

The six palettes retained before adding `bandera`, accepted shapes and menu
templates remain unchanged; all 178 snapshotted artwork files are byte-identical.
The package contains fourteen Dock variants and two menu templates. The inventory
and checksums were regenerated after adding `bandera`. Artwork approval does not
select a default for the application.

Approval was finalized after the owner accepted the fire variant. The final
documentation/metadata update was verified to leave every packaged artwork
file byte-identical before the seventh palette was added; approval metadata is
included in refreshed checksums.

Runtime menu-bar/Dock behavior is reserved for the integration session.
