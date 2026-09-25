#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

build_dir="build/guards/phase19_composition"
source_fixture="compiler/phase19_cross_feature_composition_source.gst"
clone_fixture="compiler/phase16_non_string_clone_deferred_source.gst"
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

# Reference parameters now reach canonical full-program lowering. The native
# std_Clone runtime entry has a Str ABI, so both this composed Index clone and
# the small independent Index clone must defer before driver discovery. The
# frozen 91 exit above remains the oracle for the composition behaviour.
for fixture in "$source_fixture" "$clone_fixture"; do
  test -f "$fixture"
  case_dir="$build_dir/$(basename "$fixture" .gst)"
  mkdir -p "$case_dir"
  if GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
     GUST_NATIVE_BACKEND_DRIVER="$PWD/$case_dir/deliberately-absent-driver" \
      ./gust --backend cranelift -o "$case_dir/native-program" "$fixture" \
        >"$case_dir/native.stdout" 2>"$case_dir/native.stderr"; then
    echo "Explicit Cranelift unexpectedly accepted non-string Clone: $fixture" >&2
    exit 1
  fi
  for token in \
    'decision=deferred capability=phase13_generic_source_to_mir' \
    'reason_code=deferred_p14_full_program_non_string_clone' \
    'expected_failure_stage=before_driver_discovery' \
    'class=unsupported_native_capability' \
    'source-level route is not connected yet'
  do
    rg -n -F "$token" "$case_dir/native.stdout" >/dev/null
  done
  test ! -e "$case_dir/native-program"
  test ! -s "$case_dir/native.stderr"
  if find "$case_dir" -maxdepth 1 -type f \
      \( -name '*.c' -o -name '*.phase10.bundle' -o -name '*.phase10.request' \) \
      -print -quit | grep -q .; then
    echo "Non-string Clone left a C or transient MIR artifact: $fixture" >&2
    exit 1
  fi
done

echo "guard-cranelift-phase19-composition-parity: ok (frozen exit $expected_status; non-string Clone deferred without fallback, Level 2)"
