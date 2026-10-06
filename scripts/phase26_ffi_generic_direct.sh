#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_ffi_generic_direct"
rm -rf "$build_root"
mkdir -p "$build_root"
test -x ./gust
test -f build/gust-native-backend
driver="$PWD/build/gust-native-backend"

cc -std=c11 -Wall -Wextra -Werror -c \
  tests/cranelift/phase26_generic_direct_hosts.c -o "$build_root/hosts.o"
cat >"$build_root/cc-with-host" <<'CC'
#!/usr/bin/env bash
exec cc "$@" "$GUST_PHASE26_DIRECT_HOST_OBJECT"
CC
chmod +x "$build_root/cc-with-host"
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  GUST_PHASE26_DIRECT_HOST_OBJECT="$PWD/$build_root/hosts.o" \
  CC="$PWD/$build_root/cc-with-host" \
  ./gust --backend cranelift -o "$build_root/native" \
    compiler/phase26_ffi_generic_direct_source.gst \
    >"$build_root/positive.stdout" 2>"$build_root/positive.stderr"
test ! -s "$build_root/positive.stdout"
test ! -s "$build_root/positive.stderr"
"$build_root/native" >"$build_root/runtime.stdout" 2>"$build_root/runtime.stderr"
test ! -s "$build_root/runtime.stderr"
python3 - "$build_root/runtime.stdout" <<'PY'
from pathlib import Path
import sys

actual = Path(sys.argv[1]).read_text().splitlines()
expected = ['direct_alpha_host', '35', '1', '34', '7',
            'direct_beta_host', '67', '7', '41', '9',
            'direct_alpha_host', '35', 'direct_beta_host', '33', '41', '13',
            'direct_alpha_host', '35', '34', 'direct_defer_marker']
assert actual == expected, (actual, expected)
PY

echo 'Phase26 generic direct C pointer ABI, original-place writes and continuation routes passed.'

canonical="compiler/fixtures/native_backend_phase26_generic_direct_minimal.mir"
"$driver" phase21-full-program-validate "$canonical" >"$build_root/canonical-positive.stdout"
"$driver" phase21-full-program-object "$canonical" "$build_root/canonical-positive.o" \
  >"$build_root/canonical-object.stdout"
test -s "$build_root/canonical-positive.o"
python3 - "$build_root/canonical-positive.o" <<'PY'
import re
import subprocess
import sys

obj = sys.argv[1]
symbols = subprocess.check_output(['readelf', '-Ws', obj], text=True)
relocations = subprocess.check_output(['readelf', '-r', obj], text=True)
functions = {}
for line in symbols.splitlines():
    match = re.match(r'\s*\d+: ([0-9a-f]+)\s+(\d+) FUNC\s+LOCAL\s+DEFAULT\s+\d+\s+(\S+)', line)
    if match and match[3] in {'early_return_call', 'guard_after_call',
                               'defer_after_call', 'gust_phase21_program_main'}:
        functions[match[3]] = (int(match[1], 16), int(match[2]))
assert len(functions) == 4, functions
calls = []
for line in relocations.splitlines():
    match = re.match(r'([0-9a-f]+)\s+\S+\s+R_X86_64_GOTPCREL\s+\S+\s+(\S+)', line)
    if match:
        calls.append((int(match[1], 16), match[2]))
counts = {'early_return_call': 1, 'guard_after_call': 1,
          'defer_after_call': 1, 'gust_phase21_program_main': 2}
for function, (start, size) in functions.items():
    local = [symbol for offset, symbol in calls if start <= offset < start + size]
    hosts = [symbol for symbol in local if symbol in {'host_direct_alpha', 'host_direct_beta'}]
    assert len(hosts) == counts[function], (function, local)
    # The source explicitly creates one arena in guard_after_call for its
    # HashMap; the direct native calls themselves acquire no transient arena.
    assert 'os_ArenaAlloc' not in local, (function, local)
    if function != 'guard_after_call':
        assert 'os_Arena_New' not in local and 'os_Arena_Free' not in local, (function, local)
