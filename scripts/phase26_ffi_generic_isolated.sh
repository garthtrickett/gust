#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_ffi_generic_isolated"
rm -rf "$build_root"
mkdir -p "$build_root"
test -x ./gust
test -f build/gust-native-backend
driver="$PWD/build/gust-native-backend"

cc -std=c11 -Wall -Wextra -Werror -c \
  tests/cranelift/phase26_generic_isolated_hosts.c -o "$build_root/hosts.o"
cat >"$build_root/cc-with-host" <<'CC'
#!/usr/bin/env bash
exec cc "$@" "$GUST_PHASE26_ISOLATED_HOST_OBJECT"
CC
chmod +x "$build_root/cc-with-host"
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  GUST_PHASE26_ISOLATED_HOST_OBJECT="$PWD/$build_root/hosts.o" \
  CC="$PWD/$build_root/cc-with-host" \
  ./gust --backend cranelift -o "$build_root/native" \
    compiler/phase26_ffi_generic_isolated_source.gst \
    >"$build_root/positive.stdout" 2>"$build_root/positive.stderr"
test ! -s "$build_root/positive.stdout"
test ! -s "$build_root/positive.stderr"
"$build_root/native" >"$build_root/runtime.stdout" 2>"$build_root/runtime.stderr"
test ! -s "$build_root/runtime.stderr"
python3 - "$build_root/runtime.stdout" <<'PY'
from pathlib import Path
import sys

actual = Path(sys.argv[1]).read_text().splitlines()
expected = ['alpha_host', '35', '1', '34', '7',
            'beta_host', '67', '7', '41', '9',
            'alpha_host', '35', 'beta_host', '33', '13',
            'alpha_host', '35', 'isolated_defer_marker']
assert actual == expected, (actual, expected)
PY

echo 'Phase26 generic isolated C pointer ABI, read isolation and write copy-back passed.'

mkdir -p "$build_root/negatives"
python3 - "$build_root/negatives" <<'PY'
from pathlib import Path
import sys

base = Path('compiler/phase26_ffi_generic_isolated_source.gst').read_text()
root = Path(sys.argv[1])
read = 'read: &IsolatedAlpha #[ffi(borrow_read_isolated_call)]'
write = 'write: *IsolatedBeta #[ffi(borrow_write_isolated_call)]'
variants = {
    'missing_repr': base.replace('#[repr(C)]\ntype IsolatedAlpha', 'type IsolatedAlpha', 1),
    'declaration_order': base.replace('lead: byte,\n    tail: byte,\n    tally: int',
                                      'lead: byte,\n    tally: int,\n    tail: byte', 1),
    'nested_field': base.replace('tail: byte,', 'tail: *int,', 1)
        .replace('alpha.tail = 3 as byte;', '')
        .replace('alpha.tail as int', '0', 1),
    'read_raw': base.replace(read, 'read: *IsolatedAlpha #[ffi(borrow_read_isolated_call)]', 1),
    'write_reference': base.replace(write,
        'write: &IsolatedBeta #[ffi(borrow_write_isolated_call)]', 1),
    'indirect_read': base.replace(
        'os.LogInt(host_isolated_alpha(&alpha, beta_pointer, 4));',
        'mut read_alias := &alpha;\n        os.LogInt(host_isolated_alpha(read_alias, beta_pointer, 4));', 1),
    'retained': base.replace(read, 'read: &IsolatedAlpha #[ffi(retain)]', 1),
    'missing_policy': base.replace(read, 'read: &IsolatedAlpha', 1),
}
for name, source in variants.items():
    assert source != base, name
    (root / f'{name}.gst').write_text(source)
PY
poison="$build_root/poison-driver"
marker="$PWD/$build_root/driver-invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_ISOLATED_POISON_MARKER"
exit 91
POISON
chmod +x "$poison"
for case_name in missing_repr declaration_order nested_field read_raw \
  write_reference indirect_read retained missing_policy; do
  rm -f "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
    GUST_PHASE26_ISOLATED_POISON_MARKER="$marker" \
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

canonical="compiler/fixtures/native_backend_phase26_generic_isolated_minimal.mir"
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
    local = [(offset, symbol) for offset, symbol in calls
             if start <= offset < start + size]
    hosts = [index for index, (_, symbol) in enumerate(local)
             if symbol in {'host_isolated_alpha', 'host_isolated_beta'}]
    assert len(hosts) == counts[function], (function, local)
    for index in hosts:
        before = local[:index]
        arena_start = max(i for i, (_, symbol) in enumerate(before)
                          if symbol == 'os_Arena_New')
        assert sum(symbol == 'os_ArenaAlloc' for _, symbol in before[arena_start:]) == 2
        after = [symbol for _, symbol in local[index + 1:]
                 if symbol != 'memcpy']
        # Each call's write copy-back precedes its one call-owned free; the
        # free precedes logging, a guard branch, a defer, or function return.
        assert after and after[0] == 'os_Arena_Free', (function, after)
        if function == 'early_return_call':
            assert after.count('os_Arena_Free') == 1, after
        if function == 'guard_after_call':
            assert after[1] == 'os_LogInt', after
        if function == 'defer_after_call':
            assert after[1] == 'os_LogInt' and 'os_LogStr' in after[2:], after
print('Five native calls each have two arena allocations and one call-owned free before continuation.')
PY

python3 - "$canonical" "$build_root/negatives" <<'PY'
from pathlib import Path
import sys

