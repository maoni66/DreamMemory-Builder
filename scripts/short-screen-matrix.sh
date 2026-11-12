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

# The full suite runs once on the standard emulator. The compact display matrix
# repeats only the life editor's focused end-to-end path: notebook creation,
# navigation, IME-aware scrolling, Room persistence, and lazy-list visibility.
# Date selection is covered by the standard instrumentation suite.
adb shell settings put system font_scale 1.3
adb shell settings put system accelerometer_rotation 0
adb shell wm density 320

test_selector="com.dreammemory.app.MainActivityTest#lifeNotebookEditorSavesInCompactLayout"
for orientation in portrait landscape; do
  if [ "$orientation" = portrait ]; then
    adb shell settings put system user_rotation 0
    adb shell wm size 720x1280
  else
    adb shell settings put system user_rotation 1
    adb shell wm size 1280x720
  fi

  echo "Targeted life editor instrumentation — $orientation / enlarged font:"
  adb shell settings get system font_scale
  adb shell wm size
  timeout --signal=TERM --kill-after=15s 3m gradle :dm-app:connectedDebugAndroidTest "-Pandroid.testInstrumentationRunnerArguments.class=$test_selector" --stacktrace --console=plain
done

adb shell wm size reset
adb shell wm density reset
adb shell settings put system font_scale 1.0
