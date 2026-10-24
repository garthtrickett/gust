#!/usr/bin/env python3
"""Additive lexical allocator-proof enrollment over merged direct invalidation."""
from __future__ import annotations
import base64
import copy
from functools import lru_cache
import gzip
import hashlib
import importlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
BASE = '9df2eb10291caa6a76e5cc1c2c20a7488a54e67d'
KEY = 'allocator_identity_successor_v1'
GUARD = 'guard-cranelift-phase26-2-allocator-identities'
STATE = 'GUST_LANE_STATE.md'
BASELINE = 'compiler/phase26-2-allocator-identity/predecessor-baseline.json.gz'
BASELINE_SHA256 = '38118f9047355b4a925a313c58221283c565a85ea945fd933c45b36390c5f10b'
REGISTRY = ROOT / 'scripts/cranelift_feature_registry.json'
ANCESTOR_REGISTRATIONS = ('phase26_2_allocator_registration', 'phase26_release_registration',
    'phase26_readonly_input_copy_registration', 'phase26_ticket_composition_registration',
    'phase26_imported_native_registration', 'phase26_ticket_publication_registration')
CHANGED = ('compiler/typechecker.gst', 'TASK.md', 'justfile',
    'scripts/cranelift_test_levels.json', 'scripts/phase26_2_allocator_registration.py',
    'compiler/phase26-release/release.json', 'compiler/phase26-release/reachable-audit.json')
ADDED = (BASELINE, 'scripts/phase26_2_allocator_identity_registration.py',
    'scripts/phase26_2_allocator_identity_guard.py',
    'compiler/phase26-2-allocator-identity/cases.json',
    'compiler/phase26-2-allocator-identity/proof_facts.gst',
    '.github/workflows/phase26-2-allocator-identity.yml',
    'compiler/CRANELIFT_PHASE26_2_ALLOCATOR_IDENTITIES.md')
RECIPE = ('\n# Lexical allocator proof identities and immutable actual-origin dependencies.\n' + GUARD + ':\n'
    '    python3 scripts/phase26_2_allocator_identity_registration.py validate\n'
    '    python3 scripts/phase26_2_allocator_identity_registration.py inversions\n'
    '    python3 scripts/phase26_2_allocator_identity_guard.py\n')


