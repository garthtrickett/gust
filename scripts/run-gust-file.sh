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

# Force make to recognize compiler changes by touching the entrypoint and rebuilding.
if [ -f compiler/test_runner_entry.gst ]; then
  touch compiler/test_runner_entry.gst
fi

mkdir -p build
BUILD_LOG="build/gust-build.log"
if ! make gust >"$BUILD_LOG" 2>&1; then
  cat "$BUILD_LOG" >&2
  echo "❌ Error: 'make gust' failed. Aborting. Full diagnostics: $BUILD_LOG" >&2
  exit 1
fi

TEST_STEM="$(basename "$TEST_PATH" .gst)"
TEMP_OUTPUT="build/${TEST_STEM}.compile.log"

echo "=== [1/3] COMPILING GUST TO C ===" > to.log

./gust --backend mir-to-c "$TEST_PATH" > "$TEMP_OUTPUT" 2>&1
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

grep -a -v -E "^(🔍|🎯|📥|🔄|⚙|🗄|✅|❌|👁|⚖)" "$TEMP_OUTPUT" > "build/${TEST_STEM}.c"

echo -e "\n=== [2/3] COMPILING NATIVE C EXECUTABLE ===" >> to.log
cat src/runtime.c "build/${TEST_STEM}.c" > "build/${TEST_STEM}_final.c"

CC_BIN="${CC:-cc}"
"$CC_BIN" -O2 -Wall -pthread -Isrc "build/${TEST_STEM}_final.c" -o "build/${TEST_STEM}_bin" >> to.log 2>&1
C_STATUS=$?

if [ "$C_STATUS" -ne 0 ]; then
  echo "❌ Native C compilation failed! See to.log for compiler errors."
  exit "$C_STATUS"
fi

echo -e "\n=== [3/3] RUNNING COMPILED BINARY ===" >> to.log
"./build/${TEST_STEM}_bin" >> to.log 2>&1
RUN_STATUS=$?

if [ "$RUN_STATUS" -ne 0 ]; then
  echo "❌ Runtime execution failed! See to.log for panic/segfault traces."
  exit "$RUN_STATUS"
fi

echo "📝 Test '$TEST_PATH' executed successfully. Output written to to.log"
