#!/usr/bin/env bash
set -euo pipefail

python3 scripts/phase21_opening.py validate

build_root="build/guards/phase21_opening_evidence"
rm -rf "$build_root"
mkdir -p "$build_root"

worker="build/gust-native-backend"
if [ ! -x "$worker" ]; then
  make "$worker"
fi
worker_abs="$PWD/$worker"

while IFS=$'\t' read -r witness_id source_fixture expected_exit
do
  case_root="$build_root/witness-$witness_id"
  mkdir -p "$case_root"
  ./gust --backend mir-to-c "$source_fixture" \
    >"$case_root/mir-to-c.c" 2>"$case_root/mir-to-c.compile.stderr"
  test ! -s "$case_root/mir-to-c.compile.stderr"
  cat src/runtime.c "$case_root/mir-to-c.c" >"$case_root/mir-to-c.final.c"
  "${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
    "$case_root/mir-to-c.final.c" -o "$case_root/mir-to-c-program"

  GUST_NATIVE_BACKEND_DRIVER="$worker_abs" \
    ./gust --backend cranelift -o "$case_root/native-program" \
      "$source_fixture" >"$case_root/native.compile.stdout" \
      2>"$case_root/native.compile.stderr"
  test ! -s "$case_root/native.compile.stdout"
  test ! -s "$case_root/native.compile.stderr"

  set +e
  "$case_root/mir-to-c-program" >"$case_root/mir-to-c.stdout" \
    2>"$case_root/mir-to-c.stderr"
  mir_status="$?"
  "$case_root/native-program" >"$case_root/native.stdout" \
    2>"$case_root/native.stderr"
  native_status="$?"
  set -e
  test "$mir_status" = "$expected_exit"
  test "$native_status" = "$expected_exit"
  cmp -s "$case_root/mir-to-c.stdout" "$case_root/native.stdout"
  cmp -s "$case_root/mir-to-c.stderr" "$case_root/native.stderr"
done < <(python3 scripts/phase21_opening.py witness-cases)

poison="$build_root/poison-driver"
poison_marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
set -euo pipefail
: >"${GUST_PHASE21_POISON_MARKER:?}"
exit 97
POISON
chmod +x "$poison"
poison_abs="$PWD/$poison"

while IFS=$'\t' read -r category source_fixture decision reason_code \
  diagnostic failure_stage
do
  case_root="$build_root/residue-$category"
  mkdir -p "$case_root"
  ./gust --backend mir-to-c "$source_fixture" \
    >"$case_root/mir-to-c.c" 2>"$case_root/mir-to-c.stderr"
  test ! -s "$case_root/mir-to-c.stderr"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE21_POISON_MARKER="$poison_marker" \
  GUST_NATIVE_BACKEND_DRIVER="$poison_abs" \
    ./gust --backend cranelift -o "$case_root/native" \
      "$source_fixture" >"$case_root/native.stdout" \
      2>"$case_root/native.stderr"
  residue_status="$?"
  set -e
  test "$residue_status" -ne 0
  test ! -e "$poison_marker"
  test ! -e "$case_root/native"
  rg -F "decision=$decision" "$case_root/native.stdout" >/dev/null
  rg -F "reason_code=$reason_code" "$case_root/native.stdout" >/dev/null
  rg -F "expected_failure_stage=$failure_stage" \
    "$case_root/native.stdout" >/dev/null
  case "$diagnostic" in
    stdout:*) rg -F "${diagnostic#stdout:}" "$case_root/native.stdout" >/dev/null ;;
    stderr:*) rg -F "${diagnostic#stderr:}" "$case_root/native.stderr" >/dev/null ;;
    *) echo "unknown Patch 21.1 diagnostic owner: $diagnostic" >&2; exit 1 ;;
  esac
done < <(python3 scripts/phase21_opening.py active-residue-cases)

full_root="$build_root/full-compiler"
mkdir -p "$full_root"
set +e
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_PHASE21_POISON_MARKER="$poison_marker" \
GUST_NATIVE_BACKEND_DRIVER="$poison_abs" \
  ./gust --backend cranelift -o "$full_root/native-compiler" \
    compiler/test_runner_entry.gst >"$full_root/stdout" \
    2>"$full_root/stderr"
full_status="$?"
set -e
test "$full_status" = 1
test ! -e "$poison_marker"
test ! -e "$full_root/native-compiler"
rg -F 'decision=source_or_type_failure' "$full_root/stdout" >/dev/null
rg -F 'capability=phase13_generic_source_to_mir' "$full_root/stdout" >/dev/null
rg -F 'reason_code=source_or_type_failure' "$full_root/stdout" >/dev/null
rg -F 'expected_failure_stage=before_driver_discovery' "$full_root/stdout" >/dev/null
rg -F 'source=compiler/test_runner_entry.gst line=238 column=1' \
  "$full_root/stdout" >/dev/null
rg -F 'class=canonical_mir_verification_error' "$full_root/stdout" >/dev/null
rg -F 'Native backend canonical MIR verification failed: unsupported top-level statement in module/import cohort' \
  "$full_root/stderr" >/dev/null

echo "✅ Phase 21 opening evidence passed: 2 executable query shapes, the active inherited residues, and 1 classified full-compiler baseline; completed successor migrations remain owned by their transition records"
