"""Bounded memoization of immutable predecessor data, never live admission.

Callers still obtain their actual payload on every call and check all live
physical pins. Content and requested path are the complete cache keys.
"""
from collections import OrderedDict
import base64
import json
import sys

ENTRY_LIMIT = 64
BYTE_LIMIT = 128 * 1024 ** 2
_CACHE = OrderedDict()
_retained = 0
_hits = 0
_misses = 0

PREDECESSORS = (
    "allocator_resource_liveness_successor_v1", "first_release_closure_successor_v1",
    "readonly_input_copy_successor_v1", "closed_ticket_composition_successor_v1",
    "imported_native_successor_v1", "scoped_ticket_publication_successor_v1",
)


def _scalar_size(value):
    if type(value) is str:
        # Include a conservative allowance for a retained UTF-8 representation.
        return sys.getsizeof(value) + 4 * len(value)
    if type(value) in (bytes, int, float, bool, type(None)):
        return sys.getsizeof(value)
    return None


def _key_size(key):
    total = 1024 + sys.getsizeof(key)  # Container/node/counter overhead allowance.
    for part in key:
        if type(part) not in (str, bytes):
            return None
        total += _scalar_size(part)
        if total > BYTE_LIMIT:
            return None
    return total


def _result_size(value):
    if type(value) is bytes:
        return sys.getsizeof(value)
    if type(value) is not frozenset:
        return None
    total = sys.getsizeof(value)
    if total > BYTE_LIMIT:
        return None
    for part in value:
        size = _scalar_size(part)
        if size is None:
            return None
        total += size
        if total > BYTE_LIMIT:
            return None
    return total


def _memoized(key, produce):
    global _retained, _hits, _misses
    key_size = _key_size(key)
    if key_size is None:
        return produce()  # Mutable, unsupported or oversized input: original algorithm.
    found = _CACHE.get(key)
    if found is not None:
        _CACHE.move_to_end(key)
        _hits += 1
        return found[0]
    _misses += 1
    value = produce()  # Exceptions retain their original type; never cached.
    result_size = _result_size(value)
    if result_size is None or key_size + result_size > BYTE_LIMIT:
        return value
    cost = key_size + result_size
    while _CACHE and (len(_CACHE) >= ENTRY_LIMIT or _retained + cost > BYTE_LIMIT):
        _old_key, (_old_value, old_cost) = _CACHE.popitem(last=False)
        _retained -= old_cost
    if ENTRY_LIMIT > 0 and cost <= BYTE_LIMIT:
        _CACHE[key] = (value, cost)
        _retained += cost
    return value


def decoded_payload(encoded):
    return _memoized(("base64", encoded), lambda: base64.b64decode(encoded, validate=True))


def _derive_coordinates(raw, path, cohort):
    predecessor = json.loads(raw)
    result = set()
    for key in cohort:
        for item in predecessor["phase26_activation_audit"][key]["changed_files"]:
            if item.get("path") == path:
                result.update(item[field] for field in ("current_digest", "previous_digest"))
    return frozenset(result)


def inherited_digests(raw, path):
    cohort = tuple(PREDECESSORS)
    return _memoized(("coordinates", raw, path, *cohort),
                     lambda: _derive_coordinates(raw, path, cohort))


def inherited_digests_indexed(raw, path, cohort):
    """Preserve callers whose original loop requires every row's path key.

    The tolerant default above deliberately keeps its existing get() semantics.
    Only immutable extraction is reused; callers still read and validate their
    physical dependency and current file on each invocation.
    """
    cohort = tuple(cohort)
    def derive():
        predecessor = json.loads(raw)
        result = set()
        for key in cohort:
            for item in predecessor["phase26_activation_audit"][key]["changed_files"]:
                if item["path"] == path:
                    result.update(item[field] for field in ("current_digest", "previous_digest"))
        return frozenset(result)
    return _memoized(("indexed_coordinates", raw, path, *cohort), derive)


def clear_cache():
    global _retained, _hits, _misses
    _CACHE.clear()
    _retained = _hits = _misses = 0


def cache_state():
    return dict(entries=len(_CACHE), accounted_bytes=_retained,
                hits=_hits, misses=_misses, max_entries=ENTRY_LIMIT, max_bytes=BYTE_LIMIT)
