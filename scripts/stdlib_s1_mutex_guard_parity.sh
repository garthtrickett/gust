#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

module="tests/stdlib_s1_mutex_guard_generic_derivation_module.gst"
fixture="tests/stdlib_s1_mutex_guard.gst"
build_dir="build/guards/stdlib_s1_mutex_guard"

for path in "$module" "$fixture"; do
  if [ ! -f "$path" ]; then
    echo "Missing S1.8 fixture: $path" >&2
    exit 1
  fi
done

for token in \
  '#[linear]' \
  '#[destructor(release_mutex_guard)]' \
  '#[opaque]' \
  '#[private]' \
  'type MutexGuard[T, ctx] struct' \
  'func lock(mutex: &std.Mutex[T, ctx]) MutexGuard[T, ctx]' \
  'func get(owner: &MutexGuard[T, ctx]) &T' \
  'owner.protected = (*mutex).Lock();' \
  '(*owner.mutex).Unlock();'
do
  rg -n -F "$token" "$module" >/dev/null
done

rm -rf "$build_dir"
mkdir -p "$build_dir"
make gust >"$build_dir/make-gust.log" 2>&1
make phase10-native-package >"$build_dir/native-package.log" 2>&1

run_route() {
  local route="$1"
  local log="$build_dir/$route.log"
  if ! GUST_RUNNER_SKIP_BUILD=1 GUST_RUNNER_ROUTE="$route" \
      timeout 20s bash scripts/run-gust-file.sh "$fixture" \
        >"$build_dir/$route.runner.stdout" \
        2>"$build_dir/$route.runner.stderr"; then
    cat "$build_dir/$route.runner.stdout" >&2
    cat "$build_dir/$route.runner.stderr" >&2
    echo "S1.8 $route execution failed or timed out." >&2
    exit 1
  fi
  cp to.log "$log"
  test ! -s "$build_dir/$route.runner.stderr"
  rg -n -x -F '41' "$log" >/dev/null
  rg -n -x -F '42' "$log" >/dev/null
  rg -N -x -e '41|42' "$log" >"$build_dir/$route.observable"
}

# Issue #398: the retired route's arm is replayed. The record carries both
# halves this guard needs -- the program's stdout, and the C the backend
# emitted -- so the observable comparison and the generic-derivation token
# assertions below are unchanged.
python3 scripts/phase24_frozen_oracle.py materialize \
  "$fixture" "$build_dir/frozen" --kind exec
test "$(cat "$build_dir/frozen.compile.status")" = "0"
test ! -s "$build_dir/frozen.compile.stderr"
test "$(cat "$build_dir/frozen.status")" = "0"
test ! -s "$build_dir/frozen.stderr"
cp "$build_dir/frozen.stdout" "$build_dir/mir-to-c.log"
rg -n -x -F '41' "$build_dir/mir-to-c.log" >/dev/null
rg -n -x -F '42' "$build_dir/mir-to-c.log" >/dev/null
rg -N -x -e '41|42' "$build_dir/mir-to-c.log" >"$build_dir/mir-to-c.observable"
cp "$build_dir/frozen.compile.stdout" "$build_dir/mir-to-c.c"

# Issue #398: INVERTED. This guard used to run the fixture through the
# generated-C route and compare what it printed against the native run. That
# route is removed, so the run is replayed from the frozen record above and
# what is asserted live is that ASKING for the route is refused -- which is
# the no-silent-fallback half the comparison was really protecting.
refuse_retired_route() {
  local target="$1"
  set +e
  GUST_RUNNER_SKIP_BUILD=1 GUST_RUNNER_ROUTE=mir-to-c \
    timeout 30s bash scripts/run-gust-file.sh "$target" \
      >"$build_dir/refused.stdout" 2>"$build_dir/refused.stderr"
  local status="$?"
  set -e
  if [ "$status" = "0" ]; then
    echo "The removed generated-C route still ran $target." >&2
    exit 1
  fi
  rg -F 'which was removed in Phase 24' "$build_dir/refused.stderr" >/dev/null || {
    cat "$build_dir/refused.stderr" >&2
    echo "The refused route did not name the Phase 24 removal." >&2
    exit 1
  }
}
refuse_retired_route "$fixture"
run_route cranelift

printf '41\n42\n' >"$build_dir/expected.observable"
cmp -s "$build_dir/expected.observable" "$build_dir/mir-to-c.observable"
cmp -s "$build_dir/expected.observable" "$build_dir/cranelift.observable"

# The selected source remains an ordinary module. Its retained C projection
# proves one generic acquisition call and one registered cleanup body; runtime
# execution above proves that two successive acquisitions both complete.
for token in \
  'stdlib_s1_mutex_guard_generic_derivation_module__lock_protected_MutexGuard_Counter_ctx' \
  'stdlib_s1_mutex_guard_generic_derivation_module__get_protected_MutexGuard_Counter_ctx' \
  'stdlib_s1_mutex_guard_generic_derivation_module__release_mutex_guard_protected_MutexGuard_Counter_ctx'
do
  rg -n -F "$token" "$build_dir/mir-to-c.c" >/dev/null
done
test "$(rg -o -F 'std_Mutex_Lock_impl' "$build_dir/mir-to-c.c" | wc -l)" -eq 1
test "$(rg -o -F 'std_Mutex_Unlock_impl' "$build_dir/mir-to-c.c" | wc -l)" -eq 1

echo "guard-stdlib-s1-mutex-guard: ok (safe 41/42 behavior on the frozen MIR-to-C record and live Cranelift; one generic lock/unlock body; Level 1 + Level 2)"
