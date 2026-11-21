#!/usr/bin/env python3
"""Exact additive enrollment for the selected compile-only CR16 successor."""
import copy
import gzip
import hashlib
import json
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
KEY = 'cr16_scoped_fixture'
BASE = '39e37696b775b25827d54c1c5a52b005d30e386b'
PREDECESSOR = 'compiler/phase26-2-deferred-allocator-order/cr16-cleanup-predecessor-v1.json.gz'
PREDECESSOR_SHA256 = '615c00b15036c180c25adac8227c8f09d2260439a3ddf962966df7fdb1366e07'
PREDECESSOR_FILES = {
    'scripts/phase20_unsafe_mutex_migration.py': 'd8da255ba0ca89c075f911850d5a86bf92e6c3e1c734f7ec70af1e0b852e80d8',
    'compiler/CRANELIFT_PHASE20_UNSAFE_MUTEX_MIGRATION.md': '01dd1107f7fd93c129794d007a0c58b1d0575fdfc4ec67f77c716d9123d06a0d',
    'scripts/stdlib_s1_mutex_guard_scope_parity.sh': '46a248c2f81afa9c3c655e3c8ff834d96bc5942810de33ef6af3ee52af2d18d6',
    'docs/STDLIB_MUTEX_GUARD_SCOPE.md': '04d81b917095e7bc24297a47af35fbc924d887ea061820aa394cd40cc122b535',
}
ORIGINAL = 'tests/stdlib_s1_mutex_guard_scope_raw_double_unlock.gst'
SUCCESSOR = 'tests/stdlib_s1_mutex_guard_scope_raw_double_unlock_inner_scope.gst'
CONTRACT = dict(
    contract_version='phase26_2d_cr16_scoped_compile_only_v1',
    expectation='compile_only_never_execute',
    safe_raw_calls_added=0,
    added_call_site=dict(path=SUCCESSOR,
        role='stdlib_s1_9_scoped_raw_double_unlock_compile_only',
        lock_calls=0, unlock_calls=1),
    source_sha256='3c82f4786609c6ec0354846e31a55d9abc5478008f3d96a3a1090f1c26838d1e')
EVIDENCE = {
    ORIGINAL: '88be94b1cee6a138a5df33439f230a03be7414ef3fa93e006800f8fe5dd1ef55',
    SUCCESSOR: CONTRACT['source_sha256'],
    'tests/stdlib_s1_mutex_guard_generic_derivation_module.gst': '9f275fd64a4a8ff65b4be05ff25c81f10f777c507eefdf720ff5b2031d55bc07',
    'scripts/stdlib_s1_raw_double_unlock.py': '4a64ed38d2b7aca214007b7a632f442fe962fe9da21ad8c450bd7b2adbda5471',
    'scripts/stdlib_s1_raw_double_unlock_test.py': 'aa388f1fff2a8cf2ceea5c71f3830b6272f26ab701720ef039128a698e937795',
    'scripts/stdlib_s1_mutex_guard_scope_parity.sh': '321cbd085eb8752182b9d957930646279b511aacbee9dc977531204623256bf3',
    'scripts/stdlib_s1_mutex_guard_scope_refusal.py': 'f180d9c814848bf25a10c75934c286be49d3a818ab1ecf055360126fd07c6c9d',
    'scripts/stdlib_s1_mutex_guard_scope_refusal_test.py': 'acae6043d8bd684e96ad01136978e673de8a437473f6ef35303eb4bab10de2a7',
    'docs/STDLIB_MUTEX_GUARD_SCOPE.md': '69288dad85920336cdb53754cc58ae5ba7ec3e14db4cb421f4041b06ba958c67',
}


class ContractError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ContractError(message)


def checked_predecessor(value):
    from phase26_predecessor_data import decoded_payload
    require(set(value) == {'schema', 'base', 'files'} and
            value['schema'] == 'gust.cr16_cleanup_fixture.predecessor.v1' and
            value['base'] == BASE and set(value['files']) == set(PREDECESSOR_FILES),
            'CR16 predecessor identity or population drifted')
    for name, digest in PREDECESSOR_FILES.items():
        require(hashlib.sha256(decoded_payload(value['files'][name])).hexdigest() == digest,
                'CR16 predecessor payload drifted: ' + name)
    return value


def predecessor_bytes(name):
    from phase26_predecessor_data import decoded_payload
    raw = (ROOT / PREDECESSOR).read_bytes()
    require(hashlib.sha256(raw).hexdigest() == PREDECESSOR_SHA256,
            'CR16 predecessor archive drifted')
    require(name in PREDECESSOR_FILES, 'CR16 predecessor file is unregistered')
    value = checked_predecessor(json.loads(gzip.decompress(raw)))
    return decoded_payload(value['files'][name])


