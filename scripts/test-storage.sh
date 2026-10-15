#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/standalone-tests
xcrun clang -fobjc-arc -Wall -Wextra -Wno-unused-parameter \
    -include Gas_Mask_Prefix.pch -I Source -framework Cocoa \
    Source/FileUtil.m Tests/Standalone/FileUtilMigrationTests.m \
    -o build/standalone-tests/storage-migration
build/standalone-tests/storage-migration
