# Icon sets and settings handoff

16 October 2026. The owner approved exactly two sets, `mask` and `balloon`, and
all seven palettes listed below. This pass packages their artwork, including
a monochrome menu-bar balloon and matching Dock palettes. **Icon selection in
Settings is not implemented.** The owner intends to request that implementation
in another session. No application assets, runtime preferences or installed app
are changed by the artwork package. Publishing is not authorized by this work.

## Accepted artwork

Open the [approved icon gallery](../Artwork/IconSets/gallery.html) for the visual
reference: both sets, all seven palettes, fourteen Dock variants and both menu-bar
templates. This self-contained page is saved in the repository for the next session.

The canonical package is [Artwork/IconSets](../Artwork/IconSets/).
Its `manifest.json`, `palettes.json` and packaged SVG masters govern the final
selection. Use those exact assets; do not recover variants from `Artwork/Studies`,
`build` or conversation previews, and do not substitute the production Potrace
icon. The study paths below record provenance only.

| Set | Historical design source | Canonical packaged master | Menu-bar asset |
| --- | --- | --- | --- |
| `mask` | [menu-mask-geometric.svg](../Artwork/Studies/menu-mask-geometric.svg) | `Artwork/IconSets/mask/symbol.svg` | `Artwork/IconSets/mask/menubar/MenuMask.imageset` |
| `balloon` | [balloon-compact.svg](../Artwork/Studies/Balloon/balloon-compact.svg) | `Artwork/IconSets/balloon/symbol.svg` | `Artwork/IconSets/balloon/menubar/MenuBalloon.imageset` |

Each menu-bar imageset contains black, transparent 16 px and 32 px template
images. Dock variants live under `Artwork/IconSets/<set>/dock/<palette>/`, with
`icon.svg`, `icon.png`, `icon.icns` and `AppIcon.appiconset/`. Both sets offer
`heritage`, `cobalt`, `slate`, `pine`, `sunset-sky`, `fire-sky` and `bandera`: seven
palettes and fourteen Dock variants in total. All seven are approved; none awaits design
review. Both silhouettes, colors and gradients are frozen. `fire-sky` uses fire
colors rising below dark sky. The rejected IDs `sunset`,
`fantasy-sunset`, `sunrise` and `sunrise-sky` remain excluded.
The palette changes color only; it does not select a different silhouette.
The package README documents generation and validation commands. The default
set/palette choice has not been decided; that does not reopen the approved designs.
`bandera` adds a solid black `#000000` background and red `#CC0000` symbol to both
sets, preserving the previous six palettes exactly. These are the owner's exact
sRGB reference colors; earlier approximate red/reference estimates are superseded.

The two gradient palettes use `backgroundGradient` stops (`offset`, `color`) and a
solid luminous yellow symbol. `background` is a fallback color, not an equivalent
rendering. Use the exact exported SVG/PNG artwork for previews and runtime
resources; do not flatten the gradient to the fallback color.

Keep the accepted geometry fixed:

- Mask: elongated tilted crown, original eye placement, oval separation and
  square-bottomed filter with parallel sides. The user explicitly asked to stop
  refining its silhouette after accepting the length correction.
- Balloon: no eyes, globe, envelope seams or other emblem; retain the earlier
  simple flame, compact basket, narrowed lower envelope and inward-curved cut.
  The final basket scale is 0.86 around its local center; the lower cut is 12%
  narrower than the full-size balloon base.
- Preserve aspect ratio, tilt and spacing at every export size. Menu-bar assets
  use a template silhouette without a colored application-icon tile.

Older geometry, globe and panel variants in `Artwork/Studies/Balloon/` are
comparison history and must not become Settings choices. The original production
`menuIcon` remains the historical
reference; it is not the new `MenuMask` asset.

## Current application integration points

These source locations were inspected during this handoff. Line numbers may move
when implementation begins.

