#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

build_dir="build/guards/phase19_composition"
source_fixture="compiler/phase19_cross_feature_composition_source.gst"
expected_status="$(jq -r '.phase19_composition.expected_exit_status' scripts/cranelift_feature_registry.json)"

python3 scripts/phase19_composition.py validate >/dev/null
if [ ! -x ./gust ]; then
  echo "Phase 19.11 composition parity requires the rebuilt ./gust compiler." >&2
  exit 1
fi

rm -rf "$build_dir"
mkdir -p "$build_dir"

# Patch 24.12: the emit-determinism check and the generated-C arena-spelling
# leak check both asserted properties of the retired emitter's output text,
# with no native counterpart, so they are removed rather than frozen on both
# sides. The behavioural comparison below is preserved against frozen
# observables.
python3 scripts/phase24_frozen_oracle.py materialize \
  "$source_fixture" "$build_dir/mir-to-c" --kind exec
test ! -s "$build_dir/mir-to-c.compile.stderr"
cp "$build_dir/mir-to-c.stdout" "$build_dir/runtime.stdout"
cp "$build_dir/mir-to-c.stderr" "$build_dir/runtime.stderr"
actual_status="$(cat "$build_dir/mir-to-c.status")"
if [ "$actual_status" != "$expected_status" ]; then
  echo "Phase 19.11 MIR-to-C returned $actual_status, expected $expected_status." >&2
  exit 1
fi
test ! -s "$build_dir/runtime.stdout"
test ! -s "$build_dir/runtime.stderr"

# The combined generic source is outside the connected native source route.
# The roadmap permits that half to be explicitly deferred, but never to fall
# back to MIR-to-C. A deliberately absent driver proves the refusal happens
# before driver discovery.
if GUST_NATIVE_BACKEND_DRIVER="$build_dir/deliberately-absent-driver" \
    ./gust --backend cranelift -o "$build_dir/native-program" "$source_fixture" \
      >"$build_dir/native.stdout" 2>"$build_dir/native.stderr"; then
  echo "Explicit Cranelift unexpectedly accepted the deferred composition fixture." >&2
  exit 1
fi
for token in \
  'decision=deferred capability=phase13_generic_source_to_mir' \
  'reason_code=deferred_p13_parameter_argument_target_dependent_abi' \
  'expected_failure_stage=before_driver_discovery' \
  'class=unsupported_native_capability' \
  'source-level route is not connected yet'
do
  rg -n -F "$token" "$build_dir/native.stdout" >/dev/null
done
test ! -e "$build_dir/native-program"
test ! -s "$build_dir/native.stderr"

echo "guard-cranelift-phase19-composition-parity: ok (MIR-to-C exit $expected_status; explicit Cranelift deferred without fallback, Level 2)"
