#!/bin/bash
set -euo pipefail
cd "${SRCROOT:?}"
gasmask_helper_out="${TARGET_BUILD_DIR:?}/${CONTENTS_FOLDER_PATH:?}/Helpers"
mkdir -p "$gasmask_helper_out" "${DERIVED_FILE_DIR:?}/hosts-writer"
gasmask_slices=()
for gasmask_arch in ${ARCHS:?}; do
    gasmask_slice="$DERIVED_FILE_DIR/hosts-writer/writer-$gasmask_arch"
    xcrun clang -arch "$gasmask_arch" -isysroot "$(xcrun --sdk macosx --show-sdk-path)" \
        -mmacosx-version-min=13.0 -O2 -Wall -Wextra -Werror -Wno-deprecated-declarations \
        -fstack-protector-strong -D_FORTIFY_SOURCE=2 \
        Source/Security/HostsWriterHelper.c Source/Security/HostsWriterPeer.c Source/Security/HostsWriterCore.c \
        -framework Security -framework CoreFoundation -lbsm -o "$gasmask_slice"
    gasmask_slices+=("$gasmask_slice")
done
xcrun lipo -create "${gasmask_slices[@]}" -output "$gasmask_helper_out/HostsWriter"
chmod 755 "$gasmask_helper_out/HostsWriter"
# The app embeds this exact file digest in its Mach-O, not in an editable plist.
# The release packager must preserve this nested signature when signing the outer app.
codesign --force --sign - --options runtime --identifier work.ww7.gasmask.hosts-writer "$gasmask_helper_out/HostsWriter"
gasmask_helper_hash=$(shasum -a 256 "$gasmask_helper_out/HostsWriter")
gasmask_helper_hash=${gasmask_helper_hash%% *}
printf '#define GM_HOSTS_WRITER_SHA256 @"%s"\n' "$gasmask_helper_hash" > "$DERIVED_FILE_DIR/HostsWriterHash.h"
