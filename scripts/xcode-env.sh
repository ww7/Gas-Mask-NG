#!/bin/bash
# Source this file from build/test scripts; no global xcode-select change is needed.
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
if ! xcodebuild -version >/dev/null 2>&1; then
    echo 'Full Xcode is required. Install and open Xcode once, or set DEVELOPER_DIR.' >&2
    exit 1
fi
