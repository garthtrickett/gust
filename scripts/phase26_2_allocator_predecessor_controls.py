"""Separate frozen predecessor pin proof from actual current composed refusal."""
import ast
from contextlib import contextmanager
import copy
import json
from pathlib import Path
import types
from unittest.mock import patch


def _function(source, name):
    matches = [node for node in ast.parse(source).body
               if isinstance(node, ast.FunctionDef) and node.name == name]
    assert len(matches) == 1, name
    return matches[0]


def _frozen_renewal(child):
    path = 'scripts/phase26_production_renewal_registration.py'
    raw = child.base_bytes(path)  # Hash-checked exact merged39 input, never Git/network.
    module = types.ModuleType('_allocator_frozen39_renewal_pin_control')
    module.__file__ = str(child.ROOT/path)
    exec(compile(raw, module.__file__, 'exec'), module.__dict__)
    return module


def _verify_liveness_extraction(child, current):
    path = 'scripts/phase26_2_allocator_registration.py'
    original = _function(child.base_bytes(path), 'validate')
    actual = _function((child.ROOT/path).read_bytes(), 'check_files')
    loops = [node for node in original.body if isinstance(node, ast.For)
             and isinstance(node.iter, ast.Subscript)
             and isinstance(node.iter.value, ast.Name) and node.iter.value.id == 'row'
             and isinstance(node.iter.slice, ast.Constant)
             and node.iter.slice.value in ('changed_files', 'added_files')]
    child.require(len(loops) == 2 and len(actual.body) == 3,
                  'predecessor physical-check extraction shape drifted')
    child.require([ast.dump(node, include_attributes=False) for node in actual.body[1:]] ==
                  [ast.dump(node, include_attributes=False) for node in loops],
                  'predecessor physical-check predicates drifted from exact39')
    current_validate = _function((child.ROOT/path).read_bytes(), 'validate')
    row = [node for node in original.body if isinstance(node, ast.Assign)
           and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name)
           and node.targets[0].id == 'row']
    child.require(len(row) == 1 and ast.dump(actual.body[0], include_attributes=False) ==
                  ast.dump(row[0], include_attributes=False),
                  'predecessor physical-check identity entry drifted')
    expected_body = []
    for node in original.body:
        if node is loops[0]:
            expected_body.append(ast.parse('check_files(registry)').body[0])
        elif node is not loops[1]:
            expected_body.append(node)
    child.require([ast.dump(node, include_attributes=False) for node in current_validate.body] ==
                  [ast.dump(node, include_attributes=False) for node in expected_body],
                  'predecessor validate no longer calls exact pin seam at the original position')
    child.require(callable(current.check_files), 'predecessor physical-check seam absent')


@contextmanager
def _physical39_view(child, registry, current, frozen_renewal):
    # Always check actual current files BEFORE entering the test-only read view.
    child.physical_files(registry, child.identity(registry))
    original_read = Path.read_bytes
    view = {child.ROOT/path:child.base_bytes(path) for path in child.CHANGED}
    predecessor = json.loads(child.base_bytes('scripts/cranelift_feature_registry.json'))
    child.require(child.KEY not in predecessor['phase26_activation_audit'],
                  'frozen predecessor view contains the child authority')
    check = frozen_renewal.check_files
    if current.KEY == 'allocator_resource_liveness_successor_v1':
        _verify_liveness_extraction(child, current)
        check = current.check_files
    else:
        child.require(current.KEY == 'production_epoch2_renewal_successor_v1',
                      'unsupported predecessor pin-control owner')
    with patch.object(Path, 'read_bytes', lambda path:
            view[path] if path in view else original_read(path)):
        # Prove the full original renewal physical boundary, not a diagnostic shim.
        frozen_renewal.check_files(predecessor)
        if current.KEY == 'allocator_resource_liveness_successor_v1':
            with patch.object(current, 'successor', frozen_renewal):
                check(predecessor)
                yield predecessor, check
        else:
            check(predecessor)
            yield predecessor, check


