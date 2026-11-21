"""Immutable-index equivalence, lazy-error and shared-budget controls."""
import copy
import json
import sys
from unittest.mock import patch

import phase26_predecessor_data as data


def controls():
    rows = []
    strict = data.inherited_digests_indexed

    def checked(label, condition):
        assert condition, label
        rows.append(dict(label=label, outcome='PASS'))

    def bounded():
        state = data.cache_state()
        assert state['entries'] <= state['max_entries']
        assert 0 <= state['accounted_bytes'] <= state['max_bytes']

    def observe(fn):
        try:
            return 'value', fn()
        except Exception as error:
            return 'error', type(error), error.args

    value = {'phase26_activation_audit': {
        'alpha': {'changed_files': [
            dict(path='target', current_digest='one', previous_digest='zero'),
            dict(path='other', current_digest='x', previous_digest='y')]},
        'beta': {'changed_files': [
            dict(path='target', current_digest='two', previous_digest='one')]}}}
    raw = json.dumps(value).encode()
    try:
        data.clear_cache()
        checked('literal strict union', strict(raw, 'target', ('alpha', 'beta')) ==
                frozenset(('zero', 'one', 'two')))
        checked('literal other path', strict(raw, 'other', ('alpha', 'beta')) ==
                frozenset(('x', 'y')))
        checked('absent requested path', strict(raw, 'absent', ('alpha', 'beta')) == frozenset())

        cases = [('duplicate cohort', raw, 'target', ('alpha', 'alpha', 'beta')),
                 ('reordered cohort', raw, 'target', ('beta', 'alpha')),
                 ('empty cohort and no authority', b'[]', 'target', ()),
                 ('missing cohort', raw, 'target', ('missing',)),
                 ('malformed JSON', b'{', 'target', ('alpha',)),
                 ('invalid UTF8', b'\xff', 'target', ('alpha',))]
        for label, target, change in (
            ('unrelated missing digest', 'other', lambda row: row.pop('current_digest')),
            ('matched missing digest', 'target', lambda row: row.pop('current_digest')),
            ('unrelated unhashable digest', 'other', lambda row: row.update(current_digest=[])),
            ('matched unhashable digest', 'target', lambda row: row.update(current_digest=[])),
            ('unrelated nonstring path', 'other', lambda row: row.update(path=['other'])),
            ('missing path', 'other', lambda row: row.pop('path')),
        ):
            changed = copy.deepcopy(value)
            item = next(r for r in changed['phase26_activation_audit']['alpha']['changed_files']
                        if r['path'] == target)
            change(item)
            cases.append((label, json.dumps(changed).encode(), 'target', ('alpha', 'beta')))
        changed = copy.deepcopy(value)
        changed['phase26_activation_audit']['alpha']['changed_files'].append(None)
        cases.append(('nonobject row', json.dumps(changed).encode(), 'target', ('alpha',)))
        changed = copy.deepcopy(value)
        changed['phase26_activation_audit']['alpha']['changed_files'].append(dict(path='target'))
        cases.append(('mixed valid invalid duplicate', json.dumps(changed).encode(), 'target', ('alpha',)))
        for label, payload, path, cohort in cases:
            data.clear_cache()
            expected = observe(lambda: data._derive_indexed(payload, path, cohort))
            checked(label + ' cold original equivalence',
                    observe(lambda: strict(payload, path, cohort)) == expected)
            checked(label + ' warm original equivalence',
                    observe(lambda: strict(payload, path, cohort)) == expected)
            bounded()

        names = ['x', 'xlong', 'x","y', 'é中\x00']
        unusual = {'phase26_activation_audit': {'alpha': {'changed_files': [
            dict(path=n, current_digest='current-' + n, previous_digest='previous-' + n)
            for n in names]}}}
        encoded = json.dumps(unusual, ensure_ascii=False).encode()
        data.clear_cache()
        for name in names:
            checked('structured path encoding ' + repr(name),
                    strict(encoded, name, ('alpha',)) ==
                    frozenset(('current-' + name, 'previous-' + name)))

        data.clear_cache()
        strict(raw, 'target', ('alpha',))
        state = data.cache_state()
        mutable = bytearray(raw)
        checked('mutable original input', strict(mutable, 'target', ('alpha',)) ==
                frozenset(('one', 'zero')))
        mutable[:] = raw.replace(b'"one"', b'"new"')
        checked('mutable changed input', strict(mutable, 'target', ('alpha',)) ==
                frozenset(('new', 'zero')))
        checked('mutable input not retained', data.cache_state() == state)

        class Text(str):
            pass

        checked('nonstandard string input fallback', strict(Text(raw.decode()), 'target', ('alpha',)) ==
                frozenset(('one', 'zero')))
        checked('nonstandard path fallback', strict(raw, Text('target'), ('alpha',)) ==
                frozenset(('one', 'zero')))
        numeric = json.dumps({'phase26_activation_audit': {'alpha': {'changed_files': [
            dict(path=17, current_digest='a', previous_digest='b')]}}}).encode()
        checked('nonstring path value fallback', strict(numeric, 17, ('alpha',)) == frozenset(('a', 'b')))

        # A warm public result cannot conceal replacement of the actual parser.
        data.clear_cache()
        strict(raw, 'target', ('alpha',))
        altered = copy.deepcopy(value)
        altered['phase26_activation_audit']['alpha']['changed_files'][0]['current_digest'] = 'replacement'
        with patch.object(data.json, 'loads', lambda _raw: copy.deepcopy(altered)):
            checked('substituted parser after warm', strict(raw, 'target', ('alpha',)) ==
                    frozenset(('replacement', 'zero')))

        def broken(_raw):
            raise RuntimeError('replacement parser error')

        with patch.object(data.json, 'loads', broken):
            checked('substituted parser exception after warm',
                    observe(lambda: strict(raw, 'target', ('alpha',))) ==
                    ('error', RuntimeError, ('replacement parser error',)))
        with patch.object(data.json, 'dumps', broken):
            checked('substituted encoder uses original operation', strict(raw, 'target', ('alpha',)) ==
                    frozenset(('one', 'zero')))

        # More paths than the entry bound must share one actual decoded document.
        many = {'phase26_activation_audit': {'alpha': {'changed_files': [
            dict(path='path-' + str(i), current_digest='now-' + str(i), previous_digest='old-' + str(i))
            for i in range(80)]}}}
        many_raw = json.dumps(many).encode()
        data.clear_cache()
        for i in range(80):
            assert (strict(many_raw, 'path-' + str(i), ('alpha',)) ==
                    frozenset(('now-' + str(i), 'old-' + str(i))))
        state = data.cache_state()
        checked('one document decoded beyond64 paths', state['document_misses'] == 1 and
                state['document_hits'] == 79 and state['document_entries'] == 1)
        checked('public counters retain per-path meaning', state['misses'] == 80 and state['hits'] == 0)
        bounded()
        misses = state['misses']
        strict(many_raw, 'path-0', ('alpha',))
        checked('coordinate eviction still effective', data.cache_state()['misses'] == misses + 1 and
                data.cache_state()['document_misses'] == 1)

        data.clear_cache()
        with patch.object(data, 'ENTRY_LIMIT', 1):
            strict(raw, 'target', ('alpha',)); strict(raw, 'other', ('alpha',))
            before = data.cache_state()
            strict(raw, 'target', ('alpha',))
            checked('original single-entry path eviction', data.cache_state()['misses'] == before['misses'] + 1 and
                    data.cache_state()['entries'] == 1 and data.cache_state()['document_entries'] == 0)
            bounded()

        data.clear_cache()
        strict(raw, 'target', ('alpha',))
        cost = data.cache_state()['accounted_bytes']
        data.clear_cache()
        with patch.object(data, 'BYTE_LIMIT', cost + 1024):
            strict(raw, 'target', ('alpha',))
            strict(raw.replace(b'"one"', b'"new"'), 'target', ('alpha',))
            before = data.cache_state()
            strict(raw, 'target', ('alpha',))
            checked('document byte-pressure eviction', data.cache_state()['document_misses'] ==
                    before['document_misses'] + 1)
            bounded()

        data.clear_cache()
        with patch.object(data, 'BYTE_LIMIT', len(many_raw) + 4096):
            checked('oversized derived index fallback', strict(many_raw, 'path-0', ('alpha',)) ==
                    frozenset(('now-0', 'old-0')) and data.cache_state()['document_entries'] == 0)
            bounded()

        # Conservative accounting includes both layers' retained keys and values.
        data.clear_cache()
        strict(encoded, names[-1], ('alpha',))
        minimum = sum(sys.getsizeof(key) + sum(sys.getsizeof(part) for part in key) +
                      sys.getsizeof(result) + sum(sys.getsizeof(part) for part in result)
                      for key, (result, _cost) in data._CACHE.items())
        checked('document and coordinate byte accounting', data.cache_state()['accounted_bytes'] >= minimum)
        bounded()
        print('PREDECESSOR_DOCUMENT_INDEX_CONTROLS_PASS ' + str(len(rows)), flush=True)
        return rows
    finally:
        data.clear_cache()


if __name__ == '__main__':
    controls()
