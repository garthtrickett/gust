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

import phase26_2_cleanup_witnesses as cleanup_witnesses

ROOT = Path(__file__).resolve().parents[1]
BASE = '39e37696b775b25827d54c1c5a52b005d30e386b'
KEY = 'allocator_identity_successor_v1'
GUARD = 'guard-cranelift-phase26-2-allocator-identities'
STATE = 'GUST_LANE_STATE.md'
BASELINE = 'compiler/phase26-2-allocator-identity/predecessor-baseline-v2.json.gz'
BASELINE_SHA256 = '4ecb5ffe2f511d9cd2a22b6cb6e07b8889af747310cfba07b50758549ca47438'
PROFILE_BASELINE = 'compiler/phase26-2-allocator-identity/bootstrap-profile-predecessor-v2.json.gz'
PROFILE_BASELINE_SHA256 = '1f82b0f3b52dedacabd39a111b18b68fee3ebddc541f17bfe5ad6ce5287fe91c'
LIFECYCLE_BASELINE = 'compiler/phase26-2-allocator-identity/lifecycle-evidence-predecessor-v2.json.gz'
LIFECYCLE_BASELINE_SHA256 = '2105278aa3cb1e840dd0a4c3b791300942bff9d2b99038b1946fcbb072f2a2be'
CONTROL_BASELINE = 'compiler/phase26-2-allocator-identity/predecessor-pin-controls-v1.json.gz'
CONTROL_BASELINE_SHA256 = '39852d3d4aa62f0b8298d8f81bda9609a0f8dd9722e05d048777edc28ceae6d2'
CONTROL_CHANGED = ('scripts/phase26_2_allocator_registration.py',
    'scripts/phase26_predecessor_data.py')
TOOLCHAIN_CHANGED = ('scripts/phase26_production_toolchain.py',)
TOOLCHAIN_BASELINE = 'compiler/phase26-2-allocator-identity/ci-toolchain-predecessor-v1.json.gz'
TOOLCHAIN_BASELINE_SHA256 = 'c827c1ed55fecc9238352e6f640d9d7663ac5b6de1ec24b812c7ca3bd438fda1'
DEFER_WORKER = 'compiler/experiments/cranelift/src/full_program.rs'
DEFER_INVOCATION_ADAPTER = 'scripts/phase22_opening.py'
DEFER_RUNNER = 'scripts/phase26_2_defer_lexical.py'
DEFER_ORDER_RUNNER = 'scripts/phase26_2_deferred_allocator_order.py'
DEFER_BASELINE = 'compiler/phase26-2-defer-lexical/predecessor-worker-and-global-census-v3.json.gz'
DEFER_BASELINE_SHA256 = '7212c97768f2e6716279a374a4e127ecbb1ab3e59647156285ee838ca2e4a4ee'
DISK_SCAN_CHANGED = ('scripts/phase26_release_paging.py',
    'scripts/phase26_release_execution_controls.py')
DISK_SCAN_BASELINE = 'compiler/phase26-2-defer-lexical/owned-disk-scan-predecessor-v1.json.gz'
DISK_SCAN_BASELINE_SHA256 = '38fae8d1b71ffb732f023eec5e8d344ba4785a5d63f9ba07201e44bdf424cb09'
R3_GUARD = 'scripts/phase26_r3_zlib_adapter_guard.sh'
R3_BASELINE = 'compiler/phase26-2-allocator-identity/r3-source-guard-predecessor-v1.json.gz'
R3_BASELINE_SHA256 = '4805ad37481c4d5646638503a6728a895b923ad4e68bda0d28e9a90138f9100b'
CR15_BASELINE = 'compiler/phase26-2-deferred-allocator-order/cr15-cleanup-predecessor-v1.json.gz'
CR15_BASELINE_SHA256 = '70e6aa282b01eea9f43f1fe5b7971e96e208792039e1198baf6a5e912e584c7f'
CR15_PREDECESSOR_DIGESTS = {
    'scripts/phase24_cr15_derivation.py': 'df2e7b2d0bc10e44bc31535a944e38919497a6777bcfcdba877d74f4cc47961f',
    'compiler/CRANELIFT_PHASE24_CR15_DERIVATION.md': '1302bf5478b6bc9a50fc95468f53a509c52467aaa2c572a86e6a4d5d97d21bb9',
    '.github/workflows/phase24-cr15-derivation.yml': '9acbdfe2ff96bb1ebfb2a4b4f839db081ffc425d2814863bc5897d19e45640ff',
    '.github/workflows/phase24-cr15-qualification.yml': 'cf9745a25df539a502f75da62a4c24bf0e2d14243b73d65e87aeb7a1efc9857c',
}
CR15_CHANGED = tuple(CR15_PREDECESSOR_DIGESTS)
HISTORICAL_BASELINES = {
    'compiler/phase26-2-allocator-identity/predecessor-baseline.json.gz':
        '38118f9047355b4a925a313c58221283c565a85ea945fd933c45b36390c5f10b',
    'compiler/phase26-2-allocator-identity/bootstrap-profile-predecessor.json.gz':
        '49cc8924af5b587ab2171869c53a8feffcbf83eb2f4d5346c6526ec839fdf502',
    'compiler/phase26-2-allocator-identity/lifecycle-evidence-predecessor.json.gz':
        '954b34d58a9bef15bdd4e0783e6ec5e878b6ae4e4a8482a266a49a78194a0c91',
}
LIFECYCLE_CHANGED = ('scripts/phase20_arena_lifecycle.py',)
LIFECYCLE_HELPER = 'scripts/phase26_2_allocator_lifecycle_evidence.py'
PROFILE_CHANGED = ('.github/workflows/phase26-2-allocator-liveness.yml',)
REGISTRY = ROOT / 'scripts/cranelift_feature_registry.json'
ANCESTOR_REGISTRATIONS = ('phase26_production_renewal_registration',
    'phase26_2_allocator_registration', 'phase26_release_registration',
    'phase26_readonly_input_copy_registration', 'phase26_ticket_composition_registration',
    'phase26_imported_native_registration', 'phase26_ticket_publication_registration')
CHANGED = ('compiler/typechecker.gst', 'TASK.md', 'justfile',
    *CR15_CHANGED,
    *cleanup_witnesses.PREDECESSOR_FILES,
    'scripts/cranelift_test_levels.json', 'scripts/phase26_production_renewal_registration.py',
    'compiler/phase26-release/release-epoch2.json', 'compiler/phase26-release/reachable-audit-epoch2.json',
    *PROFILE_CHANGED, *LIFECYCLE_CHANGED, *CONTROL_CHANGED, *TOOLCHAIN_CHANGED,
    R3_GUARD, DEFER_WORKER, DEFER_INVOCATION_ADAPTER, *DISK_SCAN_CHANGED)
