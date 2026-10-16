# Application icon

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
