#!/usr/bin/env bash
set -euo pipefail

build_root=build/guards/phase26_ffi_policy_vector_status
rm -rf "$build_root"
mkdir -p "$build_root"
test -x ./gust
test -f build/gust-native-backend
cc -std=c11 -Wall -Wextra -Werror -c \
  tests/cranelift/phase26_policy_vector_status_hosts.c -o "$build_root/hosts.o"

cat >"$build_root/cc-with-host" <<'CC'
#!/usr/bin/env bash
exec cc "$@" "$GUST_PHASE26_VECTOR_HOST_OBJECT"
CC
chmod +x "$build_root/cc-with-host"
cat >"$build_root/capture-driver" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == phase10-backend-request-compile ]]; then
  cp "${2%.request}.bundle" "$GUST_PHASE26_VECTOR_CAPTURE_BUNDLE"
fi
exec "$GUST_PHASE26_VECTOR_REAL_DRIVER" "$@"
SH
chmod +x "$build_root/capture-driver"
ln -s "$PWD/build/gust-runtime-package.a" "$build_root/gust-runtime-package.a"

GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$build_root/capture-driver" \
  GUST_PHASE26_VECTOR_REAL_DRIVER="$PWD/build/gust-native-backend" \
  GUST_PHASE26_VECTOR_CAPTURE_BUNDLE="$PWD/$build_root/canonical.bundle" \
  GUST_PHASE26_VECTOR_HOST_OBJECT="$PWD/$build_root/hosts.o" \
  CC="$PWD/$build_root/cc-with-host" \
  ./gust --backend cranelift -o "$build_root/native" \
    compiler/phase26_ffi_policy_vector_status_source.gst \
    >"$build_root/positive.stdout" 2>"$build_root/positive.stderr"
test ! -s "$build_root/positive.stdout"
test ! -s "$build_root/positive.stderr"
"$build_root/native" >"$build_root/runtime.stdout" 2>"$build_root/runtime.stderr"
test ! -s "$build_root/runtime.stderr"
python3 - "$build_root/runtime.stdout" <<'PY'
from pathlib import Path
import sys

actual = Path(sys.argv[1]).read_text().splitlines()
expected = ['0', '100', '200', '17', '-23', '-2147483648', '2147483647',
            '0', '300', '400', '31', '-41', '-2147483648', '2147483647', '0', '0',
            '319', '281', '0', '100', '200', 'vector_defer_marker']
assert actual == expected, (actual, expected)
PY
echo 'Phase26 Call8 two-host status and write-copyback runtime: ok'

python3 - "$build_root/canonical.bundle" "$build_root/canonical-positive.mir" <<'PY'
from pathlib import Path
import sys

bundle = Path(sys.argv[1]).read_text()
begin = 'module_0_canonical_mir_begin\n'
end = 'module_0_canonical_mir_end\n'
assert bundle.count(begin) == bundle.count(end) == 1
canonical = bundle.split(begin, 1)[1].split(end, 1)[0]
assert canonical.startswith('format: gust.compiler_executable_mir.v1\n')
assert canonical.endswith('\n')
Path(sys.argv[2]).write_text(canonical)
PY
"$PWD/build/gust-native-backend" phase21-full-program-validate \
  "$build_root/canonical-positive.mir" >"$build_root/canonical-positive.stdout"
"$PWD/build/gust-native-backend" phase21-full-program-object \
  "$build_root/canonical-positive.mir" "$build_root/canonical-positive.o" \
  >"$build_root/canonical-object.stdout"
test -s "$build_root/canonical-positive.o"
echo 'Phase26 Call8 canonical plan validates and emits its native object: ok'

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
    if match and match[3] in {'return_after_status', 'guard_after_status',
            'defer_after_status', 'gust_phase21_program_main'}:
        functions[match[3]] = (int(match[1], 16), int(match[2]))
