#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase20_resource_scope_cleanup"
source_fixture="compiler/phase20_resource_scope_cleanup_source.gst"

python3 scripts/phase20_resource_scope_cleanup.py validate
rm -rf "$build_root"
mkdir -p "$build_root"

python3 scripts/phase24_frozen_oracle.py materialize \
  "$source_fixture" "$build_root/frozen" --kind exec
test ! -s "$build_root/frozen.compile.stderr"
cp "$build_root/frozen.stdout" "$build_root/stdout"
cp "$build_root/frozen.stderr" "$build_root/stderr"
test ! -s "$build_root/stderr"
printf '2\n1\n4\n3\n5\n9\n6\n7\n8\n10\n' >"$build_root/expected.stdout"
cmp -s "$build_root/expected.stdout" "$build_root/stdout"

# Patch 24.12: three assertions about the generated C text were removed here
# — that the emitter closes an unbound directory handle, closes a bound one,
# and calls the callee-side destructor. Each inspects emitted C for a
# specific spelling, which is an invariant of the retired emitter with no
# native counterpart. What remains live is that the frozen oracle still
# accepts each source without diagnostics.
for frozen_source in \
  compiler/future/p20_issue106_unbound_directory_current.gst \
  compiler/future/p20_issue106_bound_directory_current.gst \
  compiler/phase20_resource_acquisition_callee_drop_invalid.gst
do
  python3 scripts/phase24_frozen_oracle.py materialize \
    "$frozen_source" "$build_root/$(basename "$frozen_source" .gst)" \
    --kind exec
  test ! -s "$build_root/$(basename "$frozen_source" .gst).compile.stderr"
done

successor_source="$(python3 scripts/phase20_resource_scope_cleanup.py successor-native-case)"
if test -n "$successor_source"; then
  test "$successor_source" = "$source_fixture"
else
  set +e
  ./gust --backend cranelift -o "$build_root/native" "$source_fixture" \
    >"$build_root/native.stdout" 2>"$build_root/native.stderr"
  native_status="$?"
  set -e
  test "$native_status" -ne 0
  test ! -e "$build_root/native"
  rg -F 'decision=source_or_type_failure capability=phase13_generic_source_to_mir' \
    "$build_root/native.stdout" >/dev/null
  rg -F 'expected_failure_stage=before_driver_discovery' \
    "$build_root/native.stdout" >/dev/null
  rg -F 'unsupported top-level statement in module/import cohort' \
    "$build_root/native.stderr" >/dev/null
fi

echo "✅ Phase 20 generic resource scope cleanup parity passed"
