#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_ffi_retained_lease"
rm -rf "$build_root"
mkdir -p "$build_root"
test -x ./gust
test -f build/gust-native-backend
driver="$PWD/build/gust-native-backend"

cc -std=c11 -Wall -Wextra -Werror -c \
  tests/cranelift/phase26_retained_lease_hosts.c -o "$build_root/hosts.o"
cat >"$build_root/cc-with-host" <<'CC'
#!/usr/bin/env bash
exec cc "$@" "$GUST_PHASE26_RETAINED_HOST_OBJECT"
CC
chmod +x "$build_root/cc-with-host"
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  GUST_PHASE26_RETAINED_HOST_OBJECT="$PWD/$build_root/hosts.o" \
  CC="$PWD/$build_root/cc-with-host" \
  ./gust --backend cranelift -o "$build_root/native" \
    compiler/phase26_ffi_retained_lease_source.gst \
    >"$build_root/positive.stdout" 2>"$build_root/positive.stderr"
test ! -s "$build_root/positive.stdout"
test ! -s "$build_root/positive.stderr"
"$build_root/native" >"$build_root/runtime.stdout" 2>"$build_root/runtime.stderr"
test ! -s "$build_root/runtime.stderr"
python3 - "$build_root/runtime.stdout" <<'PY'
from pathlib import Path
import sys

actual = Path(sys.argv[1]).read_text().splitlines()
expected = [
    "registered_int", "retained_int_read", "unregistered_int", "freed_int",
    "registered_byte", "retained_byte_read", "unregistered_byte", "freed_byte", "7",
    "registered_byte", "retained_byte_read", "unregistered_byte", "freed_byte", "13",
    "registered_int", "defer_marker", "retained_int_read", "unregistered_int", "freed_int",
]
assert actual == expected, (actual, expected)
PY

# Unsupported origins and escapes must fail before native driver discovery.
mkdir -p "$build_root/negatives"
python3 - "$build_root/negatives" <<'PY'
from pathlib import Path
import sys

source = Path('compiler/phase26_ffi_retained_lease_source.gst').read_text()
root = Path(sys.argv[1])
acquire = 'mut owner := host_make_lease_int(41);'
register = 'host_register_lease_int(owner.raw, 1);'
assert acquire in source and register in source
cases = {
    'unbound_raw': source.replace(register,
        'host_register_lease_int(0 as *int, 1);', 1),
    'stack_origin': source.replace(acquire,
        'mut local := 3;\n        ' + acquire, 1).replace(register,
        'host_register_lease_int(&local as *int, 1);', 1),
    'arena_origin': source.replace(acquire,
        'mut arena := os.Arena.New();\n        defer arena.Free();\n'
        '        mut index: Index[int, arena] := os.ArenaAlloc(arena);\n        ' + acquire,
        1).replace(register,
        'host_register_lease_int(&arena[index] as *int, 1);', 1),
    'intervening_statement': source.replace(acquire,
        acquire + '\n        os.LogInt(1);', 1),
    'preexisting_alias': source.replace(acquire,
        acquire + '\n        mut alias := owner;', 1),
    'preexisting_raw_alias': source.replace(acquire,
        acquire + '\n        mut alias := owner.raw;', 1),
    'post_registration_access': source.replace(register,
        register + '\n        os.LogInt(*owner.raw);', 1),
    'post_registration_take': source.replace(register,
        register + '\n        mut taken := take owner;', 1),
    'post_registration_move': source.replace(register,
        register + '\n        mut moved := move owner;', 1),
    'post_registration_overwrite': source.replace(register,
        register + '\n        owner = host_make_lease_int(42);', 1),
    'post_registration_raw_alias': source.replace(register,
        register + '\n        mut alias := owner.raw;', 1),
    'post_registration_transfer': source.replace(
        'extern func host_make_lease_byte()',
        'extern func host_take_lease_int(owner: LeaseInt #[ffi(transfer_owned)]);\n'
        'extern func host_make_lease_byte()', 1).replace(register,
        register + '\n        host_take_lease_int(owner);', 1),
    'post_registration_return': source.replace(
        'func normal_route() {', 'func normal_route() LeaseInt {', 1).replace(register,
        register + '\n        return owner;', 1),
    'duplicate_registration': source.replace(register,
        register + '\n        host_register_lease_int(owner.raw, 1);', 1),
    'wrong_release_signature': source.replace(
        'host_free_lease_int(raw: *int', 'host_free_lease_int(raw: *byte', 1),
    'missing_owner_policy': source.replace(
        'LeaseInt #[ffi(owned_return)]', 'LeaseInt #[ffi(value)]', 1),
}
for name, contents in cases.items():
    assert contents != source, name
    (root / f'{name}.gst').write_text(contents)
PY

cat >"$build_root/poison-driver" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_RETAINED_POISON_MARKER"
exit 91
POISON
chmod +x "$build_root/poison-driver"
marker="$PWD/$build_root/driver-invoked"
for case_name in unbound_raw stack_origin arena_origin intervening_statement \
  preexisting_alias preexisting_raw_alias post_registration_access \
  post_registration_take post_registration_move post_registration_overwrite \
  post_registration_raw_alias post_registration_transfer \
  post_registration_return duplicate_registration wrong_release_signature \
  missing_owner_policy; do
  rm -f "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
    GUST_PHASE26_RETAINED_POISON_MARKER="$marker" \
    GUST_NATIVE_BACKEND_DRIVER="$PWD/$build_root/poison-driver" \
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
    wrong_release_signature) rg -q '\[FFIReleaseAuthority\]' "$build_root/$case_name.stdout" ;;
    post_registration_overwrite) rg -q '\[FFIOwnedOverwrite\]' "$build_root/$case_name.stdout" ;;
    post_registration_*) rg -q '\[FFIRetainedOwnerAccess\]' "$build_root/$case_name.stdout" ;;
    *) rg -q '\[FFIRetainAuthority\]' "$build_root/$case_name.stdout" ;;
  esac
