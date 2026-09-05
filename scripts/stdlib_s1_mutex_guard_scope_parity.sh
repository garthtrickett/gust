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
  docs/STDLIB_MUTEX_GUARD_SCOPE.md
do
  if [ ! -f "$path" ]; then
    echo "Missing S1.9 evidence: $path" >&2
    exit 1
  fi
done

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

run_positive mir-to-c
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

for spec in "${negative_specs[@]}"; do
  IFS=: read -r fixture diagnostic label <<<"$spec"
  compile_fail_on_route mir-to-c "$fixture" "$diagnostic" "$label"
  compile_fail_on_route cranelift "$fixture" "$diagnostic" "$label"
done

echo "guard-stdlib-s1-mutex-guard-scope: ok (7 control-flow forms; 5 compile-fail classes; MIR-to-C and Cranelift parity)"