| Concern | Current behavior and source |
| --- | --- |
| Menu-bar image | [`Source/Menulet.m:29`](../Source/Menulet.m#L29), `awakeFromNib`, loads `imageNamed:@"menuIcon"` once and assigns it to the status-item button. [`Assets.xcassets/menuIcon.imageset/Contents.json`](../Assets.xcassets/menuIcon.imageset/Contents.json) already declares template rendering. |
| Menu-bar updates | [`Source/Menulet.m:41`](../Source/Menulet.m#L41) observes only the name-display and active-profile defaults. Its KVO handler starts at line 78; observer cleanup is at line 95. A future icon update must preserve the existing title, menu action and status-item sizing. |
| Settings UI | [`Source/Swift/PreferencesView.swift:17`](../Source/Swift/PreferencesView.swift#L17), `GeneralTab`, uses `@AppStorage`. The Appearance picker demonstrates applying a preference immediately after a change. |
| Settings window | [`Source/Swift/PreferencesPresenter.swift:16`](../Source/Swift/PreferencesPresenter.swift#L16) hosts 400-point content inside a 500-point window and sizes each tab to its content. New controls must fit this layout. |
| Defaults registration | [`Source/Preferences.m:66`](../Source/Preferences.m#L66) registers [`Resources/UserDefaults.plist`](../Resources/UserDefaults.plist). No menu-bar or Dock icon-selection keys exist yet. |
| Launch application | [`Source/ApplicationController.m:279`](../Source/ApplicationController.m#L279) applies appearance during launch. Its XCTest guard skips live profile loading, downloads and permissions. Keep that isolation intact. |
| Dock visibility | [`Source/ApplicationController.m:416`](../Source/ApplicationController.m#L416) and line 426 switch between regular/accessory activation policies. Icon choice must not change when the app appears in the Dock or how editor windows open/close. The Dock menu remains `HostsMenu` at line 337. |
| Default application icon | [`Info.plist:34`](../Info.plist#L34) names `AppIcon`; [`Gas Mask.xcodeproj/project.pbxproj:1208`](../Gas%20Mask.xcodeproj/project.pbxproj#L1208) and line 1244 select the corresponding app-icon asset. No runtime application-icon override exists in current source. |
| About icon | [`Source/Swift/AboutBoxView.swift:12`](../Source/Swift/AboutBoxView.swift#L12) independently displays `AboutIcon`. The user's request covers menu bar and Dock; whether About should follow the Dock choice remains a separate product decision. |

## Next implementation scope

Expose independent choices: menu-bar symbol (`mask` or `balloon`), Dock symbol
(`mask` or `balloon`) and Dock palette. Changing one surface must not silently
change the other. Store stable identifiers, apply them at launch and on selection,
and provide a deterministic fallback for missing or invalid identifiers. Set the
default/migration policy explicitly before replacing the current default artwork.

Import the two uniquely named menu-bar imagesets into the application asset
catalog. Package all selectable Dock images under unique resource names. Do not
copy every exported `AppIcon.appiconset` into the same catalog under the same
name: those directories are standalone alternatives, not fourteen simultaneous
build-time defaults. A runtime Dock override should use bundled resources and
must not rewrite the installed application bundle.

The menu-bar selection should refresh the existing status-item image. Dock
selection should update the running application's icon and be reapplied at
launch; verify it survives the existing regular/accessory policy transitions.
Changing the Finder icon for the installed `.app` is outside this runtime
selection request. Keep new settings separate from profile activation, hosts-file
writes and remote downloads.

## Acceptance for the implementation session

Use temporary profile/system-file fixtures and an isolated defaults suite. Do
not use the owner's live profiles or `/etc/hosts` for testing.

1. Verify all four menu-bar/Dock symbol combinations and all seven Dock palettes;
   a selection on one surface leaves the other unchanged.
2. Verify immediate refresh, relaunch persistence and missing/unknown-value
   fallback. Opening and closing editor/Settings windows must preserve the icon
   choice and existing Dock visibility behavior.
3. Inspect menu-bar symbols at actual size on light and dark menu bars, at 1× and
   2× scale, with the profile-name option both off and on. Check the flame, cut,
   eye openings and basket remain legible and unclipped. Inspect Dock variants
   at small and large sizes, using all seven approved palettes. Verify the sky/fire
   gradients match the exported artwork.
4. Check menu clicks, profile-name display and Dock menu actions still work using
   fixtures. Verify no profile activation or system-hosts write occurs merely
   from changing icons.
5. Extend the relevant preferences/runtime tests, run `scripts/test.sh`, build
   with `scripts/build-release.sh`, and record fresh evidence. Existing entry
   points include [`PreferencesPresenterTests.swift`](../Tests/GasMaskTests/PreferencesPresenterTests.swift)
   and [`ApplicationControllerTests.m`](../Tests/GasMaskTests/ApplicationControllerTests.m).

This document is an implementation handoff, not evidence that those runtime checks
have passed. Follow the project installation policy after a future verified app
build; source publication and release uploads still require owner authorization.
