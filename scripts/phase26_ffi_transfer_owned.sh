#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_ffi_transfer_owned"
rm -rf "$build_root"
mkdir -p "$build_root/negatives"
test -x ./gust
test -f build/gust-native-backend
driver="$PWD/build/gust-native-backend"

cc -std=c11 -Wall -Wextra -Werror -c \
  tests/cranelift/phase26_transfer_owned_hosts.c -o "$build_root/hosts.o"
cat >"$build_root/cc-with-host" <<'CC'
#!/usr/bin/env bash
exec cc "$@" "$GUST_PHASE26_TRANSFER_HOST_OBJECT"
CC
chmod +x "$build_root/cc-with-host"
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  GUST_PHASE26_TRANSFER_HOST_OBJECT="$PWD/$build_root/hosts.o" \
  CC="$PWD/$build_root/cc-with-host" \
  ./gust --backend cranelift -o "$build_root/native" \
    compiler/phase26_ffi_transfer_owned_source.gst \
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
    'taken_int:11', 'released_int',
    'taken_int:12', 'released_int', '3',
    'taken_byte:7', 'released_byte', 'defer_marker',
    'counts:2:2:1:1',
]
assert lines == expected, (lines, expected)
PY

python3 - "$build_root/negatives" <<'PY'
from pathlib import Path
import sys

base = Path('compiler/phase26_ffi_transfer_owned_source.gst').read_text()
root = Path(sys.argv[1])
acquire = 'mut owner := host_owned_int(11);'
transfer = 'host_take_owned_int(owner);'
assert acquire in base and transfer in base
variants = {
    'unbound': base.replace(acquire + '\n        ' + transfer,
        'host_take_owned_int(host_owned_int(11));'),
    'discarded': base.replace(acquire + '\n        ' + transfer,
        'host_owned_int(11);'),
    'double_transfer': base.replace(transfer, transfer + '\n        ' + transfer, 1),
    'same_call_double': base.replace(
        'extern func host_owned_byte()',
        'extern func host_take_owned_pair(left: OwnedInt #[ffi(transfer_owned)], right: OwnedInt #[ffi(transfer_owned)]);\nextern func host_owned_byte()'
    ).replace(transfer, 'host_take_owned_pair(owner, owner);', 1),
    'use_after_transfer': base.replace(transfer,
        transfer + '\n        os.LogInt(*owner.raw);', 1),
    'alias_after_transfer': base.replace(transfer,
        'mut alias := owner;\n        ' + transfer + '\n        os.LogInt(*alias.raw);', 1),
    'overwrite': base.replace(transfer,
        'owner = host_owned_int(13);\n        ' + transfer, 1),
    'wrong_owner_type': base.replace('owner: OwnedInt #[ffi(transfer_owned)]',
        'owner: OwnedByte #[ffi(transfer_owned)]'),
    'missing_transfer_policy': base.replace('owner: OwnedInt #[ffi(transfer_owned)]',
        'owner: OwnedInt'),
    'raw_transfer_policy': base.replace('owner: OwnedInt #[ffi(transfer_owned)]',
        'owner: *int #[ffi(transfer_owned)]'),
    'retained_policy': base.replace('owner: OwnedInt #[ffi(transfer_owned)]',
        'owner: OwnedInt #[ffi(retain)]'),
    'callback_policy': base.replace('owner: OwnedInt #[ffi(transfer_owned)]',
        'owner: OwnedInt #[ffi(callback)]'),
    'bad_release': base.replace('unsafe { host_release_owned_int(owner.raw); }',
        'unsafe { os.LogInt(*owner.raw); }'),
    'bad_release_signature': base.replace('host_release_owned_int(raw: *int',
        'host_release_owned_int(raw: *byte'),
    'missing_acquisition': base.replace('OwnedInt #[ffi(owned_return)]', 'OwnedInt'),
    'forged_brand': base.replace(transfer,
        'mut ctx := os.Arena.New();\n        defer ctx.Free();\n        mut forged: Index[int, ctx] := owner.raw as Index[int, ctx];\n        ' + transfer, 1),
    'native_error_policy': base.replace('owner: OwnedInt #[ffi(transfer_owned)]',
        'owner: OwnedInt #[ffi(native_error)]'),
}
for name, source in variants.items():
    assert source != base, name
    (root / f'{name}.gst').write_text(source)
PY