def composed_added_controls(current, registry, rejected):
    """Return the explicitly tested overlapping added pins; test no others here."""
    import phase26_2_allocator_identity_registration as child
    if not child.record(registry):
        return set()  # The unchanged parent still runs every original control.
    overlaps = set(current.ADDED) & set(child.CHANGED + child.ADDED)
    frozen = _frozen_renewal(child)
    for path in sorted(overlaps):
        child.require(path in child.CHANGED,
                      'unreviewed added-versus-added predecessor pin overlap: '+path)
        physical = child.ROOT/path
        original_read = Path.read_bytes
        with patch.object(Path, 'read_bytes', lambda value, physical=physical:
                original_read(value)+b'\n' if value == physical else original_read(value)):
            rejected('current composed added substitution '+path, current.validate,
                     child.GUARD+': R4 changed file drifted: '+path)
        # Enter a fresh positively checked39 view for each original pin mutation.
        with _physical39_view(child, registry, current, frozen) as (previous, check):
            original_view = Path.read_bytes
            with patch.object(Path, 'read_bytes', lambda value, physical=physical:
                    original_view(value)+b'\n' if value == physical else original_view(value)):
                expected = ('renewal added file drifted: ' if current.KEY ==
                    'production_epoch2_renewal_successor_v1' else 'allocator added file drifted: ')
                rejected('exact39 predecessor added substitution '+path,
                         lambda:check(copy.deepcopy(previous)), expected+path)
    return overlaps


