#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase17_thread_runtime"
request="/tmp/gust-phase17-thread-runtime.request"
mir_to_c="/tmp/gust-phase17-thread-runtime.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile thread runtime fixture"
trap 'status=$?; echo "Phase 17.12 thread runtime parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_thread_runtime_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 17.12 threading synchronization smoke passed' to.log >/dev/null

stage="build Cranelift thread runtime consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned thread runtime witnesses"
"$worker" phase17-thread-runtime-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

# The bounded operation inventory and the thread vocabulary appear, so the
# witness records the contract rather than a summary of it.
for token in 'operation=mutex_create' 'operation=mutex_lock' 'operation=channel_send' \
             'operation=fiber_create' 'operation=scheduler_init' \
             'system_library=pthread' 'system_library=none' \
             'lifetime=caller_scoped' 'lifetime=process_lifetime' \
             'cancellation=no_cancellation_supported' \
             'cancellation=cooperative_yield_point' \
             'linkage=thread_operations_use_their_classified_explicit_runtime_path'; do
  rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null
done

# Scheduler ordering is deliberately not a stable oracle. The deferred
# scheduling helpers must not appear as selected operations.
stage="confirm scheduler ordering is not treated as a stable oracle"
for deferred in gust_yield gust_context_switch gust_fiber_switch gust_shard_loop; do
  if rg -n -F "helper=$deferred" "$build_dir/cranelift.witness" >/dev/null; then
    echo "deferred scheduling helper $deferred appears as a selected contract" >&2
    false
  fi
done

reject_mutation() {
  local label="$1" reason="$2" expression="$3"
  local mutated="$build_dir/$1.request" output="$build_dir/$1.output" temporary="$build_dir/$1.tmp"
  cp "$request" "$mutated"; sed -i "$expression" "$mutated"
  printf 'sentinel: preserve-existing-output\n' >"$output"
  if "$worker" phase17-thread-runtime-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr"; then
    echo "mutation unexpectedly succeeded: $label" >&2; false
  fi
  rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
  rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null
}

stage="reject malformed thread contracts before object or link access"
reject_mutation undeclared_library runtime_thread_undeclared_system_library \
  '0,/system_library=pthread;/ s/system_library=pthread;/system_library=libuv;/'
reject_mutation bad_cancellation runtime_thread_unsupported_cancellation \
  '0,/cancellation=no_cancellation_supported;/ s/cancellation=no_cancellation_supported;/cancellation=async_cancellation;/'
reject_mutation bad_operation runtime_thread_unsupported_target \
  '0,/operation=mutex_create;/ s/operation=mutex_create;/operation=atomic_fetch_add;/'
reject_mutation bad_lifetime runtime_thread_missing_component \
  '0,/lifetime=caller_scoped;/ s/lifetime=caller_scoped;/lifetime=forever_probably;/'
reject_mutation unknown_format runtime_thread_missing_component \
  '0,/format: gust.compiler_thread_runtime.v1/ s/format: gust.compiler_thread_runtime.v1/format: gust.compiler_thread_runtime.v9/'

echo "guard-cranelift-phase17-thread-runtime-parity: ok (Level 2)"
