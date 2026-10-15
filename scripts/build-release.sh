#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh

gasmask_revision=$(git rev-parse HEAD)
gasmask_label=$(/usr/libexec/PlistBuddy -c 'Print :WW7BuildLabel' Info.plist)
gasmask_derived="$PWD/build/release"
gasmask_artifact_dir="$PWD/dist/${gasmask_label}-${gasmask_revision:0:12}"
mkdir -p "$gasmask_artifact_dir"

xcodebuild -resolvePackageDependencies -project 'Gas Mask.xcodeproj' -scheme 'Gas Mask' \
    -derivedDataPath "$gasmask_derived" -onlyUsePackageVersionsFromResolvedFile
osacompile -o Resources/RestartDNSResponder.scpt Resources/RestartDNSResponder.applescript
xcodebuild build -project 'Gas Mask.xcodeproj' -scheme 'Gas Mask' -configuration Release \
    -derivedDataPath "$gasmask_derived" -onlyUsePackageVersionsFromResolvedFile \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Recreate only the generated bundle inside this revision's artifact directory.
rm -rf "$gasmask_artifact_dir/Gas Mask.app"
ditto "$gasmask_derived/Build/Products/Release/Gas Mask.app" "$gasmask_artifact_dir/Gas Mask.app"
/usr/libexec/PlistBuddy -c "Add :WW7SourceRevision string $gasmask_revision" \
    "$gasmask_artifact_dir/Gas Mask.app/Contents/Info.plist"
codesign --force --deep --sign - "$gasmask_artifact_dir/Gas Mask.app"
codesign --verify --deep --strict "$gasmask_artifact_dir/Gas Mask.app"
lipo -verify_arch arm64 x86_64 "$gasmask_artifact_dir/Gas Mask.app/Contents/MacOS/Gas Mask"

gasmask_archive="gas_mask_${gasmask_label}_${gasmask_revision:0:12}_universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$gasmask_artifact_dir/Gas Mask.app" "$gasmask_artifact_dir/$gasmask_archive"
(
    cd "$gasmask_artifact_dir"
    shasum -a 256 "$gasmask_archive" > SHA256SUMS
)
printf '\nArtifact: %s/%s\n' "$gasmask_artifact_dir" "$gasmask_archive"
