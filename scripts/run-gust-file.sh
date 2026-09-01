#!/usr/bin/env bash
set -u
set -o pipefail

if [ $# -lt 1 ]; then
  echo "❌ Error: Please provide a test path (e.g., scripts/run-gust-file.sh tests/e2e_collections_methods.gst)"
  exit 1
fi

TEST_PATH="$1"

if [ ! -f "$TEST_PATH" ]; then
  echo "❌ Error: Test file '$TEST_PATH' does not exist."
  exit 1
fi

mkdir -p build
BUILD_LOG="build/gust-build.log"
if [ "${GUST_RUNNER_SKIP_BUILD:-0}" != "1" ]; then
  # Force make to recognize compiler changes before a normal developer run.
  if [ -f compiler/test_runner_entry.gst ]; then
    touch compiler/test_runner_entry.gst
  fi
  if ! make phase10-native-package >"$BUILD_LOG" 2>&1; then
    cat "$BUILD_LOG" >&2
    echo "❌ Error: native package build failed. Aborting. Full diagnostics: $BUILD_LOG" >&2
    exit 1
  fi
elif [ ! -x gust ] || [ ! -x build/gust-native-backend ] || \
    [ ! -f build/gust-runtime-package.a ]; then
  echo "❌ Error: GUST_RUNNER_SKIP_BUILD requires an existing native package." >&2
  exit 1
fi

TEST_STEM="$(basename "$TEST_PATH" .gst)"
TEMP_OUTPUT="build/${TEST_STEM}.compile.log"
NATIVE_OUTPUT="build/${TEST_STEM}_bin"

echo "=== [1/2] COMPILING GUST WITH CRANELIFT ===" > to.log

rm -f "$NATIVE_OUTPUT"
./build/phase10-package/bin/gust --backend cranelift -o "$NATIVE_OUTPUT" \
  "$TEST_PATH" > "$TEMP_OUTPUT" 2>&1
COMP_STATUS=$?
cat "$TEMP_OUTPUT" >> to.log

if [[ "$TEST_PATH" == *"rejected"* || "$TEST_PATH" == *"violation"* ]]; then
  if [ "$COMP_STATUS" -ne 0 ]; then
    echo "✅ Negative test caught compilation failure successfully! Full diagnostics: $TEMP_OUTPUT"
    exit 0
  fi

  echo "❌ FAIL: Expected negative test to fail compilation, but it succeeded."
  exit 1
fi

if [ "$COMP_STATUS" -ne 0 ]; then
  cat "$TEMP_OUTPUT" >&2
  echo "❌ Gust compilation failed. Full diagnostics: $TEMP_OUTPUT and to.log" >&2
  exit "$COMP_STATUS"
fi

if [ ! -x "$NATIVE_OUTPUT" ]; then
  echo "❌ Cranelift compilation produced no executable artifact. See to.log for compiler diagnostics."
  exit 1
fi

echo -e "\n=== [2/2] RUNNING COMPILED BINARY ===" >> to.log
"$NATIVE_OUTPUT" >> to.log 2>&1
RUN_STATUS=$?

if [ "$RUN_STATUS" -ne 0 ]; then
  echo "❌ Runtime execution failed! See to.log for panic/segfault traces."
  exit "$RUN_STATUS"
fi

echo "📝 Test '$TEST_PATH' executed successfully. Output written to to.log"
