#!/bin/bash
set -euo pipefail
workspace_root="$(cd "$(dirname "$0")/../.." && pwd)"
run_device="0C3DC278-7663-4B7E-9FCD-10F2FF679569"
run_derived="${BIBI_ONLINE_DERIVED_DATA:-/private/tmp/bibi-a-build}"
run_evidence="$(mktemp -d /private/tmp/bibi-online-run.XXXXXX)"
cd "$workspace_root"
xcrun simctl bootstatus "$run_device" -b > "$run_evidence/boot.log" 2>&1
# Simulator Keychain requires a signed application with its simulated identity.
xcodebuild -project BibiApp/Bibi.xcodeproj -scheme Bibi \
  -configuration Debug -destination "platform=iOS Simulator,id=$run_device" \
  -derivedDataPath "$run_derived" -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build > "$run_evidence/build.log" 2>&1
xcrun simctl install "$run_device" "$run_derived/Build/Products/Debug-iphonesimulator/Bibi.app"
env -u SIMCTL_CHILD_BIBI_OFFLINE_PURCHASE_VALIDATION xcrun simctl launch \
  --terminate-running-process "$run_device" com.bibi.quadratic
printf 'Online acceptance logs: %s\n' "$run_evidence"
