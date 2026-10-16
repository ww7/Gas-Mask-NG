#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh
mkdir -p build/standalone-tests
xcrun clang -O1 -g -fsanitize=address,undefined -Wall -Wextra -Werror -Wno-deprecated-declarations \
    -Dwrite=GMFixtureWrite -Dfsync=GMFixtureFsync -Drenameatx_np=GMFixtureRename \
    -I Source/Security -c Source/Security/HostsWriterCore.c -o build/standalone-tests/writer-core-fixture.o
xcrun clang -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer -Wall -Wextra -Werror -Wno-deprecated-declarations \
    -I Source/Security Tests/Standalone/HostsWriterTests.c build/standalone-tests/writer-core-fixture.o Source/Security/HostsWriterPeer.c \
    -framework Security -framework CoreFoundation -lbsm -o build/standalone-tests/hosts-writer
codesign --force --sign - --options runtime --identifier work.ww7.gasmask.writer-fixtures build/standalone-tests/hosts-writer
build/standalone-tests/hosts-writer

# A matching PID/CDHash is insufficient if its signature allows code injection.
for gasmask_unsafe_key in com.apple.security.get-task-allow com.apple.security.cs.disable-library-validation; do
    gasmask_unsafe_binary=build/standalone-tests/hosts-writer-unsafe
    cp build/standalone-tests/hosts-writer "$gasmask_unsafe_binary"
    printf '<?xml version="1.0"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>%s</key><true/></dict></plist>\n' "$gasmask_unsafe_key" > build/standalone-tests/unsafe-test-entitlements.plist
    codesign --force --sign - --options runtime --entitlements build/standalone-tests/unsafe-test-entitlements.plist "$gasmask_unsafe_binary"
    "$gasmask_unsafe_binary" --expect-unsafe-signature
done