ADDED = ('compiler/phase26-2-defer-lexical/predecessor-worker.json.gz',
    *cleanup_witnesses.PREDECESSOR_ARCHIVES,
    'scripts/phase26_2_cleanup_witnesses.py',
    'compiler/phase26-2-deferred-allocator-order/cleanup-witnesses.json',
    'tests/phase24_cr15_qualification_positive_scoped.gst',
    'tests/phase24_cr15_qualification_explicit_scoped.gst',
    'compiler/future/p20_issue106_unbound_directory_current_scoped.gst',
    CR15_BASELINE,
    'scripts/phase26_2_cr15_cleanup_fixtures.py',
    'compiler/phase26-2-deferred-allocator-order/cr15-cleanup-fixtures.json',
    'tests/phase24_cr15_protected_resource_native_inferred_scoped.gst',
    'tests/phase24_cr15_protected_resource_native_explicit_scoped.gst',
    'tests/phase24_cr15_protected_resource_native_second_type_scoped.gst',
    'compiler/phase26-2-defer-lexical/predecessor-worker-and-invocation-v2.json.gz', DEFER_BASELINE,
    DISK_SCAN_BASELINE, 'scripts/phase26_2_defer_lexical.py',
    'compiler/phase26-2-defer-lexical/cases.json',
    'compiler/CRANELIFT_PHASE26_2_DEFER_LEXICAL.md',
    DEFER_ORDER_RUNNER, 'compiler/phase26-2-deferred-allocator-order/cases.json',
    'compiler/phase26-2-deferred-allocator-order/observation_facts.gst',
    'compiler/CRANELIFT_PHASE26_2_DEFERRED_ALLOCATOR_ORDER.md',
    *HISTORICAL_BASELINES, BASELINE, PROFILE_BASELINE, LIFECYCLE_BASELINE, CONTROL_BASELINE,
    'scripts/phase26_2_allocator_predecessor_controls.py',
    LIFECYCLE_HELPER, 'scripts/phase26_2_allocator_identity_registration.py',
    'scripts/phase26_2_allocator_identity_guard.py',
    'compiler/phase26-2-allocator-identity/cases.json',
    'compiler/phase26-2-allocator-identity/proof_facts.gst',
    'compiler/phase26-2-allocator-identity/primitive_fields.gst',
    'compiler/phase26-2-allocator-identity/primitive_cases.json',
    '.github/workflows/phase26-2-allocator-identity.yml',
    'compiler/CRANELIFT_PHASE26_2_ALLOCATOR_IDENTITIES.md',
    'scripts/phase26_bootstrap_bounded.py', TOOLCHAIN_BASELINE, R3_BASELINE,
    'scripts/phase26_toolchain_compatibility.py',
    'scripts/phase26_production_toolchain_controls.py',
    'compiler/experiments/cranelift/production/ci-toolchain-compatibility.json')
BOOTSTRAP = 'scripts/phase26_bootstrap_bounded.py'
RELEASE_WORKFLOW = '.github/workflows/phase26-release-closure.yml'
PREDECESSOR_KEY = 'production_epoch2_renewal_successor_v1'
WORKFLOWS = (
    ('.github/workflows/phase26-2-allocator-liveness.yml', 'make -j2 gust',
     'guard-cranelift-phase26-2-allocator-liveness', BOOTSTRAP),
    ('.github/workflows/phase26-2-allocator-identity.yml', 'make -j2 gust', GUARD, BOOTSTRAP))
RECIPE = ('\n# Lexical allocator proof identities and immutable actual-origin dependencies.\n' + GUARD + ':\n'
    '    python3 scripts/phase26_2_allocator_identity_registration.py validate\n'
    '    python3 scripts/phase26_2_allocator_identity_registration.py inversions\n'
    '    python3 scripts/phase26_bootstrap_bounded.py inversions\n'
    '    python3 scripts/phase26_release_execution.py controls\n'
    '    python3 scripts/phase26_production_toolchain_controls.py\n'
    '    python3 scripts/phase26_2_allocator_identity_guard.py\n'
    '    python3 scripts/phase26_2_defer_lexical.py validate\n'
    '    python3 scripts/phase26_2_defer_lexical.py inversions\n'
    '    python3 scripts/phase26_2_defer_lexical.py native\n'
    '    python3 scripts/phase26_2_deferred_allocator_order.py validate\n'
    '    python3 scripts/phase26_2_deferred_allocator_order.py inversions\n'
    '    python3 scripts/phase26_2_deferred_allocator_order.py native\n'
    '    python3 scripts/phase26_2_cleanup_witnesses.py validate\n'
    '    python3 scripts/phase26_2_cleanup_witnesses.py inversions\n')


