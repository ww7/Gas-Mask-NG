#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh
scripts/test-storage.sh
gasmask_test_derived="$PWD/build/tests"
gasmask_results="$PWD/build/TestResults-$(date -u +%Y%m%dT%H%M%SZ).xcresult"
xcodebuild build-for-testing -project 'Gas Mask.xcodeproj' -scheme 'Gas Mask' \
    -derivedDataPath "$gasmask_test_derived" -destination 'platform=macOS' \
    -onlyUsePackageVersionsFromResolvedFile \
    PRODUCT_BUNDLE_IDENTIFIER=work.ww7.gasmask.tests \
    CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
xcodebuild test-without-building -project 'Gas Mask.xcodeproj' -scheme 'Gas Mask' \
    -derivedDataPath "$gasmask_test_derived" -destination 'platform=macOS' \
    -parallel-testing-enabled NO -resultBundlePath "$gasmask_results" \
    PRODUCT_BUNDLE_IDENTIFIER=work.ww7.gasmask.tests \
    CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
