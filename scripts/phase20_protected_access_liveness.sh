#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase20_protected_access_liveness"
positive="compiler/phase20_protected_access_source.gst"
canonical_mir="compiler/fixtures/native_backend_phase20_protected_access_liveness.mir"
probe="compiler/fixtures/phase20_protected_access_lifecycle_probe.c"
worker="build/gust-native-backend"

python3 scripts/phase20_protected_access_liveness.py validate
rm -rf "$build_root"
mkdir -p "$build_root"

./gust "$positive" >"$build_root/default.c" 2>"$build_root/default.compiler.stderr"
./gust --backend mir-to-c "$positive" \
  >"$build_root/explicit.c" 2>"$build_root/explicit.compiler.stderr"
test ! -s "$build_root/default.compiler.stderr"
test ! -s "$build_root/explicit.compiler.stderr"
cmp -s "$build_root/default.c" "$build_root/explicit.c"

cat src/runtime.c "$build_root/default.c" >"$build_root/final.c"
"${CC:-cc}" ${CFLAGS:--O0 -w -pthread} -Isrc \
  "$build_root/final.c" -o "$build_root/mir-to-c-program"
set +e
"$build_root/mir-to-c-program" \
  >"$build_root/mir-to-c.stdout" 2>"$build_root/mir-to-c.stderr"
mir_status="$?"
set -e
test "$mir_status" = 72
printf '1\n2\n9\n3\n4\n13\n5\n6\n0\n21\n22\n23\n24\n72\n' \
  >"$build_root/expected.stdout"
rg -v '^os_OpenDir:' "$build_root/mir-to-c.stdout" \
  >"$build_root/mir-to-c.filtered.stdout"
cmp -s "$build_root/expected.stdout" "$build_root/mir-to-c.filtered.stdout"
test "$(rg -c -F 'os_OpenDir: opendir("/phase20-protected-access-missing") failed!' "$build_root/mir-to-c.stdout")" = 2
test ! -s "$build_root/mir-to-c.stderr"

while IFS=$'\t' read -r fixture diagnostic; do
  name="$(basename "$fixture" .gst)"
  set +e
  ./gust --backend mir-to-c "$fixture" \
    >"$build_root/$name.stdout" 2>"$build_root/$name.stderr"
  status="$?"
  set -e
  test "$status" -ne 0
  rg -F "[$diagnostic]" "$build_root/$name.stdout" "$build_root/$name.stderr" >/dev/null
done <<'EOF'
compiler/phase20_protected_access_after_close_invalid.gst	ProtectedAccessNotLive
compiler/phase20_protected_access_return_invalid.gst	ProtectedAccessEscape
compiler/phase20_protected_access_storage_invalid.gst	ProtectedAccessEscape
compiler/phase20_protected_access_argument_invalid.gst	ProtectedAccessEscape
compiler/phase20_protected_access_ambiguous_invalid.gst	ProtectedAccessAmbiguousRoot
compiler/phase20_mutex_lock_safe_invalid.gst	UnsafeMutexPrimitive
compiler/phase20_mutex_unlock_safe_invalid.gst	UnsafeMutexPrimitive
EOF

if [ ! -x "$worker" ]; then
  make build/gust-native-backend
fi
"$worker" compiler-mir-validate-fixture "$canonical_mir" \
  >"$build_root/native.validate.stdout" 2>"$build_root/native.validate.stderr"
"$worker" compiler-mir-ingestion-object "$canonical_mir" "$build_root/native.o" \
  >"$build_root/native.compile.stdout" 2>"$build_root/native.compile.stderr"
"${CC:-cc}" -pthread "$build_root/native.o" "$probe" -o "$build_root/native-program"
set +e
"$build_root/native-program" >"$build_root/native.stdout" 2>"$build_root/native.stderr"
native_status="$?"
set -e
test "$native_status" = "$mir_status"
test ! -s "$build_root/native.stdout"
test ! -s "$build_root/native.stderr"

echo "✅ Phase 20 protected-access liveness parity passed"
