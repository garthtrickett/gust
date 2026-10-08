#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_ffi_native_error_status"
rm -rf "$build_root"
mkdir -p "$build_root"
test -x ./gust
test -f build/gust-native-backend
driver="$PWD/build/gust-native-backend"

cc -std=c11 -Wall -Wextra -Werror -c \
  tests/cranelift/phase26_native_error_status_hosts.c -o "$build_root/hosts.o"
cat >"$build_root/cc-with-host" <<'CC'
#!/usr/bin/env bash
exec cc "$@" "$GUST_PHASE26_STATUS_HOST_OBJECT"
CC
chmod +x "$build_root/cc-with-host"
cat >"$build_root/capture-driver" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == phase10-backend-request-compile ]]; then
  cp "${2%.request}.bundle" "$GUST_PHASE26_STATUS_CAPTURE_BUNDLE"
fi
exec "$GUST_PHASE26_STATUS_REAL_DRIVER" "$@"
SH
chmod +x "$build_root/capture-driver"
ln -s "$PWD/build/gust-runtime-package.a" "$build_root/gust-runtime-package.a"
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$build_root/capture-driver" \
  GUST_PHASE26_STATUS_REAL_DRIVER="$driver" \
  GUST_PHASE26_STATUS_CAPTURE_BUNDLE="$PWD/$build_root/canonical.bundle" \
  GUST_PHASE26_STATUS_HOST_OBJECT="$PWD/$build_root/hosts.o" \
  CC="$PWD/$build_root/cc-with-host" \
  ./gust --backend cranelift -o "$build_root/native" \
    compiler/phase26_ffi_native_error_status_source.gst \
    >"$build_root/positive.stdout" 2>"$build_root/positive.stderr"
test ! -s "$build_root/positive.stdout"
test ! -s "$build_root/positive.stderr"
"$build_root/native" >"$build_root/runtime.stdout" 2>"$build_root/runtime.stderr"
test ! -s "$build_root/runtime.stderr"
python3 - "$build_root/runtime.stdout" <<'PY'
from pathlib import Path
import sys

actual = Path(sys.argv[1]).read_text().splitlines()
expected = ['0', '17', '-23', '2147483647', '-2147483648',
            '0', '31', '-41', '2147483647', '-2147483648',
            '-2147483648']
assert actual == expected, (actual, expected)
PY
echo 'Phase26 native-error status C ABI preserved zero, signed errors, and both Int extrema.'
mkdir -p "$build_root/negatives"
python3 - "$build_root/negatives" <<'PY'
from pathlib import Path
import re
import sys

base = Path('compiler/phase26_ffi_native_error_status_source.gst').read_text()
root = Path(sys.argv[1])
declaration = 'host_status_alpha(selector: int #[ffi(value)]) int #[ffi(native_error)]'
variants = {
    'result_byte': base.replace(declaration,
        'host_status_alpha(selector: int #[ffi(value)]) byte #[ffi(native_error)]', 1),
    'result_pointer': base.replace(declaration,
        'host_status_alpha(selector: int #[ffi(value)]) *int #[ffi(native_error)]', 1),
    'parameter_annotation': base.replace('selector: int #[ffi(value)]',
        'selector: int #[ffi(native_error)]', 1),
    'mixed_callback': base.replace(declaration,
        'host_status_alpha(selector: Callback[int, int] #[ffi(callback)]) int #[ffi(native_error)]', 1),
    'unsupported_borrow_shape': re.sub(r'host_status_alpha\([0-4]\)', 'host_status_alpha("x")',
        base.replace(declaration, 'host_status_alpha(selector: str #[ffi(borrow_read_call)]) int #[ffi(native_error)]', 1)),
    'wrong_result_policy': base.replace('int #[ffi(native_error)]',
        'int #[ffi(raw_untrusted)]', 1),
    'outside_unsafe': base.replace('    unsafe {\n', '', 1).replace('    }\n    return 0;',
        '    return 0;', 1),
}
for name, source in variants.items():
    assert source != base, name
    (root / f'{name}.gst').write_text(source)
