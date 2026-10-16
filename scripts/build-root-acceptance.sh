#!/bin/bash
# Build only; this script neither launches the harness nor authorizes root.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh
writer=${1:?Usage: build-root-acceptance.sh path/to/built/HostsWriter}
output="$PWD/build/isolated-macos/RootWriterHarness.app"
mkdir -p "$output/Contents/MacOS" "$output/Contents/Helpers" "$PWD/build/isolated-macos/include"
cp "$writer" "$output/Contents/Helpers/HostsWriter"
writer_hash=$(shasum -a 256 "$output/Contents/Helpers/HostsWriter")
printf '#define GM_HOSTS_WRITER_SHA256 @"%s"\n' "${writer_hash%% *}" > build/isolated-macos/include/HostsWriterHash.h
xcrun clang -arch arm64 -mmacosx-version-min=13.0 -fobjc-arc -Wno-deprecated-declarations \
    -I Source -I build/isolated-macos/include Tests/IsolatedMac/RootWriterHarness.m Source/PrivilegedActions.m \
    -framework AppKit -framework Security -framework Carbon -o "$output/Contents/MacOS/RootWriterHarness"
cat > "$output/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>RootWriterHarness</string>
<key>CFBundleIdentifier</key><string>work.ww7.gasmask.root-acceptance</string>
<key>CFBundleName</key><string>Gas Mask NG Acceptance</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
codesign --force --sign - --options runtime "$output"
codesign --verify --deep --strict "$output"
printf '%s\n' "$output"
