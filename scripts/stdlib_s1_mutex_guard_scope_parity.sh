#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

positive="tests/stdlib_s1_mutex_guard_scope.gst"
build_dir="build/guards/stdlib_s1_mutex_guard_scope"

negative_specs=(
  "tests/stdlib_s1_mutex_guard_scope_copy_rejected.gst:LinearResourceUseAfterMove:copy"
  "tests/stdlib_s1_mutex_guard_scope_double_release_rejected.gst:PrivateDeclarationAccess:double_release"
  "tests/stdlib_s1_mutex_guard_scope_use_after_move_rejected.gst:LinearResourceUseAfterMove:use_after_move"
  "tests/stdlib_s1_mutex_guard_scope_two_owners_rejected.gst:LinearResourceUseAfterMove:two_owners"
  "tests/stdlib_s1_mutex_guard_scope_fabricated_rejected.gst:OpaqueConstruction:fabricated"
)

for path in "$positive" \
  tests/stdlib_s1_mutex_guard_scope_copy_rejected.gst \
  tests/stdlib_s1_mutex_guard_scope_double_release_rejected.gst \
  tests/stdlib_s1_mutex_guard_scope_use_after_move_rejected.gst \
  tests/stdlib_s1_mutex_guard_scope_two_owners_rejected.gst \
  tests/stdlib_s1_mutex_guard_scope_fabricated_rejected.gst \
  tests/stdlib_s1_mutex_guard_scope_raw_double_unlock.gst \
  docs/STDLIB_MUTEX_GUARD_SCOPE.md
do
  if [ ! -f "$path" ]; then
    echo "Missing S1.9 evidence: $path" >&2
    exit 1
  fi
done

PYTHONDONTWRITEBYTECODE=1 python3 scripts/stdlib_s1_raw_double_unlock_test.py

rm -rf "$build_dir"
mkdir -p "$build_dir"
make gust >"$build_dir/make-gust.log" 2>&1
make phase10-native-package >"$build_dir/native-package.log" 2>&1

run_positive() {
  local route="$1"
  if ! GUST_RUNNER_SKIP_BUILD=1 GUST_RUNNER_ROUTE="$route" \
      timeout 30s bash scripts/run-gust-file.sh "$positive" \
        >"$build_dir/$route.runner.stdout" \
        2>"$build_dir/$route.runner.stderr"; then
    cat "$build_dir/$route.runner.stdout" >&2
    cat "$build_dir/$route.runner.stderr" >&2
    echo "S1.9 $route scope execution failed or timed out." >&2
    exit 1
  fi
  cp to.log "$build_dir/$route.log"
  test ! -s "$build_dir/$route.runner.stderr"
  rg -N -x -e '1|2|3|4|5|6|7' "$build_dir/$route.log" >"$build_dir/$route.observable"
}

# Issue #398: the mir-to-c arm is served from the frozen oracle. It ran the
# program through the retired backend and compared what it printed against
# the native run; the recording carries that same stdout, so the comparison
# it made survives the backend that used to produce one side of it.
#
# The observable is extracted from the record with the SAME filter the live
# arm applies to its log, so the two sides are still compared on equal terms.
replay_positive() {
  python3 scripts/phase24_frozen_oracle.py materialize \
    "$positive" "$build_dir/frozen" --kind exec
  test "$(cat "$build_dir/frozen.compile.status")" = "0"
  test ! -s "$build_dir/frozen.compile.stderr"
  test "$(cat "$build_dir/frozen.status")" = "0"
  test ! -s "$build_dir/frozen.stderr"
  rg -N -x -e '1|2|3|4|5|6|7' "$build_dir/frozen.stdout" \
    >"$build_dir/mir-to-c.observable"
}

# INVERTED. This asserted the runner would execute the positive fixture
# through the generated-C route. That route is removed, so what must hold is
# that asking for it is REFUSED -- which is the stronger half of what the old
# assertion was really protecting: that nothing silently falls back.
refuse_retired_route() {
  set +e
  GUST_RUNNER_SKIP_BUILD=1 GUST_RUNNER_ROUTE=mir-to-c \
    timeout 30s bash scripts/run-gust-file.sh "$positive" \
      >"$build_dir/mir-to-c.runner.stdout" \
      2>"$build_dir/mir-to-c.runner.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "The removed generated-C route still runs the S1.9 fixture." >&2
    exit 1
  fi
  rg -F 'which was removed in Phase 24' "$build_dir/mir-to-c.runner.stderr" \
    >/dev/null || {
      cat "$build_dir/mir-to-c.runner.stderr" >&2
      echo "The refused route did not name the Phase 24 removal." >&2
      exit 1
    }
}