poison="$build_root/poison-driver"
marker="$PWD/$build_root/driver-invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_TRANSFER_POISON_MARKER"
exit 91
POISON
chmod +x "$poison"
for case_name in unbound discarded double_transfer same_call_double use_after_transfer \
  alias_after_transfer overwrite wrong_owner_type missing_transfer_policy \
  raw_transfer_policy retained_policy callback_policy native_error_policy \
  bad_release bad_release_signature missing_acquisition forged_brand; do
  rm -f "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
    GUST_PHASE26_TRANSFER_POISON_MARKER="$marker" \
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
    unbound|wrong_owner_type|same_call_double) expected='[FFITransferOwnedAuthority]' ;;
    discarded) expected='[ResourceAcquisitionDiscarded]' ;;
    double_transfer|use_after_transfer) expected='[FFIOwnedUseAfterRelease]' ;;
    alias_after_transfer) expected='LinearResourceUseAfterMove' ;;
    overwrite) expected='[FFIOwnedOverwrite]' ;;
    missing_transfer_policy|missing_acquisition) expected='[FFIByValueAggregateUnsupported]' ;;
    raw_transfer_policy) expected='[FFIUnsupportedOwnershipPolicy]' ;;
    retained_policy) expected='[FFIByValueAggregateUnsupported]' ;;
    callback_policy|native_error_policy) expected='[FFICallbackNativeErrorUnsupported]' ;;
    bad_release|bad_release_signature) expected='[FFIReleaseAuthority]' ;;
    forged_brand) expected='Non-laundering violation' ;;
  esac
  rg -F "$expected" "$build_root/$case_name.stdout" >/dev/null
done

canonical="compiler/fixtures/native_backend_phase26_transfer_owned_minimal.mir"
"$driver" phase21-full-program-validate "$canonical" >"$build_root/canonical-positive.stdout"
"$driver" phase21-full-program-object "$canonical" "$build_root/canonical-positive.o" \
  >"$build_root/canonical-object.stdout"
test -s "$build_root/canonical-positive.o"

python3 - "$canonical" "$build_root/negatives" <<'PY'
from pathlib import Path
import sys

base = Path(sys.argv[1]).read_text()
root = Path(sys.argv[2])

def hx(value):
    return value.encode().hex()

def mutate_row(source, prefix, change):
    lines = source.splitlines()
    index = next(i for i, line in enumerate(lines) if line.startswith(prefix))
    fields = lines[index][len('function: '):].split('|')
    change(fields)
    lines[index] = 'function: ' + '|'.join(fields)
    return '\n'.join(lines) + '\n'

def transfer_change(change):
    return mutate_row(base, 'function: 4|', change)

def suffix_index(fields):
    return fields.index('ffi_policy.v1')

variants = {
    'missing_policy': transfer_change(lambda fields: fields.__delitem__(slice(suffix_index(fields), None))),
    'partial_policy': transfer_change(lambda fields: fields.__delitem__(slice(suffix_index(fields) + 2, None))),
    'unknown_tag': transfer_change(lambda fields: fields.__setitem__(suffix_index(fields), 'ffi_policy.v2')),
    'wrong_count': transfer_change(lambda fields: fields.__setitem__(suffix_index(fields) + 2, '2')),
    'oversized_count': transfer_change(lambda fields: fields.__setitem__(suffix_index(fields) + 2, str(2**64-1))),
    'borrow_policy': transfer_change(lambda fields: fields.__setitem__(suffix_index(fields) + 3, hx('borrow_read_call'))),
    'wrong_owner': transfer_change(lambda fields: fields.__setitem__(10, hx('Struct("SessionNode", None)'))),
    'raw_position': transfer_change(lambda fields: fields.__setitem__(10, hx('RawPointer(Int)'))),
    'missing_producer': mutate_row(base, 'function: 0|', lambda fields: fields.__setitem__(suffix_index(fields) + 1, hx('value'))),
    'wrong_release': mutate_row(base, 'function: 1|', lambda fields: fields.__setitem__(suffix_index(fields) + 3, hx('borrow_read_call'))),
    'wrong_target': base.replace(hx('x86_64-unknown-linux-gnu'), hx('aarch64-unknown-linux-gnu'), 1),
    'wrong_layout': base.replace('|1|0|43|1|726177|526177506f696e74657228496e7429',
                                 '|0|0|43|1|726177|526177506f696e74657228496e7429', 1),
}
for name, value in variants.items():
    assert value != base, name
    (root / f'canonical_{name}.mir').write_text(value)
PY

for case_name in missing_policy partial_policy unknown_tag wrong_count \
  oversized_count borrow_policy wrong_owner raw_position missing_producer \
  wrong_release wrong_target wrong_layout; do
  set +e
  "$driver" phase21-full-program-object \
    "$build_root/negatives/canonical_$case_name.mir" \
    "$build_root/canonical_$case_name.o" \
    >"$build_root/canonical_$case_name.stdout" \
    2>"$build_root/canonical_$case_name.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  test ! -e "$build_root/canonical_$case_name.o"
  rg -F 'gust Cranelift experiment failed:' \
    "$build_root/canonical_$case_name.stderr" >/dev/null
done

echo 'Phase26.1D by-value owner transfer, native release, and fail-closed policy evidence passed.'
