#!/bin/bash
# Runs the iOS tests on a simulator.
#   iosApp/scripts/test.sh          unit tests and UI tests
#   iosApp/scripts/test.sh unit     unit tests only (fast)
#   iosApp/scripts/test.sh ui       UI tests only
#   iosApp/scripts/test.sh screenshots   every screen (dark only) into iosApp/build/screenshots
# Set SIMULATOR to use another device, e.g. SIMULATOR="iPhone 16" iosApp/scripts/test.sh
# Set TEST_WORKERS=2 to run the UI test classes on two simulator clones side by side. On
# CI's 3-core machines that was slower than one simulator (15 minutes against 11), so it's off.
set -euo pipefail
cd "$(dirname "$0")/.."

# The project is committed. If XcodeGen is installed, regenerate it so a changed
# project.yml is picked up; CI then checks the committed project matches.
if command -v xcodegen >/dev/null; then
  xcodegen generate --quiet
fi

mode="${1:-all}"
workers=1
only=()
results="build/TestResults.xcresult"
log="build/xcodebuild.log"
case "$mode" in
  unit) only=(-only-testing:TaskWallTests) ;;
  ui) only=(-only-testing:TaskWallUITests); workers="${TEST_WORKERS:-1}" ;;
  screenshots)
    only=(-only-testing:TaskWallUITests/ScreenshotTests)
    results="build/Screenshots.xcresult"
    log="build/screenshots.log"
    # xcodebuild hands TEST_RUNNER_* variables to the tests without the prefix.
    export TEST_RUNNER_SCREENSHOTS=1
    ;;
  all) workers="${TEST_WORKERS:-1}" ;;
  *) echo "usage: $0 [unit|ui|all|screenshots]" >&2; exit 2 ;;
esac

device="${SIMULATOR:-iPhone 17 Pro}"
if ! xcrun simctl list devices available | grep -q "^ *$device ("; then
  device="$(xcrun simctl list devices available | grep -m1 -oE "^ *iPhone [^(]+" | sed -E 's/^ *//; s/ *$//')"
fi
if [ -z "$device" ]; then
  echo "error: no iPhone simulator is installed. In Xcode, open Settings › Components and add an iOS simulator." >&2
  exit 1
fi
echo "Testing on $device"

# Boot the simulator and wait until it's fully up before testing. Otherwise it
# boots during the first UI test, whose app launch can then time out.
udid="$(xcrun simctl list devices available | grep -m1 "^ *$device (" | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}')"
xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b
# Xcode runs test classes side by side on clones of this simulator. Shut it down so they
# are cloned from it with its slow first boot already done.
if [ "$workers" -gt 1 ]; then
  xcrun simctl shutdown "$udid"
fi

rm -rf "$results"
mkdir -p build

run() {
  xcodebuild test \
    -project TaskWall.xcodeproj \
    -scheme TaskWall \
    -destination "platform=iOS Simulator,id=$udid" \
    -resultBundlePath "$results" \
    CODE_SIGNING_ALLOWED=NO \
    -parallel-testing-enabled "$([ "$workers" -gt 1 ] && echo YES || echo NO)" \
    -parallel-testing-worker-count "$workers" \
    ${only[@]+"${only[@]}"}
}

# The full output goes to a file too; xcbeautify hides test print() output.
status=0
if command -v xcbeautify >/dev/null; then
  run 2>&1 | tee "$log" | xcbeautify || status=$?
else
  run 2>&1 | tee "$log" || status=$?
fi

if [ "$mode" = screenshots ]; then
  out="build/screenshots"
  rm -rf "$out" "$out.raw"
  xcrun xcresulttool export attachments --path "$results" --output-path "$out.raw"
  # Name each image after its attachment, e.g. 20-wallpaper.png.
  python3 - "$out.raw" "$out" <<'PY'
import json, os, shutil, sys
raw, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
for test in json.load(open(os.path.join(raw, "manifest.json"))):
    for a in test.get("attachments", []):
        name = a.get("suggestedHumanReadableName") or a["exportedFileName"]
        name = name.split("_")[0]
        shutil.copy(os.path.join(raw, a["exportedFileName"]), os.path.join(out, name + ".png"))
PY
  echo "Screenshots: iosApp/$out ($(ls "$out" | wc -l | tr -d ' ') images)"
fi

echo "Results: iosApp/$results (open it in Xcode to see screenshots of any failure); full log in iosApp/$log"
exit $status
