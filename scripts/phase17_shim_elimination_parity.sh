#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase17_shim"
request="/tmp/gust-phase17-shim-elimination.request"
mir_to_c="/tmp/gust-phase17-shim-elimination.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile shim elimination fixture"
trap 'status=$?; echo "Phase 17.9 shim elimination parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_shim_elimination_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 17.9 shim elimination smoke passed' to.log >/dev/null

stage="build Cranelift shim elimination consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

# The exit gate: explicit Cranelift must succeed with the C compiler
# unavailable. This is a demonstration, not a declaration. The environment is
# emptied so no cc, gcc, clang, or linker driver can be found, and a native
# object carrying one symbol per removed shim class must still be produced.
stage="emit a native object with no C compiler available"
rm -f "$build_dir/no_cc.o"
env -i PATH="/nonexistent" "$root/$worker" phase17-shim-elimination-object \
    "$request" "$build_dir/no_cc.o"
test -s "$build_dir/no_cc.o"
if command -v nm >/dev/null 2>&1; then
  nm -g --defined-only "$build_dir/no_cc.o" >"$build_dir/no_cc.symbols"
  for class in runtime_call_wrapper abi_adaptation_wrapper \
               resource_or_cleanup_wrapper allocation_or_string_helper_wrapper \
               io_filesystem_or_threading_wrapper target_selection_wrapper_fragment; do
    rg -n -F "gust_phase17_no_shim_$class" "$build_dir/no_cc.symbols" >/dev/null
  done
  # No obsolete generated-C family may appear in a native object.
  if rg -n -e '_IsValid' -e '_pthread_wrapper' -e 'gust_user_main' \
       -e 'GenerationalArena_Clone' "$build_dir/no_cc.symbols" >/dev/null; then
    echo "an obsolete generated-C family reached the native object" >&2; false
  fi
fi

stage="confirm the native request carries no C wrapper source"
if rg -n -e 'c_wrapper_source' -e 'generated_c_body' -e 'shim_source_text' \
     compiler/mir_native_backend_runtime_request.gst \
     compiler/mir_runtime_boundary_authority.gst >/dev/null; then
  echo "the native request transports C wrapper source" >&2; false
fi
if rg -n -e 'fn synthesize_c_wrapper' -e 'fn emit_program_c_shim' \
     compiler/experiments/cranelift/src/*.rs >/dev/null; then
  echo "the worker synthesizes C wrapper source" >&2; false
fi

stage="compare compiler-owned shim elimination witnesses"
"$worker" phase17-shim-elimination-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"
for token in 'banned_class=runtime_call_wrapper' 'banned_class=abi_adaptation_wrapper' \
             'banned_class=resource_or_cleanup_wrapper' \
             'banned_class=allocation_or_string_helper_wrapper' \
             'banned_class=io_filesystem_or_threading_wrapper' \
             'banned_class=target_selection_wrapper_fragment' \
             'evidence=explicit_cranelift_succeeds_with_c_compiler_unavailable' \
             'linkage=native_path_emits_no_program_specific_c'; do
  rg -n -F "$token" "$build_dir/cranelift.witness" >/dev/null
done

reject_mutation() {
  local label="$1" reason="$2" expression="$3"
  local mutated="$build_dir/$1.request" output="$build_dir/$1.output" temporary="$build_dir/$1.tmp"
  cp "$request" "$mutated"; sed -i "$expression" "$mutated"
  printf 'sentinel: preserve-existing-output\n' >"$output"
  if "$worker" phase17-shim-elimination-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr"; then
    echo "mutation unexpectedly succeeded: $label" >&2; false
  fi
  rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
  rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null
}

stage="reject malformed shim elimination metadata"
reject_mutation unclassified runtime_shim_unclassified_ban \
  '0,/banned_class=runtime_call_wrapper;/ s/banned_class=runtime_call_wrapper;/banned_class=mystery_wrapper;/'
reject_mutation no_replacement runtime_shim_ban_without_replacement \
  '0,/replacement_kind=compiler_owned_direct_import;/ s/replacement_kind=compiler_owned_direct_import;/replacement_kind=just_removed_it;/'
reject_mutation no_evidence runtime_shim_missing_evidence \
  '0,/evidence=explicit_cranelift_succeeds_with_c_compiler_unavailable;/ s/evidence=explicit_cranelift_succeeds_with_c_compiler_unavailable;/evidence=trust_me;/'
reject_mutation unknown_format runtime_shim_unclassified_ban \
  '0,/format: gust.compiler_shim_elimination.v1/ s/format: gust.compiler_shim_elimination.v1/format: gust.compiler_shim_elimination.v9/'

echo "guard-cranelift-phase17-shim-elimination-parity: ok (Level 2)"
