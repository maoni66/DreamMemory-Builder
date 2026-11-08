#!/bin/sh
set -eu

dump_failure_diagnostics() {
  status=$?
  if [ "$status" -ne 0 ]; then
    echo "Short-screen matrix failed with exit code $status; recent emulator diagnostics:"
    adb logcat -d -t 5000 | grep -E 'AndroidRuntime|ActivityTaskManager|Instrumentation|FATAL EXCEPTION|ANR' | tail -n 500 || true
  fi
  exit "$status"
}
trap dump_failure_diagnostics EXIT

# Run the current instrumentation suite at enlarged font scale in both
# orientations. Do not pin a legacy test class: test packages evolve with the app.
adb shell settings put system font_scale 1.3
adb shell settings put system accelerometer_rotation 0
adb shell wm density 320

for orientation in portrait landscape; do
  if [ "$orientation" = portrait ]; then
    adb shell settings put system user_rotation 0
    adb shell wm size 720x1280
  else
    adb shell settings put system user_rotation 1
    adb shell wm size 1280x720
  fi

  echo "Current Android instrumentation suite — $orientation / enlarged font:"
  adb shell settings get system font_scale
  adb shell wm size
  gradle :dm-app:connectedDebugAndroidTest --stacktrace --console=plain
done

# Restore emulator display settings for subsequent steps.
adb shell wm size reset
adb shell wm density reset
adb shell settings put system font_scale 1.0
