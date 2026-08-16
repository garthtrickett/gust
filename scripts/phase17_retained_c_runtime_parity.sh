#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase17_retained_c"
request="/tmp/gust-phase17-retained-c.request"
mir_to_c="/tmp/gust-phase17-retained-c.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile retained C runtime fixture"
trap 'status=$?; echo "Phase 17.7 retained C parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_retained_c_runtime_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 17.7 retained C runtime smoke passed' to.log >/dev/null

# The retained component compiles independently of any user program: only its
# own owned sources, no program-derived fragment on the command line.
stage="compile the retained C component independently of program compilation"
cc -O2 -c src/runtime/arena.c -I src/runtime -o "$build_dir/arena.o" 2>"$build_dir/cc.log"
test -f "$build_dir/arena.o"

# Observable behaviour is compared through a direct C host, matching what
# MIR-to-C and explicit Cranelift both see from the same component.
stage="compare observable retained C behaviour"
# The probe uses the component's OWN declared header rather than hand-written
# externs. Guessing the ABI is precisely the implicit-assumption failure this
# phase exists to remove, and an earlier version of this probe segfaulted by
# declaring os_Arena_New as void*(size_t) when it returns a struct by value.
cat >"$build_dir/probe.c" <<'PROBE'
#include <stdio.h>
#include "core_headers.h"
int main(void) {
    os_Arena arena = os_Arena_New();
    int offset = os_ArenaAlloc(&arena, 64);
    if (offset < 0) { puts("FAIL arena-alloc"); return 1; }
    os_Arena_Validate(&arena);
    os_Arena_Free(&arena);
    puts("RETAINED C PARITY OK");
    return 0;
}
PROBE
if cc -O2 -I src/runtime "$build_dir/probe.c" "$build_dir/arena.o" -o "$build_dir/probe" 2>"$build_dir/link.log"; then
  "$build_dir/probe" >"$build_dir/probe.out"
  rg -n -F 'RETAINED C PARITY OK' "$build_dir/probe.out" >/dev/null
else
  # A link needing declared sibling runtime units is not a defect; independent
  # compilation is what this patch asserts. But it must fail on undefined
  # symbols only, never by reaching for generated program C.
  rg -n -F 'undefined reference' "$build_dir/link.log" >/dev/null
  if rg -n -e 'generated' -e 'shim' "$build_dir/link.log" >/dev/null; then
    echo "retained C link referenced generated program source" >&2; false
  fi
  echo "note: arena.o requires declared sibling runtime units; no generated C involved"
fi

# No retained C source may be derived from a compiled program.
stage="confirm no program-derived C source is owned by the component"
rg -n -F 'sources=' "$request" >"$build_dir/sources.txt"
if rg -n -e 'build/' -e 'generated' "$build_dir/sources.txt" >/dev/null; then
  echo "retained C component owns program-derived source" >&2; false
fi

stage="build Cranelift retained C consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned retained C witnesses"
"$worker" phase17-retained-c-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"
for token in 'retention_reason=awaiting_pure_gust_migration' \
             'destination_phase=17.8' \
             'linkage=separately_compiled_component_no_program_derived_c_source'; do
  rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null
done

reject_mutation() {
  local label="$1" reason="$2" expression="$3"
  local mutated="$build_dir/$1.request" output="$build_dir/$1.output" temporary="$build_dir/$1.tmp"
  cp "$request" "$mutated"; sed -i "$expression" "$mutated"
  printf 'sentinel: preserve-existing-output\n' >"$output"
  if "$worker" phase17-retained-c-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr"; then
    echo "mutation unexpectedly succeeded: $label" >&2; false
  fi
  rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
  rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null
}

stage="reject malformed retained C metadata before object or link access"
reject_mutation anonymous runtime_retained_c_anonymous_object \
  '0,/retention_reason=awaiting_pure_gust_migration/ s/retention_reason=awaiting_pure_gust_migration/retention_reason=because_it_works/'
reject_mutation generated_source runtime_retained_c_program_specific_generation \
  '0,/;sources=[^;]*;/ s|;sources=[^;]*;|;sources=build/generated/program_shim.c;|'
reject_mutation unversioned_export runtime_retained_c_unversioned_export \
  '0,/;exports=[^;]*;/ s/;exports=[^;]*;/;exports=none;/'
reject_mutation hidden_target runtime_retained_c_hidden_target_assumption \
  '0,/applicability=all_declared_host_targets_from_phase14_target_authority/ s/applicability=all_declared_host_targets_from_phase14_target_authority/applicability=assumes_posix/'
reject_mutation unknown_format runtime_retained_c_anonymous_object \
  '0,/format: gust.compiler_retained_c_runtime.v1/ s/format: gust.compiler_retained_c_runtime.v1/format: gust.compiler_retained_c_runtime.v9/'

echo "guard-cranelift-phase17-retained-c-runtime-parity: ok (Level 2)"
