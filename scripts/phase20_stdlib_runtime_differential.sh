#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase20_stdlib_runtime_differential"
python3 scripts/phase20_stdlib_runtime_differential.py validate
rm -rf "$build_root"
mkdir -p "$build_root"

# The selected approved-scalar-import component is the real multi-file
# whole-program case owned by Patch 20.12. Re-run that observable contract.
just guard-cranelift-phase20-whole-program-corpus-parity

poison="$build_root/poison-driver"
poison_marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"$GUST_P20_COMPONENT_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"
poison_abs="$(cd "$(dirname "$poison")" && pwd)/$(basename "$poison")"

while IFS=$'\t' read -r category source_fixture decision reason_code owner destination
do
  case_dir="$build_root/$category"
  mkdir -p "$case_dir"

  ./gust --backend mir-to-c "$source_fixture" \
    >"$case_dir/mir-to-c.c" 2>"$case_dir/mir-to-c.stderr"
  test ! -s "$case_dir/mir-to-c.stderr"

  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_P20_COMPONENT_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_abs" \
    ./gust --backend cranelift -o "$case_dir/native-program" "$source_fixture" \
      >"$case_dir/native.stdout" 2>"$case_dir/native.stderr"
  native_status="$?"
  set -e
  test "$native_status" -ne 0
  test ! -e "$poison_marker"
  test ! -e "$case_dir/native-program"
  rg -F "decision=$decision" "$case_dir/native.stdout" >/dev/null
  rg -F "reason_code=$reason_code" "$case_dir/native.stdout" >/dev/null
  rg -F 'expected_failure_stage=before_driver_discovery' \
    "$case_dir/native.stdout" >/dev/null
  test -n "$owner"
  test "$destination" = 20.16
  echo "✅ Patch 20.13 explicit exclusion passed: $category"
done < <(python3 scripts/phase20_stdlib_runtime_differential.py exclusion-cases)

echo "✅ Phase 20 stdlib/runtime selection and exclusion differential passed"
