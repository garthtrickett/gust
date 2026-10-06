#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_ffi_owned_return"
rm -rf "$build_root"
mkdir -p "$build_root/negatives"
test -x ./gust
test -f build/gust-native-backend
driver="$PWD/build/gust-native-backend"

# The two hosts use actual C by-value one-pointer struct signatures. The CC
# wrapper adds only the fixture object to the selected native link step.
cc -std=c11 -Wall -Wextra -Werror -c \
  tests/cranelift/phase26_owned_return_hosts.c -o "$build_root/hosts.o"
cat >"$build_root/cc-with-host" <<'CC'
#!/usr/bin/env bash
exec cc "$@" "$GUST_PHASE26_OWNED_HOST_OBJECT"
CC
chmod +x "$build_root/cc-with-host"
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  GUST_PHASE26_OWNED_HOST_OBJECT="$PWD/$build_root/hosts.o" \
  CC="$PWD/$build_root/cc-with-host" \
  ./gust --backend cranelift -o "$build_root/native" \
    compiler/phase26_ffi_owned_return_source.gst \
    >"$build_root/positive.stdout" 2>"$build_root/positive.stderr"
test ! -s "$build_root/positive.stdout"
test ! -s "$build_root/positive.stderr"
"$build_root/native" >"$build_root/runtime.stdout" 2>"$build_root/runtime.stderr"
test ! -s "$build_root/runtime.stderr"
python3 - "$build_root/runtime.stdout" <<'PY'
from pathlib import Path
import sys

lines = Path(sys.argv[1]).read_text().splitlines()
expected = [
    '41', '7', 'released_byte', 'released_int',
    '42', 'released_int', '12',
    'released_byte', '13',
    '43', 'defer_marker', 'released_int',
    '44', 'released_int',
]
assert lines == expected, (lines, expected)
PY

# Every unsupported ownership route must fail before driver discovery.
python3 - "$build_root/negatives" <<'PY'
from pathlib import Path
import sys

base = Path('compiler/phase26_ffi_owned_return_probe_source.gst').read_text()
root = Path(sys.argv[1])
acquire = 'mut owner := host_owned_int(1);'
assert acquire in base
variants = {
    'discarded': base.replace(acquire, 'host_owned_int(1);'),
    'overwritten': base.replace(acquire, acquire + '\n        owner = host_owned_int(2);'),
    'alias_use_after_move': base.replace(acquire, acquire + '\n        mut alias := owner;\n        os.LogInt(*owner.raw);'),
    'direct_release': base.replace(acquire, acquire + '\n        host_release_owned_int(owner.raw);'),
    'duplicate_release': base.replace(acquire, acquire + '\n        release_owned_int(owner);\n        release_owned_int(owner);'),
    'use_after_release': base.replace(acquire, acquire + '\n        release_owned_int(owner);\n        os.LogInt(*owner.raw);'),
    'forged_brand': base.replace(acquire, acquire + '\n        mut ctx := os.Arena.New();\n        defer ctx.Free();\n        mut forged: Index[int, ctx] := owner.raw as Index[int, ctx];'),
    'wrong_release_type': base.replace('host_release_owned_int(raw: *int', 'host_release_owned_int(raw: *byte'),
    'missing_release': base.replace('unsafe { host_release_owned_int(owner.raw); }', 'unsafe { os.LogInt(*owner.raw); }'),
    'wrong_destructor': base.replace('#[destructor(release_owned_int)]', '#[destructor(release_owned_wrong)]'),
    'missing_policy': base.replace('OwnedInt #[ffi(owned_return)]', 'OwnedInt'),
    'unsupported_retained': base.replace('OwnedInt #[ffi(owned_return)]', 'OwnedInt #[ffi(retained)]'),
}
for name, source in variants.items():
    assert source != base, name
    (root / f'{name}.gst').write_text(source)
PY

poison="$build_root/poison-driver"
marker="$PWD/$build_root/driver-invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_OWNED_POISON_MARKER"
exit 91
POISON
chmod +x "$poison"
for case_name in discarded overwritten alias_use_after_move direct_release \
  duplicate_release use_after_release forged_brand wrong_release_type \
  missing_release wrong_destructor missing_policy unsupported_retained; do
  rm -f "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
    GUST_PHASE26_OWNED_POISON_MARKER="$marker" \
    GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$build_root/$case_name" \
      "$build_root/negatives/$case_name.gst" \
      >"$build_root/$case_name.stdout" 2>"$build_root/$case_name.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  test ! -e "$marker"
  test ! -e "$build_root/$case_name"
  test ! -s "$build_root/$case_name.stderr"
  case "$case_name" in
    discarded) expected='[ResourceAcquisitionDiscarded]' ;;
    overwritten) expected='[FFIOwnedOverwrite]' ;;
    alias_use_after_move) expected='LinearResourceUseAfterMove' ;;
    direct_release|wrong_release_type|missing_release) expected='[FFIReleaseAuthority]' ;;
    duplicate_release|use_after_release) expected='[FFIOwnedUseAfterRelease]' ;;
    forged_brand) expected='Non-laundering violation' ;;
    wrong_destructor) expected='[ResourceDestructorMissing]' ;;
    missing_policy|unsupported_retained) expected='[FFIByValueAggregateUnsupported]' ;;
  esac
  rg -F "$expected" "$build_root/$case_name.stdout" >/dev/null
done

echo 'Phase26.1D owned native return, exactly-once release, and fail-closed policy evidence passed.'
