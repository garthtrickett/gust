#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_target_support"
request="/tmp/gust-phase18-support.request"
mir_to_c="/tmp/gust-phase18-support.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile target support fixture"
trap 'status=$?; echo "Phase 18.2 target support parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_target_support_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 18.2 target support tuple smoke passed' to.log >/dev/null

stage="build Cranelift target support consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned support tuple witnesses"
"$worker" phase18-target-support-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm the witness records an incomplete tuple at this patch"
rg -n -F 'decision=unsupported_pending_tuple_evidence' "$build_dir/cranelift.witness" >/dev/null
rg -n -F 'complete=0' "$build_dir/cranelift.witness" >/dev/null

# Support is a conjunction: claiming supported without four elements must be
# refused by the worker, not merely absent from the accepting path.
stage="reject supported without a complete tuple"
sed 's/decision=unsupported_pending_tuple_evidence/decision=supported/' "$request" >"$build_dir/overclaim.request"
if "$worker" phase18-target-support-witness "$build_dir/overclaim.request" >"$build_dir/overclaim.witness" 2>"$build_dir/overclaim.err"; then
  echo "worker accepted supported without a complete tuple" >&2
  exit 1
fi
rg -n -F 'target_supported_without_complete_tuple' "$build_dir/overclaim.err" >/dev/null

# A request cannot declare itself complete; the worker recomputes it.
stage="reject a claimed completeness that disagrees with the elements"
sed 's/complete=0/complete=1/' "$request" >"$build_dir/claimed.request"
if "$worker" phase18-target-support-witness "$build_dir/claimed.request" >"$build_dir/claimed.witness" 2>"$build_dir/claimed.err"; then
  echo "worker accepted a claimed completeness disagreeing with its elements" >&2
  exit 1
fi
rg -n -F 'target_support_decision_drift' "$build_dir/claimed.err" >/dev/null

stage="reject an element order that is not the frozen order"
sed 's/kind=compiler;/kind=abi;/' "$request" >"$build_dir/order.request"
if "$worker" phase18-target-support-witness "$build_dir/order.request" >"$build_dir/order.witness" 2>"$build_dir/order.err"; then
  echo "worker accepted an element order that is not the frozen order" >&2
  exit 1
fi
rg -n -F 'target_support_order_drift' "$build_dir/order.err" >/dev/null

echo "guard-cranelift-phase18-target-support-parity: ok (byte-identical witness, 3 refusals, Level 2)"