assert len(functions) == 4, functions
calls = []
for line in relocations.splitlines():
    match = re.match(r'([0-9a-f]+)\s+\S+\s+R_X86_64_GOTPCREL\s+\S+\s+(\S+)', line)
    if match:
        calls.append((int(match[1], 16), match[2]))
expected = {'return_after_status': 1, 'guard_after_status': 1,
            'defer_after_status': 1, 'gust_phase21_program_main': 12}
hosts = {'host_vector_alpha', 'host_vector_beta', 'host_vector_alias_pair',
         'host_vector_scalar_mix'}
for function, (start, size) in functions.items():
    local = [symbol for offset, symbol in calls if start <= offset < start + size]
    selected = [index for index, symbol in enumerate(local) if symbol in hosts]
    assert len(selected) == expected[function], (function, local)
    for index in selected:
        arena_start = max(i for i, symbol in enumerate(local[:index])
                          if symbol == 'os_Arena_New')
        before = local[arena_start + 1:index]
        isolated_count = 1 if local[index] in {'host_vector_alias_pair',
                                               'host_vector_scalar_mix'} else 2
        assert before.count('os_ArenaAlloc') == isolated_count, (function, before)
        assert before.count('memcpy') == isolated_count, (function, before)
        assert 'os_Arena_Free' not in before, (function, before)
        after = local[index + 1:]
        free = after.index('os_Arena_Free')
        next_host = next((i for i in range(index + 1, len(local))
                          if local[i] in hosts), len(local))
        next_arena = next((i for i in range(index + 1, len(local))
                           if local[i] == 'os_Arena_New'), len(local))
        call_tail = local[index + 1:min(next_host, next_arena)]
        if function == 'guard_after_status':
            # Its HashMap arena has separate frees on mutually exclusive exits.
            guard_continuation = next(i for i, symbol in enumerate(after)
                                      if symbol.startswith('os_HashMap'))
            assert after[:guard_continuation].count('os_Arena_Free') == 1, (function, after)
        else:
            assert call_tail.count('os_Arena_Free') == 1, (function, call_tail)
        copyback_count = 0 if local[index] in {'host_vector_alias_pair',
                                              'host_vector_scalar_mix'} else 1
        assert after[:free].count('memcpy') == copyback_count, (function, after)
        assert not any(symbol in hosts or symbol in {'os_LogInt', 'os_LogStr'}
                       for symbol in after[:free]), (function, after)
        assert free < len(after), (function, after)
    if function in {'return_after_status', 'defer_after_status'}:
        assert local.count('os_Arena_Free') == 1, (function, local)
    if function == 'defer_after_status':
        assert local.index('os_Arena_Free') < local.index('os_LogInt') < local.index('os_LogStr')
print('Call8 object routes prove selected copies, all write copybacks and one call-owned free before continuation.')
PY

mkdir -p "$build_root/negatives"
python3 - "$build_root/canonical-positive.mir" "$build_root/negatives" <<'PY'
from pathlib import Path
import sys

base = Path(sys.argv[1]).read_text().splitlines()
root = Path(sys.argv[2])
def hx(value): return value.encode().hex()

def mutate(name, selector, change):
    lines = base.copy()
    row_index = next(i for i, row in enumerate(lines) if selector(row))
    fields = lines[row_index][len('node: '):].split('|')
    tag = fields.index('ffi_policy_vector_status.v1')
    change(fields, tag)
    lines[row_index] = 'node: ' + '|'.join(fields)
    (root / f'canonical_{name}.mir').write_text('\n'.join(lines) + '\n')

