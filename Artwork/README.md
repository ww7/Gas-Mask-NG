# Application icon

The [approved icon gallery](IconSets/gallery.html) is the saved visual reference
for the two final sets, seven palettes, fourteen Dock variants and both menu-bar
templates. The package JSON and SVG masters remain canonical.

`menu-mask.svg` and `menu-mask.pdf` are deterministic Potrace 1.16 traces of the
alpha channel in the original `Assets.xcassets/menuIcon.imageset/menuIcon@2x.png`
(32×32). They preserve the asymmetric mask, both eye holes and detached filter;
they are not a generative reinterpretation. The original menu-bar bitmap remains
unchanged.

`scripts/generate-app-icon.swift` renders the traced mask in yellow `#FFD700` on a
blue `#0057B7` rounded square, with transparent outside margins, and exports every
existing AppIcon/AboutIcon asset-catalog slot. Run it from the repository root with
full Xcode selected. `app-icon.png` is the rendered master. The mask retains its
upstream provenance and licensing.

On 16 October 2026 the owner approved exactly two sets, `mask` and `balloon`,
and seven palettes: `heritage`, `cobalt`, `slate`, `pine`, `sunset-sky`, `fire-sky`,
`bandera`. [IconSets](IconSets/README.md) contains fourteen Dock variants and both transparent
menu-bar templates. Its `manifest.json`, `palettes.json` and packaged masters are
canonical. Preserve their exact shapes, colors and gradients; use SVG/PNG exports
rather than a flat fallback background. No default set/palette is selected yet.
`bandera` adds a black `#000000` background and red `#CC0000` symbol to both sets;
the previous six palettes are retained exactly.

The rejected `sunset`, `fantasy-sunset`, `sunrise` and `sunrise-sky` palettes
remain excluded. [Studies](Studies/README.md), `build` and conversation previews
are history, not sources for future choices. Do not substitute the production
trace above for either approved set.
The application asset catalogs still use the traced icon described above.
Icon selection in Settings is not implemented; see the
[settings handoff](../docs/ICON-SETS-HANDOFF.md) for the next session.