PY
cat >"$build_root/poison-driver" <<'SH'
#!/usr/bin/env bash
touch "$GUST_PHASE26_STATUS_POISON_MARKER"
exit 97
SH
chmod +x "$build_root/poison-driver"
for source in "$build_root"/negatives/*.gst; do
  name="$(basename "${source%.gst}")"
  marker="$build_root/negatives/$name.driver"
  output="$build_root/negatives/$name.native"
  if GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
      GUST_NATIVE_BACKEND_DRIVER="$PWD/$build_root/poison-driver" \
      GUST_PHASE26_STATUS_POISON_MARKER="$PWD/$marker" \
      ./gust --backend cranelift -o "$output" "$source" \
      >"$build_root/negatives/$name.stdout" \
      2>"$build_root/negatives/$name.stderr"; then
    echo "native-error source negative unexpectedly compiled: $name" >&2
    exit 1
  fi
  test ! -e "$marker"
  test ! -e "$output"
done
python3 - "$build_root/negatives" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
expected = {
    'result_byte': '[FFINativeErrorStatus]',
    'result_pointer': '[FFINativeErrorStatus]',
    'parameter_annotation': '[FFICallbackNativeErrorUnsupported]',
    'mixed_callback': '[FFINativeErrorStatus]',
    'unsupported_borrow_shape': 'reason_code=deferred_p13_parameter_argument_target_dependent_abi',
    'wrong_result_policy': '[FFIValuePolicy]',
    'outside_unsafe': "Direct external/native function calls require an explicit 'unsafe' block",
}
for name, marker in expected.items():
    actual = (root / f'{name}.stdout').read_text()
    assert marker in actual, (name, actual)
    if name == 'unsupported_borrow_shape':
        assert 'expected_failure_stage=before_driver_discovery' in actual, (name, actual)
    else:
        assert 'TypeError' in actual or 'reason_code=source_or_type_failure' in actual, (name, actual)
PY
echo 'Phase26 native-error source negatives rejected before driver discovery.'

python3 - "$build_root/canonical.bundle" "$build_root" <<'PY'
from pathlib import Path
import sys

bundle = Path(sys.argv[1]).read_text()
root = Path(sys.argv[2])
begin = 'module_0_canonical_mir_begin\n'
end = 'module_0_canonical_mir_end\n'
assert bundle.count(begin) == bundle.count(end) == 1
canonical = bundle.split(begin, 1)[1].split(end, 1)[0]
assert canonical.startswith('format: gust.compiler_executable_mir.v1\n')
assert canonical.endswith('\n')
(root / 'canonical-positive.mir').write_text(canonical)
lines = canonical.splitlines()
calls = [(i, row.split('|')) for i, row in enumerate(lines)
         if row.startswith('node: ') and row.split('|')[6] == '7']
assert len(calls) == 11, calls
zero_arg = [(i, row) for i, row in calls if row[11] == '1']
assert len(zero_arg) == 1
zero_end = 12 + int(zero_arg[0][1][11])
assert zero_arg[0][1][zero_end] == 'native_error_status.v1'
assert zero_arg[0][1][zero_end + 3] == '1'
assert zero_arg[0][1][zero_end + 4] == '0'
call_index, call = next((i, row) for i, row in calls if row[11] == '2')
child_end = 12 + int(call[11])
assert call[child_end] == 'native_error_status.v1'
function_index = next(i for i, row in enumerate(lines)
                      if row.startswith('function: ') and
                      bytes.fromhex(row.split('|')[2]).decode() == 'host_status_alpha')
unsafe_index = next(i for i, row in enumerate(lines)
                    if row.startswith('node: ') and
                    bytes.fromhex(row.split('|')[1]).decode() == 'UnsafeScope')

def change_row(index, change):
    changed = lines.copy()
    fields = changed[index].split('|')
    change(fields)
    changed[index] = '|'.join(fields)
    return '\n'.join(changed) + '\n'

def set_field(index, value):
    return lambda fields: fields.__setitem__(index, value)

def truncate(fields):
    del fields[child_end:]

def legacy_without_plan(fields):
    fields[6] = '0'
    del fields[child_end:]

def forge_result_policy(fields):
    marker = fields.index('ffi_policy.v1')
    fields[marker + 1] = '76616c7565'

variants = {
    'missing_plan': change_row(call_index, truncate),
    'unknown_version': change_row(call_index, set_field(child_end, 'native_error_status.v2')),
    'wrong_target': change_row(call_index, set_field(child_end + 1, '666f72676564')),
    'wrong_convention': change_row(call_index, set_field(child_end + 2, '666f72676564')),
    'wrong_count': change_row(call_index, set_field(child_end + 3, '2')),
    'wrong_position': change_row(call_index, set_field(child_end + 4, '0')),
    'wrong_zero_arg_position': change_row(zero_arg[0][0], set_field(zero_end + 4, '1')),
    'wrong_direction': change_row(call_index, set_field(child_end + 5, '666f72676564')),
    'wrong_type': change_row(call_index, set_field(child_end + 6, '42797465')),
    'wrong_size': change_row(call_index, set_field(child_end + 7, '8')),
    'wrong_align': change_row(call_index, set_field(child_end + 8, '8')),
    'wrong_provenance': change_row(call_index, set_field(child_end + 9, '666f72676564')),
    'wrong_callee': change_row(call_index, set_field(3, '666f72676564')),
    'wrong_resolved_extern': change_row(call_index, set_field(4, '666f72676564')),
    'wrong_result_policy': change_row(function_index, forge_result_policy),
    'unsafe_scope_removed': change_row(unsafe_index, set_field(1, '426c6f636b')),
    'legacy_without_plan': change_row(call_index, legacy_without_plan),
}
for name, mutated in variants.items():
    (root / 'negatives' / f'canonical_{name}.mir').write_text(mutated)
PY
"$driver" phase21-full-program-validate "$build_root/canonical-positive.mir" \
  >"$build_root/canonical-positive.stdout"
"$driver" phase21-full-program-object "$build_root/canonical-positive.mir" \
  "$build_root/canonical-positive.o" >"$build_root/canonical-object.stdout"
test -s "$build_root/canonical-positive.o"
for source in "$build_root"/negatives/canonical_*.mir; do
  name="$(basename "${source%.mir}")"
  output="$build_root/negatives/$name.o"
  if "$driver" phase21-full-program-object "$source" "$output" \
      >"$build_root/negatives/$name.stdout" \
      2>"$build_root/negatives/$name.stderr"; then
    echo "native-error canonical poison unexpectedly emitted: $name" >&2
    exit 1
  fi
  test ! -e "$output"
done
echo 'Phase26 native-error tagged-plan poison rejected before object emission.'
