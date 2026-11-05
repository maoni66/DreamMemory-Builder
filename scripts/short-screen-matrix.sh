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

# Invoked as a single-line command by android-emulator-runner.
# Keep this list limited to instrumentation classes that exist in app/src/androidTest.
adb shell settings put system font_scale 1.3
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0
adb shell wm density 320

for orientation in portrait landscape; do
  if [ "$orientation" = portrait ]; then
    adb shell wm size 720x1280
  else
    adb shell wm size 1280x720
  fi

  echo "Short $orientation / font scale:"
  adb shell settings get system font_scale
  adb shell wm size

  for test_class in \
    com.dreammemory.app.feature.create.CreateCanvasRendererInstrumentedTest \
    com.dreammemory.app.feature.memory.NotebookReducedMotionPagerTest \
    com.dreammemory.app.feature.record.RecordExperienceAttachmentProviderTest \
    com.dreammemory.app.navigation.DreamBottomBarTest \
    com.dreammemory.app.navigation.MainActivityNavigationTest
  do
    echo "Running $orientation instrumentation class: $test_class"
    timeout --signal=TERM --kill-after=15s 180s ./gradlew connectedDebugAndroidTest \
      "-Pandroid.testInstrumentationRunnerArguments.class=$test_class" \
      --stacktrace --console=plain
  done
done
