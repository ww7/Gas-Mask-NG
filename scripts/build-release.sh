#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh
python3 scripts/verify-icon-resources.py

gasmask_revision=$(git rev-parse HEAD)
gasmask_label=$(/usr/libexec/PlistBuddy -c 'Print :WW7BuildLabel' Info.plist)
gasmask_derived="$PWD/build/release"
gasmask_artifact_dir="$PWD/dist/${gasmask_label}-${gasmask_revision:0:12}"
mkdir -p "$gasmask_artifact_dir"

xcodebuild -resolvePackageDependencies -project 'Gas Mask.xcodeproj' -scheme 'Gas Mask' \
    -derivedDataPath "$gasmask_derived" -onlyUsePackageVersionsFromResolvedFile
xcodebuild build -project 'Gas Mask.xcodeproj' -scheme 'Gas Mask' -configuration Release \
    -derivedDataPath "$gasmask_derived" -onlyUsePackageVersionsFromResolvedFile \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Recreate only the generated bundle inside this revision's artifact directory.
rm -rf "$gasmask_artifact_dir/Gas Mask.app"
ditto "$gasmask_derived/Build/Products/Release/Gas Mask.app" "$gasmask_artifact_dir/Gas Mask.app"
/usr/libexec/PlistBuddy -c "Add :WW7SourceRevision string $gasmask_revision" \
    "$gasmask_artifact_dir/Gas Mask.app/Contents/Info.plist"
# Preserve the writer's pre-signed bytes: its SHA-256 is pinned inside the main
# executable. Sign other nested bundles inside-out, then the outer app only.
find "$gasmask_artifact_dir/Gas Mask.app/Contents" -depth \( -name '*.app' -o -name '*.xpc' -o -name '*.framework' \) -type d -print0 |
while IFS= read -r -d '' gasmask_nested; do
    codesign --force --sign - --options runtime "$gasmask_nested"
done
gasmask_notices="$gasmask_artifact_dir/Gas Mask.app/Contents/Resources/Legal"
mkdir -p "$gasmask_notices"
cp LICENSE "$gasmask_notices/GPL-2.0.txt"
cp SUPPORT.md SECURITY.md "$gasmask_notices/"
cp "$gasmask_derived/SourcePackages/checkouts/MASShortcut/LICENSE" "$gasmask_notices/MASShortcut-LICENSE.txt"
printf 'Corresponding source: https://github.com/ww7/gas-mask-ng/tree/%s\n' "$gasmask_revision" > "$gasmask_notices/SOURCE.txt"
codesign --force --sign - --options runtime "$gasmask_artifact_dir/Gas Mask.app"
codesign --verify --deep --strict "$gasmask_artifact_dir/Gas Mask.app"
gasmask_archs=$(xcrun lipo -archs "$gasmask_artifact_dir/Gas Mask.app/Contents/MacOS/Gas Mask")
for gasmask_required_arch in arm64 x86_64; do
    if [[ " $gasmask_archs " != *" $gasmask_required_arch "* ]]; then
        echo "Missing architecture: $gasmask_required_arch (found: $gasmask_archs)" >&2
        exit 1
    fi
done

if [[ -d "$gasmask_artifact_dir/Gas Mask.app/Contents/Frameworks/Sparkle.framework" ]]; then
    echo 'Unexpected obsolete Sparkle framework in release; clean the build output and rebuild.' >&2
    exit 1
fi

gasmask_archive="gas_mask_${gasmask_label}_${gasmask_revision:0:12}_universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$gasmask_artifact_dir/Gas Mask.app" "$gasmask_artifact_dir/$gasmask_archive"
(
    cd "$gasmask_artifact_dir"
    shasum -a 256 "$gasmask_archive" > SHA256SUMS
)
printf '\nArtifact: %s/%s\n' "$gasmask_artifact_dir" "$gasmask_archive"