base = Path(sys.argv[1]).read_text()
root = Path(sys.argv[2])

def hx(value):
    return value.encode().hex()

def mutate_call(change):
    lines = base.splitlines()
    index = next(i for i, line in enumerate(lines)
                 if line.startswith('node: ') and '|isolated_call.v1|' in line)
    fields = lines[index][len('node: '):].split('|')
    suffix = fields.index('isolated_call.v1')
    change(fields, suffix)
    lines[index] = 'node: ' + '|'.join(fields)
    return '\n'.join(lines) + '\n'

def mutate_function(change):
    lines = base.splitlines()
    index = next(i for i, line in enumerate(lines)
                 if line.startswith('function: 0|'))
    fields = lines[index][len('function: '):].split('|')
    change(fields)
    lines[index] = 'function: ' + '|'.join(fields)
    return '\n'.join(lines) + '\n'

def forge_read_origin():
    lines = base.splitlines()
    call = next(line for line in lines
                if line.startswith('node: ') and '|isolated_call.v1|' in line)
    read_argument = int(call[len('node: '):].split('|')[13])
    index = next(i for i, line in enumerate(lines)
                 if line.startswith(f'node: {read_argument}|'))
    fields = lines[index][len('node: '):].split('|')
    assert fields[1] == hx('AddressOf')
    fields[1] = hx('MoveValue')
    lines[index] = 'node: ' + '|'.join(fields)
    return '\n'.join(lines) + '\n'

variants = {
    'missing_plan': mutate_call(lambda f, s: f.__delitem__(slice(s, None))),
    'unknown_version': mutate_call(lambda f, s: f.__setitem__(s, 'isolated_call.v2')),
    'partial_plan': mutate_call(lambda f, s: f.__delitem__(slice(s + 6, None))),
    'wrong_cleanup': mutate_call(lambda f, s: f.__setitem__(s + 2, hx('deferred_arena'))),
    'wrong_count': mutate_call(lambda f, s: f.__setitem__(s + 3, '1')),
    'oversized_count': mutate_call(lambda f, s: f.__setitem__(s + 3, str(2**64-1))),
    'wrong_index': mutate_call(lambda f, s: f.__setitem__(s + 4, '2')),
    'wrong_direction': mutate_call(lambda f, s: f.__setitem__(s + 5, hx('write'))),
    'wrong_type': mutate_call(lambda f, s: f.__setitem__(s + 6, hx('Struct("Other", None)'))),
    'wrong_size': mutate_call(lambda f, s: f.__setitem__(s + 7, '7')),
    'wrong_align': mutate_call(lambda f, s: f.__setitem__(s + 8, '8')),
    'wrong_provenance': mutate_call(lambda f, s: f.__setitem__(s + 9, hx('raw_cast'))),
    'forged_read_origin': forge_read_origin(),
    'mixed_pointer': mutate_function(lambda f: f.__setitem__(14, hx('RawPointer(Int)'))),
    'raw_result': mutate_function(lambda f: f.__setitem__(6, hx('RawPointer(Int)'))),
    'forged_contract': mutate_function(lambda f: f.__delitem__(slice(f.index('ffi_policy.v1'), None))),
    'wrong_target': mutate_call(lambda f, s: f.__setitem__(s + 1, hx('aarch64-unknown-linux-gnu'))),
    'unknown_variant': mutate_call(lambda f, s: f.__setitem__(6, '4')),
    'missing_variant': mutate_call(lambda f, s: f.__setitem__(6, '0')),
}
for name, source in variants.items():
    assert source != base, name
    (root / f'canonical_{name}.mir').write_text(source)

# A now-supported non-fixture host must still be rejected if a canonical
# mutation tries to claim the older host-specific Call marker.
for direction, marker in (("read", "1"), ("write", "2")):
    fixture = Path(
        f"compiler/fixtures/native_backend_phase26_generic_isolated_unknown_{direction}.mir"
    ).read_text()
    lines = fixture.splitlines()
    index = next(i for i, line in enumerate(lines)
                 if line.startswith("node: ") and "|isolated_call.v1|" in line)
    fields = lines[index][len("node: "):].split("|")
    suffix = fields.index("isolated_call.v1")
    assert fields[6] == "3" and suffix > 11
    fields[6] = marker
    del fields[suffix:]
    lines[index] = "node: " + "|".join(fields)
    (root / f"canonical_legacy_{direction}_unknown_host.mir").write_text(
        "\n".join(lines) + "\n"
    )
PY
for case_name in missing_plan unknown_version partial_plan wrong_cleanup wrong_count \
  oversized_count wrong_index wrong_direction wrong_type wrong_size \
  wrong_align wrong_provenance forged_read_origin mixed_pointer raw_result \
  forged_contract wrong_target unknown_variant missing_variant \
  legacy_read_unknown_host legacy_write_unknown_host; do
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
  if [[ "$case_name" == forged_read_origin || "$case_name" == wrong_provenance ]]; then
    rg -F 'isolated FFI read lacks direct local address provenance' \
      "$build_root/canonical_$case_name.stderr" >/dev/null
  fi
  if [[ "$case_name" == legacy_read_unknown_host || "$case_name" == legacy_write_unknown_host ]]; then
    rg -F 'legacy isolated FFI Call has a mismatched contract' \
      "$build_root/canonical_$case_name.stderr" >/dev/null
  fi
done

echo 'Phase26 generic isolated source and canonical fail-closed evidence passed.'
