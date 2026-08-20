#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$root"
build_dir="build/guards/phase18_source_location"
request="/tmp/gust-phase18-srcloc.request"
mir_to_c="/tmp/gust-phase18-srcloc.mir-to-c.witness"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
stage="compile source location fixture"
trap 'status=$?; echo "Phase 18.13 source location parity failed: stage=$stage status=$status line=$LINENO" >&2; exit $status' ERR

bash scripts/run-gust-file.sh compiler/mir_source_location_smoke_test_entry.gst
rg -n -F 'SUCCESS: Phase 18.13 source location smoke passed' to.log >/dev/null

stage="build Cranelift source location consumer"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1

stage="compare compiler-owned source location witnesses"
"$worker" phase18-source-location-witness "$request" >"$build_dir/cranelift.witness"
cmp -s "$mir_to_c" "$build_dir/cranelift.witness"

stage="confirm the witness records a compiler-produced location"
rg -n -F 'produced_by=canonical_mir' "$build_dir/cranelift.witness" >/dev/null

# A location with no canonical MIR association was reconstructed by the backend.
stage="reject a location the backend reconstructed"
sed 's/mir=mir.block.3;/mir=;/' "$request" >"$build_dir/reconstructed.request"
if "$worker" phase18-source-location-witness "$build_dir/reconstructed.request" >"$build_dir/reconstructed.witness" 2>"$build_dir/reconstructed.err"; then
  echo "worker accepted a backend-reconstructed source location" >&2; exit 1
fi
rg -n -F 'source_location_reconstructed_by_backend' "$build_dir/reconstructed.err" >/dev/null

# Inventing a span for code the source did not write points a debugger
# confidently at the wrong line, which is worse than admitting the gap.
stage="reject a fabricated location with no source span"
sed 's/span=12:5-12:20;/span=;/' "$request" >"$build_dir/fabricated.request"
if "$worker" phase18-source-location-witness "$build_dir/fabricated.request" >"$build_dir/fabricated.witness" 2>"$build_dir/fabricated.err"; then
  echo "worker accepted a fabricated source location" >&2; exit 1
fi
rg -n -F 'source_location_fabricated_without_a_source_span' "$build_dir/fabricated.err" >/dev/null

stage="reject a location lost between canonical MIR and emitted records"
sed 's/emitted=dwarf.line.7;/emitted=;/' "$request" >"$build_dir/lost.request"
if "$worker" phase18-source-location-witness "$build_dir/lost.request" >"$build_dir/lost.witness" 2>"$build_dir/lost.err"; then
  echo "worker accepted a location lost in lowering" >&2; exit 1
fi
rg -n -F 'source_location_lost_in_lowering' "$build_dir/lost.err" >/dev/null

echo "guard-cranelift-phase18-source-location-parity: ok (byte-identical witness, 3 refusals, Level 2)"