print('Five native calls use the ordinary original-pointer ABI without a call-owned arena.')
PY

mkdir -p "$build_root/negatives"
python3 - "$build_root/negatives" <<'PY'
from pathlib import Path
import sys

base = Path('compiler/phase26_ffi_generic_direct_source.gst').read_text()
root = Path(sys.argv[1])
read = 'read: &DirectAlpha #[ffi(borrow_read_call)]'
write = 'write: *DirectBeta #[ffi(borrow_write_call)]'
call = 'os.LogInt(host_direct_alpha(&alpha, &beta as *DirectBeta, 4));'
variants = {
    'missing_repr': base.replace('#[repr(C)]\ntype DirectAlpha', 'type DirectAlpha', 1),
    'declaration_order': base.replace('lead: byte,\n    tail: byte,\n    tally: int',
                                      'lead: byte,\n    tally: int,\n    tail: byte', 1),
    'nested_field': base.replace('tail: byte,', 'tail: *int,', 1)
        .replace('alpha.tail = 3 as byte;', '')
        .replace('alpha.tail as int', '0', 1),
    'read_raw': base.replace(read, 'read: *DirectAlpha #[ffi(borrow_read_call)]', 1),
    'write_reference': base.replace(write,
        'write: &DirectBeta #[ffi(borrow_write_call)]', 1),
    'indirect_read': base.replace(call,
        'mut read_alias := &alpha;\n        os.LogInt(host_direct_alpha(read_alias, &beta as *DirectBeta, 4));', 1),
    'indirect_write': base.replace(call,
        'mut write_alias := &beta as *DirectBeta;\n        os.LogInt(host_direct_alpha(&alpha, write_alias, 4));', 1),
    'duplicate_local': base.replace('func main() int {',
        'extern func host_direct_duplicate(read: &DirectAlpha #[ffi(borrow_read_call)], '
        'write: *DirectAlpha #[ffi(borrow_write_call)], bonus: int #[ffi(value)]) int;\n'
        'func main() int {', 1)
        .replace(call, 'os.LogInt(host_direct_duplicate(&alpha, &alpha as *DirectAlpha, 4));', 1),
    'retained': base.replace(read, 'read: &DirectAlpha #[ffi(retain)]', 1),
    'missing_policy': base.replace(read, 'read: &DirectAlpha', 1),
    'pointer_result': base.replace('bonus: int #[ffi(value)]) int;',
        'bonus: int #[ffi(value)]) *DirectAlpha;', 1),
}
for name, source in variants.items():
    assert source != base, name
    (root / f'{name}.gst').write_text(source)
PY
poison="$build_root/poison-driver"
marker="$PWD/$build_root/driver-invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_DIRECT_POISON_MARKER"
exit 91
POISON
chmod +x "$poison"
for case_name in missing_repr declaration_order nested_field read_raw \
  write_reference indirect_read indirect_write duplicate_local retained \
  missing_policy pointer_result; do
  rm -f "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
    GUST_PHASE26_DIRECT_POISON_MARKER="$marker" \
    GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$build_root/$case_name" \
      "$build_root/negatives/$case_name.gst" \
      >"$build_root/$case_name.stdout" 2>"$build_root/$case_name.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  test ! -e "$marker"
  test ! -e "$build_root/$case_name"
done

python3 - "$canonical" "$build_root/negatives" <<'PY'
from pathlib import Path
import sys

base = Path(sys.argv[1]).read_text()
root = Path(sys.argv[2])
def hx(value): return value.encode().hex()

def change_call(name, change):
    lines = base.splitlines()
    index = next(i for i, line in enumerate(lines)
                 if line.startswith('node: ') and '|direct_call.v1|' in line)
    fields = lines[index][len('node: '):].split('|')
    tag = fields.index('direct_call.v1')
    change(fields, tag)
    lines[index] = 'node: ' + '|'.join(fields)
    (root / f'{name}.mir').write_text('\n'.join(lines) + '\n')

