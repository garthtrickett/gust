#!/usr/bin/env python3
"""Preserve unsafe historical witnesses and require scoped positive successors."""
import argparse
import base64
import copy
from functools import lru_cache
import gzip
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

from phase26_2_cr15_cleanup_fixtures import frontend_refusal, refusal_controls

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'compiler/phase26-2-deferred-allocator-order/cleanup-witnesses.json'
MANIFEST_SHA256 = '155dd067deb8e2dadff8a7975a18bf40c9b8418237cc81723ec86fbccbc7de5e'
ORIGINALS = {
    'qualification_inferred': ('tests/phase24_cr15_qualification_positive.gst',
        '1b5ebd3679f9c0790b504dbc5ef9538ea23dedc731fd376b93561a5d4e6b5fe9'),
    'qualification_explicit': ('tests/phase24_cr15_qualification_explicit.gst',
        '7df0159f34dc57dd64a3306064672be2dee600cb79427c2eff41bd59cfcbe8c8'),
    'directory_unbound': ('compiler/future/p20_issue106_unbound_directory_current.gst',
        'f0f12baf396c5baa7a0119bb52cd44de70ef26ea9f1d7d85fa73b65c54ef0bea'),
}
SUPPORTS = {'tests/phase24_cr15_qualification_module.gst': 'bced9d4aee1e7bd66314b08ac6be8f8507dbc8f583b50ccb96b111ede2663f7e'}
HISTORICAL = {'status': 'UNQUALIFIED historical native-positive expectation',
              'compile_exit': 0, 'routes': ['default', 'cranelift']}
REFUSAL = {'compile_exit': 1, 'diagnostic': '[LinearResourceLeak]',
           'worker_reached': False, 'program_executed': False}
DIRECTORY_RECIPE = 'phase26-cleanup-directory-positive'
DIRECTORY_LABELS = ('phase20_resource_cleanup_unbound_directory',
                    'phase20_resource_scope_cleanup_unbound_directory')
PREDECESSOR = 'compiler/phase26-2-deferred-allocator-order/cleanup-witness-predecessor-v1.json.gz'
PREDECESSOR_SHA256 = 'c6984ca239f79c98cb66f9407ddd8e654c159f735e3381eae12cc878b697136e'
PREDECESSOR_BASE = '39e37696b775b25827d54c1c5a52b005d30e386b'
PREDECESSOR_FILES = {
    'scripts/phase24_cr15_qualification.py': '13fa77156c2aa97113fc3303460f0ad1b0db5ac3d6ce55c9908ff11179aeddc1',
    'compiler/CRANELIFT_PHASE24_CR15_QUALIFICATION.md': '4e4bebb53af1d8376672b1fc59f2eb49813bf37fd8455f839a8ffccb0d5237e4',
    'scripts/phase20_resource_acquisition.py': '74926ed7c1d0f4cd03a19febc641d09a98a9f83e57af28af1c62526c7e4828f7',
    'compiler/CRANELIFT_PHASE20_RESOURCE_ACQUISITION_OBLIGATIONS.md': '357f69e8677975fb42382beae2c721527533ee88f90da797f2f9802582a88a19',
}
DIRECTORY_JUST_RECIPE = (
    '\n# Selected fixture-only successor; original remains a frontend-only refusal witness.\n'
    'phase26-cleanup-directory-positive label:\n'
    '    python3 scripts/phase26_2_cleanup_witnesses.py reject-directory\n'
    '    just guard-compile-pass compiler/future/p20_issue106_unbound_directory_current_scoped.gst {{label}}\n')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def checked_predecessor(value):
    assert (set(value) == {'schema', 'base', 'files'} and
            value['schema'] == 'gust.cleanup_witness.predecessor.v1' and
            value['base'] == PREDECESSOR_BASE and
            set(value['files']) == set(PREDECESSOR_FILES)), 'cleanup predecessor identity or population drifted'
    for name, expected in PREDECESSOR_FILES.items():
        assert digest(base64.b64decode(value['files'][name], validate=True)) == expected, 'cleanup predecessor payload drifted'
    return value


@lru_cache(maxsize=1)
def decoded_predecessor(raw):
    return checked_predecessor(json.loads(gzip.decompress(raw)))


def predecessor_bytes(name):
    raw = (ROOT / PREDECESSOR).read_bytes()
    assert digest(raw) == PREDECESSOR_SHA256, 'cleanup predecessor archive drifted'
    assert name in PREDECESSOR_FILES, 'unknown cleanup predecessor file'
    return base64.b64decode(decoded_predecessor(raw)['files'][name], validate=True)


