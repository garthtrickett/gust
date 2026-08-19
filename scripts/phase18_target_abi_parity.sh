#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_target_abi"
request="/tmp/gust-phase18-abi.request"
mir_to_c="/tmp/gust-phase18-abi.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile target ABI fixture"
trap 'status=$?; echo "Phase 18.5 target ABI parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_target_abi_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 18.5 target ABI selection smoke passed' to.log >/dev/null

stage="build Cranelift target ABI consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned ABI selection witnesses"
"$worker" phase18-target-abi-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm the witness records a deferred platform convention"
rg -n -F 'platform_convention=deferred_to_a_later_abi_phase' "$build_dir/cranelift.witness" >/dev/null
rg -n -F 'abi_id=gust_canonical_v1' "$build_dir/cranelift.witness" >/dev/null

# Phase 18 selects only what Phase 16 accepts. Inventing an ABI is Phase 18
# defining ABI semantics, which the boundary forbids.
stage="reject an ABI Phase 16 does not accept"
sed 's/abi_id=gust_canonical_v1;/abi_id=sysv_x86_64;/' "$request" >"$build_dir/invented.request"
if "$worker" phase18-target-abi-witness "$build_dir/invented.request" >"$build_dir/invented.witness" 2>"$build_dir/invented.err"; then
  echo "worker accepted an ABI Phase 16 does not accept" >&2; exit 1
fi
rg -n -F 'target_abi_undeclared_by_phase16' "$build_dir/invented.err" >/dev/null

stage="reject a selected platform calling convention"
sed 's/platform_convention=deferred_to_a_later_abi_phase;/platform_convention=selected_sysv;/' "$request" >"$build_dir/platform.request"
if "$worker" phase18-target-abi-witness "$build_dir/platform.request" >"$build_dir/platform.witness" 2>"$build_dir/platform.err"; then
  echo "worker accepted a selected platform calling convention" >&2; exit 1
fi
rg -n -F 'target_abi_platform_convention_selected_without_phase16_support' "$build_dir/platform.err" >/dev/null

stage="reject a compatibility field that is not a decision"
sed 's/compatibility=compatible;/compatibility=probably;/' "$request" >"$build_dir/undecided.request"
if "$worker" phase18-target-abi-witness "$build_dir/undecided.request" >"$build_dir/undecided.witness" 2>"$build_dir/undecided.err"; then
  echo "worker accepted a compatibility field that is not a decision" >&2; exit 1
fi
rg -n -F 'target_abi_incompatible' "$build_dir/undecided.err" >/dev/null

echo "guard-cranelift-phase18-target-abi-parity: ok (byte-identical witness, 3 refusals, Level 2)"
