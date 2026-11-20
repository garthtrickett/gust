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
_document_hits = 0
_document_misses = 0
_JSON_LOADS = json.loads
_JSON_DUMPS = json.dumps

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


def _memoized(key, produce, *, document=False):
    global _retained, _hits, _misses, _document_hits, _document_misses
    key_size = _key_size(key)
    if key_size is None:
        return produce()  # Mutable, unsupported or oversized input: original algorithm.
    found = _CACHE.get(key)
    if found is not None:
        _CACHE.move_to_end(key)
        if document:
            _document_hits += 1
        else:
            _hits += 1
        return found[0]
    if document:
        _document_misses += 1
    else:
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


def _derive_indexed(raw, path, cohort):
    """The original strict, requested-path operation, including its errors."""
    predecessor = json.loads(raw)
    result = set()
    for key in cohort:
        for item in predecessor["phase26_activation_audit"][key]["changed_files"]:
            if item["path"] == path:
                result.update(item[field] for field in ("current_digest", "previous_digest"))
    return frozenset(result)


def _document_index(raw, cohort):
    """Return immutable canonical string rows, or decline to optimize."""
    key_cost = _key_size(("indexed_document", raw, *cohort))
    if key_cost is None:
        return None
    predecessor = json.loads(raw)
    if type(predecessor) is not dict:
        return None
    audit = predecessor.get("phase26_activation_audit")
    if type(audit) is not dict:
        return None
    result = set()
    retained_strings = 0
    for key in cohort:
        owner = audit.get(key)
        if type(owner) is not dict or type(owner.get("changed_files")) is not list:
            return None
        for item in owner["changed_files"]:
            fields = ("path", "current_digest", "previous_digest")
            if type(item) is not dict or not all(type(item.get(field)) is str for field in fields):
                # Do not introduce errors from an unrelated row: the original
                # operation only accesses digest fields on the requested path.
                return None
            encoded = json.dumps([item[field] for field in fields], separators=(",", ":"))
            if encoded not in result:
                retained_strings += _scalar_size(encoded)
                result.add(encoded)
                if key_cost + sys.getsizeof(result) + retained_strings > BYTE_LIMIT:
                    return None
    return frozenset(result)


def _indexed_lookup(raw, path, cohort):
    key = ("indexed_document", raw, *cohort)
    if ENTRY_LIMIT < 2 or _key_size(key) is None:
        return _derive_indexed(raw, path, cohort)
    index = _memoized(key, lambda: _document_index(raw, cohort), document=True)
    if index is None:
        return _derive_indexed(raw, path, cohort)
    prefix = "[" + json.dumps(path) + ","
    result = set()
    for encoded in index:
        if encoded.startswith(prefix):
            _path, current, previous = json.loads(encoded)
            result.update((current, previous))
    return frozenset(result)


def inherited_digests_indexed(raw, path, cohort):
    """Strict coordinates with a shared-budget immutable document index.

    Public results retain their original per-path keys and counter semantics.
    Nothing here caches a physical dependency, live pin or admission verdict.
    """
    cohort = tuple(cohort)
    if (type(raw) not in (str, bytes) or type(path) is not str or
            not all(type(key) is str for key in cohort) or
            json.loads is not _JSON_LOADS or json.dumps is not _JSON_DUMPS):
        return _derive_indexed(raw, path, cohort)
    return _memoized(("indexed_coordinates", raw, path, *cohort),
                     lambda: _indexed_lookup(raw, path, cohort))


def clear_cache():
    global _retained, _hits, _misses, _document_hits, _document_misses
    _CACHE.clear()
    _retained = _hits = _misses = 0
    _document_hits = _document_misses = 0


def cache_state():
    return dict(entries=len(_CACHE), accounted_bytes=_retained,
                hits=_hits, misses=_misses, max_entries=ENTRY_LIMIT, max_bytes=BYTE_LIMIT,
                document_hits=_document_hits, document_misses=_document_misses,
                document_entries=sum(key[0] == "indexed_document" for key in _CACHE))