def registration(registry):
    return registry.get('phase26_activation_audit', {}).get(
        'allocator_identity_successor_v1', {}).get(KEY)


def registration_matches(row):
    # JSON booleans/floats must not compare equal to the exact integer counts.
    return json.dumps(row, sort_keys=True, separators=(',', ':')) == json.dumps(
        CONTRACT, sort_keys=True, separators=(',', ':'))


def registered_site(registry, root):
    row = registration(registry)
    if row is None:
        return None
    require(registration_matches(row), 'CR16 scoped registration drifted')
    path = root / SUCCESSOR
    require(path.is_file() and not path.is_symlink() and path.resolve() == path,
            'CR16 scoped source is missing or nonregular')
    require(hashlib.sha256(path.read_bytes()).hexdigest() == row['source_sha256'],
            'CR16 scoped source bytes drifted')
    return row['added_call_site']


def evidence(sources):
    require(set(sources) == set(EVIDENCE), 'CR16 evidence population drifted')
    for name, digest in EVIDENCE.items():
        require(hashlib.sha256(sources[name]).hexdigest() == digest,
                'CR16 evidence bytes drifted: ' + name)


def validate():
    import phase20_unsafe_mutex_migration as legacy
    registry = json.loads(legacy.REGISTRY.read_text())
    require(registered_site(registry, ROOT) is not None,
            'CR16 scoped registration is absent')
    sources = {}
    for name in EVIDENCE:
        path = ROOT / name
        require(path.is_file() and not path.is_symlink() and path.resolve() == path,
                'CR16 evidence is missing or nonregular: ' + name)
        sources[name] = path.read_bytes()
    evidence(sources)
    for name in PREDECESSOR_FILES:
        predecessor_bytes(name)
    authority, calls = legacy.validate()
    require(legacy.REVIEW.read_text() == legacy.render(authority),
            'CR16 compiler projection drifted')
    require([(call.method, call.explicit_unsafe) for call in calls
             if call.path == SUCCESSOR] == [('Unlock', True)],
            'CR16 scoped live call differs from its registration')
    return registry, calls, sources


