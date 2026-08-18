#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_target_authority"
request="/tmp/gust-phase18-target.request"
mir_to_c="/tmp/gust-phase18-target.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile target authority fixture"
trap 'status=$?; echo "Phase 18.1 target authority parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_target_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 18.1 target authority smoke passed' to.log >/dev/null

stage="build Cranelift target consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned target identity witnesses"
"$worker" phase18-target-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm the witness carries layout agreement and selection provenance"
rg -n -F 'layout_agreement=agrees_with_phase14_target_layout_authority' "$build_dir/cranelift.witness" >/dev/null
rg -n -F 'mode=explicit_requested_target' "$build_dir/cranelift.witness" >/dev/null
rg -n -F 'consulted_host=0' "$build_dir/cranelift.witness" >/dev/null

# An explicit request that consulted the host must be refused by the worker,
# not merely absent from the happy path.
stage="reject host inference under an explicit target"
sed 's/consulted_host=0/consulted_host=1/' "$request" >"$build_dir/host-probe.request"
if "$worker" phase18-target-witness "$build_dir/host-probe.request" >"$build_dir/host-probe.witness" 2>"$build_dir/host-probe.err"; then
  echo "worker accepted an explicit target that consulted the host" >&2
  exit 1
fi
rg -n -F 'host_inference_under_explicit_target' "$build_dir/host-probe.err" >/dev/null

# A pointer width that disagrees with the Phase 14 layout authority must be
# refused even though the request claims agreement.
stage="reject a pointer width that disagrees with the layout authority"
sed 's/ptr_bits=64/ptr_bits=32/' "$request" >"$build_dir/width.request"
if "$worker" phase18-target-witness "$build_dir/width.request" >"$build_dir/width.witness" 2>"$build_dir/width.err"; then
  echo "worker accepted a pointer width disagreeing with the layout authority" >&2
  exit 1
fi
rg -n -F 'target_layout_disagreement' "$build_dir/width.err" >/dev/null

stage="reject an identity that does not claim layout agreement"
sed 's/layout_agreement=agrees_with_phase14_target_layout_authority/layout_agreement=unverified/' "$request" >"$build_dir/unverified.request"
if "$worker" phase18-target-witness "$build_dir/unverified.request" >"$build_dir/unverified.witness" 2>"$build_dir/unverified.err"; then
  echo "worker accepted an identity that does not claim layout agreement" >&2
  exit 1
fi
rg -n -F 'target_layout_disagreement' "$build_dir/unverified.err" >/dev/null

echo "guard-cranelift-phase18-target-authority-parity: ok (byte-identical witness, 3 refusals, Level 2)"
