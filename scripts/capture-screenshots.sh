#!/bin/bash
# Boots an iOS simulator, installs the freshly built Headwind app, and
# captures one screenshot per tab into docs/screenshots/.
# Expects the app at build/Build/Products/Debug-iphonesimulator/Headwind.app
set -euxo pipefail

BUNDLE_ID="com.headwind.app"
OUT_DIR="docs/screenshots"
APP_PATH=$(find build/Build/Products -maxdepth 2 -name "Headwind.app" -type d | head -1)
test -n "$APP_PATH"

# Pick the newest available iOS runtime, preferring a Pro iPhone.
UDID=$(xcrun simctl list devices available --json | python3 -c "
import json, sys
devices = json.load(sys.stdin)['devices']
best = None
for runtime, devs in devices.items():
    if '.iOS-' not in runtime:
        continue
    version = tuple(int(p) for p in runtime.split('.iOS-')[-1].split('-') if p.isdigit())
    for d in devs:
        name = d.get('name', '')
        if not name.startswith('iPhone'):
            continue
        key = (version, 'Pro' in name, name)
        if best is None or key > best[0]:
            best = (key, d['udid'], name)
assert best, 'no available iPhone simulator found'
print(best[1])
")
echo "Using simulator $UDID"

xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b

xcrun simctl ui "$UDID" appearance dark
xcrun simctl install "$UDID" "$APP_PATH"

# Pretend we're on final over the numbers at KSFO.
xcrun simctl privacy "$UDID" grant location "$BUNDLE_ID" || true
xcrun simctl location "$UDID" set 37.6188,-122.3750 || true
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 || true

mkdir -p "$OUT_DIR"

for tab in map plan weather logbook more search; do
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -demoData -screenshotTab "$tab"
  # Give MapKit tiles and the aviationweather.gov fetch time to land.
  sleep 15
  xcrun simctl io "$UDID" screenshot "$OUT_DIR/$tab.png"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" || true
  sleep 2
done

ls -la "$OUT_DIR"