replay_positive
refuse_retired_route
run_positive cranelift
printf '1\n2\n3\n4\n5\n6\n7\n7\n' >"$build_dir/expected.observable"
cmp -s "$build_dir/expected.observable" "$build_dir/mir-to-c.observable"
cmp -s "$build_dir/expected.observable" "$build_dir/cranelift.observable"

compile_fail_on_route() {
  local route="$1"
  local fixture="$2"
  local diagnostic="$3"
  local label="$4"
  local log="$build_dir/$label.$route.log"
  local output="$build_dir/$label.$route.bin"
  local command=(./gust --backend "$route" "$fixture")
  if [ "$route" = "cranelift" ]; then
    command=(./gust --backend cranelift -o "$output" "$fixture")
  fi
  if "${command[@]}" >"$log" 2>&1; then
    echo "Expected $fixture to reject on $route, but it compiled." >&2
    exit 1
  fi
  rg -n -F "$diagnostic" "$log" >/dev/null
}

# Issue #398: the mir-to-c rejection arm replays its frozen record. The claim
# was that these five sources reject with the SAME diagnostic on both routes
# -- a route-independence claim, which is why one arm alone was never enough.
# The recording preserves the retired route's half of it exactly: the same
# non-zero status and the same diagnostic text it produced when it existed.
reject_on_frozen_record() {
  local fixture="$1"
  local diagnostic="$2"
  local label="$3"
  local prefix="$build_dir/$label.frozen"
  python3 scripts/phase24_frozen_oracle.py materialize \
    "$fixture" "$prefix" --kind reject
  if [ "$(cat "$prefix.compile.status")" = "0" ]; then
    echo "The frozen record says $fixture compiled on the retired route." >&2
    exit 1
  fi
  cat "$prefix.compile.stdout" "$prefix.compile.stderr" \
    >"$prefix.combined"
  rg -n -F "$diagnostic" "$prefix.combined" >/dev/null
}

for spec in "${negative_specs[@]}"; do
  IFS=: read -r fixture diagnostic label <<<"$spec"
  reject_on_frozen_record "$fixture" "$diagnostic" "$label"
  compile_fail_on_route cranelift "$fixture" "$diagnostic" "$label"
done

# CR-16 is an explicit-unsafe limitation, not a rejection expectation. Compile
# directly: run-gust-file.sh executes positive fixtures and must not run this one.
raw_fixture="tests/stdlib_s1_mutex_guard_scope_raw_double_unlock.gst"
# Issue #398: replayed. The record is the emission itself rather than a mixed
# log, so the emoji filter the live arm needed is gone with the invocation
# that made it necessary -- and the syntax check below now runs against the
# same bytes the backend produced, with nothing stripped out of them.
python3 scripts/phase24_frozen_oracle.py materialize \
  "$raw_fixture" "$build_dir/raw-double-unlock" --kind compile_only
test "$(cat "$build_dir/raw-double-unlock.compile.status")" = "0"
test ! -s "$build_dir/raw-double-unlock.compile.stderr"
cp "$build_dir/raw-double-unlock.compile.stdout" \
  "$build_dir/raw-double-unlock.log"
python3 scripts/stdlib_s1_raw_double_unlock.py "$build_dir/raw-double-unlock.log"
cat src/runtime.c >"$build_dir/raw-double-unlock.c"
cat "$build_dir/raw-double-unlock.log" >>"$build_dir/raw-double-unlock.c"
"${CC:-cc}" -fsyntax-only -pthread -Isrc "$build_dir/raw-double-unlock.c" \
  >"$build_dir/raw-double-unlock.c-check.log" 2>&1
# Native compilation confirms accepted source on the already-qualified scope
# cohort. Creating the executable is evidence; executing it would double unlock.
./build/phase10-package/bin/gust --backend cranelift -o "$build_dir/raw-double-unlock.bin" "$raw_fixture" \
  >"$build_dir/raw-double-unlock.native.log" 2>&1
test -s "$build_dir/raw-double-unlock.bin"

echo "guard-stdlib-s1-mutex-guard-scope: ok (7 control-flow forms; 5 compile-fail classes; MIR-to-C and Cranelift parity; CR-16 compile-only witness)"