def predecessor_controls():
    from unittest.mock import patch
    value = checked_predecessor(json.loads(gzip.decompress((ROOT / PREDECESSOR).read_bytes())))
    rows = []

    def reject(label, expected, fn):
        try:
            fn()
        except AssertionError as error:
            verdict = 'REJECTED (expected assertion)' if str(error) == expected else 'REJECTED (different assertion)'
            rows.append(dict(label=label, outcome=verdict, assertion=str(error)))
            assert verdict == 'REJECTED (expected assertion)', rows[-1]
        else:
            raise AssertionError(label + ': ACCEPTED')

    original_read = Path.read_bytes
    with patch.object(Path, 'read_bytes', lambda p: original_read(p) + b'changed' if p == ROOT / PREDECESSOR else original_read(p)):
        reject('changed archive bytes', 'cleanup predecessor archive drifted', lambda: predecessor_bytes(next(iter(PREDECESSOR_FILES))))
    for key, replacement in (('schema', 'unselected'), ('base', '0' * 40)):
        changed = copy.deepcopy(value)
        changed[key] = replacement
        reject('changed ' + key, 'cleanup predecessor identity or population drifted', lambda changed=changed: checked_predecessor(changed))
    changed = copy.deepcopy(value)
    changed['files']['unselected.gst'] = base64.b64encode(b'unselected').decode()
    reject('extra predecessor file', 'cleanup predecessor identity or population drifted', lambda: checked_predecessor(changed))
    for name in PREDECESSOR_FILES:
        omitted = copy.deepcopy(value)
        omitted['files'].pop(name)
        reject('omitted ' + name, 'cleanup predecessor identity or population drifted', lambda omitted=omitted: checked_predecessor(omitted))
        substituted = copy.deepcopy(value)
        substituted['files'][name] = base64.b64encode(b'changed').decode()
        reject('substituted ' + name, 'cleanup predecessor payload drifted', lambda substituted=substituted: checked_predecessor(substituted))
    reject('unknown predecessor lookup', 'unknown cleanup predecessor file', lambda: predecessor_bytes('unselected.gst'))
    assert len(rows) == 13
    return rows


def directory_justfile(predecessor):
    """Change exactly the two named logical witness consumers and append their helper."""
    result = predecessor.decode()
    original = ORIGINALS['directory_unbound'][0]
    assert 'phase26-cleanup-directory-positive label:' not in result, 'directory helper already present in predecessor'
    for label in DIRECTORY_LABELS:
        old = '    just guard-compile-pass ' + original + ' ' + label
        assert result.count(old) == 1, 'directory predecessor consumer drifted'
        result = result.replace(old, '    just ' + DIRECTORY_RECIPE + ' ' + label)
    return (result + DIRECTORY_JUST_RECIPE).encode()


def check_directory_routes(just):
    for label in DIRECTORY_LABELS:
        assert just.count('    just ' + DIRECTORY_RECIPE + ' ' + label + '\n') == 1, 'directory successor consumer drifted'
        assert ('    just guard-compile-pass ' + ORIGINALS['directory_unbound'][0] + ' ' + label) not in just, 'unsafe directory positive readmitted'
    assert just.count(DIRECTORY_JUST_RECIPE) == 1, 'directory positive/refusal helper drifted'


def route_controls():
    just = (ROOT / 'justfile').read_text()
    check_directory_routes(just)
    changes = []
    for label in DIRECTORY_LABELS:
        current = '    just ' + DIRECTORY_RECIPE + ' ' + label + '\n'
        old = '    just guard-compile-pass ' + ORIGINALS['directory_unbound'][0] + ' ' + label + '\n'
        changes.append(('unsafe original ' + label, just.replace(current, old), 'directory successor consumer drifted'))
        changes.append(('duplicated consumer ' + label, just.replace(current, current + current), 'directory successor consumer drifted'))
    changes.append(('missing helper', just.replace(DIRECTORY_JUST_RECIPE, ''), 'directory positive/refusal helper drifted'))
    changed_helper = DIRECTORY_JUST_RECIPE.replace('_current_scoped.gst', '_current.gst')
    changes.append(('unsafe helper input', just.replace(DIRECTORY_JUST_RECIPE, changed_helper), 'directory positive/refusal helper drifted'))
    outcomes = []
    for label, changed, expected in changes:
        assert changed != just, 'routing mutation did not move: ' + label
        try:
            check_directory_routes(changed)
        except AssertionError as error:
            verdict = 'REJECTED (expected assertion)' if str(error) == expected else 'REJECTED (different assertion)'
            outcomes.append(dict(label=label, outcome=verdict, assertion=str(error)))
            assert verdict == 'REJECTED (expected assertion)', outcomes[-1]
        else:
            raise AssertionError(label + ': ACCEPTED')
    assert len(outcomes) == 6
    return outcomes


