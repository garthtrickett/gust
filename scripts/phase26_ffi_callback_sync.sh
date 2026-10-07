#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_ffi_callback_sync"
rm -rf "$build_root"
mkdir -p "$build_root"
test -x ./gust
test -f build/gust-native-backend
driver="$PWD/build/gust-native-backend"

cc -std=c11 -Wall -Wextra -Werror -c \
  tests/cranelift/phase26_callback_sync_hosts.c -o "$build_root/hosts.o"
cat >"$build_root/cc-with-host" <<'CC'
#!/usr/bin/env bash
exec cc "$@" "$GUST_PHASE26_CALLBACK_HOST_OBJECT"
CC
chmod +x "$build_root/cc-with-host"
cat >"$build_root/capture-driver" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == phase10-backend-request-compile ]]; then
  request="$2"
  cp "${request%.request}.bundle" "$GUST_PHASE26_CALLBACK_CAPTURE_BUNDLE"
fi
exec "$GUST_PHASE26_CALLBACK_REAL_DRIVER" "$@"
SH
chmod +x "$build_root/capture-driver"
ln -s "$PWD/build/gust-runtime-package.a" "$build_root/gust-runtime-package.a"
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$build_root/capture-driver" \
  GUST_PHASE26_CALLBACK_REAL_DRIVER="$driver" \
  GUST_PHASE26_CALLBACK_CAPTURE_BUNDLE="$PWD/$build_root/canonical.bundle" \
  GUST_PHASE26_CALLBACK_HOST_OBJECT="$PWD/$build_root/hosts.o" \
  CC="$PWD/$build_root/cc-with-host" \
  ./gust --backend cranelift -o "$build_root/native" \
    compiler/phase26_ffi_callback_sync_source.gst \
    >"$build_root/positive.stdout" 2>"$build_root/positive.stderr"
test ! -s "$build_root/positive.stdout"
test ! -s "$build_root/positive.stderr"
"$build_root/native" >"$build_root/runtime.stdout" 2>"$build_root/runtime.stderr"
test ! -s "$build_root/runtime.stderr"
python3 - "$build_root/runtime.stdout" <<'PY'
from pathlib import Path
import sys

actual = Path(sys.argv[1]).read_text().splitlines()
expected = ['callback_alpha_host', '14', 'callback_beta_host', '30',
            'callback_alpha_host', '14']
assert actual == expected, (actual, expected)
PY

echo 'Phase26 synchronous callback C ABI and two independent hosts passed.'

mkdir -p "$build_root/negatives"
python3 - "$build_root/negatives" <<'PY'
from pathlib import Path
import sys

base = Path('compiler/phase26_ffi_callback_sync_source.gst').read_text()
root = Path(sys.argv[1])
(root.parent / 'callback_collision_module.gst').write_text(
    'type Callback[T, U] struct { marker: int }\n')
formal = 'callback: Callback[int, int] #[ffi(callback)]'
call = 'host_apply_alpha(callback_add_three, 4)'
variants = {
    'wrong_formal': base.replace(formal,
        'callback: Callback[int, byte] #[ffi(callback)]', 1),
    'missing_policy': base.replace(formal,
        'callback: Callback[int, int]', 1),
    'user_type_collision': 'type Callback[T, U] struct { marker: int }\n' + base,
    'late_type_collision': base + '\ntype Callback[T, U] struct { marker: int }\n',
    'imported_type_collision':
        'import "../callback_collision_module.gst" as collision;\n' +
        base.replace(formal,
            'callback: collision.Callback[int, int] #[ffi(callback)]', 1),
    'general_parameter': base +
        '\nfunc general_callback(value: Callback[int, int]) int { return 0; }\n',
    'general_return': base +
        '\nfunc general_result() Callback[int, int] { return callback_add_three; }\n',
    'function_alias': base.replace('func main() int {',
        'func main() int {\n    mut alias := callback_add_three;', 1)
        .replace(call, 'host_apply_alpha(alias, 4)', 1),
    'call_result': base.replace(call,
        'host_apply_alpha(callback_add_three(1), 4)', 1),
    'wrong_function_signature': base.replace('func main() int {',
        'func wrong_callback(value: byte) int { return value as int; }\n'
        'func main() int {', 1)
        .replace(call, 'host_apply_alpha(wrong_callback, 4)', 1),
    'capture_attempt': base.replace('func main() int {',
        'func callback_capture(value: int) int { return value + captured; }\n'
        'func main() int {\n    mut captured := 3;', 1)
        .replace(call, 'host_apply_alpha(callback_capture, 4)', 1),
    'local_declaration': base.replace('func main() int {',
        'func main() int {\n'
        '    func local_callback(value: int) int { return value + 1; }', 1),
    'outside_unsafe': base.replace(
        'func early_callback() int {\n    unsafe {\n'
        '        return host_apply_alpha(callback_add_three, 4);\n'
        '    }\n}',
        'func early_callback() int {\n'
        '    return host_apply_alpha(callback_add_three, 4);\n}', 1),
    'retained_callback': base.replace(formal,
        'callback: Callback[int, int] #[ffi(retain)]', 1),
    'native_error_callback': base.replace(formal,
        'callback: Callback[int, int] #[ffi(native_error)]', 1),
}
for name, source in variants.items():
    assert source != base, name
    (root / f'{name}.gst').write_text(source)
