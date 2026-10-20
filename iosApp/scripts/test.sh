#!/bin/bash
# Runs the iOS tests on a simulator.
#   iosApp/scripts/test.sh          unit tests and UI tests
#   iosApp/scripts/test.sh unit     unit tests only (fast)
#   iosApp/scripts/test.sh ui       UI tests only
# Set SIMULATOR to use another device, e.g. SIMULATOR="iPhone 16" iosApp/scripts/test.sh
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null; then
  echo "error: XcodeGen is missing. Install it with 'brew install xcodegen'." >&2
  exit 1
fi
xcodegen generate --quiet

device="${SIMULATOR:-iPhone 17 Pro}"
if ! xcrun simctl list devices available | grep -q "^ *$device ("; then
  device="$(xcrun simctl list devices available | grep -m1 -oE "^ *iPhone [^(]+" | sed -E 's/^ *//; s/ *$//')"
fi
if [ -z "$device" ]; then
  echo "error: no iPhone simulator is installed. In Xcode, open Settings › Components and add an iOS simulator." >&2
  exit 1
fi
echo "Testing on $device"

only=()
case "${1:-all}" in
  unit) only=(-only-testing:TaskWallTests) ;;
  ui) only=(-only-testing:TaskWallUITests) ;;
  all) ;;
  *) echo "usage: $0 [unit|ui|all]" >&2; exit 2 ;;
esac

results="build/TestResults.xcresult"
rm -rf "$results"
mkdir -p build

run() {
  xcodebuild test \
    -project TaskWall.xcodeproj \
    -scheme TaskWall \
    -destination "platform=iOS Simulator,name=$device" \
    -resultBundlePath "$results" \
    CODE_SIGNING_ALLOWED=NO \
    ${only[@]+"${only[@]}"}
}

# The full output goes to a file too; xcbeautify hides test print() output.
if command -v xcbeautify >/dev/null; then
  run 2>&1 | tee build/xcodebuild.log | xcbeautify
else
  run 2>&1 | tee build/xcodebuild.log
fi
echo "Results: iosApp/$results (open it in Xcode to see screenshots of any failure); full log in iosApp/build/xcodebuild.log"