def scoped_source(role, original):
    if role == 'directory_unbound':
        start = original.index(b'    mut opt_dir')
        end = original.rindex(b'}')
    else:
        assert role in ('qualification_inferred', 'qualification_explicit'), 'unknown fixture role'
        start = original.index(b'    mut repeated')
        end = original.index(b'    return 0;', start)
    chunk = original[start:end]
    inner = b''.join(b'    ' + line if line.strip() else line
                     for line in chunk.splitlines(keepends=True))
    return original[:start] + b'    if 1 {\n' + inner + b'    }\n' + original[end:]


def check_mapping(value, sources):
    assert set(value) == {'contract', 'original_expectation', 'current_original_expectation', 'supports', 'cases'}, 'cleanup witness fields drifted'
    assert value['contract'] == 'phase26_cleanup_witnesses_v1', 'cleanup witness contract drifted'
    assert value['original_expectation'] == HISTORICAL, 'historical positive relabelled'
    assert value['current_original_expectation'] == REFUSAL, 'original refusal weakened'
    assert value['supports'] == SUPPORTS, 'support contract drifted'
    for name, expected in SUPPORTS.items():
        assert digest(sources[name]) == expected, 'support source drifted'
    assert [row['role'] for row in value['cases']] == list(ORIGINALS), 'selected witness population drifted'
    for row in value['cases']:
        assert set(row) == {'role', 'original', 'original_sha256', 'successor', 'successor_sha256'}, 'witness row fields drifted'
        role = row['role']
        name, expected = ORIGINALS[role]
        assert row['original'] == name and row['original_sha256'] == expected, 'original identity drifted'
        assert digest(sources[name]) == expected, 'original source drifted'
        successor = name.removesuffix('.gst') + '_scoped.gst'
        assert row['successor'] == successor, 'positive successor route drifted'
        assert sources[successor] == scoped_source(role, sources[name]), 'scoped witness bytes drifted'
        assert digest(sources[successor]) == row['successor_sha256'], 'scoped witness digest drifted'


def validate():
    raw = MANIFEST.read_bytes()
    assert digest(raw) == MANIFEST_SHA256, 'cleanup witness manifest drifted'
    value = json.loads(raw)
    paths = [*SUPPORTS, *(name for row in value['cases'] for name in (row['original'], row['successor']))]
    sources = {}
    for name in paths:
        path = ROOT / name
        assert path.is_file() and not path.is_symlink(), 'witness is not a regular file'
        sources[name] = path.read_bytes()
    check_mapping(value, sources)
    check_directory_routes((ROOT / 'justfile').read_text())
    return value, sources


