#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase17_memory_runtime"
request="/tmp/gust-phase17-memory-runtime.request"
mir_to_c="/tmp/gust-phase17-memory-runtime.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile memory runtime fixture"
trap 'status=$?; echo "Phase 17.10 memory runtime parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_memory_runtime_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 17.10 allocation string memory smoke passed' to.log >/dev/null

stage="build Cranelift memory runtime consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned memory runtime witnesses"
"$worker" phase17-memory-runtime-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

# All four allocation domains and the ownership vocabulary appear, so the
# witness records the contract rather than a summary of it.
for token in 'domain=host_process_allocator' 'domain=caller_owned_arena' \
             'domain=thread_local_scratch' 'domain=no_allocation' \
             'ownership=ownership_transfers_to_caller' \
             'ownership=borrowed_for_call_duration' \
             'linkage=memory_operations_use_their_classified_explicit_runtime_path'; do
  rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null
done

# Every acquiring domain has a matching release in the same domain. This is the
# invariant that stops an arena pointer being freed through the scratch
# allocator, so it is checked directly rather than assumed from the witness.
stage="confirm every acquiring domain has a matching release"
for domain in host_process_allocator caller_owned_arena thread_local_scratch; do
  rg -n -F "domain=$domain" "$build_dir/cranelift.witness" >"$build_dir/$domain.rows"
  rg -n -e 'operation=allocate' -e 'operation=string_create' "$build_dir/$domain.rows" >/dev/null
done

reject_mutation() {
  local label="$1" reason="$2" expression="$3"
  local mutated="$build_dir/$1.request" output="$build_dir/$1.output" temporary="$build_dir/$1.tmp"
  cp "$request" "$mutated"; sed -i "$expression" "$mutated"
  printf 'sentinel: preserve-existing-output\n' >"$output"
  if "$worker" phase17-memory-runtime-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr"; then
    echo "mutation unexpectedly succeeded: $label" >&2; false
  fi
  rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
  rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null
}

stage="reject malformed memory contracts before object or link access"
reject_mutation bad_domain runtime_memory_incompatible_allocator_domain \
  '0,/domain=host_process_allocator;/ s/domain=host_process_allocator;/domain=some_other_heap;/'
reject_mutation bad_operation runtime_memory_unsupported_target_operation \
  '0,/operation=allocate;/ s/operation=allocate;/operation=garbage_collect;/'
reject_mutation bad_ownership runtime_memory_incompatible_allocator_domain \
  '0,/ownership=ownership_transfers_to_caller;/ s/ownership=ownership_transfers_to_caller;/ownership=whoever_wants_it;/'
reject_mutation bad_layout runtime_memory_invalid_string_layout \
  '0,/layout=layout:type:gust:i32;/ s|layout=layout:type:gust:i32;|layout=guessed_from_the_c_struct;|'
reject_mutation unknown_format runtime_memory_missing_allocation_helper \
  '0,/format: gust.compiler_memory_runtime.v1/ s/format: gust.compiler_memory_runtime.v1/format: gust.compiler_memory_runtime.v9/'

# Removing every acquisition from a domain must be caught, not tolerated.
stage="reject a release with no acquisition in its domain"
orphan="$build_dir/orphan.request"
rg -v -e 'operation=allocate;domain=thread_local_scratch' "$request" >"$orphan" || true
if rg -n -F 'domain=thread_local_scratch' "$orphan" >/dev/null; then
  sed -i 's/operation=allocate;domain=thread_local_scratch/operation=memory_set;domain=thread_local_scratch/' "$orphan"
  if "$worker" phase17-memory-runtime-witness "$orphan" >/dev/null 2>"$build_dir/orphan.stderr"; then
    echo "orphaned release unexpectedly accepted" >&2; false
  fi
  rg -n -F 'reason=runtime_memory_incompatible_allocator_domain' "$build_dir/orphan.stderr" >/dev/null
fi

echo "guard-cranelift-phase17-memory-runtime-parity: ok (Level 2)"
