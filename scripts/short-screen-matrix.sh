#!/bin/sh
set -eu

# Never let a dead ADB server hang failure collection or cleanup indefinitely.
adb() {
  timeout --signal=TERM --kill-after=2s 10s command adb "$@"
}

restore_standard_baseline() {
  adb shell wm size 1080x1920 >/dev/null 2>&1 || true
  adb shell wm density 420 >/dev/null 2>&1 || true
  adb shell settings put system font_scale 1.0 >/dev/null 2>&1 || true
  adb shell cmd uimode night no >/dev/null 2>&1 || true
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
    adb logcat -d -t 10000 | grep -E 'AndroidRuntime|ActivityTaskManager|InputMethodManager|InputMethodService|Instrumentation|FATAL EXCEPTION|ANR|com\.dreammemory\.app|TestRunner' | tail -n 1400 || true
  fi
  restore_standard_baseline
  exit "$status"
}
trap on_exit EXIT

# Every run starts from the same known API 35 Pixel 2 display baseline.
timeout --signal=TERM --kill-after=3s 30s adb wait-for-device
adb shell wm size 1080x1920
adb shell wm density 420
adb shell settings put system font_scale 1.0
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

# Stress matrix: Home/Inbox + Life/Schedule on compact dimensions, enlarged text, both orientations and contrasting themes.
adb shell settings put system font_scale 1.5
adb shell settings put system accelerometer_rotation 0
adb shell wm density 320

test_selector="com.dreammemory.app.feature.inbox.HomeInboxScreenTest,com.dreammemory.app.MainActivityTest#bottomNavigationShowsAllFiveDestinations,com.dreammemory.app.MainActivityTest#homeMoodStickerSelectionPersistsAndClearsWithoutCreatingNotebook,com.dreammemory.app.MainActivityTest#homeInboxDraftSurvivesTabSwitch,com.dreammemory.app.MainActivityTest#homeInboxSavesAndDisplaysRawText,com.dreammemory.app.MainActivityTest#homeInboxSavesAndDisplaysRawLink,com.dreammemory.app.MainActivityTest#homeInboxCanChangeItemStatus,com.dreammemory.app.MainActivityTest#lifeNotebookEditorSavesInCompactLayout,com.dreammemory.app.MainActivityTest#lifeScheduleEntryOpensTheScheduleModuleAndReturnsToLife,com.dreammemory.app.MainActivityTest#scheduleReminderIntentOpensTheExactScheduleEditor,com.dreammemory.app.feature.schedule.ScheduleScreenTest"
for orientation in portrait landscape; do
  if [ "$orientation" = portrait ]; then
    adb shell settings put system user_rotation 0
    adb shell wm size 640x1136
    adb shell cmd uimode night no
  else
    adb shell settings put system user_rotation 1
    adb shell wm size 1136x640
    adb shell cmd uimode night yes
  fi

  echo "Targeted Home/Inbox + Life/Schedule UI instrumentation — $orientation / fontScale 1.5 / density 320 / $([ "$orientation" = portrait ] && echo light || echo dark):"
  adb shell settings get system font_scale
  adb shell settings get system accelerometer_rotation
  adb shell settings get system user_rotation
  adb shell wm size
  adb shell wm density
  timeout --signal=TERM --kill-after=30s 6m gradle :dm-app:connectedDebugAndroidTest "-Pandroid.testInstrumentationRunnerArguments.class=$test_selector" --stacktrace --console=plain
done
