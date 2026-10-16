#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/xcode-env.sh
scripts/test-storage.sh
scripts/test-security.sh
gasmask_test_derived="$PWD/build/tests"
gasmask_results="$PWD/build/TestResults-$(date -u +%Y%m%dT%H%M%SZ).xcresult"
xcodebuild build-for-testing -project 'Gas Mask.xcodeproj' -scheme 'Gas Mask' \
    -derivedDataPath "$gasmask_test_derived" -destination 'platform=macOS' \
    -onlyUsePackageVersionsFromResolvedFile \
    PRODUCT_BUNDLE_IDENTIFIER=work.ww7.gasmask.tests \
    CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
gasmask_test_flags=(-parallel-testing-enabled NO)
if [[ "${GASMASK_SKIP_PERFORMANCE:-0}" == "1" ]]; then
    gasmask_test_flags+=('-skip-testing:Gas Mask Tests/HostsTextViewPerformanceTests')
fi
xcodebuild test-without-building -project 'Gas Mask.xcodeproj' -scheme 'Gas Mask' \
    -derivedDataPath "$gasmask_test_derived" -destination 'platform=macOS' \
    "${gasmask_test_flags[@]}" -resultBundlePath "$gasmask_results" \
    PRODUCT_BUNDLE_IDENTIFIER=work.ww7.gasmask.tests \
    CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
