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

# Patch 25.5 rescoped this from arena.c to strings.c, and did NOT delete
# the assertion. arena.c is in the Rust crate now, so the obligation moved
# rather than ending: what this stage checks is that the retained C runtime
# -- whatever is left of it -- compiles from its OWN sources with no
# program-derived fragment on the command line. Dropping the stage because
# its subject moved would have quietly stopped asserting that.
#
# So the check is two-sided. arena.c must be ABSENT, and the symbols it
# used to define must be PRESENT in the archive. Either half alone passes
# for the wrong reason: a missing file proves nothing if nothing replaced
# it, and a defined symbol proves nothing if the C is still there too.
stage="confirm the ported runtime C is gone and its symbols moved, not vanished"
for gone in arena scratch collections file_io host_io strings; do
  if test -e "src/runtime/$gone.c"; then
    echo "src/runtime/$gone.c is back; Patch 25.5 moved it to src/runtime-rs" >&2; false
  fi
done
cargo build --release --manifest-path src/runtime-rs/Cargo.toml >"$build_dir/cargo-rs.log" 2>&1
archive="src/runtime-rs/target/release/libgust_runtime_rs.a"
for symbol in os_Arena_New os_ArenaAlloc os_Arena_Free os_Arena_Validate; do
  nm -g "$archive" | rg -n -F " T $symbol" >/dev/null
done
# Patch 25.10a: strings.c joins them, so the same two-sided check covers
# its ten symbols. Listing them rather than trusting the file's absence is
# the half that matters -- a deleted C file with nothing defining its
# symbols is a broken runtime, not a ported one.
for symbol in std_str_eq std_str_byte_at std_is_alpha std_is_digit \
              std_is_whitespace std_str_find std_parse_int std_str_slice \
              std_str_trim std_str_bounds_fail; do
  nm -g "$archive" | rg -n -F " T $symbol" >/dev/null
done

# Patch 25.10a: THERE IS NO RETAINED C COMPONENT LEFT, and this stage
# inverts with strings.c rather than being deleted with it.
#
# It compiled the retained component from its own sources, with no
# program-derived fragment on the command line, to show the component was
# independent of any user program. With strings.c in the Rust crate there
# is nothing left to compile, so what is asserted instead is the stronger
# thing that absence now buys: the runtime archive every natively compiled
# program links has NO C member at all. $(CC) is off its critical path.
#
# Stated as the archive's contents rather than as "no .c files exist":
# src/runtime.c and core_headers.h are still there, and neither is
# compiled into the archive. The claim is about what the runtime IS, not
# about which paths happen to remain.
# SCOPE, because `make` runs first and that is easy to misread: this
# checks what the BUILD produces, not what happens to be sitting in
# build/. A stray object dropped in by hand is rebuilt away before the
# comparison. That is the right scope -- the thing that could put C back
# on this path is a Makefile rule, and that is exactly what this catches.
stage="confirm the runtime archive retains no C member"
package=build/gust-runtime-package.a
make "$package" >"$build_dir/archive.log" 2>&1
members="$(ar t "$package" | tr '\n' ' ')"
if test "$members" != "gust_runtime_rs_exports.o "; then
  echo "runtime archive members are '$members', expected exactly" >&2
  echo "'gust_runtime_rs_exports.o '. A C member is back on the runtime's" >&2
  echo "critical path, which is what Patch 25.10a removed." >&2
  false
fi

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
# The probe is unchanged -- the same four arena entry points, through the
# component's own header rather than hand-written externs. It links against
# the crate archive now instead of arena.o, which is the point: the
# observable behaviour has to survive the move, not just the symbols.
# The link must SUCCEED. It did not have to before: the probe linked arena.o
# alone, which is incomplete by design, so an undefined reference meant "needs
# its sibling units" and an `else` branch accepted it. This patch links the
# complete crate archive, and against a complete archive an unresolved
# reference means the ported component is unusable -- so that branch could no
# longer be right, and it would have swallowed the next real regression in
# silence because it exited 0 and skipped the behavioural probe below.
# Measured at the time of the change: the link already succeeded, so requiring
# it changes nothing observable today and closes the hole for later.
cc -O2 -I src/runtime "$build_dir/probe.c" "$archive" -pthread \
  -o "$build_dir/probe" 2>"$build_dir/link.log"
# Kept from the deleted branch rather than dropped with it: whatever the link
# does, it must not have reached for generated C. An assertion that only ran
# on the failure path asserted nothing on the path we actually take.
if rg -n -e 'generated' -e 'shim' "$build_dir/link.log" >/dev/null; then
  echo "retained C link referenced generated program source" >&2; false
fi
"$build_dir/probe" >"$build_dir/probe.out"
rg -n -F 'RETAINED C PARITY OK' "$build_dir/probe.out" >/dev/null

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