def inversions():
    import phase20_unsafe_mutex_migration as legacy
    registry, calls, sources = validate()
    rows = []

    def reject(label, expected, action):
        try:
            action()
        except (ContractError, legacy.Error) as error:
            message = str(error)
            matched = message == expected or message.startswith(expected + ':')
            verdict = 'REJECTED (expected assertion)' if matched else 'REJECTED (different assertion)'
            rows.append(dict(label=label, verdict=verdict, assertion=message))
            require(matched, 'CR16 inversion used a different assertion: ' + label)
        else:
            raise ContractError('CR16 inversion ACCEPTED: ' + label)

    # Run the actual validator with its real inventory once, then mutate only
    # its registry/inventory inputs. No tracked source is removed or rewritten.
    output = ROOT / 'build/guards/phase26_2_cr16_cleanup_static'
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='controls-', dir=output) as tmp:
        candidate = Path(tmp) / 'registry.json'

        def validate_candidate(value, inventory=calls):
            candidate.write_text(json.dumps(value))
            with patch.object(legacy, 'REGISTRY', candidate), \
                    patch.object(legacy, 'complete_inventory', lambda: inventory):
                legacy.validate()

        validate_candidate(registry)
        omitted = copy.deepcopy(registry)
        omitted['phase26_activation_audit']['allocator_identity_successor_v1'].pop(KEY)
        reject('row is load-bearing', 'raw Mutex call-site classification drifted',
               lambda: validate_candidate(omitted))
        for label, field, replacement in (
                ('contract', 'contract_version', 'unregistered'),
                ('execution', 'expectation', 'native_execute'),
                ('safe-call waiver', 'safe_raw_calls_added', 1),
                ('boolean count', 'safe_raw_calls_added', False),
                ('float count', 'safe_raw_calls_added', 0.0),
                ('source digest', 'source_sha256', '0' * 64)):
            changed = copy.deepcopy(registry)
            changed['phase26_activation_audit']['allocator_identity_successor_v1'][KEY][field] = replacement
            reject(label, 'CR16 scoped registration drifted', lambda changed=changed: validate_candidate(changed))
        for field, replacement in (('path', ORIGINAL), ('role', 'unowned'),
                                   ('lock_calls', 1), ('unlock_calls', 2)):
            changed = copy.deepcopy(registry)
            changed['phase26_activation_audit']['allocator_identity_successor_v1'][KEY]['added_call_site'][field] = replacement
            reject('site ' + field, 'CR16 scoped registration drifted',
                   lambda changed=changed: validate_candidate(changed))
        from dataclasses import replace
        site = next(call for call in calls if call.path == SUCCESSOR)
        for method in ('Lock', 'Unlock'):
            changed = calls + [replace(site, method=method)]
            reject('extra ' + method, 'CR16 scoped raw call shape drifted',
                   lambda changed=changed: validate_candidate(registry, changed))
        changed = [replace(call, explicit_unsafe=False) if call.path == SUCCESSOR else call for call in calls]
        reject('safe raw call', 'raw Mutex-style method call outside explicit unsafe differs from the exact Patch 20.16d enforcement-negative fixtures',
               lambda: validate_candidate(registry, changed))
        changed = calls + [replace(site, path='tests/unregistered_raw_sibling.gst')]
        reject('unregistered sibling', 'raw Mutex call-site classification drifted',
               lambda: validate_candidate(registry, changed))
        real_is_file, real_is_symlink, real_read = Path.is_file, Path.is_symlink, Path.read_bytes
        path = ROOT / SUCCESSOR
        with patch.object(Path, 'is_file', lambda p: False if p == path else real_is_file(p)):
            reject('missing successor', 'CR16 scoped source is missing or nonregular', lambda: registered_site(registry, ROOT))
        with patch.object(Path, 'is_symlink', lambda p: True if p == path else real_is_symlink(p)):
            reject('successor symlink', 'CR16 scoped source is missing or nonregular', lambda: registered_site(registry, ROOT))
        source = sources[SUCCESSOR]
        start = source.index(b'    if 1 {\n')
        end = source.index(b'    }\n    return 0;', start)
        inner = source[start + len(b'    if 1 {\n'):end]
        unscoped = source[:start] + b''.join(line[4:] + b'\n' for line in inner.splitlines()) + source[end + len(b'    }\n'):]
        for label, replacement in (
                ('inner scope removed', unscoped),
                ('owner removed', sources[SUCCESSOR].replace(b'        mut owner := sync.lock(&mutex);\n', b'', 1))):
            require(replacement != sources[SUCCESSOR], 'CR16 mutation did not move')
            with patch.object(Path, 'read_bytes', lambda p, value=replacement: value if p == path else real_read(p)):
                reject(label, 'CR16 scoped source bytes drifted', lambda: registered_site(registry, ROOT))
    for name in EVIDENCE:
        changed = dict(sources)
        changed[name] += b'\n'
        reject('evidence ' + name, 'CR16 evidence bytes drifted: ' + name,
               lambda changed=changed: evidence(changed))
    real_text = Path.read_text
    with patch.object(Path, 'read_text', lambda p, *a, **k:
                      real_text(p, *a, **k) + '\n' if p == legacy.REVIEW else real_text(p, *a, **k)):
        reject('live projection drift', 'CR16 compiler projection drifted', validate)
    previous = checked_predecessor(json.loads(gzip.decompress((ROOT / PREDECESSOR).read_bytes())))
    for field, replacement in (('schema', 'unregistered'), ('base', '0' * 40)):
        changed = copy.deepcopy(previous)
        changed[field] = replacement
        reject('predecessor ' + field, 'CR16 predecessor identity or population drifted',
               lambda changed=changed: checked_predecessor(changed))
    for name in PREDECESSOR_FILES:
        changed = copy.deepcopy(previous)
        changed['files'].pop(name)
        reject('predecessor missing ' + name, 'CR16 predecessor identity or population drifted',
               lambda changed=changed: checked_predecessor(changed))
        changed = copy.deepcopy(previous)
        changed['files'][name] = 'Y2hhbmdlZA=='
        reject('predecessor substituted ' + name, 'CR16 predecessor payload drifted: ' + name,
               lambda changed=changed: checked_predecessor(changed))
    real_read = Path.read_bytes
    with patch.object(Path, 'read_bytes', lambda p: real_read(p) + b'changed' if p == ROOT / PREDECESSOR else real_read(p)):
        reject('predecessor archive substituted', 'CR16 predecessor archive drifted',
               lambda: predecessor_bytes(next(iter(PREDECESSOR_FILES))))
    validate()
    print(json.dumps(dict(status='PASS CR16 exact registration/evidence inversions',
                         controls=rows, program_executions=0), indent=2))


if __name__ == '__main__':
    {'validate': validate, 'inversions': inversions}[sys.argv[1]]()