def inversions():
    value, sources = validate()
    outcomes = []

    def reject(label, expected, change=None, change_sources=None):
        candidate, payloads = copy.deepcopy(value), dict(sources)
        if change:
            change(candidate)
        if change_sources:
            change_sources(candidate, payloads)
        try:
            check_mapping(candidate, payloads)
        except AssertionError as error:
            result = 'REJECTED (expected assertion)' if str(error) == expected else 'REJECTED (different assertion)'
            outcomes.append(dict(label=label, outcome=result, assertion=str(error)))
            assert result == 'REJECTED (expected assertion)', outcomes[-1]
        else:
            raise AssertionError(label + ': ACCEPTED')

    reject('omitted witness', 'selected witness population drifted', lambda v: v['cases'].pop())
    reject('duplicated witness', 'selected witness population drifted', lambda v: v['cases'].append(copy.deepcopy(v['cases'][0])))
    reject('unselected witness', 'selected witness population drifted', lambda v: v['cases'][0].update(role='unselected'))
    reject('reordered witnesses', 'selected witness population drifted', lambda v: v['cases'].reverse())
    for index, role in enumerate(ORIGINALS):
        reject(role + ' original identity', 'original identity drifted', lambda v, i=index: v['cases'][i].update(original_sha256='0' * 64))
        reject(role + ' original bytes', 'original source drifted', change_sources=lambda v, s, i=index: s.update({v['cases'][i]['original']: b'changed'}))
        reject(role + ' unsafe positive route', 'positive successor route drifted', lambda v, i=index: v['cases'][i].update(successor=v['cases'][i]['original']))
        reject(role + ' successor digest', 'scoped witness digest drifted', lambda v, i=index: v['cases'][i].update(successor_sha256='0' * 64))

        def changed_scope(v, s, i=index):
            row = v['cases'][i]
            s[row['successor']] = s[row['original']]
            row['successor_sha256'] = digest(s[row['successor']])

        reject(role + ' removed scope despite rehash', 'scoped witness bytes drifted', change_sources=changed_scope)

        def changed_behavior(v, s, i=index):
            row = v['cases'][i]
            needle, replacement = ((b'"src"', b'"missing"') if row['role'] == 'directory_unbound'
                                   else (b'repeated_access.value = repeated_access.value + 1;',
                                         b'repeated_access.value = repeated_access.value + 2;'))
            assert s[row['successor']].count(needle) == 1, 'behavior mutation did not move'
            s[row['successor']] = s[row['successor']].replace(needle, replacement)
            row['successor_sha256'] = digest(s[row['successor']])

        reject(role + ' changed outer bytes despite rehash', 'scoped witness bytes drifted', change_sources=changed_behavior)
    support = next(iter(SUPPORTS))
    reject('support contract', 'support contract drifted', lambda v: v['supports'].update({support: '0' * 64}))
    reject('support source', 'support source drifted', change_sources=lambda v, s: s.update({support: b'changed'}))
    reject('historical pass relabelled', 'historical positive relabelled', lambda v: v['original_expectation'].update(status='PASS'))
    reject('refusal removed', 'original refusal weakened', lambda v: v['current_original_expectation'].update(diagnostic=''))
    reject('new authority', 'cleanup witness fields drifted', lambda v: v.update(new_semantics=True))
    assert len(outcomes) == 27 and len({row['label'] for row in outcomes}) == 27
    return outcomes


def successor(role):
    value, _ = validate()
    return ROOT / next(row['successor'] for row in value['cases'] if row['role'] == role)


def qualification_successors(witnesses):
    result = dict(witnesses)
    for key, role in (('inferred', 'qualification_inferred'), ('explicit', 'qualification_explicit')):
        assert result[key] == ROOT / ORIGINALS[role][0], 'historical qualification route drifted'
        result[key] = successor(role)
    return result


def reject_originals(compiler, roles):
    value, _ = validate()
    assert roles and len(set(roles)) == len(roles) and set(roles) <= set(ORIGINALS), 'invalid refusal cohort'
    parent = ROOT / 'build/guards'
    parent.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix='phase26_cleanup_witness_', dir=parent))
    rows = []
    for row in value['cases']:
        if row['role'] not in roles:
            continue
        for route in ([], ['--backend', 'cranelift']):
            label = row['role'] + ('-default' if not route else '-cranelift')
            artifact = output / label
            command = [str(compiler), *route, '-o', str(artifact), str(ROOT / row['original'])]
            result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=120,
                                    env=dict(os.environ, GUST_NATIVE_BACKEND_DRIVER='/bin/false'))
            (output / (label + '.stdout')).write_bytes(result.stdout)
            (output / (label + '.stderr')).write_bytes(result.stderr)
            (output / (label + '.status')).write_text(str(result.returncode) + '\n')
            artifact_present = artifact.exists() or artifact.is_symlink()
            passed = frontend_refusal(result.returncode, result.stdout, result.stderr, artifact_present)
            rows.append(dict(role=row['role'], route=route, command=command, compile_exit=result.returncode,
                             stdout_sha256=digest(result.stdout), stderr_sha256=digest(result.stderr),
                             artifact_present=artifact_present, program_executed=False, passed=passed))
            (output / 'result.json').write_text(json.dumps(dict(cases=rows), indent=2) + '\n')
            assert passed, 'original cleanup refusal failed: ' + label
    print('CLEANUP_WITNESS_ORIGINAL_REFUSALS_PASS ' + str(output))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=('validate', 'inversions', 'reject-directory'))
    args = parser.parse_args()
    validate()
    if args.command == 'inversions':
        print(json.dumps(dict(mapping=inversions(), routes=route_controls(), predecessor=predecessor_controls(),
                              refusal=refusal_controls()), indent=2))
    if args.command == 'reject-directory':
        inversions()
        refusal_controls()
        reject_originals(ROOT / 'gust', ['directory_unbound'])
    print('phase26_cleanup_witnesses: ' + args.command + ' PASS')
