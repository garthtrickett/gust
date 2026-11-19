#!/usr/bin/env python3
"""Qualify declaration identity and late values at native deferred exits."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CASES = ROOT / 'compiler/phase26-2-defer-lexical/cases.json'
WORKER = ROOT / 'compiler/experiments/cranelift/src/full_program.rs'
SUPPORT = ROOT / 'compiler/phase20_protected_access_module.gst'
BUILD = ROOT / 'build/guards/phase26_2_defer_lexical'
CASE_DIGEST = '2e89f53df7a969d77651cb8f97eea3f3d7a07ffeee2298a39c204af897f6f312'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate(value=None, worker=None):
    value = json.loads(CASES.read_text()) if value is None else value
    canonical = json.dumps(value, sort_keys=True, separators=(',', ':')).encode()
    assert hashlib.sha256(canonical).hexdigest() == CASE_DIGEST, 'deferred lexical case contract drifted'
    source = WORKER.read_text() if worker is None else worker
    for obligation in ('struct ScheduledDefer {', 'bindings: HashMap<String, Local>',
                       'expression: node.children[0]', 'bindings,',
                       'vec![deferred.bindings]', 'deferred.expression, None'):
        assert obligation in source, 'deferred lexical storage binding missing: ' + obligation
    assert source.index('self.scopes = active_scopes;') < source.index('            result?;'), \
        'deferred lexical error restoration missing'
    return value['cases']


def inversions():
    value = json.loads(CASES.read_text())
    validate(value)
    changes = []
    changed = copy.deepcopy(value)
    changed['cases'][1]['stdout'] = '22\n'
    changes.append(('wrong shadow oracle', changed, None, 'deferred lexical case contract drifted'))
    changed = copy.deepcopy(value)
    changed['cases'].pop()
    changes.append(('missing match control', changed, None, 'deferred lexical case contract drifted'))
    worker = WORKER.read_text()
    changes.append(('missing binding capture', value,
                    worker.replace('bindings: HashMap<String, Local>', 'bindings: usize', 1),
                    'deferred lexical storage binding missing: bindings: HashMap<String, Local>'))
    changes.append(('missing error restoration', value,
                    worker.replace('self.scopes = active_scopes;', '/* missing restore */', 1),
                    None))
    for name, cases, source, expected in changes:
        try:
            validate(cases, source)
        except (AssertionError, ValueError) as error:
            if expected is not None:
                assert str(error) == expected, 'REJECTED (different assertion): ' + name + ': ' + str(error)
            else:
                assert isinstance(error, ValueError), 'REJECTED (different assertion): ' + name
            print('REJECTED (expected assertion): ' + name)
        else:
            raise AssertionError('ACCEPTED mutation: ' + name)


def native():
    cases = validate()
    BUILD.mkdir(parents=True, exist_ok=True)
    tools = {name: digest(ROOT / name) for name in ('gust', 'gust-native-backend')}
    inputs = {str(path.relative_to(ROOT)): digest(path) for path in (CASES, WORKER, SUPPORT)}
    rows = []
    for case in cases:
        folder = BUILD / case['name']
        folder.mkdir(exist_ok=True)
        source = folder / 'case.gst'
        source.write_text(case['source'])
        (folder / 'support.gst').write_bytes(SUPPORT.read_bytes())
        binary = folder / 'program'
        binary.unlink(missing_ok=True)
        command = [str(ROOT / 'gust'), '--backend', 'cranelift', '-o', str(binary), str(source)]
        compiled = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=120,
                                  env=dict(os.environ, GUST_NATIVE_BACKEND_DRIVER=str(ROOT / 'gust-native-backend')))
        (folder / 'compile.stdout').write_bytes(compiled.stdout)
        (folder / 'compile.stderr').write_bytes(compiled.stderr)
        (folder / 'compile.status').write_text(str(compiled.returncode) + '\n')
        assert compiled.returncode == 0 and binary.is_file(), 'deferred lexical compile failed: ' + case['name']
        header = binary.read_bytes()[:20]
        assert header[:7] == b'\x7fELF\x02\x01\x01' and int.from_bytes(header[18:20], 'little') == 62
        run = subprocess.run([str(binary)], cwd=folder, capture_output=True, timeout=15)
        (folder / 'run.stdout').write_bytes(run.stdout)
        (folder / 'run.stderr').write_bytes(run.stderr)
        (folder / 'run.status').write_text(str(run.returncode) + '\n')
        row = dict(name=case['name'], command=command, compile_exit=compiled.returncode,
                   run_exit=run.returncode, expected_stdout=case['stdout'], stdout=run.stdout.decode(),
                   files={p.name: digest(p) for p in folder.iterdir() if p.is_file()})
        rows.append(row)
        (BUILD / 'cases.json').write_text(json.dumps(rows, indent=2) + '\n')
        assert run.returncode == case['exit'] and run.stdout == case['stdout'].encode() and not run.stderr, \
            'deferred lexical output failed: ' + case['name']
        print('PASS ' + case['name'], flush=True)
    assert tools == {name: digest(ROOT / name) for name in tools}, 'deferred lexical tools changed'
    assert inputs == {path: digest(ROOT / path) for path in inputs}, 'deferred lexical sources changed'
    (BUILD / 'result.json').write_text(json.dumps(dict(status='PASS', tools=tools, inputs=inputs,
        cases=rows, scope='Existing lexical binding and late values only; no allocator-order qualification.'), indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=('validate', 'inversions', 'native'), default='native', nargs='?')
    {'validate': validate, 'inversions': inversions, 'native': native}[parser.parse_args().mode]()
