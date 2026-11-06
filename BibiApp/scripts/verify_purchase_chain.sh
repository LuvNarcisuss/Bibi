#!/bin/bash
set -euo pipefail
workspace_root="$(cd "$(dirname "$0")/../.." && pwd)"
validation_device="0C3DC278-7663-4B7E-9FCD-10F2FF679569"
validation_derived="${BIBI_VALIDATION_DERIVED_DATA:-/private/tmp/bibi-a-build}"
validation_label="${1:-purchase-chain}"
validation_evidence="$workspace_root/BibiApp/Design/RunEvidence/$validation_label"
mkdir -p "$validation_evidence"
cd "$workspace_root"
for rules_file in AGENTS.md docs/IMPLEMENTATION.md docs/STATIC-AUDIT.md; do
  test -s "$rules_file"
done
xcrun simctl list devices available > "$validation_evidence/devices.txt"
python3 - "$validation_evidence/devices.txt" <<'PY'
import pathlib,sys
text=pathlib.Path(sys.argv[1]).read_text()
assert 'Bibi UI Acceptance (0C3DC278-7663-4B7E-9FCD-10F2FF679569)' in text
PY
xcrun simctl bootstatus "$validation_device" -b > "$validation_evidence/boot.txt" 2>&1
xcodebuild -project BibiApp/Bibi.xcodeproj -scheme Bibi -configuration Debug \
  -destination "platform=iOS Simulator,id=$validation_device" -derivedDataPath "$validation_derived" \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build-for-testing > "$validation_evidence/build.log" 2>&1
xcrun simctl install "$validation_device" "$validation_derived/Build/Products/Debug-iphonesimulator/Bibi.app" > "$validation_evidence/install.txt" 2>&1
SIMCTL_CHILD_BIBI_OFFLINE_PURCHASE_VALIDATION=1 xcrun simctl launch --terminate-running-process \
  "$validation_device" com.bibi.quadratic > "$validation_evidence/launch.txt" 2>&1
xcrun simctl spawn "$validation_device" launchctl list > "$validation_evidence/processes.txt"
python3 - "$validation_evidence/launch.txt" "$validation_evidence/processes.txt" <<'PY'
import pathlib,re,sys
launch=pathlib.Path(sys.argv[1]).read_text(); processes=pathlib.Path(sys.argv[2]).read_text()
match=re.search(r'com\.bibi\.quadratic: (\d+)',launch)
assert match and any(line.startswith(match[1]+'\t') and 'com.bibi.quadratic' in line for line in processes.splitlines())
PY
# Pass the isolated purchase runtime flag only to this explicit test action.
TEST_RUNNER_BIBI_OFFLINE_PURCHASE_VALIDATION=1 xcodebuild -project BibiApp/Bibi.xcodeproj -scheme Bibi -configuration Debug \
  -destination "platform=iOS Simulator,id=$validation_device" -derivedDataPath "$validation_derived" \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -only-testing:BibiBackendTests/BibiPurchaseChainTests -only-testing:BibiBackendTests/BibiPurchaseRecoveryTests \
  -resultBundlePath "$validation_evidence/PurchaseChain.xcresult" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  test-without-building > "$validation_evidence/tests.log" 2>&1
printf 'Offline purchase chain verification passed: %s\n' "$validation_evidence"
