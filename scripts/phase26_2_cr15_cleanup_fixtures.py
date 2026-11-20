#!/usr/bin/env python3
"""Preserve historical CR15 witnesses and qualify their scoped successors."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'compiler/phase26-2-deferred-allocator-order/cr15-cleanup-fixtures.json'
MANIFEST_SHA256 = '075bab82ecea298f66b9d7337233f61c44c1ae9ccc9e9b358912f53481e7684a'
ORIGINALS = {
    'native_inferred': '0f2781b567bb7540ab138b50af5a0fd7225ff6f4bc467c4450742f9107096cd4',
    'native_explicit': 'b366f8d92c84dd295905f1fbeb7acf90ca18e9347a0f5e1d968889687cf34182',
    'native_second_type': '4e9f3c19f8dd60a180045837d7b690945f17760e7c8f10680387fe0a443500bc',
}
SUPPORT = 'tests/stdlib_s1_mutex_guard_generic_derivation_module.gst'
SUPPORT_SHA256 = '9f275fd64a4a8ff65b4be05ff25c81f10f777c507eefdf720ff5b2031d55bc07'
HISTORICAL = dict(status='UNQUALIFIED historical native-positive expectation under current cleanup-order validation',
                  routes=['default', 'cranelift'], compile_exit=0)
REFUSAL = dict(compile_exit=1, diagnostic='[LinearResourceLeak]',
               worker_reached=False, program_executed=False)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def scoped_source(original):
    start = original.index(b'    mut mutex:')
    end = original.index(b'    return 0;', start)
    inner = b''.join(b'    ' + line + b'\n' for line in original[start:end].splitlines())
    return original[:start] + b'    {\n' + inner + b'    }\n' + original[end:]


def check_mapping(value, sources):
    assert set(value) == {'contract', 'original_expectation', 'current_original_expectation', 'support', 'cases'}, 'fixture contract fields drifted'
    assert value['contract'] == 'phase26_cr15_cleanup_fixtures_v1', 'fixture contract version drifted'
    assert value['original_expectation'] == HISTORICAL, 'historical positive expectation relabelled'
    assert value['current_original_expectation'] == REFUSAL, 'original refusal weakened'
    assert value['support'] == dict(path=SUPPORT, sha256=SUPPORT_SHA256), 'support contract drifted'
    assert digest(sources[SUPPORT]) == SUPPORT_SHA256, 'support source bytes drifted'
    assert [row['role'] for row in value['cases']] == list(ORIGINALS), 'selected three-fixture population drifted'
    for row in value['cases']:
        assert set(row) == {'role', 'original', 'original_sha256', 'successor', 'successor_sha256'}, 'fixture row fields drifted'
        role = row['role']
        original = 'tests/phase24_cr15_protected_resource_' + role + '.gst'
        successor = original.removesuffix('.gst') + '_scoped.gst'
        assert row['original'] == original, 'original path drifted'
        assert row['original_sha256'] == ORIGINALS[role], 'original digest drifted'
        assert digest(sources[original]) == ORIGINALS[role], 'original source bytes drifted'
        assert row['successor'] == successor, 'positive successor route drifted'
        assert sources[successor] == scoped_source(sources[original]), 'scoped source bytes drifted'
        assert digest(sources[successor]) == row['successor_sha256'], 'successor digest drifted'


def validate():
    raw = MANIFEST.read_bytes()
    assert digest(raw) == MANIFEST_SHA256, 'fixture manifest digest drifted'
    value = json.loads(raw)
    paths = [SUPPORT] + [row[key] for row in value['cases'] for key in ('original', 'successor')]
    sources = {}
    for name in paths:
        path = ROOT / name
        assert path.is_file() and not path.is_symlink(), 'fixture source is not a regular file'
        sources[name] = path.read_bytes()
    check_mapping(value, sources)
    return value, sources


def inversions():
    value, sources = validate()
    outcomes = []

    def refuse(label, expected, change=None, change_sources=None):
        candidate, payloads = copy.deepcopy(value), dict(sources)
        if change:
            change(candidate)
        if change_sources:
            change_sources(candidate, payloads)
        try:
            check_mapping(candidate, payloads)
        except AssertionError as error:
            outcome = 'REJECTED (expected assertion)' if str(error) == expected else 'REJECTED (different assertion)'
            outcomes.append(dict(label=label, outcome=outcome, assertion=str(error)))
            assert outcome == 'REJECTED (expected assertion)', outcomes[-1]
        else:
            raise AssertionError(label + ': ACCEPTED')

    refuse('missing original', 'selected three-fixture population drifted', lambda v: v['cases'].pop())
    refuse('duplicate original', 'selected three-fixture population drifted', lambda v: v['cases'].append(copy.deepcopy(v['cases'][0])))
    refuse('directory authority added', 'selected three-fixture population drifted', lambda v: v['cases'][0].update(role='unbound_directory'))
    refuse('reordered cohort', 'selected three-fixture population drifted', lambda v: v['cases'].reverse())
    refuse('original path changed', 'original path drifted', lambda v: v['cases'][0].update(original='../other.gst'))
    refuse('original digest changed', 'original digest drifted', lambda v: v['cases'][0].update(original_sha256='0' * 64))
    refuse('original bytes changed', 'original source bytes drifted', change_sources=lambda v, s: s.update({v['cases'][0]['original']: b'changed'}))
    refuse('unsafe original readmitted', 'positive successor route drifted', lambda v: v['cases'][0].update(successor=v['cases'][0]['original']))
    refuse('successor digest changed', 'successor digest drifted', lambda v: v['cases'][0].update(successor_sha256='0' * 64))

    def replace_successor(v, s, payload):
        row = v['cases'][0]
        s[row['successor']] = payload(s[row['original']], s[row['successor']])
        row['successor_sha256'] = digest(s[row['successor']])

    refuse('scope removed despite rehash', 'scoped source bytes drifted', change_sources=lambda v, s: replace_successor(v, s, lambda old, new: old))
    refuse('outer behavior changed despite rehash', 'scoped source bytes drifted', change_sources=lambda v, s: replace_successor(v, s, lambda old, new: new.replace(b'return 0;', b'return 1;')))
    refuse('support digest changed', 'support contract drifted', lambda v: v['support'].update(sha256='0' * 64))
    refuse('support bytes changed', 'support source bytes drifted', change_sources=lambda v, s: s.update({SUPPORT: b'changed'}))
    refuse('historical pass relabelled', 'historical positive expectation relabelled', lambda v: v['original_expectation'].update(status='PASS'))
    refuse('historical exit rewritten', 'historical positive expectation relabelled', lambda v: v['original_expectation'].update(compile_exit=1))
    refuse('refusal diagnostic removed', 'original refusal weakened', lambda v: v['current_original_expectation'].update(diagnostic=''))
    refuse('new authority field', 'fixture contract fields drifted', lambda v: v.update(directory_selected=True))
    assert len(outcomes) == 17
    return outcomes


def successors(witnesses):
    value, _ = validate()
    for row in value['cases']:
        assert witnesses[row['role']] == ROOT / row['original'], 'historical owning witness route drifted'
    return {row['role']: ROOT / row['successor'] for row in value['cases']}


def reject_originals(compiler):
    """Require frontend refusals; a false worker makes accidental admission fail."""
    value, _ = validate()
    parent = ROOT / 'build/guards'
    parent.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix='phase26_cr15_cleanup_', dir=parent))
    rows = []
    for row in value['cases']:
        for route in ([], ['--backend', 'cranelift']):
            label = row['role'] + ('-default' if not route else '-cranelift')
            artifact = output / label
            command = [str(compiler), *route, '-o', str(artifact), str(ROOT / row['original'])]
            result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=120,
                                    env=dict(os.environ, GUST_NATIVE_BACKEND_DRIVER='/bin/false'))
            (output / (label + '.stdout')).write_bytes(result.stdout)
            (output / (label + '.stderr')).write_bytes(result.stderr)
            (output / (label + '.status')).write_text(str(result.returncode) + '\n')
            passed = (result.returncode == 1 and not result.stderr and
                      b'[LinearResourceLeak]' in result.stdout and
                      b'Deferred allocator Free executes before dependent cleanup' in result.stdout and
                      not artifact.exists() and not artifact.is_symlink())
            rows.append(dict(role=row['role'], route=route, command=command, compile_exit=result.returncode,
                             stdout_sha256=digest(result.stdout), stderr_sha256=digest(result.stderr),
                             passed=passed, program_executed=False))
            (output / 'result.json').write_text(json.dumps(dict(cases=rows), indent=2) + '\n')
            assert passed, 'original cleanup-order refusal failed: ' + label
    print('CR15_CLEANUP_ORIGINAL_REFUSALS_PASS ' + str(output))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=('validate', 'inversions'))
    args = parser.parse_args()
    validate()
    if args.command == 'inversions':
        print(json.dumps(inversions(), indent=2))
    print('phase26_cr15_cleanup_fixtures: ' + args.command + ' PASS')
