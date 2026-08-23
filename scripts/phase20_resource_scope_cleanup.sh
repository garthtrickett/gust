#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase20_resource_scope_cleanup"
source_fixture="compiler/phase20_resource_scope_cleanup_source.gst"

python3 scripts/phase20_resource_scope_cleanup.py validate
rm -rf "$build_root"
mkdir -p "$build_root"

./gust "$source_fixture" >"$build_root/default.c" 2>"$build_root/default.stderr"
./gust --backend mir-to-c "$source_fixture" >"$build_root/explicit.c" 2>"$build_root/explicit.stderr"
test ! -s "$build_root/default.stderr"
test ! -s "$build_root/explicit.stderr"
cmp -s "$build_root/default.c" "$build_root/explicit.c"

cat src/runtime.c "$build_root/default.c" >"$build_root/final.c"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  "$build_root/final.c" -o "$build_root/program"
"$build_root/program" >"$build_root/stdout" 2>"$build_root/stderr"
test ! -s "$build_root/stderr"
printf '2\n1\n4\n3\n5\n9\n6\n7\n8\n10\n' >"$build_root/expected.stdout"
cmp -s "$build_root/expected.stdout" "$build_root/stdout"

./gust --backend mir-to-c compiler/future/p20_issue106_unbound_directory_current.gst \
  >"$build_root/unbound-directory.c" 2>"$build_root/unbound-directory.stderr"
test ! -s "$build_root/unbound-directory.stderr"
rg -F 'if (opt_dir.Ok) { os_CloseDir(opt_dir.Val); }' \
  "$build_root/unbound-directory.c" >/dev/null

./gust --backend mir-to-c compiler/future/p20_issue106_bound_directory_current.gst \
  >"$build_root/bound-directory.c" 2>"$build_root/bound-directory.stderr"
test ! -s "$build_root/bound-directory.stderr"
rg -F 'os_CloseDir(d);' "$build_root/bound-directory.c" >/dev/null

./gust --backend mir-to-c compiler/phase20_resource_acquisition_callee_drop_invalid.gst \
  >"$build_root/callee.c" 2>"$build_root/callee.stderr"
test ! -s "$build_root/callee.stderr"
rg -F 'phase20_resource_enforcement_module__destroy_handle(handle);' \
  "$build_root/callee.c" >/dev/null

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

echo "✅ Phase 20 generic resource scope cleanup parity passed"