def indexed_coordinate_controls(child):
    """Strict extraction stays separate from tolerant data and live admission."""
    import errno
    import phase26_predecessor_data as data
    import phase26_2_allocator_registration as liveness
    require = child.require

    def rejects(label, callback, kind, message=None):
        try:
            callback()
        except kind as error:
            require(message is None or message in str(error),
                    label+': REJECTED (different assertion): '+str(error))
            print(label+': REJECTED (expected '+kind.__name__+')', flush=True)
        else:
            raise SystemExit(label+': ACCEPTED')

    value = {'phase26_activation_audit': {
        'alpha': {'changed_files': [dict(path='target', current_digest='one', previous_digest='zero'),
                                   dict(path='other', current_digest='x', previous_digest='y')]},
        'beta': {'changed_files': [dict(path='target', current_digest='two', previous_digest='one')]}}}
    raw = json.dumps(value).encode()
    strict = data.inherited_digests_indexed
    try:
        data.clear_cache()
        require(strict(raw, 'target', ('alpha',)) == frozenset(('zero', 'one')),
                'indexed coordinate values drifted')
        require(strict(raw, 'target', ('alpha',)) == frozenset(('zero', 'one')) and
                data.cache_state()['hits'] == 1, 'indexed cache was not warmed')
        require(strict(raw, 'target', ('alpha', 'beta')) == frozenset(('zero', 'one', 'two')),
                'indexed cohort change reused old coordinates')
        misses = data.cache_state()['misses']
        strict(raw, 'target', ('beta', 'alpha'))
        require(data.cache_state()['misses'] == misses+1, 'indexed cohort order omitted from key')
        require(strict(raw, 'other', ('alpha',)) == frozenset(('x', 'y')),
                'indexed path change reused old coordinates')
        changed = copy.deepcopy(value)
        changed['phase26_activation_audit']['alpha']['changed_files'][0]['current_digest'] = 'three'
        require(strict(json.dumps(changed).encode(), 'target', ('alpha',)) == frozenset(('zero', 'three')),
                'indexed content change reused old coordinates')

        missing = copy.deepcopy(value)
        missing['phase26_activation_audit']['alpha']['changed_files'][0].pop('path')
        malformed = json.dumps(missing).encode()
        with patch.object(data, 'PREDECESSORS', ('alpha',)):
            require(data.inherited_digests(malformed, 'target') == frozenset(),
                    'unchanged tolerant default no longer ignores an absent path')
            rejects('strict operation after tolerant warm missing path',
                    lambda:strict(malformed, 'target', ('alpha',)), KeyError, 'path')
            rejects('strict missing path errors remain uncached',
                    lambda:strict(malformed, 'target', ('alpha',)), KeyError, 'path')
        for field in ('current_digest', 'previous_digest'):
            missing = copy.deepcopy(value)
            missing['phase26_activation_audit']['alpha']['changed_files'][0].pop(field)
            rejects('strict missing '+field,
                    lambda missing=missing:strict(json.dumps(missing).encode(), 'target', ('alpha',)),
                    KeyError, field)
        rejects('strict missing cohort', lambda:strict(raw, 'target', ('absent',)), KeyError, 'absent')
        rejects('strict malformed JSON', lambda:strict(b'{', 'target', ('alpha',)), json.JSONDecodeError)
        data.clear_cache()
        with patch.object(data, 'ENTRY_LIMIT', 1):
            strict(raw, 'target', ('alpha',))
            strict(raw, 'other', ('alpha',))
            misses = data.cache_state()['misses']
            strict(raw, 'target', ('alpha',))
            require(data.cache_state()['entries'] == 1 and data.cache_state()['misses'] == misses+1,
                    'indexed operation bypassed shared entry eviction')
        data.clear_cache()
        with patch.object(data, 'BYTE_LIMIT', 1):
            require(strict(raw, 'target', ('alpha',)) == frozenset(('zero', 'one')) and
                    data.cache_state()['entries'] == 0, 'indexed oversized fallback changed')

        # Exercise both real callers after warming; no test view is active here.
        registry = json.loads(child.REGISTRY.read_text())
        path = 'compiler/typechecker.gst'
        physical = child.ROOT/path
        live = child.sha(physical.read_bytes())
        for owner in (child, liveness):
            data.clear_cache()
            expected = owner.prior_digest(registry, path, live)
            require(owner.prior_digest(registry, path, live) == expected and
                    data.cache_state()['hits'] > 0, 'real indexed caller did not warm cache')
            original_base = owner.base_bytes
            def missing_registry(name):
                if name == 'scripts/cranelift_feature_registry.json':
                    raise FileNotFoundError(errno.ENOENT, 'missing indexed predecessor seam', name)
                return original_base(name)
            with patch.object(owner, 'base_bytes', missing_registry):
                rejects(owner.KEY+' warm missing registry seam',
                        lambda:owner.prior_digest(registry, path, live), FileNotFoundError,
                        'missing indexed predecessor seam')
            original_read = Path.read_bytes
            def missing_physical(candidate):
                if candidate == physical:
                    raise FileNotFoundError(errno.ENOENT, 'missing indexed physical input', str(candidate))
                return original_read(candidate)
            with patch.object(Path, 'read_bytes', missing_physical):
                rejects(owner.KEY+' warm missing physical input',
                        lambda:owner.prior_digest(registry, path, live), FileNotFoundError,
                        'missing indexed physical input')
            with patch.object(Path, 'read_bytes', lambda candidate:
                    original_read(candidate)+b'\n' if candidate == physical else original_read(candidate)):
                rejects(owner.KEY+' warm substituted physical input',
                        lambda:owner.prior_digest(registry, path, live), SystemExit,
                        'R4 changed file drifted')
            require(owner.prior_digest(registry, path, live) == expected,
                    'indexed controls changed restored admission')
        state = data.cache_state()
        require(state['entries'] <= state['max_entries'] and state['accounted_bytes'] <= state['max_bytes'],
                'indexed operation exceeded shared cache bounds')
        from phase26_2_predecessor_index_controls import controls as document_index_controls
        document_index_controls()
        print('ALLOCATOR_INDEXED_COORDINATE_CONTROLS_PASS', flush=True)
    finally:
        data.clear_cache()