def require(ok, message):
    if not ok:
        raise SystemExit(GUARD + ': ' + message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def fingerprint(value):
    return sha(json.dumps(value, sort_keys=True, separators=(',', ':')).encode())


@lru_cache(maxsize=1)
def _baseline(raw):
    value = json.loads(gzip.decompress(raw))
    require(value['base'] == BASE, 'allocator identity predecessor identity drifted')
    return value


def baseline():
    # Read and hash the declared dependency on every call; cache only decoding.
    raw = (ROOT / BASELINE).read_bytes()
    require(sha(raw) == BASELINE_SHA256, 'allocator identity predecessor baseline bytes drifted')
    return _baseline(raw)


@lru_cache(maxsize=1)
def _profile_baseline(raw):
    value = json.loads(gzip.decompress(raw))
    require(value['schema'] == 'gust.bootstrap_profile.predecessor.v1' and
            value['base'] == BASE and value['predecessor_baseline_sha256'] == BASELINE_SHA256 and
            set(value['files']) == set(PROFILE_CHANGED),
            'bootstrap profile predecessor identity or file population drifted')
    return value


def profile_baseline():
    raw = (ROOT / PROFILE_BASELINE).read_bytes()
    require(sha(raw) == PROFILE_BASELINE_SHA256, 'bootstrap profile predecessor bytes drifted')
    return _profile_baseline(raw)


@lru_cache(maxsize=1)
def _lifecycle_baseline(raw):
    value = json.loads(gzip.decompress(raw))
    previous = json.loads(base64.b64decode(baseline()['files']['scripts/cranelift_feature_registry.json']))
    import phase26_2_allocator_lifecycle_evidence as evidence
    require(value['schema'] == 'gust.allocator_lifecycle_evidence.predecessor.v1' and
            value['base'] == BASE and set(value['files']) == set(LIFECYCLE_CHANGED) and
            value['phase20_authority_sha256'] == fingerprint(previous['phase20_arena_lifecycle']) and
            value['retired_anchors'] == list(evidence.RETIRED),
            'lifecycle predecessor identity or file population drifted')
    return value


def lifecycle_baseline():
    raw = (ROOT / LIFECYCLE_BASELINE).read_bytes()
    require(sha(raw) == LIFECYCLE_BASELINE_SHA256, 'lifecycle predecessor bytes drifted')
    return _lifecycle_baseline(raw)


def checked_cr15_predecessor(value):
    from phase26_predecessor_data import decoded_payload
    require(set(value) == {'schema', 'base', 'files'} and
            value['schema'] == 'gust.cr15_cleanup_fixture.predecessor.v1' and
            value['base'] == BASE and set(value['files']) == set(CR15_CHANGED),
            'CR15 cleanup predecessor identity or population drifted')
    for path, digest in CR15_PREDECESSOR_DIGESTS.items():
        require(sha(decoded_payload(value['files'][path])) == digest,
                'CR15 cleanup predecessor payload drifted: ' + path)
    return value


def cr15_predecessor():
    raw = (ROOT / CR15_BASELINE).read_bytes()
    require(sha(raw) == CR15_BASELINE_SHA256, 'CR15 cleanup predecessor archive bytes drifted')
    return checked_cr15_predecessor(json.loads(gzip.decompress(raw)))


def cr15_predecessor_controls(rejected):
    value = cr15_predecessor()
    from unittest.mock import patch
    original_read = Path.read_bytes
    archive = ROOT / CR15_BASELINE
    with patch.object(Path, 'read_bytes', lambda path:
                      original_read(path) + b'changed' if path == archive else original_read(path)):
        rejected('CR15 predecessor archive substitution', cr15_predecessor,
                 'CR15 cleanup predecessor archive bytes drifted')
    for field, replacement in (('schema', 'unregistered'), ('base', '0' * 40)):
        changed = copy.deepcopy(value)
        changed[field] = replacement
        rejected('CR15 predecessor ' + field,
                 lambda changed=changed: checked_cr15_predecessor(changed),
                 'CR15 cleanup predecessor identity or population drifted')
    changed = copy.deepcopy(value)
    changed['files']['compiler/future/p20_issue106_unbound_directory_current.gst'] = base64.b64encode(b'unselected').decode()
    rejected('CR15 predecessor unselected directory',
             lambda: checked_cr15_predecessor(changed),
             'CR15 cleanup predecessor identity or population drifted')
    for path in CR15_CHANGED:
        omitted = copy.deepcopy(value)
        omitted['files'].pop(path)
        rejected('CR15 predecessor omitted ' + path,
                 lambda omitted=omitted: checked_cr15_predecessor(omitted),
                 'CR15 cleanup predecessor identity or population drifted')
        substituted = copy.deepcopy(value)
        substituted['files'][path] = base64.b64encode(b'changed').decode()
        rejected('CR15 predecessor substituted ' + path,
                 lambda substituted=substituted: checked_cr15_predecessor(substituted),
                 'CR15 cleanup predecessor payload drifted: ' + path)


def base_bytes(path):
    from phase26_predecessor_data import decoded_payload
    files = baseline()['files']
    if path in cleanup_witnesses.PREDECESSOR_FILES:
        return cleanup_witnesses.predecessor_bytes(path)
    if path in CR15_CHANGED:
        return decoded_payload(cr15_predecessor()['files'][path])
    if path in files:
        return decoded_payload(files[path])
    if path in DISK_SCAN_CHANGED:
        raw = (ROOT/DISK_SCAN_BASELINE).read_bytes()
        require(sha(raw) == DISK_SCAN_BASELINE_SHA256, 'owned disk scan predecessor bytes drifted')
        value = json.loads(gzip.decompress(raw))
        require(set(value) == {'schema', 'base', 'files'} and
                value['schema'] == 'gust.owned_disk_scan.predecessor.v1' and
                value['base'] == '59ef3f3fccfc6b6d10c7f9967f1e510856cf0aaa' and
                set(value['files']) == set(DISK_SCAN_CHANGED),
                'owned disk scan predecessor identity or population drifted')
        return decoded_payload(value['files'][path])
    if path in (DEFER_WORKER, DEFER_INVOCATION_ADAPTER):
        raw = (ROOT/DEFER_BASELINE).read_bytes()
        require(sha(raw) == DEFER_BASELINE_SHA256, 'deferred lexical predecessor bytes drifted')
        value = json.loads(gzip.decompress(raw))
        require(set(value) == {'schema', 'base', 'files'} and
                value['schema'] == 'gust.defer_lexical.predecessor.v1' and
                value['base'] == '59ef3f3fccfc6b6d10c7f9967f1e510856cf0aaa' and
                set(value['files']) == {DEFER_WORKER, DEFER_INVOCATION_ADAPTER},
                'deferred lexical predecessor identity drifted')
        return decoded_payload(value['files'][path])
    if path == R3_GUARD:
        raw = (ROOT/R3_BASELINE).read_bytes()
        require(sha(raw) == R3_BASELINE_SHA256, 'R3 source guard predecessor bytes drifted')
        value = json.loads(gzip.decompress(raw))
        require(set(value) == {'schema', 'base', 'files'} and
                value['schema'] == 'gust.r3_source_guard.predecessor.v1' and
                value['base'] == BASE and set(value['files']) == {R3_GUARD},
                'R3 source guard predecessor identity or population drifted')
        return decoded_payload(value['files'][path])
    if path in TOOLCHAIN_CHANGED:
        raw = (ROOT/TOOLCHAIN_BASELINE).read_bytes()
        require(sha(raw) == TOOLCHAIN_BASELINE_SHA256, 'toolchain predecessor archive bytes drifted')
        value = json.loads(gzip.decompress(raw))
        require(set(value) == {'schema', 'base', 'files'} and
                value['schema'] == 'gust.ci_toolchain_predecessor.v1' and
                value['base'] == BASE and set(value['files']) == set(TOOLCHAIN_CHANGED),
                'toolchain predecessor identity or file population drifted')
        return decoded_payload(value['files'][path])
    if path in PROFILE_CHANGED:
        return decoded_payload(profile_baseline()['files'][path])
    if path in CONTROL_CHANGED:
        raw = (ROOT/CONTROL_BASELINE).read_bytes()
        require(sha(raw) == CONTROL_BASELINE_SHA256, 'predecessor pin-control archive bytes drifted')
        value = json.loads(gzip.decompress(raw))
        require(set(value) == {'schema', 'base', 'predecessor_baseline_sha256', 'files'} and
                value['schema'] == 'gust.allocator_predecessor_pin_controls.v1' and
                value['base'] == BASE and value['predecessor_baseline_sha256'] == BASELINE_SHA256 and
                set(value['files']) == set(CONTROL_CHANGED),
                'predecessor pin-control archive identity drifted')
        return decoded_payload(value['files'][path])
    require(path in LIFECYCLE_CHANGED, 'unknown predecessor file: ' + path)
    return decoded_payload(lifecycle_baseline()['files'][path])


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
    require(row.get('defer_native_invocations') == defer_invocation_rows(),
            'deferred lexical compiler invocation enrollment drifted')
    require(row.get('defer_order_native_invocations') == defer_order_invocation_rows(),
            'deferred allocator order compiler invocation enrollment drifted')
    require((ROOT / STATE).is_file() and (ROOT / STATE).stat().st_size > 0,
            'operational lane state is absent')
    return row


def prior_digest(registry, path, live):
    if not record(registry) or path not in CHANGED:
        return live
    pin = next(p for p in identity(registry)['changed_files'] if p['path'] == path)
    admitted = {pin['current_digest'], pin['previous_digest']}
    from phase26_predecessor_data import inherited_digests_indexed
    cohort = (PREDECESSOR_KEY, 'allocator_resource_liveness_successor_v1', 'first_release_closure_successor_v1', 'readonly_input_copy_successor_v1',
                'closed_ticket_composition_successor_v1', 'imported_native_successor_v1',
                'scoped_ticket_publication_successor_v1')
    admitted.update(inherited_digests_indexed(base_bytes('scripts/cranelift_feature_registry.json'),
                                           path, cohort))
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


def check_text_rows(kind, current):
    require(isinstance(current, list) and all(isinstance(p, dict) and 'path' in p for p in current),
            'R4 ' + kind + ' live projection drifted (allocator identity successor)')
    require(sum(p['path'] == STATE for p in current) <= 1,
            'R4 ' + kind + ' live projection drifted (allocator identity successor)')


def operational_text(kind, current):
    check_text_rows(kind, current)
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
        if result == previous:
            return result
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


def mixed_ancestor_subset(subset, images, allowed):
    paths = {p['path'] for p in subset}
    for other in images:
        for replacement in other:
            if replacement['path'] not in paths:
                continue
            mixed = [replacement if p['path'] == replacement['path'] else p for p in subset]
            if fingerprint(mixed) not in allowed:
                return mixed
    return None


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
        state = next(p for p in image if p['path'] == STATE)
        rejected('ancestor '+digest[:12]+' duplicated operational state '+kind,
            lambda image=image,state=state:project(registry, kind, image+[copy.deepcopy(state)]),
            'R4 '+kind+' live projection drifted')
        rejected('ancestor '+digest[:12]+' malformed row '+kind,
            lambda image=image:project(registry, kind, image+[None]),
            'R4 '+kind+' live projection drifted')
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
        mixed = mixed_ancestor_subset(subset, images.values(), allowed)
        if mixed is not None:
            mixed_checked = True
            changed = operational_text(kind, foreign + copy.deepcopy(mixed))
            rejected('mixed ancestor '+digest[:12]+' '+kind,
                lambda:project(registry, kind, changed), 'R4 '+kind+' live projection drifted')
    require(mixed_checked, 'no mixed ancestor text rejection was exercised')
    for name in ANCESTOR_REGISTRATIONS:
        previous = importlib.import_module(name)
        image = previous.project(registry, kind, current)
        require(project(registry, kind, image) == image,
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
    for p in row['added_files']:
        require(p['digest'] == sha((ROOT / p['path']).read_bytes()),
                'allocator identity added file drifted: '+p['path'])
    for path, expected in HISTORICAL_BASELINES.items():
        require(sha((ROOT/path).read_bytes()) == expected,
                'historical allocator baseline bytes drifted: '+path)
    for p in row['changed_files']:
        prior_digest(registry, p['path'], sha((ROOT / p['path']).read_bytes()))


def ancestor_record_images(kind):
    """Only complete archived normal forms, including their live state variant."""
    images = [importlib.import_module(name).baseline()['projections'][kind]
              for name in ANCESTOR_REGISTRATIONS]
    if kind == 'r4_record':
        for value in list(images):
            value = copy.deepcopy(value)
            next(p for p in value['changed_files'] if p['path'] == STATE)[
                'current_digest'] = sha((ROOT/STATE).read_bytes())
            images.append(value)
    return images


def project(registry, kind, current):
    if not record(registry):
        return current
    row = identity(registry)
    physical_files(registry, row)
    previous = baseline()['projections'][kind]
    require(type(current) is type(previous),
            'R4 ' + kind + ' live projection drifted (allocator identity successor)')
    if kind in ('text', 'r4_text'):
        check_text_rows(kind, current)
        owned = set(CHANGED + ADDED)
        subset = [p for p in current if p['path'] in owned]
        if fingerprint(subset) in ancestor_text_subsets(kind):
            # Preserve a complete predecessor image before operational retagging.
            # Physical checks above remain mandatory; foreign rows stay untouched.
            return copy.deepcopy(current)
    if kind not in ('text', 'r4_text') and any(
            current == image for image in ancestor_record_images(kind)):
        return copy.deepcopy(current)
    current = canonical_projection(kind, current)
    previous = baseline()['projections'][kind]
    if kind in ('text', 'r4_text'):
        owned = set(CHANGED + ADDED)
        subset = [p for p in current if p['path'] in owned]
        old_subset = [p for p in previous if p['path'] in owned]
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
    if record(registry):
        physical_files(registry, identity(registry))
    result = copy.deepcopy(registry)
    result.get('phase26_activation_audit', {}).pop(KEY, None)
    return result


def prior_render_digest(registry, live):
    if not record(registry):
        return live
    require(live == identity(registry)['spelling_render_current_digest'],
            'R4 current spelling review is stale or missing (allocator identity successor)')
    return json.loads(base_bytes('scripts/cranelift_feature_registry.json'))[
        'phase26_activation_audit'][PREDECESSOR_KEY]['spelling_render_current_digest']


@lru_cache(maxsize=2)
def _parsed_invocation_lists(path, source, parser):
    """Cache decoding only; immutable text cannot share mutable rows with callers."""
    require(path in (ROOT / DEFER_RUNNER, ROOT / DEFER_ORDER_RUNNER),
            'unregistered deferred invocation parser path')
    require(path.read_text(encoding='utf-8') == source,
            'deferred invocation source changed while parsing')
    rows = parser(path)
    require(path.read_text(encoding='utf-8') == source,
            'deferred invocation source changed while parsing')
    # The maintained parser returns (line:int, command:str, token:str) tuples.
    # Store an immutable snapshot, then reconstruct fresh tuple rows below.
    return json.dumps(rows, ensure_ascii=False)


def live_invocation_lists(path):
    from phase22_opening import python_compiler_lists
    # Never cache a physical-file read, registry verdict, pin or classification.
    source = path.read_text(encoding='utf-8')
    snapshot = _parsed_invocation_lists(path, source, python_compiler_lists)
    return [tuple(row) for row in json.loads(snapshot)]


def defer_invocation_rows():
    from phase22_opening import classify, selection
    return [classify(ROOT/DEFER_RUNNER, line, command, '', token, selection(command))
            for line, command, token in live_invocation_lists(ROOT/DEFER_RUNNER)]


def normalize_defer_invocations(registry, rows):
    row = identity(registry)
    physical_files(registry, row)
    actual = [p for p in rows if p['path'] == DEFER_RUNNER]
    expected = row['defer_native_invocations']
    without_line = lambda p: {k:v for k,v in p.items() if k != 'line'}
    require(len(actual) == len(expected) == 1 and
            [without_line(p) for p in actual] == [without_line(p) for p in expected] and
            actual == defer_invocation_rows() and
            actual[0]['selection'] == 'explicit_cranelift' and
            actual[0]['command'] == "[str(ROOT / 'gust'), '--backend', 'cranelift', '-o', str(binary), str(source)]",
            'deferred lexical compiler invocation missing, extra or substituted')
    return [p for p in rows if p['path'] != DEFER_RUNNER]


def defer_order_invocation_rows():
    from phase22_opening import classify, selection
    return sorted((classify(ROOT/DEFER_ORDER_RUNNER, line, command, '', token, selection(command))
                   for line, command, token in live_invocation_lists(ROOT/DEFER_ORDER_RUNNER)),
                  key=lambda row: (row['line'], row['command']))


def invocation_cache_controls(registry, rejected):
    """Warm-cache controls exercise the real readers and uncached authority."""
    from unittest.mock import patch
    import phase22_opening as opening
    original_text = Path.read_text
    original_parser = opening.python_compiler_lists
    for relative, rows_function, diagnostic in (
            (DEFER_RUNNER, defer_invocation_rows,
             'deferred lexical compiler invocation enrollment drifted'),
            (DEFER_ORDER_RUNNER, defer_order_invocation_rows,
             'deferred allocator order compiler invocation enrollment drifted')):
        path = ROOT / relative
        source = original_text(path, encoding='utf-8')
        expected = original_parser(path)
        _parsed_invocation_lists.cache_clear()
        require(live_invocation_lists(path) == expected == live_invocation_lists(path),
                'cached deferred parser changed original rows or ordering')
        expected_rows = rows_function()
        changed_rows = rows_function()
        changed_rows[0]['command'] = 'caller mutation'
        require(rows_function() == expected_rows,
                'cached deferred classification shared mutable rows')
        reads = []
        def counted_text(target, *args, **kwargs):
            if target == path:
                reads.append(target)
            return original_text(target, *args, **kwargs)
        with patch.object(Path, 'read_text', counted_text):
            live_invocation_lists(path)
            live_invocation_lists(path)
        require(reads == [path, path], 'warm deferred cache skipped physical reads')

        # Each mutation follows a warm original read. Path/stat identity stays
        # fixed; exact live text, not metadata, must select a new parser result.
        replacements = (
            ('same-size token', source.replace("'--backend'", "'--backenx'", 1)),
            ('backend substitution', source.replace("'cranelift'", "'mir-to-c'", 1)),
            ('omitted invocation', source.replace("ROOT / 'gust'", "ROOT / 'missing'", 1)),
            ('extra invocation', source + '\ncache_probe = ' + expected[0][1] + '\n'))
        for label, changed in replacements:
            require(changed != source, 'deferred cache mutation did not move: ' + label)
            require(live_invocation_lists(path) == expected,
                    'original deferred source failed before warm mutation')
            with patch.object(Path, 'read_text', lambda target, *args, **kwargs:
                    changed if target == path else original_text(target, *args, **kwargs)):
                rejected(relative + ' warm cache ' + label,
                         lambda: identity(registry), diagnostic)
            require(live_invocation_lists(path) == expected,
                    'deferred cache did not restore exact original parse')

        # A replacement parser must not inherit an entry from the old callable.
        with patch.object(opening, 'python_compiler_lists', lambda target:
                          original_parser(target) + [expected[0]] if target == path
                          else original_parser(target)):
            rejected(relative + ' replacement parser', lambda: identity(registry), diagnostic)

        # Immutable cached serialization also isolates nested mutable mock data.
        nested = [(1, {'argv': ['original']}, 'probe')]
        with patch.object(opening, 'python_compiler_lists', lambda target: nested):
            first = live_invocation_lists(path)
            nested[0][1]['argv'].append('parser-side mutation')
            first[0][1]['argv'].append('caller-side mutation')
            require(live_invocation_lists(path) == [(1, {'argv': ['original']}, 'probe')],
                    'deferred parser cache leaked nested result mutation')

        _parsed_invocation_lists.cache_clear()
        with patch.object(opening, 'python_compiler_lists', side_effect=ValueError('parser probe')):
            for _ in range(2):
                try:
                    live_invocation_lists(path)
                except ValueError as error:
                    require(str(error) == 'parser probe', 'deferred parser exception changed')
                else:
                    require(False, 'deferred parser exception was swallowed')
            require(_parsed_invocation_lists.cache_info().currsize == 0,
                    'deferred parser exception was cached')

        # A cache miss must reject source movement during the actual parse.
        def moving_parser(target):
            value = original_parser(target)
            if target == path:
                moved[0] = True
            return value
        moved = [False]
        with patch.object(opening, 'python_compiler_lists', moving_parser), \
                patch.object(Path, 'read_text', lambda target, *args, **kwargs:
                    source + '\n' if target == path and moved[0]
                    else original_text(target, *args, **kwargs)):
            rejected(relative + ' source movement during parse',
                     lambda: live_invocation_lists(path),
                     'deferred invocation source changed while parsing')

        _parsed_invocation_lists.cache_clear()
        parsed = []
        def counting_parser(target):
            parsed.append(target)
            return original_parser(target)
        with patch.object(opening, 'python_compiler_lists', counting_parser):
            for suffix in ('', '\n', '\n\n', ''):
                with patch.object(Path, 'read_text', lambda target, *args, **kwargs:
                        source + suffix if target == path
                        else original_text(target, *args, **kwargs)):
                    require(live_invocation_lists(path) == expected,
                            'deferred cache eviction changed original parser result')
            require(parsed == [path] * 4 and _parsed_invocation_lists.cache_info().maxsize == 2
                    and _parsed_invocation_lists.cache_info().currsize == 2,
                    'deferred parser cache eviction or two-entry bound drifted')
        require(rows_function() == expected_rows,
                'deferred parser cache controls changed original authority')
    _parsed_invocation_lists.cache_clear()
    print('DEFERRED_INVOCATION_DECODE_CACHE_CONTROLS_PASS', flush=True)


def normalize_defer_order_invocations(registry, rows):
    """Project only the complete, physically pinned order-matrix calls."""
    row = identity(registry)
    physical_files(registry, row)
    actual = [p for p in rows if p['path'] == DEFER_ORDER_RUNNER]
    expected = row['defer_order_native_invocations']
    without_line = lambda p: {k:v for k,v in p.items() if k != 'line'}
    commands = ("[str(ROOT / 'gust'), '--backend', 'cranelift', '-o', str(binary), str(source)]",
                "[str(ROOT / 'gust'), '--backend', 'cranelift', '-o', str(binary), str(INTERNAL)]")
    require(len(actual) == len(expected) == 2 and
            [without_line(p) for p in actual] == [without_line(p) for p in expected] and
            actual == defer_order_invocation_rows() and
            all(p['selection'] == 'explicit_cranelift' for p in actual) and
            tuple(p['command'] for p in actual) == commands,
            'deferred allocator order compiler invocation missing, extra or substituted')
    return [p for p in rows if p['path'] != DEFER_ORDER_RUNNER]


def current_projections():
    import phase26_2_allocator_registration as previous
    return previous.current_projections()


def build_record():
    import phase24_semantic_spelling_inventory as spelling
    values = current_projections()
    sites = spelling.source_sites()
    return dict(predecessor_main=BASE, owner='cranelift', guard=GUARD,
        phase26_2_status='OPEN', od23='OPEN; no slot ownership or admission selected',
        operational_state_excluded=STATE, defer_native_invocations=defer_invocation_rows(),
        defer_order_native_invocations=defer_order_invocation_rows(),
        changed_files=[dict(path=p, previous_digest=sha(base_bytes(p)),
            current_digest=sha((ROOT / p).read_bytes())) for p in CHANGED],
        added_files=[dict(path=p, digest=sha((ROOT / p).read_bytes())) for p in ADDED],
        owned_text={k:fingerprint([p for p in operational_text(k,values[k]) if p['path'] in CHANGED+ADDED])
            for k in ('text','r4_text')},
        projections={k:fingerprint(canonical_projection(k,v)) for k,v in values.items()},
        spelling_render_current_digest=sha(spelling.render(spelling.load_authority(), sites,
            spelling.manifest_summary(sites)).encode()))


def workflow_profile(text, build_arguments, guard, trigger):
    bootstrap = 'run: python3 ' + BOOTSTRAP + ' ' + build_arguments
    qualification = 'run: python3 scripts/phase26_release_bounded.py just ' + guard
    require(text.count(bootstrap) == 1 and text.count(qualification) == 1 and
            text.count("      - '" + trigger + "'") == 2 and
            'run: python3 ' + BOOTSTRAP + ' just ' not in text and
            'if: false' not in text and 'timeout-minutes: 60' in text,
            'bootstrap/qualification workflow profile drifted')


def toolchain_workflow_profile(text, artifact):
    dependencies = ('phase26_production_toolchain.py', 'phase26_toolchain_compatibility.py',
                    'phase26_production_toolchain_controls.py')
    retention = ('      - name: Retain closed existing-package transaction provenance\n'
        '        if: always()\n'
        '        uses: actions/upload-artifact@v4\n'
        '        with:\n'
        '          name: '+artifact+'\n'
        '          if-no-files-found: error\n'
        '          path: |\n'
        '            build/phase26-2-toolchain/*.json\n'
        '            build/phase26-2-toolchain/apt-simulation.*\n')
    require(all(text.count("      - 'scripts/"+name+"'") == 2 for name in dependencies) and
            text.count('run: python3 scripts/phase26_production_toolchain.py install-ci build/phase26-2-toolchain') == 1 and
            text.count(retention) == 1,
            'closed toolchain workflow obligation drifted')


def release_workflow_profile(text):
    # This predecessor now owns an authenticated cold 4GiB product build.
    # A preceding 6GiB bootstrap would warm it and invalidate that evidence.
    require(text == base_bytes(RELEASE_WORKFLOW).decode() and
            'run: python3 scripts/phase26_release_execution.py build ' in text and
            BOOTSTRAP not in text,
            'protected cold product workflow profile drifted')


def lifecycle_evidence(registry, source):
    """Reanchor only two old call coordinates after current physical pin checks."""
    import phase26_2_allocator_lifecycle_evidence as evidence
    row = identity(registry)
    physical_files(registry, row)
    pin = next(p for p in row['changed_files'] if p['path'] == 'compiler/typechecker.gst')
    require(sha(source.encode()) == pin['current_digest'], 'current lifecycle source drifted')
    try:
        evidence.validate(source)
    except ValueError as error:
        require(False, str(error))
    return evidence.RETIRED


def lifecycle_legacy_inversions(registry, rejected):
    """Keep old authority/fixture/inert checks executable in their exact base view."""
    import phase20_arena_lifecycle as lifecycle
    import phase26_2_allocator_lifecycle_evidence as evidence
    from unittest.mock import patch
    original = Path.read_text
    previous = project_registry(registry)
    predecessor = base_bytes('compiler/typechecker.gst').decode()
    fixture = ROOT / previous['phase20_arena_lifecycle']['semantic_fixture']
    fixture_text = fixture.read_text()

    def check(value, source, semantic=fixture_text):
        def read(path, *args, **kwargs):
            if path == lifecycle.REGISTRY:
                return json.dumps(value)
            if path == lifecycle.TYPECHECKER:
                return source
            if path == fixture:
                return semantic
            return original(path, *args, **kwargs)
        with patch.object(Path, 'read_text', read):
            try:
                return lifecycle.validate()
            except lifecycle.Error as error:
                raise SystemExit(str(error)) from error

    check(previous, predecessor)
    changed = copy.deepcopy(previous)
    changed['phase20_arena_lifecycle']['observed_operations'].pop()
    rejected('legacy operation coverage', lambda: check(changed, predecessor),
             'arena lifecycle operation coverage drifted')
    changed = copy.deepcopy(previous)
    changed['phase20_arena_lifecycle']['identity_flows'].pop()
    rejected('legacy identity flow coverage', lambda: check(changed, predecessor),
             'arena lifecycle identity-flow coverage drifted')
    parameter = 'env_arena_lifecycle_record_binding(env, param.name, param_arena_identity, ctx)'
    require(predecessor.count(parameter) == 1, 'legacy parameter mutation did not move')
    rejected('legacy parameter transport',
             lambda: check(previous, predecessor.replace(parameter, 'omitted_parameter', 1)),
             'arena lifecycle compiler evidence missing: '+parameter)
    observer = evidence.function_source(predecessor, 'env_arena_lifecycle_observe_identity')
    for label, addition in (
            ('enforcing inert observer', 'report_error(2);'),
            ('freed inert observer', 'state.state = arena_lifecycle_state_freed();')):
        changed_observer = observer[:observer.rfind('}')] + addition + observer[observer.rfind('}'):]
        changed_source = predecessor.replace(observer, changed_observer, 1)
        require(changed_source != predecessor, 'legacy observer mutation did not move')
        rejected('legacy '+label,
                 lambda changed_source=changed_source: check(previous, changed_source),
                 'Patch 20.4 inert observation primitive changed meaning')
    require('"alias"' in fixture_text, 'legacy fixture mutation did not move')
    rejected('legacy fixture coverage',
             lambda: check(previous, predecessor, fixture_text.replace('"alias"', '"omitted"')),
             'arena lifecycle semantic fixture coverage missing: "alias"')
    rejected('missing successor cannot opt current source out',
             lambda: check(previous, (ROOT/'compiler/typechecker.gst').read_text()),
             'arena lifecycle compiler evidence missing: '+evidence.RETIRED[0])


def check_r3_source_route(text):
    previous = base_bytes(R3_GUARD).decode()
    fetch = ('archive="$scratch/zlib-1.3.2.tar.gz"\n'
             "curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \\\n"
             '    --retry 3 --max-time 90 https://zlib.net/fossils/zlib-1.3.2.tar.gz \\\n'
             '    --output "$archive"\n')
    require(previous.count(fetch) == 1, 'R3 source guard predecessor fetch anchor drifted')
    expected = previous.replace(fetch,
        'archive=compiler/experiments/cranelift/production/source/zlib-1.3.2.tar.gz\n', 1)
    require(text == expected, 'R3 canonical source route or unchanged guard assertions drifted')


def validate():
    registry = json.loads(REGISTRY.read_text())
    row = identity(registry)
    require(project_registry(registry) == json.loads(base_bytes('scripts/cranelift_feature_registry.json')),
            'allocator identity changed frozen predecessor or foreign registry rows')
    physical_files(registry, row)
    check_r3_source_route((ROOT/R3_GUARD).read_text())
    import phase20_arena_lifecycle as lifecycle
    try:
        lifecycle.validate()
    except lifecycle.Error as error:
        require(False, str(error))
    for path, arguments, guard, trigger in WORKFLOWS:
        workflow_profile((ROOT/path).read_text(), arguments, guard, trigger)
        artifact = 'phase26-2-allocator-'+('identity' if guard == GUARD else 'liveness')+'-toolchain'
        toolchain_workflow_profile((ROOT/path).read_text(), artifact)
    release_workflow_profile((ROOT/RELEASE_WORKFLOW).read_text())
    require((ROOT/'justfile').read_bytes() == cleanup_witnesses.directory_justfile(
        base_bytes('justfile')+RECIPE.encode()), 'allocator recipe drifted')
    levels = json.loads((ROOT/'scripts/cranelift_test_levels.json').read_text())
    require(levels['guards'].pop(GUARD,None)==2 and levels==json.loads(base_bytes('scripts/cranelift_test_levels.json')),
            'allocator test level or predecessor guards drifted')
    for kind,value in current_projections().items():
        project(registry,kind,value)
    print(GUARD+': exact additive registration PASS')


def inversions():
    validate()
    from phase26_2_allocator_predecessor_controls import indexed_coordinate_controls
    indexed_coordinate_controls(sys.modules[__name__])
    registry = json.loads(REGISTRY.read_text())
    from unittest.mock import patch
    import phase26_2_allocator_lifecycle_evidence as lifecycle_evidence
    for result in lifecycle_evidence.inversions((ROOT/'compiler/typechecker.gst').read_text(),
            base_bytes('compiler/typechecker.gst').decode()):
        print(result['label']+': '+result['outcome']+': '+result['assertion'], flush=True)
    def rejected(label,callback,expected):
        try:
            callback()
        except SystemExit as error:
            if expected not in str(error):
                raise SystemExit(label+': REJECTED (different assertion): '+str(error))
            print(label+': REJECTED (expected assertion): '+str(error),flush=True)
        else:
            raise SystemExit(label+': ACCEPTED')
    cr15_predecessor_controls(rejected)
    for result in cleanup_witnesses.predecessor_controls():
        print(result['label'] + ': ' + result['outcome'] + ': ' + result['assertion'], flush=True)
    invocation_cache_controls(registry, rejected)
    import phase22_opening as opening
    import phase26_r3_zlib_adapter_registration as r3
    require(not opening.python_compiler_lists(Path(__file__)),
            'registration metadata is represented as an executable compiler call')
    require(not any(p['path'] in (DEFER_RUNNER, DEFER_ORDER_RUNNER)
                    for p in opening.scan_invocations()),
            'global deferred invocation projection did not move')
    require(r3.normalize_invocations(registry, r3.invocation_rows()) == [],
            'R3 partial invocation compatibility drifted')
    calls = defer_invocation_rows()
    require(normalize_defer_invocations(registry, calls) == [],
            'deferred lexical invocation projection did not move')
    changed_call = dict(calls[0], selection='implicit_default')
    for label, changed_calls in (('missing', []), ('extra', calls + calls),
                                 ('substituted', [changed_call])):
        rejected('deferred compiler invocation ' + label,
                 lambda changed_calls=changed_calls: normalize_defer_invocations(registry, changed_calls),
                 'deferred lexical compiler invocation missing, extra or substituted')
    foreign_call = dict(calls[0], path='scripts/unregistered-foreign-call.py')
    require(normalize_defer_invocations(registry, calls + [foreign_call]) == [foreign_call],
            'deferred lexical invocation projection hid foreign call')
    missing = copy.deepcopy(registry)
    missing['phase26_activation_audit'].pop(KEY)
    rejected('missing deferred invocation authority',
             lambda: normalize_defer_invocations(missing, calls),
             'allocator proof identity, file population or operational-state retirement drifted')
    order_calls = defer_order_invocation_rows()
    require(normalize_defer_order_invocations(registry, order_calls) == [],
            'deferred allocator order invocation projection did not move')
    substituted = dict(order_calls[0], selection='implicit_default')
    for label, changed_calls in (
            ('missing all', []), ('missing source call', order_calls[1:]),
            ('missing internal call', order_calls[:1]), ('extra', order_calls + order_calls[:1]),
            ('substituted', [substituted, order_calls[1]]),
            ('reordered', list(reversed(order_calls)))):
        rejected('deferred order compiler invocation ' + label,
                 lambda changed_calls=changed_calls: normalize_defer_order_invocations(registry, changed_calls),
                 'deferred allocator order compiler invocation missing, extra or substituted')
    foreign_order_call = dict(order_calls[0], path='scripts/unregistered-foreign-order.py')
    require(normalize_defer_order_invocations(registry, order_calls + [foreign_order_call]) == [foreign_order_call],
            'deferred allocator order invocation projection hid foreign call')
    rejected('missing deferred order invocation authority',
             lambda: normalize_defer_order_invocations(missing, order_calls),
             'allocator proof identity, file population or operational-state retirement drifted')
    source_route = (ROOT/R3_GUARD).read_text()
    for label, changed_route in (
            ('network rollback', base_bytes(R3_GUARD).decode()),
            ('substituted archive', source_route.replace(
                'archive=compiler/experiments/cranelift/production/source/zlib-1.3.2.tar.gz',
                'archive=unverified.tar.gz', 1)),
            ('removed digest check', source_route.replace('| sha256sum -c -', '| cat', 1)),
            ('omitted native assertion', source_route.replace(
                "rg -F 'test result: ok. 1 passed; 0 failed'", "rg -F 'test result:'", 1))):
        require(changed_route != source_route, 'R3 source route inversion did not move: '+label)
        rejected('R3 '+label, lambda text=changed_route:check_r3_source_route(text),
                 'R3 canonical source route or unchanged guard assertions drifted')
    profile = profile_baseline()
    profile_mutations = []
    for field, value in (('schema', 'other'), ('base', '0' * 40),
                         ('predecessor_baseline_sha256', '0' * 64)):
        changed = copy.deepcopy(profile)
        changed[field] = value
        profile_mutations.append((field, changed))
    changed = copy.deepcopy(profile)
    changed['files'].pop(PROFILE_CHANGED[0])
    profile_mutations.append(('omitted predecessor file', changed))
    changed = copy.deepcopy(profile)
    changed['files']['foreign'] = ''
    profile_mutations.append(('extra predecessor file', changed))
    for label, changed in profile_mutations:
        _profile_baseline.cache_clear()
        try:
            # Keep the immutable raw-byte check, then exercise the independent
            # decoded authority checks without modifying either archive.
            with patch.object(gzip, 'decompress', return_value=json.dumps(changed).encode()):
                rejected('bootstrap predecessor ' + label, profile_baseline,
                    'bootstrap profile predecessor identity or file population drifted')
        finally:
            _profile_baseline.cache_clear()
    for path, arguments, guard, trigger in WORKFLOWS:
        workflow = (ROOT/path).read_text()
        bootstrap = 'run: python3 ' + BOOTSTRAP + ' ' + arguments
        qualification = 'run: python3 scripts/phase26_release_bounded.py just ' + guard
        for label, changed in (
                ('unbounded bootstrap', workflow.replace(bootstrap, 'run: ' + arguments, 1)),
                ('old bootstrap cap', workflow.replace(bootstrap,
                    'run: python3 scripts/phase26_release_bounded.py ' + arguments, 1)),
                ('qualification at bootstrap cap', workflow.replace(qualification,
                    'run: python3 ' + BOOTSTRAP + ' just ' + guard, 1)),
                ('omitted bootstrap trigger', workflow.replace("      - '" + trigger + "'\n", '', 1)),
                ('duplicated bootstrap', workflow + '\n' + bootstrap),
                ('disabled qualification', workflow.replace('    if: github.actor',
                    '    if: false # github.actor', 1))):
            require(changed != workflow, 'workflow inversion did not move: ' + path + ' ' + label)
            rejected(path + ' ' + label,
                lambda changed=changed,arguments=arguments,guard=guard,trigger=trigger:
                    workflow_profile(changed, arguments, guard, trigger),
                'bootstrap/qualification workflow profile drifted')
    for path, _, guard, _ in WORKFLOWS:
        workflow = (ROOT/path).read_text()
        artifact = 'phase26-2-allocator-'+('identity' if guard == GUARD else 'liveness')+'-toolchain'
        toolchain_workflow_profile(workflow, artifact)
        for label, changed in (
                ('omitted compatibility trigger', workflow.replace("      - 'scripts/phase26_toolchain_compatibility.py'\n", '', 1)),
                ('bypassed installer', workflow.replace('run: python3 scripts/phase26_production_toolchain.py install-ci build/phase26-2-toolchain', 'run: true', 1)),
                ('omitted transaction provenance', workflow.replace('          name: '+artifact+'\n', '', 1)),
                ('disabled provenance', workflow.replace('      - name: Retain closed existing-package transaction provenance\n        if: always()', '      - name: Retain closed existing-package transaction provenance\n        if: false', 1))):
            require(changed != workflow, 'toolchain workflow inversion did not move')
            rejected('toolchain '+label, lambda changed=changed,artifact=artifact:
                     toolchain_workflow_profile(changed, artifact),
                     'closed toolchain workflow obligation drifted')
    workflow = (ROOT/RELEASE_WORKFLOW).read_text()
    build = 'run: python3 scripts/phase26_release_execution.py build build/guards/phase26_release_execution'
    qualification = 'run: python3 scripts/phase26_release_bounded.py just guard-cranelift-phase26-release-closure'
    for label, changed in (
            ('6GiB substitution', workflow.replace(build, 'run: python3 '+BOOTSTRAP+' make gust', 1)),
            ('skipped cold build', workflow.replace(build, 'run: true', 1)),
            ('warmup before cold build', workflow.replace('      - name: Build current native compiler\n',
                '      - name: Warm current compiler\n        run: python3 '+BOOTSTRAP+' make gust\n'
                '      - name: Build current native compiler\n', 1)),
            ('missing authenticated metadata', workflow.replace('          GUST_RELEASE_METADATA_TOKEN: ${{ github.token }}\n', '', 1)),
            ('qualification at bootstrap cap', workflow.replace(qualification,
                'run: python3 '+BOOTSTRAP+' just guard-cranelift-phase26-release-closure', 1)),
            ('omitted product trigger', workflow.replace("      - 'scripts/phase26_*.py'\n", '', 1))):
        require(changed != workflow, 'product workflow inversion did not move: '+label)
        rejected('protected product '+label, lambda changed=changed:release_workflow_profile(changed),
                 'protected cold product workflow profile drifted')
    lifecycle_legacy_inversions(registry, rejected)
    original_lifecycle = lifecycle_baseline()
    for label, replacement in (
            ('schema', {'schema': 'wrong'}),
            ('base', {'base': 'wrong'}),
            ('file population', {'files': {}}),
            ('Phase20 authority', {'phase20_authority_sha256': '0'*64}),
            ('retired conjunct population', {'retired_anchors': []})):
        changed_lifecycle = copy.deepcopy(original_lifecycle)
        changed_lifecycle.update(replacement)
        _lifecycle_baseline.cache_clear()
        try:
            with patch.object(gzip, 'decompress', return_value=json.dumps(changed_lifecycle).encode()):
                rejected('lifecycle predecessor '+label, lifecycle_baseline,
                         'lifecycle predecessor identity or file population drifted')
        finally:
            _lifecycle_baseline.cache_clear()
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
