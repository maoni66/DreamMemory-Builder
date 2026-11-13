#!/bin/sh
set -eu

restore_standard_baseline() {
  adb shell wm size 1080x1920 >/dev/null 2>&1 || true
  adb shell wm density 420 >/dev/null 2>&1 || true
  adb shell settings put system font_scale 1.0 >/dev/null 2>&1 || true
  adb shell settings put system accelerometer_rotation 0 >/dev/null 2>&1 || true
  adb shell settings put system user_rotation 0 >/dev/null 2>&1 || true
}

on_exit() {
  status=$?
  trap - EXIT
  if [ "$status" -ne 0 ]; then
    echo "Short-screen matrix failed with exit code $status; emulator snapshot:"
    adb devices -l || true
    adb shell getprop ro.build.version.sdk || true
    adb shell getprop ro.build.fingerprint || true
    adb shell wm size || true
    adb shell wm density || true
    adb shell settings get system font_scale || true
    adb shell settings get system accelerometer_rotation || true
    adb shell settings get system user_rotation || true
    adb shell settings get secure navigation_mode || true
    adb shell settings get secure default_input_method || true
    adb shell ime list -s || true
    adb shell dumpsys input_method | grep -E 'mInputShown|mShowRequested|mCurFocusedWindow|mServedView|mImeLayeringTarget' | tail -n 160 || true
    adb shell dumpsys window | grep -E 'mCurrentFocus|mFocusedApp|mImeLayeringTarget|mInputMethod' | tail -n 160 || true
    adb shell dumpsys activity activities | tail -n 250 || true
    adb shell dumpsys activity processes | tail -n 180 || true
    adb shell ps -A | grep -E 'com\.dreammemory\.app|instrumentation' || true
    adb shell cat /data/anr/traces.txt 2>/dev/null | tail -n 300 || true
    adb logcat -d -t 10000 | grep -E 'AndroidRuntime|ActivityTaskManager|InputMethodManager|InputMethodService|Instrumentation|FATAL EXCEPTION|ANR|com.dreammemory.app|TestRunner' | tail -n 1400 || true
  fi
  restore_standard_baseline
  exit "$status"
}
trap on_exit EXIT

# Every run starts from the same known API 35 Pixel 2 display baseline.
adb wait-for-device
adb shell wm size 1080x1920
adb shell wm density 420
adb shell settings put system font_scale 1.0
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

# Compact matrix: only the focused life editor E2E path is repeated.
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
  adb shell settings get system accelerometer_rotation
  adb shell settings get system user_rotation
  adb shell wm size
  adb shell wm density
  timeout --signal=TERM --kill-after=15s 3m gradle :dm-app:connectedDebugAndroidTest "-Pandroid.testInstrumentationRunnerArguments.class=$test_selector" --stacktrace --console=plain
done