alpha = lambda row: row.startswith('node: ') and '|ffi_policy_vector_status.v1|' in row and hx('host_vector_alpha') in row
alias = lambda row: row.startswith('node: ') and '|ffi_policy_vector_status.v1|' in row and hx('host_vector_alias_pair') in row
mutate('missing_plan', alpha, lambda f, t: f.__delitem__(slice(t, None)))
mutate('unknown_version', alpha, lambda f, t: f.__setitem__(t, 'ffi_policy_vector_status.v2'))
mutate('wrong_target', alpha, lambda f, t: f.__setitem__(t + 1, hx('aarch64-unknown-linux-gnu')))
mutate('wrong_schedule', alpha, lambda f, t: f.__setitem__(t + 2, hx('arena_new;call;free;continue')))
mutate('wrong_count', alpha, lambda f, t: f.__setitem__(t + 3, '7'))
mutate('duplicate_position', alpha, lambda f, t: f.__setitem__(t + 10, '0'))
mutate('unknown_policy', alpha, lambda f, t: f.__setitem__(t + 5, hx('retain')))
mutate('wrong_layout', alpha, lambda f, t: f.__setitem__(t + 7, '16'))
mutate('wrong_origin', alpha, lambda f, t: f.__setitem__(t + 9, hx('forged_origin')))
mutate('wrong_result_index', alpha, lambda f, t: f.__setitem__(t + 4 + 5 * 6, '0'))
mutate('wrong_result_policy', alpha, lambda f, t: f.__setitem__(t + 5 + 5 * 6, hx('value')))
mutate('wrong_result_width', alpha, lambda f, t: f.__setitem__(t + 7 + 5 * 6, '8'))
mutate('wrong_result_provenance', alpha, lambda f, t: f.__setitem__(t + 9 + 5 * 6, hx('unsigned')))
mutate('truncated_result', alpha, lambda f, t: f.pop())
mutate('wrong_callee', alpha, lambda f, t: f.__setitem__(4, hx('forged_host')))

def swap_positions(fields, tag):
    start = tag + 4
    fields[start:start + 12] = fields[start + 6:start + 12] + fields[start:start + 6]
mutate('reordered_positions', alpha, swap_positions)

def legacy_call7(fields, tag):
    target = fields[tag + 1]
    result = fields[tag + 4 + 5 * 6:tag + 4 + 6 * 6]
    fields[6] = '7'
    fields[tag:] = ['native_error_status.v1', target,
                    hx('preserve_signed_status'), '1', result[0],
                    hx('result'), *result[2:]]
mutate('legacy_call7_borrow', alpha, legacy_call7)
def legacy_call0(fields, tag):
    fields[6] = '0'
    del fields[tag:]
mutate('legacy_call0_missing_plan', alpha, legacy_call0)
mutate('aliased_local', alias, lambda f, t: f.__setitem__(14, f[13]))

lines = base.copy()
for index, row in enumerate(lines):
    if row.startswith('node: ') and row.split('|')[1] == hx('UnsafeScope'):
        lines[index] = row.replace(hx('UnsafeScope'), hx('Block'), 1)
(root / 'canonical_unsafe_scope.mir').write_text('\n'.join(lines) + '\n')
PY
for source in "$build_root"/negatives/canonical_*.mir; do
  name="$(basename "${source%.mir}")"
  output="$build_root/negatives/$name.o"
  if "$PWD/build/gust-native-backend" phase21-full-program-object "$source" "$output" \
      >"$build_root/negatives/$name.stdout" \
      2>"$build_root/negatives/$name.stderr"; then
    echo "Call8 canonical poison unexpectedly emitted: $name" >&2
    exit 1
  fi
  test ! -e "$output"
done
echo 'Phase26 Call8 canonical policy, layout, alias, result and cleanup poisons rejected before object emission.'

python3 - "$build_root/negatives" <<'PY'
from pathlib import Path
import sys

