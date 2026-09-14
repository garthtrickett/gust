#!/usr/bin/env bash
set -euo pipefail
python3 scripts/phase15_resource_composition.py --check >/dev/null
build_dir="build/guards/phase15_resource_composition"
request="/tmp/gust-phase15-resource-composition.request"
expected="/tmp/gust-phase15-resource-composition.mir-to-c.witness"
rm -rf "$build_dir"
rm -f "$request" "$expected"
mkdir -p "$build_dir"

XDG_RUNTIME_DIR=/tmp TMPDIR=/tmp bash scripts/run-gust-file.sh compiler/future/p15_complete_resource_differential_source.gst
grep -F 'SUCCESS: Phase 15.13 composed resource source passed' to.log >/dev/null
# Patch 24.12: the two-spelling emit-determinism check asserted a property
# of the retired emitter and had no native counterpart, so it goes with the
# backend rather than being served frozen bytes on both sides. What stays
# live is that the frozen oracle still accepts this source cleanly; the
# witness comparison below is unchanged.
python3 scripts/phase24_frozen_oracle.py materialize \
  compiler/future/p15_complete_resource_differential_source.gst \
  "$build_dir/frozen" --kind exec
test ! -s "$build_dir/frozen.compile.stderr"

XDG_RUNTIME_DIR=/tmp TMPDIR=/tmp bash scripts/run-gust-file.sh compiler/mir_resource_composition_state_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 15.13 resource composition state policy passed' to.log >/dev/null
XDG_RUNTIME_DIR=/tmp TMPDIR=/tmp bash scripts/run-gust-file.sh compiler/mir_resource_composition_parity_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 15.13 resource composition parity smoke passed' to.log >/dev/null
test -s "$request" && test -s "$expected"

cargo build --quiet --manifest-path compiler/experiments/cranelift/Cargo.toml
compiler/experiments/cranelift/target/debug/gust-cranelift-experiment phase15-resource-composition-witness "$request" >"$build_dir/cranelift.witness"
diff -u "$expected" "$build_dir/cranelift.witness"
grep -F 'resource_composition_case: id=phase15:complete_resource_composition covered_entries=12' "$build_dir/cranelift.witness" >/dev/null
grep -F 'resource_composition_comparison: default_explicit_mir_to_c_byte_identity=1 mir_to_c_cranelift_witness_identity=1' "$build_dir/cranelift.witness" >/dev/null
echo "guard-cranelift-phase15-resource-composition-differential: ok (Level 2)"
