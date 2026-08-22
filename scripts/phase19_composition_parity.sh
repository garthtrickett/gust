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

./gust "$source_fixture" >"$build_dir/default.c" 2>"$build_dir/default.stderr"
./gust --backend mir-to-c "$source_fixture" >"$build_dir/explicit.c" 2>"$build_dir/explicit.stderr"
test ! -s "$build_dir/default.stderr"
test ! -s "$build_dir/explicit.stderr"
cmp -s "$build_dir/default.c" "$build_dir/explicit.c"

# The resource ABI is runtime-owned. A caller's arena spelling must not leak
# into the generated C type or helper names.
if rg -n -e 'os_Dir_origin' -e 'os_DirEntry_origin' \
     -e 'LookupResult_os_Dir_origin' -e 'LookupResult_os_DirEntry_origin' \
     "$build_dir/explicit.c" >/dev/null; then
  echo "A source arena spelling leaked into the canonical native resource ABI." >&2
  exit 1
fi

cat src/runtime.c "$build_dir/explicit.c" >"$build_dir/final.c"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  "$build_dir/final.c" -o "$build_dir/mir-to-c-program"
if "$build_dir/mir-to-c-program" >"$build_dir/runtime.stdout" 2>"$build_dir/runtime.stderr"; then
  actual_status=0
else
  actual_status=$?
fi
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