done

canonical="compiler/fixtures/native_backend_phase26_retained_lease_minimal.mir"
"$driver" phase21-full-program-validate "$canonical" >"$build_root/canonical-positive.stdout"
"$driver" phase21-full-program-object "$canonical" "$build_root/canonical-positive.o" \
  >"$build_root/canonical-object.stdout"
test -s "$build_root/canonical-positive.o"

python3 - "$canonical" "$build_root/negatives" <<'PY'
from pathlib import Path
import sys

base = Path(sys.argv[1]).read_text()
root = Path(sys.argv[2])
assert base.count('|retained_lease.v1|') == 4

def hx(text): return text.encode().hex()

def row(lines, index):
    prefix = f'node: {index}|'
    line = next(i for i, value in enumerate(lines) if value.startswith(prefix))
    return line, lines[line][len('node: '):].split('|')

def save(name, change):
    lines = base.splitlines()
    change(lines)
    (root / f'canonical_{name}.mir').write_text('\n'.join(lines) + '\n')

def change_call(name, change):
    def edit(lines):
        line = next(i for i, value in enumerate(lines)
                    if value.startswith('node: ') and '|retained_lease.v1|' in value)
        fields = lines[line][len('node: '):].split('|')
        tag = fields.index('retained_lease.v1')
        change(fields, tag)
        if 'retained_lease.v1' in fields:
            fields[3] = hx('|' + '|'.join(fields[fields.index('retained_lease.v1'):]))
        lines[line] = 'node: ' + '|'.join(fields)
    save(name, edit)

change_call('wrong_version', lambda f,t: f.__setitem__(t,'retained_lease.v2'))
change_call('wrong_target', lambda f,t: f.__setitem__(t+1,hx('aarch64-unknown-linux-gnu')))
change_call('wrong_release', lambda f,t: f.__setitem__(t+2,hx('release_lease_byte')))
change_call('wrong_count', lambda f,t: f.__setitem__(t+3,'2'))
change_call('wrong_position', lambda f,t: f.__setitem__(t+4,'1'))
change_call('wrong_direction', lambda f,t: f.__setitem__(t+5,hx('write')))
change_call('wrong_owner_type', lambda f,t: f.__setitem__(t+6,hx('Struct("Forged", None)')))
change_call('wrong_size', lambda f,t: f.__setitem__(t+7,'16'))
change_call('wrong_align', lambda f,t: f.__setitem__(t+8,'4'))
change_call('wrong_provenance', lambda f,t: f.__setitem__(t+9,hx('stack_raw_field')))
change_call('wrong_storage', lambda f,t: f.__setitem__(t+10,hx('alias')))
change_call('wrong_acquisition', lambda f,t: f.__setitem__(t+11,hx('acquisition:forged:0:1')))
change_call('wrong_raw_field', lambda f,t: f.__setitem__(t+12,hx('other')))
change_call('truncated', lambda f,t: f.pop())

def legacy_zero(fields, tag):
    fields[6] = '0'
    fields[3] = hx('host_register_lease_int')
    del fields[tag:]
change_call('suffix_free_call0', legacy_zero)

def drop_cleanup(lines):
    line, fields = row(lines, 30)
    fields[11] = '2'
    fields.pop()
    lines[line] = 'node: ' + '|'.join(fields)
save('missing_cleanup', drop_cleanup)

def duplicate_cleanup(lines):
    line, fields = row(lines, 19)
    fields[11] = '2'
    fields.append('18')
    lines[line] = 'node: ' + '|'.join(fields)
save('duplicate_cleanup', duplicate_cleanup)

def early_cleanup(lines):
    line, fields = row(lines, 93)
    fields[11] = str(int(fields[11]) + 1)
    fields.insert(-1, '67')
    lines[line] = 'node: ' + '|'.join(fields)
save('early_then_terminal_cleanup', early_cleanup)

def release_then_owner_use(lines):
    early_cleanup(lines)
    line, fields = row(lines, 92)
    fields[12] = '73'  # LocalRead(owner) from the retained raw-field argument.
    lines[line] = 'node: ' + '|'.join(fields)
save('release_then_owner_use', release_then_owner_use)

def owner_use(lines):
    line, fields = row(lines, 92)
    fields[12] = '73'
    lines[line] = 'node: ' + '|'.join(fields)
save('owner_use_after_register', owner_use)

def missing_return_cleanup(lines):
    line, fields = row(lines, 46)
    fields[11] = '1'
    fields.pop()
    lines[line] = 'node: ' + '|'.join(fields)
save('missing_return_cleanup', missing_return_cleanup)

def substituted_cleanup(lines):
    line, fields = row(lines, 45)
    fields[4] = hx('release_lease_int')
    lines[line] = 'node: ' + '|'.join(fields)
save('substituted_return_release', substituted_cleanup)

def reordered_acquisition(lines):
    line, fields = row(lines, 30)
    fields[12], fields[13] = fields[13], fields[12]
    lines[line] = 'node: ' + '|'.join(fields)
save('registration_before_acquisition', reordered_acquisition)
PY

for file in "$build_root"/negatives/canonical_*.mir; do
  output="$build_root/$(basename "${file%.mir}").o"
  set +e
  "$driver" phase21-full-program-object "$file" "$output" \
    >"${output%.o}.stdout" 2>"${output%.o}.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  test ! -e "$output"
done

echo 'Phase26 retained native owner lease, source rejection and canonical poison evidence passed.'