def require(ok, message):
    if not ok:
        raise SystemExit(GUARD + ': ' + message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def fingerprint(value):
    return sha(json.dumps(value, sort_keys=True, separators=(',', ':')).encode())


@lru_cache(maxsize=1)
def baseline():
    raw = (ROOT / BASELINE).read_bytes()
    require(sha(raw) == BASELINE_SHA256, 'allocator identity predecessor baseline bytes drifted')
    value = json.loads(gzip.decompress(raw))
    require(value['base'] == BASE, 'allocator identity predecessor identity drifted')
    return value


def base_bytes(path):
    return base64.b64decode(baseline()['files'][path], validate=True)


def record(registry):
    return registry.get('phase26_activation_audit', {}).get(KEY)


def identity(registry):
    row = record(registry)
    require(row and row['predecessor_main'] == BASE and row['owner'] == 'cranelift' and
        row['guard'] == GUARD and row['phase26_2_status'] == 'OPEN' and
        row['od23'] == 'OPEN; no slot ownership or admission selected' and
        row['operational_state_excluded'] == STATE and
        [p['path'] for p in row['changed_files']] == list(CHANGED) and
        [p['path'] for p in row['added_files']] == list(ADDED),
        'allocator proof identity, file population or operational-state retirement drifted')
    require((ROOT / STATE).is_file() and (ROOT / STATE).stat().st_size > 0,
            'operational lane state is absent')
    return row


def prior_digest(registry, path, live):
    if not record(registry) or path not in CHANGED:
        return live
    pin = next(p for p in identity(registry)['changed_files'] if p['path'] == path)
    admitted = {pin['current_digest'], pin['previous_digest']}
    predecessor = json.loads(base_bytes('scripts/cranelift_feature_registry.json'))
    for key in ('allocator_resource_liveness_successor_v1', 'first_release_closure_successor_v1', 'readonly_input_copy_successor_v1',
                'closed_ticket_composition_successor_v1', 'imported_native_successor_v1',
                'scoped_ticket_publication_successor_v1'):
        for item in predecessor['phase26_activation_audit'][key]['changed_files']:
            if item['path'] == path:
                admitted.update(item[field] for field in ('current_digest', 'previous_digest'))
    require(sha((ROOT / path).read_bytes()) == pin['current_digest'] and
        pin['previous_digest'] == sha(base_bytes(path)) and
        live in admitted,
        'R4 changed file drifted: ' + path + ' (allocator identity successor)')
    return pin['previous_digest']


def prior_bytes(registry, path, live):
    if not record(registry) or path not in CHANGED:
        return live
    prior_digest(registry, path, sha(live))
    return base_bytes(path)


def operational_text(kind, current):
    require(isinstance(current, list) and all(isinstance(p, dict) and 'path' in p for p in current),
            'R4 ' + kind + ' live projection drifted (allocator identity successor)')
    require(sum(p['path'] == STATE for p in current) <= 1,
            'R4 ' + kind + ' live projection drifted (allocator identity successor)')
    return sorted(copy.deepcopy([p for p in current if p['path'] != STATE] +
        [p for p in baseline()['projections'][kind] if p['path'] == STATE]), key=lambda p: p['path'])


def canonical_projection(kind, current):
    if kind in ('text', 'r4_text'):
        return operational_text(kind, current)
    if kind == 'r4_record':
        previous = baseline()['projections'][kind]
        require(isinstance(current, dict) and set(current) == set(previous),
                'R4 r4_record live projection drifted (allocator identity successor)')
        result = copy.deepcopy(current)
        states = [p for p in result['changed_files'] if p['path'] == STATE]
        require(len(states) == 1, 'R4 r4_record live projection drifted (allocator identity successor)')
        old_state = next(p for p in previous['changed_files'] if p['path'] == STATE)
        require(states[0]['previous_digest'] == old_state['previous_digest'] and
                states[0]['current_digest'] in (sha((ROOT / STATE).read_bytes()), old_state['current_digest']),
                'R4 r4_record live projection drifted (allocator identity successor)')
        states[0]['current_digest'] = old_state['current_digest']
        import phase26_r3_zlib_adapter_registration as r3
        import phase26_r4_collection_registration as r4
        raw = r4.owned_text(r3.raw_text_surfaces())
        edge = result['projections']['text']
        require(edge['current_digest'] in (fingerprint(raw),
                fingerprint(operational_text('r4_text', raw)),
                previous['projections']['text']['current_digest']),
                'R4 r4_record live projection drifted (allocator identity successor)')
        edge['current_digest'] = fingerprint(operational_text('r4_text', raw))
        return result
    return current


@lru_cache(maxsize=2)
def ancestor_text_subsets(kind):
    """Exact archived images, never independently mixed historical coordinates."""
    owned = set(CHANGED + ADDED)
    images = {}
    for name in ANCESTOR_REGISTRATIONS:
        previous = importlib.import_module(name)
        value = previous.baseline()['projections'][kind]
        subset = [p for p in value if p['path'] in owned]
        images[fingerprint(subset)] = subset
    return images


def ancestor_text_inversions(registry, kind, current, rejected):
    from unittest.mock import patch
    owned = set(CHANGED + ADDED)
    foreign = [p for p in current if p['path'] not in owned]
    images = ancestor_text_subsets(kind)
    allowed = set(images) | {identity(registry)['owned_text'][kind],
        fingerprint([p for p in baseline()['projections'][kind] if p['path'] in owned])}
    mixed_checked = False
    for digest, subset in images.items():
        image = operational_text(kind, foreign + copy.deepcopy(subset))
        require(project(registry, kind, image) == image,
                'ancestor allocator text image is not a fixed point')
        target = next(p for p in subset if p['path'] == 'compiler/typechecker.gst')
        for label, changed in (
                ('omitted', [p for p in image if p['path'] != target['path']]),
                ('duplicated', image + [copy.deepcopy(target)])):
            rejected('ancestor '+digest[:12]+' '+label+' '+kind,
                lambda changed=changed:project(registry, kind, changed),
                'R4 '+kind+' live projection drifted')
        changed = copy.deepcopy(image)
        next(p for p in changed if p['path'] == target['path'])['digest'] = '0'*64
        rejected('ancestor '+digest[:12]+' substituted '+kind,
            lambda:project(registry, kind, changed), 'R4 '+kind+' live projection drifted')
        foreign_row = next(p for p in foreign if p['path'] != STATE)
        extra = dict(copy.deepcopy(foreign_row), allocator_foreign_mutation=True)
        mutated = sorted(image + [extra], key=lambda p:p['path'])
        require(project(registry, kind, mutated) == mutated,
                'ancestor projection swallowed foreign rows or duplicates')
        for other in images.values():
            replacement = next(p for p in other if p['path'] == target['path'])
            mixed = [replacement if p['path'] == target['path'] else p for p in subset]
            if fingerprint(mixed) in allowed:
                continue  # An exact complete archived image is legitimate.
            mixed_checked = True
            changed = operational_text(kind, foreign + copy.deepcopy(mixed))
            rejected('mixed ancestor '+digest[:12]+' '+kind,
                lambda:project(registry, kind, changed), 'R4 '+kind+' live projection drifted')
            break
    require(mixed_checked, 'no mixed ancestor text rejection was exercised')
    for name in ANCESTOR_REGISTRATIONS:
        previous = importlib.import_module(name)
        image = previous.project(registry, kind, current)
        require(project(registry, kind, image) == operational_text(kind, image),
                'composed ancestor allocator text image changed: '+name)
    previous = importlib.import_module(ANCESTOR_REGISTRATIONS[0])
    image = previous.project(registry, kind, current)
    require(previous.project(registry, kind, image) == image,
            'composed predecessor allocator text normalization is not idempotent')
    original = Path.read_bytes
    path = 'compiler/typechecker.gst'
    with patch.object(Path, 'read_bytes',
            lambda p:base_bytes(path) if p == ROOT/path else original(p)):
        rejected('ancestor image physical rollback '+kind,
            lambda:project(registry, kind, image), 'R4 changed file drifted')


def physical_files(registry, row):
    for p in row['changed_files']:
        prior_digest(registry, p['path'], sha((ROOT / p['path']).read_bytes()))
    for p in row['added_files']:
        require(p['digest'] == sha((ROOT / p['path']).read_bytes()),
                'allocator identity added file drifted: '+p['path'])


def project(registry, kind, current):
    if not record(registry):
        return current
    row = identity(registry)
    previous = baseline()['projections'][kind]
    require(type(current) is type(previous),
            'R4 ' + kind + ' live projection drifted (allocator identity successor)')
    current = canonical_projection(kind, current)
    previous = baseline()['projections'][kind]
    if kind in ('text', 'r4_text'):
        owned = set(CHANGED + ADDED)
        subset = [p for p in current if p['path'] in owned]
        old_subset = [p for p in previous if p['path'] in owned]
        if fingerprint(subset) in ancestor_text_subsets(kind):
            # A predecessor may feed its own normalized image back through us.
            # Keep that exact image fixed; restoring our newer baseline would
            # undo its normalization. Projection coordinates never excuse
            # current physical rollback, and foreign rows remain untouched.
            physical_files(registry, row)
            return copy.deepcopy(current)
        require(fingerprint(subset) in (row['owned_text'][kind], fingerprint(old_subset)),
                'R4 ' + kind + ' live projection drifted (allocator identity successor)')
        return sorted(copy.deepcopy([p for p in current if p['path'] not in owned] + old_subset),
                      key=lambda p: p['path'])
    require(fingerprint(current) in (row['projections'][kind], fingerprint(previous)),
            'R4 ' + kind + ' live projection drifted (allocator identity successor)')
    result = copy.deepcopy(previous)
    if kind == 'r4_record':
        next(p for p in result['changed_files'] if p['path'] == STATE)['current_digest'] = sha((ROOT / STATE).read_bytes())
    return result


def project_registry(registry):
    result = copy.deepcopy(registry)
    result.get('phase26_activation_audit', {}).pop(KEY, None)
    return result


def prior_render_digest(registry, live):
    if not record(registry):
        return live
    require(live == identity(registry)['spelling_render_current_digest'],
            'R4 current spelling review is stale or missing (allocator identity successor)')
    return json.loads(base_bytes('scripts/cranelift_feature_registry.json'))[
        'phase26_activation_audit']['allocator_resource_liveness_successor_v1']['spelling_render_current_digest']


def current_projections():
    import phase26_2_allocator_registration as previous
    return previous.current_projections()


def build_record():
    import phase24_semantic_spelling_inventory as spelling
    values = current_projections()
    sites = spelling.source_sites()
    return dict(predecessor_main=BASE, owner='cranelift', guard=GUARD,
        phase26_2_status='OPEN', od23='OPEN; no slot ownership or admission selected',
        operational_state_excluded=STATE,
        changed_files=[dict(path=p, previous_digest=sha(base_bytes(p)),
            current_digest=sha((ROOT / p).read_bytes())) for p in CHANGED],
        added_files=[dict(path=p, digest=sha((ROOT / p).read_bytes())) for p in ADDED],
        owned_text={k:fingerprint([p for p in operational_text(k,values[k]) if p['path'] in CHANGED+ADDED])
            for k in ('text','r4_text')},
        projections={k:fingerprint(canonical_projection(k,v)) for k,v in values.items()},
        spelling_render_current_digest=sha(spelling.render(spelling.load_authority(), sites,
            spelling.manifest_summary(sites)).encode()))


def validate():
    registry = json.loads(REGISTRY.read_text())
    row = identity(registry)
    require(project_registry(registry) == json.loads(base_bytes('scripts/cranelift_feature_registry.json')),
            'allocator identity changed frozen predecessor or foreign registry rows')
    physical_files(registry, row)
    require((ROOT/'justfile').read_bytes() == base_bytes('justfile')+RECIPE.encode(), 'allocator recipe drifted')
    levels = json.loads((ROOT/'scripts/cranelift_test_levels.json').read_text())
    require(levels['guards'].pop(GUARD,None)==2 and levels==json.loads(base_bytes('scripts/cranelift_test_levels.json')),
            'allocator test level or predecessor guards drifted')
    for kind,value in current_projections().items():
        project(registry,kind,value)
    print(GUARD+': exact additive registration PASS')


def inversions():
    validate()
    registry = json.loads(REGISTRY.read_text())
    from unittest.mock import patch
    def rejected(label,callback,expected):
        try:
            callback()
        except SystemExit as error:
            if expected not in str(error):
                raise SystemExit(label+': REJECTED (different assertion): '+str(error))
            print(label+': REJECTED (expected assertion): '+str(error),flush=True)
        else:
            raise SystemExit(label+': ACCEPTED')
    for path in CHANGED:
        rejected('substituted '+path,lambda path=path:prior_digest(registry,path,'0'*64), 'R4 changed file drifted')
        original = Path.read_bytes
        with patch.object(Path,'read_bytes',lambda p,path=path:base_bytes(path) if p==ROOT/path else original(p)):
            rejected('physical rollback '+path,lambda path=path:prior_digest(registry,path,sha(base_bytes(path))), 'R4 changed file drifted')
    changed=copy.deepcopy(registry);changed['phase26_activation_audit'][KEY]['changed_files'].append(dict(path=STATE))
    rejected('re-admitted operational byte pin',lambda:identity(changed), 'allocator proof identity, file population or operational-state retirement drifted')
    changed=copy.deepcopy(registry);changed['phase26_activation_audit'][KEY]['od23']='DONE'
    rejected('unselected slot admission',lambda:identity(changed), 'allocator proof identity, file population or operational-state retirement drifted')
    for kind in identity(registry)['projections']:
        rejected('substituted '+kind,lambda kind=kind:project(registry,kind,'substituted'), 'R4 '+kind+' live projection drifted')
    live_values = current_projections()
    for kind in ('text', 'r4_text'):
        values = live_values[kind]
        owned = next(p for p in values if p['path'] in CHANGED + ADDED)
        missing = [p for p in values if p['path'] != owned['path']]
        rejected('omitted owned '+kind,
            lambda kind=kind,missing=missing:project(registry,kind,missing),
            'R4 '+kind+' live projection drifted')
        duplicate = copy.deepcopy(values) + [copy.deepcopy(owned)]
        rejected('duplicated owned '+kind,
            lambda kind=kind,duplicate=duplicate:project(registry,kind,duplicate),
            'R4 '+kind+' live projection drifted')
        foreign = next(p for p in values if p['path'] not in CHANGED + ADDED and p['path'] != STATE)
        mutated = copy.deepcopy(values)
        next(p for p in mutated if p['path'] == foreign['path'])['allocator_foreign_mutation'] = True
        result = project(registry,kind,mutated)
        require(any(p.get('allocator_foreign_mutation') for p in result),
                'allocator normalizer swallowed foreign text mutation')
        once = project(registry,kind,values)
        require(project(registry,kind,once) == once,
                'allocator text normalization is not idempotent')
        ancestor_text_inversions(registry, kind, values, rejected)
    changed = copy.deepcopy(registry)
    changed['allocator_foreign_mutation'] = True
    require(project_registry(changed) != json.loads(base_bytes('scripts/cranelift_feature_registry.json')),
            'allocator normalizer swallowed foreign registry mutation')
    original = Path.read_bytes
    for item in identity(registry)['added_files']:
        path = item['path']
        with patch.object(Path,'read_bytes',lambda p,path=path:original(p)+b'\n' if p==ROOT/path else original(p)):
            rejected('added bytes '+path,validate, 'allocator identity added file drifted')
    original_text = Path.read_text
    changed = copy.deepcopy(registry)
    changed['allocator_foreign_mutation'] = True
    with patch.object(Path,'read_text',lambda p,*args,**kwargs:
            json.dumps(changed) if p == REGISTRY else original_text(p,*args,**kwargs)):
        rejected('actual foreign registry refusal',validate,
                 'allocator identity changed frozen predecessor or foreign registry rows')
    original_is_file = Path.is_file
    with patch.object(Path,'is_file',lambda p:False if p == ROOT/STATE else original_is_file(p)):
        rejected('missing operational state',lambda:identity(registry),
                 'operational lane state is absent')
    original_stat = Path.stat
    import os
    fields = list(original_stat(ROOT/STATE));fields[6] = 0
    empty_stat = os.stat_result(fields)
    with patch.object(Path,'stat',lambda p,*args,**kwargs:
            empty_stat if p == ROOT/STATE else original_stat(p,*args,**kwargs)):
        rejected('empty operational state',lambda:identity(registry),
                 'operational lane state is absent')
    print('ALLOCATOR_IDENTITY_ENROLLMENT_INVERSIONS_PASS')


if __name__=='__main__':
    {'validate':validate,'inversions':inversions}[sys.argv[1]]()
