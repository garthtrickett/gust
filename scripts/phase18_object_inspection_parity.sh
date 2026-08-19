#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_object_inspection"
request="/tmp/gust-phase18-inspect.request"
mir_to_c="/tmp/gust-phase18-inspect.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile object inspection fixture"
trap 'status=$?; echo "Phase 18.11 object inspection parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_object_inspection_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 18.11 object inspection smoke passed' to.log >/dev/null

stage="build Cranelift object inspection consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned inspection witnesses"
"$worker" phase18-object-inspection-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm the witness records an observation traced to the compiler plan"
rg -n -F 'in_plan=1' "$build_dir/cranelift.witness" >/dev/null

# Inspection may contradict the compiler plan but never extend it.
stage="reject a symbol the compiler never planned"
sed 's/in_plan=1;/in_plan=0;/' "$request" >"$build_dir/unplanned.request"
if "$worker" phase18-object-inspection-witness "$build_dir/unplanned.request" >"$build_dir/unplanned.witness" 2>"$build_dir/unplanned.err"; then
  echo "worker accepted a symbol the compiler never planned" >&2; exit 1
fi
rg -n -F 'inspected_symbol_not_in_compiler_plan' "$build_dir/unplanned.err" >/dev/null

stage="reject a binding outside the declared vocabulary"
sed 's/binding=global;/binding=exported;/' "$request" >"$build_dir/binding.request"
if "$worker" phase18-object-inspection-witness "$build_dir/binding.request" >"$build_dir/binding.witness" 2>"$build_dir/binding.err"; then
  echo "worker accepted a binding outside the declared vocabulary" >&2; exit 1
fi
rg -n -F 'inspected_binding_outside_declared_vocabulary' "$build_dir/binding.err" >/dev/null

stage="reject an observed relocation in a section that holds no bytes"
sed 's/section=text;/section=zero_initialised_data;/' "$request" >"$build_dir/bss.request"
if "$worker" phase18-object-inspection-witness "$build_dir/bss.request" >"$build_dir/bss.witness" 2>"$build_dir/bss.err"; then
  echo "worker accepted an observed relocation in zero-initialised data" >&2; exit 1
fi
rg -n -F 'inspected_relocation_in_disallowed_section' "$build_dir/bss.err" >/dev/null

stage="reject a relocation kind no declared model permits"
sed 's/relocation=R_X86_64_64;/relocation=R_X86_64_GOTPCREL;/' "$request" >"$build_dir/kind.request"
if "$worker" phase18-object-inspection-witness "$build_dir/kind.request" >"$build_dir/kind.witness" 2>"$build_dir/kind.err"; then
  echo "worker accepted a relocation kind no declared model permits" >&2; exit 1
fi
rg -n -F 'inspected_relocation_kind_not_in_model' "$build_dir/kind.err" >/dev/null

echo "guard-cranelift-phase18-object-inspection-parity: ok (byte-identical witness, 4 refusals, Level 2)"