PY
cat >"$build_root/poison-driver" <<'SH'
#!/usr/bin/env bash
touch "$GUST_PHASE26_CALLBACK_POISON_MARKER"
exit 97
SH
chmod +x "$build_root/poison-driver"
for source in "$build_root"/negatives/*.gst; do
  name="$(basename "${source%.gst}")"
  marker="$build_root/negatives/$name.driver"
  output="$build_root/negatives/$name.native"
  if GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
      GUST_NATIVE_BACKEND_DRIVER="$PWD/$build_root/poison-driver" \
      GUST_PHASE26_CALLBACK_POISON_MARKER="$PWD/$marker" \
      ./gust --backend cranelift -o "$output" "$source" \
      >"$build_root/negatives/$name.stdout" \
      2>"$build_root/negatives/$name.stderr"; then
    echo "callback negative unexpectedly compiled: $name" >&2
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
    'wrong_formal': '[FFICallbackSignature]',
    'user_type_collision': '[FFICallbackSignature]',
    'late_type_collision': '[FFICallbackSignature]',
    'imported_type_collision': '[FFICallbackSignature]',
    'general_parameter': 'Generic template not found: Callback',
    'general_return': 'Generic template not found: Callback',
    'function_alias': '[FFICallbackSignature]',
    'call_result': '[FFICallbackSignature]',
    'wrong_function_signature': '[FFICallbackSignature]',
    'capture_attempt': '[TypeMismatch]',
    'local_declaration': 'decision=source_or_type_failure',
    'outside_unsafe': "Direct external/native function calls require an explicit 'unsafe' block",
}
for name, marker in expected.items():
    actual = (root / f'{name}.stdout').read_text()
    assert marker in actual, (name, actual)
PY
echo 'Phase26 callback source negatives rejected before driver discovery.'

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

def row_index(kind):
    prefix = f'{kind}: '
    return next(i for i, line in enumerate(lines) if line.startswith(prefix))

call_index = next(i for i, line in enumerate(lines)
                  if line.startswith('node: ') and line.split('|')[6] == '6')
call = lines[call_index].split('|')
child_end = 12 + int(call[11])
assert call[child_end] == 'callback_call.v1'
address_index = next(i for i, line in enumerate(lines)
                     if line.startswith('node: ') and
                     bytes.fromhex(line.split('|')[1]).decode() == 'FunctionAddress')
address = lines[address_index].split('|')
address_id = address[0].split(': ', 1)[1]
alias_index = next(i for i, line in enumerate(lines)
                   if line.startswith('node: ') and
                   bytes.fromhex(line.split('|')[1]).decode() == 'Call' and
                   line.split('|')[6] == '0' and line.split('|')[11] == '2')
function_index = next(i for i, line in enumerate(lines)
                      if line.startswith('function: ') and
                      bytes.fromhex(line.split('|')[2]).decode() == 'host_apply_alpha')
function = lines[function_index].split('|')
assert '63616c6c6261636b' in function

def change_row(index, action):
    changed = lines.copy()
    fields = changed[index].split('|')
    action(fields)
    changed[index] = '|'.join(fields)
    return '\n'.join(changed) + '\n'

def set_field(index, value):
    return lambda fields: fields.__setitem__(index, value)

def truncate(fields):
    del fields[child_end:]

def wrong_count(fields):
    fields[child_end + 3] = '2'

def forge_policy(fields):
    marker = fields.index('ffi_policy.v1')
    assert fields[marker + 3] == '63616c6c6261636b'
    fields[marker + 3] = '76616c7565'

def legacy_without_suffix(fields):
    fields[6] = '0'
    del fields[child_end:]

variants = {
    'unknown_version': change_row(call_index, set_field(child_end, 'callback_call.v2')),
    'missing_plan': change_row(call_index, truncate),
    'wrong_target': change_row(call_index, set_field(child_end + 1, '666f72676564')),
    'wrong_scope': change_row(call_index, set_field(child_end + 2, '666f72676564')),
    'wrong_count': change_row(call_index, wrong_count),
    'wrong_position': change_row(call_index, set_field(child_end + 4, '1')),
    'wrong_layout_size': change_row(call_index, set_field(child_end + 7, '4')),
    'wrong_provenance': change_row(call_index, set_field(child_end + 9, '666f72676564')),
    'wrong_symbol': change_row(address_index, set_field(3, '666f72676564')),
    'wrong_signature': change_row(address_index, set_field(4, '666f72676564')),
    'wrong_address_type': change_row(address_index, set_field(2, '496e74')),
    'alias_address': change_row(alias_index, set_field(13, address_id)),
    'forged_policy': change_row(function_index, forge_policy),
    'legacy_without_plan': change_row(call_index, legacy_without_suffix),
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
    echo "callback canonical poison unexpectedly emitted: $name" >&2
    exit 1
  fi
  test ! -e "$output"
done
echo 'Phase26 callback tagged-plan and FunctionAddress poison rejected before object emission.'
