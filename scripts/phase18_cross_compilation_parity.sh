#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_cross_compilation"
request="/tmp/gust-phase18-cross.request"
mir_to_c="/tmp/gust-phase18-cross.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile cross compilation fixture"
trap 'status=$?; echo "Phase 18.9 cross compilation parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_cross_compilation_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 18.9 cross compilation smoke passed' to.log >/dev/null

stage="build Cranelift cross pair consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned cross pair witnesses"
"$worker" phase18-cross-pair-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm the witness records a blocked cross candidate"
rg -n -F 'classification=cross' "$build_dir/cranelift.witness" >/dev/null
rg -n -F 'declared=0' "$build_dir/cranelift.witness" >/dev/null
rg -n -F 'blocking_reason=no_declared_cross_linker_for_this_target' "$build_dir/cranelift.witness" >/dev/null

# Declaring a pair that cannot link is a claim without evidence.
stage="reject a cross pair declared without a discovered linker"
sed 's/declared=0;/declared=1;/' "$request" >"$build_dir/unfounded.request"
if "$worker" phase18-cross-pair-witness "$build_dir/unfounded.request" >"$build_dir/unfounded.witness" 2>"$build_dir/unfounded.err"; then
  echo "worker accepted a cross pair declared without a discovered linker" >&2; exit 1
fi
rg -n -F 'cross_pair_incomplete_tuple' "$build_dir/unfounded.err" >/dev/null

stage="reject an undeclared cross pair with no blocking reason"
sed 's/blocking_reason=no_declared_cross_linker_for_this_target;/blocking_reason=;/' "$request" >"$build_dir/silent.request"
if "$worker" phase18-cross-pair-witness "$build_dir/silent.request" >"$build_dir/silent.witness" 2>"$build_dir/silent.err"; then
  echo "worker accepted an undeclared cross pair with no blocking reason" >&2; exit 1
fi
rg -n -F 'cross_pair_undeclared' "$build_dir/silent.err" >/dev/null

# Classification is recomputed from the triples, so a mislabelled pair fails.
stage="reject a classification that disagrees with the triples"
sed 's/classification=cross;/classification=native;/' "$request" >"$build_dir/class.request"
if "$worker" phase18-cross-pair-witness "$build_dir/class.request" >"$build_dir/class.witness" 2>"$build_dir/class.err"; then
  echo "worker accepted a classification disagreeing with the triples" >&2; exit 1
fi
rg -n -F 'cross_pair_undeclared' "$build_dir/class.err" >/dev/null

echo "guard-cranelift-phase18-cross-compilation-parity: ok (byte-identical witness, 3 refusals, Level 2)"