change_call('wrong_version', lambda f, t: f.__setitem__(t, 'direct_call.v2'))
change_call('wrong_target', lambda f, t: f.__setitem__(t + 1, hx('aarch64-unknown-linux-gnu')))
change_call('wrong_scope', lambda f, t: f.__setitem__(t + 2, hx('single_call_arena')))
change_call('wrong_count', lambda f, t: f.__setitem__(t + 3, '3'))
change_call('wrong_index', lambda f, t: f.__setitem__(t + 4, '1'))
change_call('wrong_direction', lambda f, t: f.__setitem__(t + 5, hx('write')))
change_call('wrong_type', lambda f, t: f.__setitem__(t + 6, hx('Struct("Forged", None)')))
change_call('wrong_size', lambda f, t: f.__setitem__(t + 7, '16'))
change_call('wrong_align', lambda f, t: f.__setitem__(t + 8, '8'))
change_call('wrong_provenance', lambda f, t: f.__setitem__(t + 9, hx('unknown')))
change_call('truncated', lambda f, t: f.pop())
change_call('missing_suffix', lambda f, t: f.__delitem__(slice(t, None)))
for legacy in (0, 1, 2, 3):
    def change(f, tag, legacy=legacy):
        f[6] = str(legacy)
        del f[tag:]
    change_call(f'legacy_{legacy}_forgery', change)

# A validly tagged row with a LocalRead alias in place of its selected
# AddressOf must fail canonical provenance validation before object emission.
lines = base.splitlines()
index = next(i for i, line in enumerate(lines)
             if line.startswith('node: ') and '|direct_call.v1|' in line)
call = lines[index][len('node: '):].split('|')
tag = call.index('direct_call.v1')
read_child = int(call[13])
assert int(call[11]) == 4 and read_child < len(lines)
node_index = next(i for i, line in enumerate(lines)
                  if line.startswith(f'node: {read_child}|'))
fields = lines[node_index][len('node: '):].split('|')
assert fields[1] == hx('AddressOf')
fields[1] = hx('LocalRead')
fields[3] = hx('forged_alias')
fields[11] = '0'
del fields[12:]
lines[node_index] = 'node: ' + '|'.join(fields)
(root / 'forged_origin.mir').write_text('\n'.join(lines) + '\n')

lines = base.splitlines()
def node_fields(number):
    index = next(i for i, line in enumerate(lines)
                 if line.startswith(f'node: {number}|'))
    return index, lines[index][len('node: '):].split('|')
call_line = next(line for line in lines
                 if line.startswith('node: ') and '|direct_call.v1|' in line)
call = call_line[len('node: '):].split('|')
_, read_address = node_fields(int(call[13]))
_, read_local = node_fields(int(read_address[12]))
_, write_cast = node_fields(int(call[14]))
_, write_address = node_fields(int(write_cast[12]))
write_index, write_local = node_fields(int(write_address[12]))
assert read_local[1] == hx('LocalRead') and write_local[1] == hx('LocalRead')
write_local[3] = read_local[3]
lines[write_index] = 'node: ' + '|'.join(write_local)
(root / 'aliased_positions.mir').write_text('\n'.join(lines) + '\n')
PY
for case_name in wrong_version wrong_target wrong_scope wrong_count wrong_index \
  wrong_direction wrong_type wrong_size wrong_align wrong_provenance truncated \
  missing_suffix legacy_0_forgery legacy_1_forgery legacy_2_forgery \
  legacy_3_forgery forged_origin aliased_positions; do
  set +e
  "$driver" phase21-full-program-object \
    "$build_root/negatives/$case_name.mir" "$build_root/$case_name.o" \
    >"$build_root/$case_name.canonical.stdout" \
    2>"$build_root/$case_name.canonical.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  test ! -e "$build_root/$case_name.o"
done

echo 'Phase26 generic direct source and canonical fail-closed mutations passed.'
