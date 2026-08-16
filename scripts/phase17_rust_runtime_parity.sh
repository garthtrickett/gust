#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase17_rust_runtime"
request="/tmp/gust-phase17-rust-runtime.request"
mir_to_c="/tmp/gust-phase17-rust-runtime.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
rust_manifest="src/runtime/rust/Cargo.toml"
rust_archive="src/runtime/rust/target/release/libgust_rust_runtime.a"
mkdir -p "$build_dir"
stage="compile rust runtime component fixture"
trap 'status=$?; echo "Phase 17.6 rust runtime parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_rust_runtime_component_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 17.6 rust runtime component smoke passed' to.log >/dev/null

# The component is compiled independently of any Gust program.
stage="build the Rust runtime component independently"
cargo build --manifest-path "$rust_manifest" --release >"$build_dir/rust-build.log" 2>&1
test -f "$rust_archive"

# ABI-facing exports must be stable and unmangled. Rust-internal mangling is not
# a runtime contract, so the symbols must appear exactly as the compiler spells
# them.
stage="confirm stable unmangled ABI-facing exports"
nm -g --defined-only "$rust_archive" >"$build_dir/rust.symbols"
for symbol in gust_rt_checked_add_i32 gust_rt_saturating_add_i32; do
  rg -n -F "T $symbol" "$build_dir/rust.symbols" >/dev/null
done
if rg -n -e '_ZN' -e '17h[0-9a-f]{16}' "$build_dir/rust.symbols" | rg -n -F 'gust_rt_' >/dev/null; then
  echo "Rust-internal mangling reached an ABI-facing export" >&2; false
fi

# Focused runtime and failure evidence: the component links into a C host and
# behaves correctly on both the success and the overflow-failure path.
stage="link the component and compare runtime and failure behaviour"
cat >"$build_dir/probe.c" <<'PROBE'
#include <stdio.h>
#include <limits.h>
extern int gust_rt_checked_add_i32(int a, int b, int *out);
extern int gust_rt_saturating_add_i32(int a, int b);
int main(void) {
    int out = 7;
    if (gust_rt_checked_add_i32(2, 3, &out) != 1 || out != 5) { puts("FAIL ok-path"); return 1; }
    if (gust_rt_checked_add_i32(INT_MAX, 1, &out) != 0) { puts("FAIL overflow-detect"); return 2; }
    if (out != 5) { puts("FAIL overflow-clobbered-out"); return 3; }
    if (gust_rt_saturating_add_i32(INT_MAX, 1) != INT_MAX) { puts("FAIL sat-max"); return 4; }
    if (gust_rt_saturating_add_i32(INT_MIN, -1) != INT_MIN) { puts("FAIL sat-min"); return 5; }
    puts("RUST RUNTIME PARITY OK");
    return 0;
}
PROBE
cc -O2 "$build_dir/probe.c" "$rust_archive" -o "$build_dir/probe"
"$build_dir/probe" >"$build_dir/probe.out"
rg -n -F 'RUST RUNTIME PARITY OK' "$build_dir/probe.out" >/dev/null

# No source-specific C generation stands between the program and the component.
stage="confirm no generated C glue in the component archive"
if rg -n -e 'gust_generated_c_shim' -e 'gust_runtime_wrapper' "$build_dir/rust.symbols" >/dev/null; then
  echo "generated C glue reached the Rust runtime component" >&2; false
fi

stage="build Cranelift rust runtime consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned rust runtime witnesses"
"$worker" phase17-rust-runtime-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"
for token in 'panic_boundary=abort_no_unwind_across_ffi' \
             'allocation_boundary=no_allocation_caller_owns_all_memory' \
             'object_form=static_library' \
             'linkage=independently_compiled_component_no_source_specific_c_generation'; do
  rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null
done

reject_mutation() {
  local label="$1" reason="$2" expression="$3"
  local mutated="$build_dir/$1.request" output="$build_dir/$1.output" temporary="$build_dir/$1.tmp"
  cp "$request" "$mutated"; sed -i "$expression" "$mutated"
  printf 'sentinel: preserve-existing-output\n' >"$output"
  if "$worker" phase17-rust-runtime-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr"; then
    echo "mutation unexpectedly succeeded: $label" >&2; false
  fi
  rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
  rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null
}

stage="reject malformed rust runtime metadata before object or link access"
reject_mutation undeclared_export runtime_rust_undeclared_export \
  '0,/;exports=[^;]*;/ s/;exports=[^;]*;/;exports=none;/'
reject_mutation unwind_boundary runtime_rust_unwind_boundary_violation \
  '0,/panic_boundary=abort_no_unwind_across_ffi/ s/panic_boundary=abort_no_unwind_across_ffi/panic_boundary=unwind_into_caller/'
reject_mutation object_form runtime_rust_abi_or_target_mismatch \
  '0,/object_form=static_library/ s/object_form=static_library/object_form=dynamic_library/'
reject_mutation c_glue runtime_rust_generated_c_glue_dependency \
  '0,/;imports=none;/ s/;imports=none;/;imports=runtime_symbol:v1:generated_c_shim_helper;/'
reject_mutation unknown_format runtime_rust_undeclared_export \
  '0,/format: gust.compiler_rust_runtime.v1/ s/format: gust.compiler_rust_runtime.v1/format: gust.compiler_rust_runtime.v9/'

echo "guard-cranelift-phase17-rust-runtime-parity: ok (Level 2)"