base = Path('compiler/phase26_ffi_policy_vector_status_source.gst').read_text()
root = Path(sys.argv[1])
call = 'host_vector_alpha(&direct_alpha, &isolated_beta, &written_alpha as *VectorAlpha, &written_beta as *VectorBeta, 0)'
alias_call = 'host_vector_alias_pair(&direct_alpha, &written_alpha)'
declaration = 'direct_read: &VectorAlpha #[ffi(borrow_read_call)]'
variants = {
    'missing_repr': base.replace('#[repr(C)]\ntype VectorAlpha', 'type VectorAlpha', 1),
    'wrong_field_order': base.replace('amount: int,\n    flag: byte', 'flag: byte,\n    amount: int', 1),
    'missing_policy': base.replace(declaration, 'direct_read: &VectorAlpha', 1),
    'retained_mix': base.replace(declaration,
        'direct_read: &VectorAlpha #[ffi(retain)]', 1),
    'callback_mix': base.replace('selector: int #[ffi(value)]) int #[ffi(native_error)];',
        'selector: Callback[int, int] #[ffi(callback)]) int #[ffi(native_error)];', 1),
    'wrong_status_result': base.replace('selector: int #[ffi(value)]) int #[ffi(native_error)];',
        'selector: int #[ffi(value)]) byte #[ffi(native_error)];', 1),
    'missing_status_policy': base.replace('selector: int #[ffi(value)]) int #[ffi(native_error)];',
        'selector: int #[ffi(value)]) int;', 1),
    'aliased_local': base.replace(alias_call,
        'host_vector_alias_pair(&direct_alpha, &direct_alpha)', 1),
    'indirect_read': base.replace('os.LogInt(' + call + ');',
        'mut direct_alias := &direct_alpha;\n        '
        'os.LogInt(host_vector_alpha(direct_alias, &isolated_beta, &written_alpha as *VectorAlpha, &written_beta as *VectorBeta, 0));', 1),
    'indirect_write': base.replace('os.LogInt(' + call + ');',
        'mut write_alias := &written_beta as *VectorBeta;\n        '
        'os.LogInt(host_vector_alpha(&direct_alpha, &isolated_beta, &written_alpha as *VectorAlpha, write_alias, 0));', 1),
    'outside_unsafe': base.replace('    os.LogInt(return_after_status());',
        '    os.LogInt(host_vector_alias_pair(&direct_alpha, &written_alpha));\n'
        '    os.LogInt(return_after_status());', 1),
}
for name, source in variants.items():
    assert source != base, name
    (root / f'source_{name}.gst').write_text(source)
PY
cat >"$build_root/poison-driver" <<'SH'
#!/usr/bin/env bash
touch "$GUST_PHASE26_VECTOR_POISON_MARKER"
exit 97
SH
chmod +x "$build_root/poison-driver"
for source in "$build_root"/negatives/source_*.gst; do
  name="$(basename "${source%.gst}")"
  marker="$build_root/negatives/$name.driver"
  output="$build_root/negatives/$name.native"
  if GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
      GUST_NATIVE_BACKEND_DRIVER="$PWD/$build_root/poison-driver" \
      GUST_PHASE26_VECTOR_POISON_MARKER="$PWD/$marker" \
      ./gust --backend cranelift -o "$output" "$source" \
      >"$build_root/negatives/$name.stdout" \
      2>"$build_root/negatives/$name.stderr"; then
    echo "Call8 source negative unexpectedly compiled: $name" >&2
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
    'aliased_local': 'class=canonical_mir_verification_error',
    'callback_mix': '[FFICallbackSignature]',
    'indirect_read': 'class=canonical_mir_verification_error',
    'indirect_write': 'class=canonical_mir_verification_error',
    'missing_policy': '[FFIBorrowPolicyRequired]',
    'missing_repr': 'class=canonical_mir_verification_error',
    'missing_status_policy': 'class=canonical_mir_verification_error',
    'outside_unsafe': "Direct external/native function calls require an explicit 'unsafe' block",
    'retained_mix': '[FFIRetainAuthority]',
    'wrong_field_order': 'class=canonical_mir_verification_error',
    'wrong_status_result': '[FFINativeErrorStatus]',
}
for name, marker in expected.items():
    actual = (root / f'source_{name}.stdout').read_text()
    assert marker in actual, (name, marker, actual)
    assert ('TypeError' in actual or 'reason_code=source_or_type_failure' in actual), name
PY
echo 'Phase26 Call8 source ownership, alias, shape, and unsafe negatives rejected before driver discovery.'
