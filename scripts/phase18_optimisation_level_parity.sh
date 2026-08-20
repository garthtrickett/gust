#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_optimisation"
request="/tmp/gust-phase18-opt.request"
mir_to_c="/tmp/gust-phase18-opt.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile optimisation level fixture"
trap 'status=$?; echo "Phase 18.14 optimisation level parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_optimisation_level_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 18.14 optimisation level smoke passed' to.log >/dev/null

stage="build Cranelift optimisation consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned optimisation witnesses"
"$worker" phase18-optimisation-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm the witness records the equivalence the compiler claims"
rg -n -F 'observable_behaviour=identical_across_declared_levels' "$build_dir/cranelift.witness" >/dev/null

stage="reject a level outside the declared vocabulary"
sed 's/level=basic;/level=aggressive;/' "$request" >"$build_dir/unknown.request"
if "$worker" phase18-optimisation-witness "$build_dir/unknown.request" >"$build_dir/unknown.witness" 2>"$build_dir/unknown.err"; then
  echo "worker accepted an undeclared optimisation level" >&2; exit 1
fi
rg -n -F 'optimisation_level_unknown' "$build_dir/unknown.err" >/dev/null

stage="reject a level the backend selected"
sed 's/selected_by=compiler;/selected_by=backend;/' "$request" >"$build_dir/backend.request"
if "$worker" phase18-optimisation-witness "$build_dir/backend.request" >"$build_dir/backend.witness" 2>"$build_dir/backend.err"; then
  echo "worker accepted a backend-selected optimisation level" >&2; exit 1
fi
rg -n -F 'optimisation_level_selected_by_backend' "$build_dir/backend.err" >/dev/null

# The unoptimised level carrying a transformation is the case that quietly
# destroys the baseline: the anchor build is optimised and nobody notices.
stage="reject the unoptimised level carrying a transformation"
sed 's/level=basic;/level=none;/' "$request" >"$build_dir/baseline.request"
if "$worker" phase18-optimisation-witness "$build_dir/baseline.request" >"$build_dir/baseline.witness" 2>"$build_dir/baseline.err"; then
  echo "worker accepted a transformation under the unoptimised level" >&2; exit 1
fi
rg -n -F 'optimisation_level_transformation_undeclared' "$build_dir/baseline.err" >/dev/null

stage="reject a transformation the level does not declare"
sed 's/transformation=dead_code_elimination;/transformation=loop_unrolling;/' "$request" >"$build_dir/undeclared.request"
if "$worker" phase18-optimisation-witness "$build_dir/undeclared.request" >"$build_dir/undeclared.witness" 2>"$build_dir/undeclared.err"; then
  echo "worker accepted an undeclared transformation" >&2; exit 1
fi
rg -n -F 'optimisation_level_transformation_undeclared' "$build_dir/undeclared.err" >/dev/null

echo "guard-cranelift-phase18-optimisation-level-parity: ok (byte-identical witness, 4 refusals, Level 2)"
