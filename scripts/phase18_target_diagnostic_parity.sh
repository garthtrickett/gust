#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_target_diagnostic"
request="/tmp/gust-phase18-diag.request"
mir_to_c="/tmp/gust-phase18-diag.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile target diagnostic fixture"
trap 'status=$?; echo "Phase 18.10 target diagnostic parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_target_diagnostic_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 18.10 target diagnostics smoke passed' to.log >/dev/null

stage="build Cranelift target diagnostic consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned diagnostic witnesses"
"$worker" phase18-target-diagnostic-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm the witness names the missing element and refuses early"
rg -n -F 'missing=linker' "$build_dir/cranelift.witness" >/dev/null
rg -n -F 'rejection=missing_linker' "$build_dir/cranelift.witness" >/dev/null
rg -n -F 'stage=before_driver_discovery' "$build_dir/cranelift.witness" >/dev/null

# A refusal that does not say why is not a diagnostic.
stage="reject an unsupported target with no rejection class"
sed 's/rejection=missing_linker;/rejection=;/' "$request" >"$build_dir/vague.request"
if "$worker" phase18-target-diagnostic-witness "$build_dir/vague.request" >"$build_dir/vague.witness" 2>"$build_dir/vague.err"; then
  echo "worker accepted an unsupported target with no rejection class" >&2; exit 1
fi
rg -n -F 'target_diagnostic_generic_refusal' "$build_dir/vague.err" >/dev/null

stage="reject a rejection class outside the declared inventory"
sed 's/rejection=missing_linker;/rejection=something_went_wrong;/' "$request" >"$build_dir/unknown.request"
if "$worker" phase18-target-diagnostic-witness "$build_dir/unknown.request" >"$build_dir/unknown.witness" 2>"$build_dir/unknown.err"; then
  echo "worker accepted a rejection class outside the declared inventory" >&2; exit 1
fi
rg -n -F 'target_diagnostic_generic_refusal' "$build_dir/unknown.err" >/dev/null

# A refusal deferred past the point output could exist cannot preserve it.
stage="reject a refusal deferred past output replacement"
sed 's/stage=before_driver_discovery;/stage=during_output_replacement;/' "$request" >"$build_dir/late.request"
if "$worker" phase18-target-diagnostic-witness "$build_dir/late.request" >"$build_dir/late.witness" 2>"$build_dir/late.err"; then
  echo "worker accepted a refusal deferred past output replacement" >&2; exit 1
fi
rg -n -F 'target_diagnostic_refused_too_late' "$build_dir/late.err" >/dev/null

echo "guard-cranelift-phase18-target-diagnostic-parity: ok (byte-identical witness, 3 refusals, Level 2)"
