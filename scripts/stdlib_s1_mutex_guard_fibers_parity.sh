#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

guarded="tests/stdlib_s1_mutex_guard_fibers.gst"
# The without-guard arm is the pre-existing raw Mutex fiber test. It is reused
# deliberately rather than duplicated: a new raw fixture would add an
# unregistered raw Mutex call site to the Cranelift-owned inventory pinned by
# guard-cranelift-phase20-unsafe-mutex-migration-contract. Reusing the
# registered baseline gives the same with/without comparison and adds none.
raw="tests/e2e_mutex_concurrency.gst"
build_dir="build/guards/stdlib_s1_mutex_guard_fibers"

for path in "$guarded" "$raw" docs/STDLIB_MUTEX_GUARD_FIBERS.md; do
  if [ ! -f "$path" ]; then
    echo "Missing S1.10 evidence: $path" >&2
    exit 1
  fi
done

# The guarded fixture must reach the mutex only through the safe surface.
if rg -n -F -e '.Lock()' -e '.Unlock()' "$guarded" >/dev/null 2>&1; then
  echo "S1.10 fixture must not call raw Mutex.Lock/Unlock." >&2
  exit 1
fi
rg -n -F 'sync.lock(' "$guarded" >/dev/null
rg -n -F 'sync.get(' "$guarded" >/dev/null

rm -rf "$build_dir"
mkdir -p "$build_dir"
make gust >"$build_dir/make-gust.log" 2>&1
make phase10-native-package >"$build_dir/native-package.log" 2>&1

run_case() {
  local fixture="$1"
  local route="$2"
  local label="$3"
  if ! GUST_RUNNER_SKIP_BUILD=1 GUST_RUNNER_ROUTE="$route" \
      timeout 90s bash scripts/run-gust-file.sh "$fixture" \
        >"$build_dir/$label.$route.stdout" \
        2>"$build_dir/$label.$route.stderr"; then
    cat "$build_dir/$label.$route.stdout" >&2
    cat "$build_dir/$label.$route.stderr" >&2
    echo "S1.10 $label on $route failed or timed out." >&2
    exit 1
  fi
  cp to.log "$build_dir/$label.$route.log"
  test ! -s "$build_dir/$label.$route.stderr"
}

# Guarded: 2 proves contention, suspension and wakeup both landed while one
# fiber held the guard across two yields. 302 proves the shared counter is
# exact across three further fibers of one hundred increments each. A dropped
# acquisition would hang the settle loop rather than print a wrong number.
# MIR-to-C only, deliberately. S1.10's exit gate is with/without-guard
# equivalence and an exact counter; unlike S1.8 and S1.9 it does not require
# both-route parity. Fiber programs do not lower on the Cranelift route at all:
# e2e_spawn_yield, e2e_sync_primitives and e2e_mutex_concurrency are each
# deferred there with unsupported_native_capability. That route is recorded as
# future coverage in docs/STDLIB_MUTEX_GUARD_FIBERS.md, per the roadmap's own
# instruction to record coverage CI cannot run.
run_case "$guarded" mir-to-c guarded
rg -N -x -e '2|302' "$build_dir/guarded.mir-to-c.log" >"$build_dir/guarded.observable"
printf '2\n302\n' >"$build_dir/guarded.expected"
cmp -s "$build_dir/guarded.expected" "$build_dir/guarded.observable"

# Without the guard: the registered raw baseline must still produce its exact
# shared-counter total on both routes. Identical contention behaviour with and
# without the guard is the S1.10 exit gate.
run_case "$raw" mir-to-c raw
rg -N -x -e '300' "$build_dir/raw.mir-to-c.log" >"$build_dir/raw.observable"
printf '300\n' >"$build_dir/raw.expected"
cmp -s "$build_dir/raw.expected" "$build_dir/raw.observable"

echo "guard-stdlib-s1-mutex-guard-fibers: ok (contention/suspension/wakeup and an exact shared counter through the guard; unchanged raw-mutex baseline; MIR-to-C; Cranelift fiber route deferred and recorded)"
