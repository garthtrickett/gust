"""Fresh scan, independent metadata and refusal controls for record view reuse."""
import copy
import errno
import json
from pathlib import Path
from unittest.mock import patch


def controls(registration):
    import phase23_production_release_audit as audit
    import phase24_semantic_spelling_inventory as spelling
    import phase24_filename_behavior_characterization as filenames
    import phase26_r3_zlib_adapter_registration as r3
    import phase26_r4_collection_registration as r4

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

    # Execute one real current view. Both the view and its nested record must
    # consume these actual suppliers only once, rather than return a cached view.
    calls = dict(text=0, production=0, spelling=0)
    def observed(name, supplier):
        def scan():
            calls[name] += 1
            return supplier()
        return scan
    with patch.object(r3, "raw_text_surfaces", observed("text", r3.raw_text_surfaces)), \
         patch.object(audit, "scan", observed("production", audit.scan)), \
         patch.object(spelling, "source_sites", observed("spelling", spelling.source_sites)):
        view = r4.live_projections()
    require(calls == dict(text=1, production=1, spelling=1),
            "R4 view duplicated or omitted a real scan")
    nested = view["r3_record"]["current"]
    production = view["production"]["current"]
    summary = view["spelling"]["current"]
    require(nested["production_audit_successor"]["current_audit"] == production and
            nested["production_audit_successor"]["current_audit"] is not production and
            nested["spelling_inventory_successor"]["current_inventory_summary"] == summary and
            nested["spelling_inventory_successor"]["current_inventory_summary"] is not summary,
            "R3 record gained aliases to sibling projection data")

    text = r3.raw_text_surfaces()
    supplied = copy.deepcopy((text, production, summary))
    result = r3.build_record_from_inputs(*supplied)
    require(result == nested, "required-input R3 record differs from the actual view")
    independent = copy.deepcopy(result)
    supplied[1]["repository_invocation_count"] += 1
    supplied[2]["classification_counts"][next(iter(supplied[2]["classification_counts"]))] += 1
    records = (result["phase23_text_surface_successor"]["changed_rows"] +
               result["phase23_text_surface_successor"]["added_rows"])
    require(records, "R3 text alias control lost its actual row mechanism")
    selected = records[0]["current_row"]["path"]
    supplied_row = next(row for row in supplied[0] if row["path"] == selected)
    supplied_row["digest"] = "0" * 64
    supplied_row["match_counts"][next(iter(supplied_row["match_counts"]))] += 1
    require(result == independent, "provided mutable input changed an existing record")
    production["repository_invocation_count"] += 1
    summary["source_file_count"] += 1
    require(nested == independent, "mutating sibling views changed their nested record")
    production["repository_invocation_count"] -= 1
    summary["source_file_count"] -= 1
    record_rows = {item["current_row"]["path"]: item["current_row"] for item in records}
    shared_rows = [row for row in view["text"]["current"] if row["path"] in record_rows]
    require(shared_rows, "sibling text alias control lost its actual shared-path mechanism")
    outer_row = shared_rows[0]
    original_row = copy.deepcopy(outer_row)
    outer_row["digest"] = "0" * 64
    outer_row["match_counts"][next(iter(outer_row["match_counts"]))] += 1
    require(nested == independent, "mutating sibling text changed its nested record")
    outer_row.clear()
    outer_row.update(original_row)

    malformed = [(None, production, summary), (text, None, summary), (text, production, None)]
    missing_production = dict(production)
    missing_production.pop("repository_invocation_count")
    malformed.append((text, missing_production, summary))
    missing_summary = dict(summary)
    missing_summary.pop("source_file_count")
    malformed.append((text, production, missing_summary))
    missing_text = copy.deepcopy(text)
    require(missing_text, "R3 text shape control has no actual rows")
    missing_text[0].pop("digest")
    malformed.append((missing_text, production, summary))
    with patch.object(r3, "raw_text_surfaces", side_effect=AssertionError("implicit scan fallback")):
        for index, values in enumerate(malformed):
            rejects("missing/malformed required scan " + str(index),
                    lambda values=values: r3.build_record_from_inputs(*values), SystemExit,
                    "R3 record scan input shape drifted")
        rejects("omitted required scan argument", lambda: r3.build_record_from_inputs(text, production),
                TypeError)

    # Real default entrypoint, supplied current scan values: observe each supplier
    # twice across independent calls. There is no retained live-view context.
    with patch.object(r3, "raw_text_surfaces", return_value=text) as text_scan, \
         patch.object(audit, "scan", return_value=production) as production_scan, \
         patch.object(spelling, "source_sites", return_value=[]) as spelling_scan, \
         patch.object(spelling, "manifest_summary", return_value=summary) as summarize:
        require(r3.build_record() == independent and r3.build_record() == independent,
                "fresh default builder changed its complete record")
        require([supplier.call_count for supplier in
                 (text_scan, production_scan, spelling_scan, summarize)] == [2, 2, 2, 2],
                "default builder reused a live scan across calls")
    with patch.object(r3, "raw_text_surfaces", side_effect=FileNotFoundError(
            errno.ENOENT, "missing independent scan input")):
        rejects("subsequent default call missing scan input", r3.build_record, FileNotFoundError,
                "missing independent scan input")

    # A provided view never freezes file presence or physical digests in a record.
    physical = r3.ROOT / r3.NEW_PATHS[0]
    original_read = Path.read_bytes
    original_bytes = original_read(physical)
    def missing_file(candidate):
        if candidate == physical:
            raise FileNotFoundError(errno.ENOENT, "missing physical R3 input", str(candidate))
        return original_read(candidate)
    with patch.object(Path, "read_bytes", missing_file):
        rejects("provided view missing physical input",
                lambda: r3.build_record_from_inputs(text, production, summary), FileNotFoundError,
                "missing physical R3 input")
    with patch.object(Path, "read_bytes", lambda candidate:
            original_read(candidate) + b"\n" if candidate == physical else original_read(candidate)):
        changed = r3.build_record_from_inputs(text, production, summary)
    pin = next(row for row in changed["new_file_hashes"] if row["path"] == r3.NEW_PATHS[0])
    require(pin["digest"] == registration.sha(original_bytes + b"\n") and changed != independent,
            "provided view hid a changed physical digest")
    registry = json.loads(registration.REGISTRY.read_text())
    rejects("changed physical R3 record still refused",
            lambda: registration.project(registry, "r3_record", changed), SystemExit,
            "R4 r3_record live projection drifted")

    actual_filenames = filenames.source_sites()
    require(actual_filenames == view["filename"]["current"] and actual_filenames,
            "filename-only probe differs from the actual view")
    changed_filenames = copy.deepcopy(actual_filenames)
    changed_filenames[0]["line"] += 1
    rejects("actual filename scanner still exercises its owning refusal",
            lambda: r4.project(registry, "filename", changed_filenames), SystemExit,
            "R4 filename live projection drifted")
    print("RENEWAL_FRESH_VIEW_CONTROLS_PASS; fresh scans, independent records and physical pins", flush=True)
