#!/usr/bin/env python3
"""Observe Keys result storage while the map and its string payload are live."""

import hashlib
import json
import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build/guards/phase26_2_allocator_identity/hashmap_keys_destination'
SUPPORT = ROOT / 'compiler/phase20_protected_access_module.gst'
RUNTIME = ROOT / 'gust-runtime-package.a'
SOURCE = """import "support.gst" as protected;

func choose_destination(destination: &Arena) &Arena {
    os.LogInt(17);
    return destination;
}

func main() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut destination := os.Arena.New();
    defer destination.Free();
    mut value: protected.ProtectedValue[ctx];
    value.value = 41;
    mut table: std.HashMap[str, int, ctx] := std.HashMapNew(&ctx);
    table.Insert(std.Clone(&ctx, "entry"), protected.sink(&value));
    mut keys := table.Keys(DESTINATION);
    if len(keys) != 1 { return 81; }
    if std.str_eq(keys[0], "entry") == 0 { return 82; }
    os.LogInt(41);
    return 0;
}
"""
# OsArena's layout is defined in src/runtime-rs/src/fiber.rs. Both arenas
# stay live until deferred cleanup, so the observer reads valid arena state.
OBSERVER = """#include <stddef.h>
#include <stdio.h>
struct OsArena {
    void *base_address;
    size_t offset;
    size_t capacity;
};
extern void __real_os_Arena_Free(struct OsArena *arena);
void __wrap_os_Arena_Free(struct OsArena *arena) {
    fprintf(stderr, "owned_arena_offset=%zu\\n", arena->offset);
    __real_os_Arena_Free(arena);
}
"""


def checked_run(command, directory, label, timeout, env=None):
    result = subprocess.run(command, cwd=directory, capture_output=True, timeout=timeout, env=env)
    (directory / (label + '.stdout')).write_bytes(result.stdout)
    (directory / (label + '.stderr')).write_bytes(result.stderr)
    assert result.returncode == 0, (label, result.returncode, result.stdout, result.stderr)
    return result


def file_hash(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    BUILD.mkdir(parents=True, exist_ok=True)
    observer = BUILD / 'observer.c'
    observer.write_text(OBSERVER)
    instrument = BUILD / 'observer.o'
    checked_run(['cc', '-std=c11', '-Wall', '-Wextra', '-Werror',
                 '-c', str(observer), '-o', str(instrument)], BUILD, 'observer', 30)
    tools = (ROOT / 'gust', ROOT / 'gust-native-backend', RUNTIME)
    hashes = {path.name: file_hash(path) for path in tools}
    rows = []
    for name, operand, distinct, stdout in (
        ('same-arena', '&ctx', False, b'41\n'),
        ('distinct-arenas', 'choose_destination(&destination)', True, b'17\n41\n'),
    ):
        directory = BUILD / name
        directory.mkdir(exist_ok=True)
        source = directory / 'case.gst'
        source.write_text(SOURCE.replace('DESTINATION', operand))
        (directory / 'support.gst').write_bytes(SUPPORT.read_bytes())
        binary = directory / 'program'
        binary.unlink(missing_ok=True)
        objects = directory / 'objects'
        obj = objects / 'module-0.o'
        obj.unlink(missing_ok=True)
        command = [str(ROOT / 'gust'), '--backend', 'cranelift', '-o', str(binary), str(source)]
        env = dict(os.environ, GUST_NATIVE_BACKEND_DRIVER=str(tools[1]), TMPDIR=str(directory),
                   GUST_NATIVE_KEEP_OBJECTS=str(objects), GUST_TEST_MIR_TO_C_UNAVAILABLE='1')
        checked_run(command, directory, 'compile', 120, env)
        assert binary.is_file() and not binary.is_symlink() and obj.is_file()
        assert b'module_0_canonical_format: gust.compiler_executable_mir.v1\n' in (
            objects / 'program.mir.bundle').read_bytes()
        observed = directory / 'observed'
        checked_run(['cc', '-o', str(observed), str(obj), str(instrument), str(RUNTIME),
                     '-Wl,--wrap=os_Arena_Free', '-lpthread', '-ldl', '-lm'], directory, 'link', 30)
        stock = checked_run([str(binary)], directory, 'stock', 15)
        trace = checked_run([str(observed)], directory, 'trace', 15)
        assert not stock.stderr and stock.stdout == trace.stdout, (name, stock, trace)
        offsets = [int(line.removeprefix(b'owned_arena_offset=')) for line in trace.stderr.splitlines()]
        assert len(offsets) == 2 and offsets[1] > 0 and (offsets[0] > 0) == distinct, (name, offsets)
        assert stock.stdout == stdout, (name, stock.stdout)
        rows.append(dict(case=name, command=command, source_sha256=file_hash(source),
                         object_sha256=file_hash(obj), stdout=stdout.decode(), free_offsets=offsets))
        print('PASS Keys destination ' + name, flush=True)
    assert hashes == {path.name: file_hash(path) for path in tools}
    (BUILD / 'result.json').write_text(json.dumps(dict(tools=hashes, cases=rows), indent=2) + '\n')


if __name__ == '__main__':
    main()
