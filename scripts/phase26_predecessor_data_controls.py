"""Actual cache/resource/fresh-input controls for the renewal guard."""
import base64
import binascii
import copy
import errno
import json
from pathlib import Path
import sys
from unittest.mock import patch

import phase26_predecessor_data as data


def controls(registration):
    require = registration.require

    def rejects(label, callback, error_type, message=None):
        try:
            callback()
        except error_type as error:
            require(message is None or message in str(error),
                    label + ": REJECTED (different assertion): " + str(error))
            print(label + ": REJECTED (expected " + error_type.__name__ + ")", flush=True)
        else:
            raise SystemExit(label + ": ACCEPTED")

    def bounded():
        state = data.cache_state()
        require(state["entries"] <= state["max_entries"] and
                0 <= state["accounted_bytes"] <= state["max_bytes"],
                "predecessor data cache exceeded its byte/entry bound")

    data.clear_cache()
    try:
        encoded = base64.b64encode(b"first").decode()
        value = data.decoded_payload(encoded)
        require(value == b"first" and data.decoded_payload(encoded) == value,
                "content decoder changed bytes")
        require(data.cache_state()["hits"] == 1, "decoder cache mechanism did not move")
        def change_bytes():
            value[0] = 0
        rejects("decoded bytes immutable", change_bytes, TypeError)
        require(data.decoded_payload(base64.b64encode(b"next").decode()) == b"next",
                "changed encoded input reused old bytes")
        entries = data.cache_state()["entries"]
        mutable = bytearray(base64.b64encode(b"a"))
        require(data.decoded_payload(mutable) == b"a", "mutable decode fallback changed")
        mutable[:] = base64.b64encode(b"b")
        require(data.decoded_payload(mutable) == b"b" and
                data.cache_state()["entries"] == entries,
                "mutable decoder input was cached")
        rejects("invalid Base64", lambda: data.decoded_payload("?"), binascii.Error)

        records = {key: {"changed_files": [
            {"path": "first", "current_digest": "one", "previous_digest": "two"},
            {"path": "second", "current_digest": "three", "previous_digest": "four"}]}
            for key in data.PREDECESSORS}
        records[data.PREDECESSORS[-1]]["changed_files"].append(
            {"path": "first", "current_digest": "last", "previous_digest": "two"})
        raw = json.dumps({"phase26_activation_audit": records}).encode()
        coordinates = data.inherited_digests(raw, "first")
        require(coordinates == frozenset(("one", "two", "last")),
                "inherited coordinate cohort changed")
        require(data.inherited_digests(raw, "second") == frozenset(("three", "four")),
                "coordinate cache omitted its path key")
        require(data.inherited_digests(raw, "first") == coordinates,
                "coordinate cache changed its value")
        rejects("coordinate result immutable", lambda: coordinates.add("other"), AttributeError)
        changed_raw = raw.replace(b'"one"', b'"new"')
        require(data.inherited_digests(changed_raw, "first") ==
                frozenset(("new", "two", "last")), "coordinate content key was omitted")
        mutable_raw = bytearray(raw)
        require(data.inherited_digests(mutable_raw, "first") == coordinates,
                "mutable JSON fallback changed")
        mutable_raw[:] = changed_raw
        require(data.inherited_digests(mutable_raw, "first") ==
                frozenset(("new", "two", "last")), "mutable JSON was cached")
        with patch.object(data, "PREDECESSORS", data.PREDECESSORS[:-1]):
            require(data.inherited_digests(raw, "first") == frozenset(("one", "two")),
                    "coordinate cache ignored its cohort")
        rejects("invalid predecessor JSON", lambda: data.inherited_digests(b"{", "first"),
                json.JSONDecodeError)
        bounded()

        # Exercise actual eviction and oversized fallback under small test bounds.
        data.clear_cache()
        with patch.object(data, "ENTRY_LIMIT", 2), patch.object(data, "BYTE_LIMIT", 4096):
            a, b, c = [base64.b64encode(value).decode() for value in (b"a", b"b", b"c")]
            data.decoded_payload(a); data.decoded_payload(b); data.decoded_payload(a)
            data.decoded_payload(c)
            before = data.cache_state()
            require(before["entries"] == 2, "entry eviction was not exercised")
            require(data.decoded_payload(b) == b"b" and
                    data.cache_state()["misses"] == before["misses"] + 1,
                    "LRU eviction did not evict the least recently used item")
            bounded()
            entries = data.cache_state()["entries"]
            large = b"x" * 8192
            require(data.decoded_payload(base64.b64encode(large).decode()) == large and
                    data.cache_state()["entries"] == entries,
                    "oversized input did not use the unchanged uncached path")
            bounded()
        data.clear_cache()
        with patch.object(data, "ENTRY_LIMIT", 64), patch.object(data, "BYTE_LIMIT", 4096):
            first, second = [base64.b64encode(value * 128).decode() for value in (b"a", b"b")]
            data.decoded_payload(first)
            data.decoded_payload(second)
            before = data.cache_state()
            require(before["entries"] == 1, "byte-limit eviction was not exercised")
            require(data.decoded_payload(first) == b"a" * 128 and
                    data.cache_state()["misses"] == before["misses"] + 1,
                    "byte-limit eviction did not evict the previous item")
            bounded()
        data.clear_cache()
        # Actual retained data are charged beyond payload lengths, including scalars.
        unicode_raw = raw.replace(b'"one"', '"é中"'.encode())
        unicode_coordinates = data.inherited_digests(unicode_raw, "first")
        minimum = (sys.getsizeof(unicode_raw) + sys.getsizeof(unicode_coordinates) +
                   sum(sys.getsizeof(item) for item in unicode_coordinates))
        require(data.cache_state()["accounted_bytes"] >= minimum,
                "cache byte accounting omitted retained keys or members")
        bounded()

        # Warm the actual caller, then remove or change inputs. No cache contains
        # the live admission, current registry, file presence, or physical digest.
        data.clear_cache()
        registry = json.loads(registration.REGISTRY.read_text())
        path = registration.WORKFLOW
        physical = registration.ROOT / path
        live = registration.sha(physical.read_bytes())
        expected = registration.prior_digest(registry, path, live)
        registration.prior_digest(registry, path, live)
        require(data.cache_state()["hits"] > 0, "actual caller did not warm the cache")

        original_baseline = registration.baseline()
        missing_files = dict(original_baseline["files"])
        missing_files.pop("scripts/cranelift_feature_registry.json")
        missing_baseline = dict(original_baseline, files=missing_files)
        with patch.object(registration, "baseline", lambda: missing_baseline):
            rejects("warm cache missing baseline entry",
                    lambda: registration.base_bytes("scripts/cranelift_feature_registry.json"), KeyError)

        original_bytes = registration.base_bytes
        def missing_registry(name):
            if name == "scripts/cranelift_feature_registry.json":
                raise FileNotFoundError(errno.ENOENT, "missing predecessor seam", name)
            return original_bytes(name)
        with patch.object(registration, "base_bytes", missing_registry):
            rejects("warm cache missing registry seam",
                    lambda: registration.prior_digest(registry, path, live), FileNotFoundError,
                    "missing predecessor seam")

        original_read = Path.read_bytes
        def missing_physical(candidate):
            if candidate == physical:
                raise FileNotFoundError(errno.ENOENT, "missing current physical input", str(candidate))
            return original_read(candidate)
        with patch.object(Path, "read_bytes", missing_physical):
            rejects("warm cache missing physical input",
                    lambda: registration.prior_digest(registry, path, live), FileNotFoundError,
                    "missing current physical input")
        with patch.object(Path, "read_bytes", lambda candidate:
                original_read(candidate) + b"\n" if candidate == physical else original_read(candidate)):
            rejects("warm cache substituted physical input",
                    lambda: registration.prior_digest(registry, path, live), SystemExit,
                    "R4 changed file drifted")
        for field in ("current_digest", "previous_digest"):
            changed = copy.deepcopy(registry)
            next(pin for pin in changed["phase26_activation_audit"][registration.KEY]["changed_files"]
                 if pin["path"] == path)[field] = "0" * 64
            rejects("warm cache changed " + field,
                    lambda changed=changed: registration.prior_digest(changed, path, live),
                    SystemExit, "R4 changed file drifted")
        require(registration.prior_digest(registry, path, live) == expected,
                "cache controls changed restored admission")
        bounded()
        print("RENEWAL_PREDECESSOR_DATA_CACHE_CONTROLS_PASS; live inputs and admission remain fresh", flush=True)
    finally:
        data.clear_cache()
