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

# --- Demo video: one continuous recording touring every tab -----------------
MEDIA_DIR="docs/media"
mkdir -p "$MEDIA_DIR"
RAW_VIDEO="/tmp/demo-raw.mp4"

# Warm the map before recording: MapKit's tile cache persists across
# launches, so the recorded map segment renders immediately instead of
# opening on a blank grid.
xcrun simctl launch "$UDID" "$BUNDLE_ID" -demoData -screenshotTab map
sleep 12
xcrun simctl terminate "$UDID" "$BUNDLE_ID" || true
sleep 1

xcrun simctl io "$UDID" recordVideo --codec h264 --force "$RAW_VIDEO" &
REC_PID=$!
sleep 2

# Headless-runner Metal renders MapKit slowly (~15s to first tiles), so the
# tour opens on the instantly-rendering weather cards and CLOSES on the map
# with the longest dwell — strongest final shot, maximum render time, and
# the recording ends on content rather than a terminate.
for tab in weather plan search logbook more map; do
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -demoData -screenshotTab "$tab"
  if [ "$tab" = "map" ]; then sleep 20; else sleep 7; fi
  if [ "$tab" != "map" ]; then
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" || true
    sleep 1
  fi
done

kill -INT "$REC_PID"
wait "$REC_PID" || true
xcrun simctl terminate "$UDID" "$BUNDLE_ID" || true
test -s "$RAW_VIDEO"

# Compress to repo-friendly 720p. macOS runners have no ffmpeg; avconvert
# ships with the OS. Fall back to the raw recording if conversion fails.
if avconvert --preset Preset1280x720 --source "$RAW_VIDEO" --output "$MEDIA_DIR/demo.mp4" --replace; then
  echo "avconvert ok"
else
  echo "avconvert failed; committing raw recording"
  cp "$RAW_VIDEO" "$MEDIA_DIR/demo.mp4"
fi
ls -la "$MEDIA_DIR"
