#!/usr/bin/env python3
"""Validate and project Patch 22.1 default-route opening evidence."""

from __future__ import annotations

import argparse
import ast
import copy
import importlib.util
import json
import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE22_OPENING.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase22-opening.yml"
GUARD_L1 = "guard-cranelift-phase22-opening-contract"
GUARD_L2 = "guard-cranelift-phase22-opening-evidence"

COMPILER_TOKEN = re.compile(
    r"(?P<token>\./gust(?:_bootstrap)?|"
    r"\./build/phase10-package/bin/gust|"
    r"\./build/(?:diagnostics/phase10-stage1/)?"
    r"gust_stage[0-9]+(?:_bin|_sanitized))(?=\s)"
)
RECIPE = re.compile(r"^([A-Za-z0-9_.-]+)(?:\s+[^:]*)?:\s*$")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def logical_commands(path: Path) -> list[tuple[int, str, str]]:
    """Return shell-like logical lines with their enclosing just recipe."""
    commands: list[tuple[int, str, str]] = []
    pending = ""
    pending_line = 0
    recipe = ""
    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if path.name.startswith("justfile") and raw and not raw[0].isspace():
            match = RECIPE.match(raw)
            if match:
                recipe = match.group(1)
        stripped = raw.strip()
        if pending:
            pending += " " + stripped
        else:
            pending = stripped
            pending_line = line_no
        if pending.endswith("\\"):
            pending = pending[:-1].rstrip()
            continue
        commands.append((pending_line, pending, recipe))
        pending = ""
    if pending:
        commands.append((pending_line, pending, recipe))
    return commands


def is_non_invocation(command: str, token_start: int) -> bool:
    prefix = command[:token_start]
    if command.startswith("#"):
        return True
    ignored_prefixes = (
        "echo ", "printf ", "rg ", "grep ", "chmod ", "touch ",
        "test -", "[ ", "if [ ", "elif [ ", "case ", "for required in ",
    )
    if command.startswith(ignored_prefixes):
        return True
    if any(marker in prefix for marker in ("echo ", "printf ", "rg ", "grep ")):
        return True
    return False


def selection(command: str) -> str:
    if (re.search(r"--backend(?:=|\s+)cranelift(?:\s|$)", command) or
            re.search(r"['\"]--backend['\"]\s*,\s*['\"]cranelift['\"]", command)):
        return "explicit_cranelift"
    if (re.search(r"--backend(?:=|\s+)(?:mir-to-c|c)(?:\s|$)", command) or
            re.search(r"['\"]--backend['\"]\s*,\s*['\"](?:mir-to-c|c)['\"]", command)):
        return "explicit_c"
    # Patch 24.13 (#420): the bootstrap-only entry is its own selection.
    #
    # It is an explicit, roadmap-decided spelling that reaches the emitter,
    # deliberately unadvertised in help. Without this branch it falls into
    # explicit_invalid_or_parser_probe, and the census cannot tell a bootstrap
    # call from a typo -- which is the distinction Patch 24.11 created this
    # entry to make. It is deliberately NOT explicit_c: calling it that would
    # assert the bootstrap entry is the retired spelling, the conflation 24.11
    # rejected when it declined to keep that spelling for bootstrap.
    if (re.search(r"--backend(?:=|\s+)bootstrap-emitter(?:\s|$)", command) or
            re.search(r"['\"]--backend['\"]\s*,\s*['\"]bootstrap-emitter['\"]",
                      command)):
        return "explicit_bootstrap_emitter"
    if "--backend" in command:
        return "explicit_invalid_or_parser_probe"
    return "implicit_default"


def classify(path: Path, line_no: int, command: str, recipe: str,
             token: str, selected: str) -> dict[str, object]:
    relative = path.relative_to(ROOT).as_posix()
    if selected != "implicit_default":
        consumer_class = "already_explicit_or_parser_probe"
        owner = (
            "stdlib" if relative.startswith("scripts/stdlib_") or
            relative.startswith("tests/") or
            recipe.startswith("guard-stdlib-") else "cranelift"
        )
        expected_artifact = "selected_backend_contract"
        transition = "preserve_explicit_selection"
        falsifier = "explicit_selection_is_removed_or_routes_to_a_different_backend"
    elif relative == "Makefile":
        consumer_class = "bootstrap_and_final_compiler_C_generation"
        owner = "cranelift"
        expected_artifact = "generated_C_or_bootstrap_diagnostic"
        transition = "22.2_explicit_mir_to_c_before_default_flip"
        falsifier = "default_flip_reaches_a_bootstrap_stage_before_explicit_C_migration"
    elif relative == "scripts/run-gust-file.sh":
        consumer_class = "developer_generated_C_pipeline"
        owner = "cranelift"
        expected_artifact = "generated_C"
        transition = "22.2_explicit_C_selection"
        falsifier = "default_flip_sends_generated_C_pipeline_to_native_output"
    elif relative in (
            "scripts/phase13_registry_differential.sh",
            "scripts/phase22_opening.sh",
            "scripts/phase22_native_implicit_output.sh",
    ):
        consumer_class = "intentional_default_selection_probe"
        owner = "cranelift"
        expected_artifact = "current_default_route_observation"
        transition = "22.6_flip_expectation_only"
        falsifier = "probe_is_migrated_before_the_default_route_changes"
    elif relative == "scripts/phase22_explicit_c_migration.sh":
        consumer_class = "intentional_default_selection_probe"
        owner = "cranelift"
        expected_artifact = "current_default_route_observation"
        transition = "22.6_flip_expectation_only"
        falsifier = "probe_is_migrated_before_the_default_route_changes"
    elif "--help" in command or re.search(r"(?:^|\s)-h(?:\s|$)", command):
        consumer_class = "help_surface_probe"
        owner = "cranelift"
        expected_artifact = "help_text"
        transition = "22.6_flip_help_expectation"
        falsifier = "help_expectation_changes_before_the_default_route"
    elif relative.startswith("scripts/stdlib_") or recipe.startswith("guard-stdlib-"):
        consumer_class = "stdlib_owned_C_or_diagnostic_guard"
        owner = "stdlib"
        expected_artifact = "generated_C_or_diagnostic"
        transition = "checked_cross_lane_relay_before_22.6"
        falsifier = "default_flip_lands_before_the_owning_lane_classifies_the_consumer"
    elif relative.startswith("tests/"):
        consumer_class = "stdlib_owned_C_or_diagnostic_guard"
        owner = "stdlib"
        expected_artifact = "generated_C_or_diagnostic"
        transition = "checked_cross_lane_relay_after_postmerge_review"
        falsifier = "default_native_route_reaches_a_test_owned_generated_C_consumer"
    elif relative.startswith("justfile") and "expect_invocation_failure" in command:
        consumer_class = "invocation_parser_probe"
        owner = "cranelift"
        expected_artifact = "pre_backend_invocation_diagnostic"
        transition = "preserve_shared_parser_diagnostic"
        falsifier = "backend_migration_changes_a_pre_backend_parser_diagnostic"
    elif relative.startswith("justfile") and recipe.startswith(
            "guard-cranelift-phase10-backend-selection"):
        consumer_class = "intentional_default_selection_probe"
        owner = "cranelift"
        expected_artifact = "current_default_route_observation"
        transition = "22.6_flip_expectation_only"
        falsifier = "probe_is_migrated_before_the_default_route_changes"
    elif relative.startswith("justfile"):
        consumer_class = "repository_C_or_diagnostic_guard"
        owner = "cranelift"
        expected_artifact = "generated_C_or_diagnostic"
        transition = "22.2_explicit_C_selection"
        falsifier = "default_flip_changes_the_guard_artifact_before_explicit_C_migration"
    elif relative.startswith("scripts/"):
        consumer_class = "cranelift_C_or_diagnostic_guard"
        owner = "cranelift"
        expected_artifact = "generated_C_or_diagnostic"
        transition = "22.2_explicit_C_selection"
        falsifier = "default_flip_changes_the_guard_artifact_before_explicit_C_migration"
    else:
        consumer_class = "unclassified"
        owner = ""
        expected_artifact = ""
        transition = ""
        falsifier = "unclassified_invocation_exists"
    return {
        "path": relative,
        "line": line_no,
        "recipe": recipe or "none",
        "compiler_token": token,
        "selection": selected,
        "consumer_class": consumer_class,
        "owner": owner,
        "expected_artifact": expected_artifact,
        "expected_transition": transition,
        "falsifier": falsifier,
        "command": command,
    }


def python_compiler_lists(path: Path) -> list[tuple[int, str, str]]:
    """Return directly represented Python argv lists that select a Gust compiler."""
    source = path.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(path))
    rows: list[tuple[int, str, str]] = []
    compiler_expr = re.compile(
        r"(?:['\"]\./gust['\"]|ROOT\s*/\s*['\"]gust['\"]|"
        r"\bPACKAGED_GUST\b|\bGUST\b)"
    )
    for node in ast.walk(tree):
        if not isinstance(node, ast.List):
            continue
        command = ast.unparse(node)
        top_level_compiler = any(
            isinstance(element, (ast.Name, ast.Constant, ast.Call, ast.BinOp))
            and compiler_expr.search(ast.unparse(element))
            for element in node.elts
        )
        if not top_level_compiler:
            continue
        rows.append((node.lineno, command, "python_argv"))
    return rows


def scan_invocations() -> list[dict[str, object]]:
    files = [ROOT / "Makefile"]
    files.extend(sorted(ROOT.glob("justfile*")))
    files.extend(sorted(ROOT.glob("*.sh")))
    files.extend(sorted((ROOT / "scripts").glob("*.sh")))
    files.extend(sorted((ROOT / "tests").glob("*.gst")))
    rows: list[dict[str, object]] = []
    for path in files:
        for line_no, command, recipe in logical_commands(path):
            for match in COMPILER_TOKEN.finditer(command):
                if is_non_invocation(command, match.start()):
                    continue
                selected = selection(command)
                rows.append(classify(
                    path, line_no, command, recipe, match.group("token"), selected
                ))
    for path in sorted((ROOT / "scripts").glob("*.py")):
        for line_no, command, token in python_compiler_lists(path):
            rows.append(classify(
                path, line_no, command, "", token, selection(command)
            ))
    rows.sort(key=lambda row: (str(row["path"]), int(row["line"]), str(row["command"])))
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    if "stdlib_guard_transition" not in registry.get("phase24_cr15_opening", {}):
        return rows
    path = ROOT / "scripts/phase24_cr15_stdlib_guard_transition.py"
    spec = importlib.util.spec_from_file_location("phase24_cr15_guard_transition", path)
    require(spec is not None and spec.loader is not None,
            "cannot load the Patch 24.0c guard transition")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.normalize_phase22_invocations(registry, rows)


def scan_summary(rows: list[dict[str, object]]) -> dict[str, object]:
    selections = Counter(str(row["selection"]) for row in rows)
    classes = Counter(str(row["consumer_class"]) for row in rows)
    owners = Counter(str(row["owner"]) for row in rows)
    return {
        "total": len(rows),
        "selection_counts": dict(sorted(selections.items())),
        "consumer_class_counts": dict(sorted(classes.items())),
        "owner_counts": dict(sorted(owners.items())),
        "unclassified_count": classes.get("unclassified", 0),
    }


def phase22_relay_inventory_rows(
        registry: dict, rows: list[dict[str, object]]) -> list[dict[str, object]]:
    """Keep Phase 22's closed relay identity while validating exact successors."""
    ffi = registry.get("phase26_activation_audit", {}).get(
        "ffi_position_policy_increment", {}).get("phase22_invocation_successor")
    if ffi is not None:
        added = ffi.get("added_rows")
        path = "scripts/phase26_ffi_position_policy.sh"
        require(ffi.get("contract_version") ==
                "phase26_1d1_phase22_invocation_successor_v1" and
                ffi.get("previous_total") == 151 and
                ffi.get("current_total") == 155 and
                ffi.get("partial_extra_or_substituted_invocation") ==
                "rejected" and isinstance(added, list) and
                len(added) == 4 and
                [row for row in rows if row.get("path") == path] == added,
                "Phase 26.1D1 external-call invocation rows are missing, "
                "extra, or substituted")
        rows = [row for row in rows if row.get("path") != path]

    # Phase 26's separate reference-argument prerequisite adds one explicit
    # native guard invocation. Validate it, then project it out of the closed
    # Phase 22 relay census; the live unfiltered census retains it.
    successor = registry.get("phase26_activation_audit", {}).get(
        "reference_receiver_prerequisite", {}).get(
            "phase22_invocation_successor")
    if successor is not None:
        added = successor.get("added_row")
        require(isinstance(added, dict) and
                successor.get("contract_version") ==
                "phase26_reference_receiver_phase22_invocation_successor_v1" and
                [row for row in rows if row.get("path") == added.get("path")]
                == [added],
                "Phase 26 native reference receiver relay successor is "
                "missing, extra, or substituted")
        rows = [row for row in rows if row != added]
    migration = registry.get("phase23_production_release_audit", {}).get(
        "phase22_closed_inventory_migration", {})
    require(migration.get("status") ==
            "exact_phase23_dual_route_projected_to_phase22_predecessor" and
            migration.get("owning_patch") == "23.12" and
            migration.get("path") == "scripts/run-gust-file.sh" and
            migration.get("falsifier") ==
            "missing_partial_extra_or_same_count_command_substitution_is_rejected",
            "Patch 23.12 Phase 22 projection authority drifted")
    historical = migration.get("current_historical_row")
    added_native = migration.get("added_native_row")
    previous = migration.get("previous_row")
    require(isinstance(historical, dict) and isinstance(added_native, dict) and
            isinstance(previous, dict),
            "Patch 23.12 Phase 22 projection rows are missing")
    live_current = [row for row in rows if row.get("path") == migration["path"]]
    # Patch 24.13: the runner was DUAL-route -- a historical explicit-C row and
    # an added native row. This patch retires the explicit-C route, so only the
    # native row survives and the dual-route record needs a successor rather
    # than an edit: Patch 23.12's record of what was true then stays true.
    #
    # The successor asserts exactly the shape of the change: the historical row
    # it drops must be the explicit-C one, and the row that remains must be the
    # native one 23.12 added. A successor that dropped the NATIVE row would
    # satisfy "one row survives" and is rejected here.
    runner_successor = registry.get("phase24_13_backend_removal", {}).get(
        "runner_route_successor")
    runner_contract = "phase24_13_runner_route_successor_v1"
    # Patch 24.13 wrote this retirement and withdrew it: the removal it
    # depended on was deferred, and the runner went back to carrying both
    # routes. Issue #398 lands the removal, so the successor is registered
    # under #398's key rather than reopening 24.13's closed record.
    #
    # Exactly one of the two may be present. Accepting both would let a tree
    # carry two records of the same single retirement, and only the first
    # would be checked against the surviving row's line -- the second could
    # name any line at all and never be read.
    issue398_successor = registry.get(
        "phase398_retained_spelling_removal", {}).get("runner_route_successor")
    require(runner_successor is None or issue398_successor is None,
            "the runner's explicit-C route is retired twice: Patch 24.13 and "
            "Issue #398 both register a runner route successor")
    if issue398_successor is not None:
        runner_successor = issue398_successor
        runner_contract = "phase398_runner_route_successor_v1"
    if runner_successor is None:
        require(live_current == [historical, added_native],
                "Patch 23.12 dual-route runner inventory is missing, partial, "
                "or substituted")
    else:
        require(runner_successor.get("contract_version") ==
                runner_contract and
                runner_successor.get("retired_row") == historical and
                runner_successor.get("partial_or_substituted_route") ==
                "rejected",
                "Patch 24.13 runner route successor drifted")
        require(len(live_current) == 1,
                f"{runner_contract} retires the runner's explicit-C route, so "
                f"the native row must be the only one left: {live_current}")
        survivor = live_current[0]
        # Deleting the explicit-C route moved the native row UP in the file, so
        # `line` is the one field 23.12's record cannot still match. Every other
        # field must be untouched -- in particular `selection` and `command`, so
        # a survivor that had been re-pointed at another backend is rejected --
        # and the shift must be upward by exactly the span the retirement freed.
        moved = {k for k in set(survivor) | set(added_native)
                 if survivor.get(k) != added_native.get(k)}
        require(moved == {"line"},
                f"{runner_contract} moved more than the native row's line: "
                f"{moved}")
        require(survivor["line"] == runner_successor.get("surviving_row_line")
                and survivor["line"] < added_native["line"],
                f"{runner_contract}: the native row is not at the line the "
                f"successor records after the retirement: {survivor['line']}")
    rows = [copy.deepcopy(row) for row in rows if row not in live_current]
    rows.append(copy.deepcopy(previous))
    rows.sort(key=lambda row: (
        str(row["path"]), int(row["line"]), str(row["command"])
    ))
    successors = [
        registry.get("phase23_issue_health_opening", {}).get(
            "phase22_closed_inventory_successor", {}),
        registry.get("phase23_structured_guard_defer_native_admission", {}).get(
            "phase22_closed_inventory_extension", {}),
        registry.get("phase23_same_scope_declaration", {}).get(
            "phase22_closed_inventory_extension", {}),
        registry.get("phase23_mir_to_c_archived_corpus", {}).get(
            "phase22_closed_inventory_extension", {}),
    ]
    expected_authorities = [
        ("23.1", "scripts/phase23_issue_health_opening.py", ["explicit_c"], 2),
        ("23.3a", "scripts/phase23_structured_guard_defer_native_admission.py",
         ["explicit_c", "explicit_cranelift", "explicit_cranelift", "explicit_cranelift"], 4),
        ("23.6", "scripts/phase23_same_scope_declaration.py",
         ["explicit_c", "implicit_default", "explicit_c", "implicit_default"], 4),
        ("23.11", "scripts/phase23_mir_to_c_archived_corpus.py",
         ["implicit_default"], 1),
    ]
    excluded: list[dict[str, object]] = []
    for successor, expected_authority in zip(successors, expected_authorities):
        patch, path, selections, count = expected_authority
        require(successor.get("status") ==
                "exact_phase23_extension_excluded_only_from_phase22_relay_identity" and
                successor.get("owning_patch") == patch and
                successor.get("path") == path and
                successor.get("selection") == (selections[0] if len(selections) == 1 else selections) and
                successor.get("invocation_count") == count,
                "Phase 23 successor invocation authority drifted")
        expected_selections = selections * count if len(selections) == 1 else selections
        expected = [
            (path, command, selection)
            for command, selection in zip(
                successor.get("commands", []), expected_selections
            )
        ]
        live_successors = [row for row in rows if row["path"] == path]
        live = [
            (str(row["path"]), str(row["command"]), str(row["selection"]))
            for row in live_successors
        ]
        # Patch 24.13 retires explicit C, so these Phase 23 executors no longer
        # match the rows they were pinned against. The pin is not edited: the
        # successor records, per PINNED index, what 24.13 did to that row --
        # "converted" (same site, now native), "retired" (the site is gone) or
        # "unchanged". The post-retirement expectation is DERIVED from those
        # dispositions, so a row that merely disappeared cannot be passed off as
        # a conversion and vice versa.
        retirement = successor.get("phase24_13_retirement")
        if retirement is not None:
            require(retirement.get("contract_version") ==
                    "phase24_13_phase23_executor_retirement_v1",
                    f"Patch 24.13 retirement successor for {path} drifted")
            dispositions = retirement.get("dispositions", [])
            require(len(dispositions) == count,
                    f"Patch 24.13 must disposition every pinned row of {path}: "
                    f"{len(dispositions)} of {count}")
            derived = []
            for index, disposition in enumerate(dispositions):
                kind = disposition.get("kind")
                was = expected_selections[index]
                if was == "explicit_c":
                    require(kind in ("converted", "retired"),
                            f"Patch 24.13 leaves explicit C at {path} row "
                            f"{index}: {kind}")
                else:
                    require(kind == "unchanged",
                            f"Patch 24.13 must not disturb the non-explicit-C "
                            f"row {index} of {path}: {kind}")
                if kind == "retired":
                    continue
                if kind == "converted":
                    derived.append((path, disposition.get("command"),
                                    "explicit_cranelift"))
                else:
                    derived.append((path, successor.get("commands", [])[index],
                                    was))
            require(live == derived,
                    "Patch 24.13 Phase 23 executor retirement does not match "
                    f"the tree at {path}: {live} != {derived}")
            require(all(row["selection"] != "explicit_c"
                        for row in live_successors),
                    f"Patch 24.13 left an explicit-C invocation in {path}")
        else:
            require(len(expected) == len(live_successors) == count
                    and live == expected,
                    "Phase 23 successor invocation path, command, or selection "
                    "drifted")
        excluded.extend(live_successors)
    return [row for row in rows if row not in excluded]


def effective_relay_inventory(registry: dict, landed_authority: dict) -> dict:
    """The pinned post-relay census, advanced by each registered successor.

    Same shape and same reason as the CR-15 census successor: Patch 24.12
    removes 107 explicit-C invocations, so the closed record's total stops
    describing the tree. The two censuses are filtered differently (this one
    drops the relay-inventory rows first), so they carry different totals, but
    the reduction is the same removal and has to be the same size — if they
    disagree, one of them is measuring something else.
    """
    pinned = landed_authority.get("exact_invocation_inventory")
    successor = registry.get("phase24_frozen_oracle_replacement", {}).get(
        "phase22_invocation_successor")
    if successor is None:
        return pinned
    previous = successor.get("previous_relay_inventory")
    current = successor.get("current_relay_inventory")
    require(previous == pinned and isinstance(current, dict),
            "Patch 24.12 post-relay inventory successor drifted")
    require(current["total"] < previous["total"] and
            current["unclassified_count"] == previous["unclassified_count"] ==
            0,
            "Patch 24.12 did not reduce a fully classified post-relay census")
    removed = previous["total"] - current["total"]
    require(removed == successor.get("removed_invocation_count") ==
            previous["selection_counts"]["explicit_c"] -
            current["selection_counts"]["explicit_c"],
            "the post-relay census reduction is not the registered "
            "explicit-C removal")
    # Patch 24.12a advances the same census again, for the same reason: the
    # seven retired harnesses take their invocations with them. Each link
    # asserts the same arithmetic, so a successor that reduces by a different
    # amount than its own frozen-surface transition registers fails here.
    emitter_only = registry.get(
        "phase24_12a_emitter_only_retirement", {}).get(
            "phase22_invocation_successor")
    if emitter_only is None:
        return current
    previous, current = current, emitter_only.get("current_relay_inventory")
    require(emitter_only.get("previous_relay_inventory") == previous and
            isinstance(current, dict),
            "Patch 24.12a post-relay inventory successor drifted")
    require(current["total"] < previous["total"] and
            current["unclassified_count"] == previous["unclassified_count"]
            == 0,
            "Patch 24.12a did not reduce a fully classified post-relay "
            "census")
    removed = previous["total"] - current["total"]
    require(removed == emitter_only.get("removed_invocation_count") ==
            previous["selection_counts"]["explicit_c"] -
            current["selection_counts"]["explicit_c"],
            "the Patch 24.12a post-relay census reduction is not the "
            "registered explicit-C removal")

    # Patch 24.12b continues the same chain, with the same arithmetic. It
    # retires the emitter-only arms inside two surviving guards and the scale
    # guard's timing cohort, so the census shrinks again by exactly the
    # explicit-C invocations those arms held.
    conversion = registry.get(
        "phase24_12b_python_parity_conversion", {}).get(
            "phase22_invocation_successor")
    if conversion is None:
        return _backend_removal_successor(registry, current)
    previous, current = current, conversion.get("current_relay_inventory")
    require(conversion.get("previous_relay_inventory") == previous and
            isinstance(current, dict),
            "Patch 24.12b post-relay inventory successor drifted")
    require(current["total"] < previous["total"] and
            current["unclassified_count"] == previous["unclassified_count"]
            == 0,
            "Patch 24.12b did not reduce a fully classified post-relay "
            "census")
    removed = previous["total"] - current["total"]
    require(removed == conversion.get("removed_invocation_count") ==
            previous["selection_counts"]["explicit_c"] -
            current["selection_counts"]["explicit_c"],
            "the Patch 24.12b post-relay census reduction is not the "
            "registered explicit-C removal")
    return _backend_removal_successor(registry, current)


def _backend_removal_successor(registry: dict, previous: dict) -> dict:
    """Patch 24.13: a COMBINED reclassification-and-retirement successor.

    Earlier successors only ever REMOVED invocations, so the chain asserts
    ``current["total"] < previous["total"]`` and that the drop equals the
    explicit-C delta. This contract was first written for the opposite case --
    24.13 moving bootstrap callers to the bootstrap-only entry, total
    unchanged -- and required ``current["total"] == previous["total"]``.

    Dispositioning the rest of Phase 23's executors broke that: 24.13 now does
    BOTH. Some explicit-C sites moved to a live backend; others were retired
    outright, taking with them the bare ``./gust`` arm that existed only to
    compare against them. So neither `<` nor `==` on the total is true, and
    the honest contract is the one that splits the explicit-C drop into its
    two fates and makes them add up.

    Measured against the registered predecessor census, not assumed:
    explicit_c 51 -> 32 (drop 19), explicit_bootstrap_emitter 0 -> 9 and
    explicit_cranelift 115 -> 120 (rise 14), implicit_default 15 -> 11 (drop
    4), explicit_invalid_or_parser_probe 3 -> 3, total 184 -> 175 (drop 9).
    So 14 invocations moved, 5 explicit-C sites were retired, and 4 companion
    default arms went with them: 14 + 5 = 19, and 5 + 4 = 9.

    The point of the split is that a site which VANISHED cannot pass as one
    that moved, and vice versa -- the property `<` bought for the reduction
    successors. A registered move that overstates itself by one leaves the
    retirement count one short and fails; a retirement that quietly dropped a
    row nobody registered fails the total. Selections outside the four this
    patch touches must not move at all.
    """
    removal = registry.get(
        "phase24_13_backend_removal", {}).get("phase22_invocation_successor")
    if removal is None:
        return previous
    current = removal.get("current_relay_inventory")
    require(removal.get("contract_version") ==
            "phase24_13_invocation_retirement_successor_v2" and
            removal.get("previous_relay_inventory") == previous and
            isinstance(current, dict) and
            removal.get("partial_or_unregistered_reclassification") ==
            "rejected",
            "Patch 24.13 invocation retirement successor drifted")
    require(current["unclassified_count"] == previous["unclassified_count"]
            == 0,
            "Patch 24.13 must leave the post-relay census fully classified")

    reclassified = removal.get("reclassified_invocation_count")
    retired_c = removal.get("retired_explicit_c_count")
    retired_companion = removal.get("retired_companion_default_count")
    require(all(isinstance(value, int) for value in
                (reclassified, retired_c, retired_companion)) and
            reclassified > 0 and retired_c > 0,
            "Patch 24.13 registered a transition that neither moves nor "
            "retires an explicit-C invocation")

    destinations = ("explicit_bootstrap_emitter", "explicit_cranelift")
    drop = (previous["selection_counts"].get("explicit_c", 0) -
            current["selection_counts"].get("explicit_c", 0))
    rise = sum(current["selection_counts"].get(name, 0) -
               previous["selection_counts"].get(name, 0)
               for name in destinations)
    require(rise == reclassified,
            f"the Patch 24.13 registered move is {reclassified} but the rise "
            f"across {destinations} is {rise}")
    require(drop == reclassified + retired_c,
            f"the Patch 24.13 explicit-C drop is {drop}, which is not the "
            f"{reclassified} that moved plus the {retired_c} retired")
    default_drop = (previous["selection_counts"].get("implicit_default", 0) -
                    current["selection_counts"].get("implicit_default", 0))
    require(default_drop == retired_companion,
            f"the Patch 24.13 implicit-default drop is {default_drop} but "
            f"{retired_companion} companion arms are registered as retired")
    require(previous["total"] - current["total"] ==
            retired_c + retired_companion,
            "the Patch 24.13 census total must fall by exactly the retired "
            f"sites: {previous['total']} -> {current['total']} against "
            f"{retired_c} + {retired_companion}")
    touched = {"explicit_c", "implicit_default", *destinations}
    for name in set(previous["selection_counts"]) | set(
            current["selection_counts"]):
        if name in touched:
            continue
        require(previous["selection_counts"].get(name, 0) ==
                current["selection_counts"].get(name, 0),
                f"Patch 24.13 moved a selection it does not claim: {name}")
    return _patch2510_departure(
        registry,
        _patch2510a_departure(
            registry,
            _patch255_successor(
                registry, _issue398_successor(registry, current, "relay"),
                "relay"),
            "relay"),
        "relay")


def _patch2510_departure(registry: dict, previous: dict, census: str) -> dict:
    """Retire the five Makefile invocations the emitter deletion removes.

    Newest first: this runs before _patch2510a_departure, which runs
    before _patch255_successor. Both censuses read the SAME registry node,
    for the reason 25.10a's link already gives -- two readers with two
    records is how they drift into two different answers.

    The five are the C stage chain: the stage-one emission from the
    bridge entry, the stage-one diagnose build, the final compiler
    emission, and the stage-two and stage-three emissions in the C fixed
    point. All five are explicit_bootstrap_emitter and all five are gone
    with the rules that ran them.
    """
    departure = registry.get("phase2510_emitter_deletion", {}).get(
        "invocation_departure")
    if departure is None:
        return previous
    key = {"relay": "relay_inventory", "unfiltered": "summary"}[census]
    current = departure.get(f"current_{key}")
    require(departure.get("contract_version") ==
            "phase2510_emitter_deletion_invocation_departure_v1" and
            departure.get("owner") == "cranelift" and
            departure.get(f"previous_{key}") == previous and
            isinstance(current, dict) and
            departure.get("escaping_the_census_by_relocation") == "rejected",
            f"Patch 25.10 {census} invocation departure drifted")
    require(current["unclassified_count"] == previous["unclassified_count"]
            == 0,
            f"Patch 25.10 must leave the {census} census fully classified")
    gone = departure.get("departed_invocation_count")
    require(isinstance(gone, int) and gone > 0 and
            previous["total"] - current["total"] == gone,
            f"the Patch 25.10 {census} census total must fall by exactly "
            f"the departed invocations: {previous['total']} -> "
            f"{current['total']} against {gone}")
    # Departures AND one reclassification -- see the note in
    # phase24_cr15_stdlib_guard_transition.py. The runner's negative path
    # changes spelling rather than leaving, so explicit_cranelift rises by
    # one while the departures fall.
    reclassified = departure.get("reclassified_invocation_rows", [])
    lost = {"explicit_bootstrap_emitter": gone}
    gained = {}
    for row in reclassified:
        lost[str(row["from_selection"])] = lost.get(
            str(row["from_selection"]), 0) + 1
        gained[str(row["to_selection"])] = gained.get(
            str(row["to_selection"]), 0) + 1
    for name in set(previous["selection_counts"]) | set(
            current["selection_counts"]):
        delta = (previous["selection_counts"].get(name, 0) -
                 current["selection_counts"].get(name, 0))
        expected = lost.get(name, 0) - gained.get(name, 0)
        require(delta == expected,
                f"Patch 25.10 moved a selection it does not claim in the "
                f"{census} census: {name} by {delta}, expected {expected}")
    return current


def _patch2510a_departure(registry: dict, previous: dict, census: str) -> dict:
    """Retire the two invocations Patch 25.5 added.

    THERE ARE TWO CENSUSES, filtered differently, and this is the second
    one. The unfiltered chain's copy of this link lives in
    scripts/phase24_cr15_stdlib_guard_transition.py. They read the SAME
    registry node, which is the only thing keeping them from drifting
    into two different answers about what departed.

    Patch 25.10a deletes both scripts that carried 25.5's added rows, so
    this is 25.5 run backwards: the relay census returns to exactly the
    inventory 25.5 recorded as its predecessor, 152 -> 150, and the only
    selection that moves is explicit_bootstrap_emitter, 15 -> 13.

    Asserted as an identity rather than as "it went back down", for the
    same reason 25.5 asserted its addition as one: a census that is only
    checked for direction is not a census.
    """
    departure = registry.get("phase2510a_strings_retirement", {}).get(
        "invocation_departure")
    if departure is None:
        return previous
    key = {"relay": "relay_inventory", "unfiltered": "summary"}[census]
    current = departure.get(f"current_{key}")
    require(departure.get("contract_version") ==
            "phase2510a_strings_invocation_departure_v1" and
            departure.get(f"previous_{key}") == previous and
            isinstance(current, dict) and
            departure.get("escaping_the_census_by_relocation") == "rejected",
            f"Patch 25.10a {census} invocation departure drifted")
    require(current["unclassified_count"] == previous["unclassified_count"]
            == 0,
            f"Patch 25.10a must leave the {census} census fully classified")
    gone = departure.get("departed_invocation_count")
    require(isinstance(gone, int) and gone > 0 and
            previous["total"] - current["total"] == gone,
            f"the Patch 25.10a {census} census total must fall by exactly "
            f"the departed invocations: {previous['total']} -> "
            f"{current['total']} against {gone}")
    for name in set(previous["selection_counts"]) | set(
            current["selection_counts"]):
        delta = (previous["selection_counts"].get(name, 0) -
                 current["selection_counts"].get(name, 0))
        expected = gone if name == "explicit_bootstrap_emitter" else 0
        require(delta == expected,
                f"Patch 25.10a moved a selection it does not claim in the "
                f"{census} census: {name} by {delta}, expected {expected}")
    return current


def _patch255_successor(registry: dict, previous: dict, census: str) -> dict:
    """Advance the census by Patch 25.5's ADDED invocations.

    Every link before this one reduces: the chain was built by patches
    retiring a spelling. Porting the runtime goes the other way. The
    strings differential has to emit the Gust side to compare it against
    the frozen C reference, and the generator that produces strings.c
    from strings.gst invokes the emitter too -- two real backend
    invocations the census is entitled to know about.

    Stated as an identity on the delta rather than as growth, for the
    same reason the seed transitions are: a census that can only be
    asserted to shrink cannot describe a phase that adds anything, and
    "it went up, so skip the check" is how a census stops being one.
    """
    successor = registry.get("phase25_runtime_port_invocations", {}).get(
        "phase22_relay_invocation_successor")
    if successor is None:
        return previous
    key = {"relay": "relay_inventory", "unfiltered": "summary"}[census]
    current = successor.get(f"current_{key}")
    require(successor.get("contract_version") ==
            "patch255_runtime_port_invocation_addition_v1" and
            successor.get(f"previous_{key}") == previous and
            isinstance(current, dict) and
            successor.get("escaping_the_census_by_relocation") == "rejected",
            f"Patch 25.5 {census} invocation successor drifted")
    require(current["unclassified_count"] == previous["unclassified_count"]
            == 0,
            f"Patch 25.5 must leave the {census} census fully classified")
    added = successor.get("added_invocation_count")
    require(isinstance(added, int) and added > 0 and
            current["total"] - previous["total"] == added,
            f"the Patch 25.5 {census} census total must rise by exactly the "
            f"added invocations: {previous['total']} -> {current['total']} "
            f"against {added}")
    # Only the selection the addition claims may move, and only by as many
    # as claim it. An addition that quietly re-points an existing
    # invocation would otherwise balance on the total alone.
    for name in set(previous["selection_counts"]) | set(
            current["selection_counts"]):
        delta = (current["selection_counts"].get(name, 0) -
                 previous["selection_counts"].get(name, 0))
        expected = added if name == "explicit_bootstrap_emitter" else 0
        require(delta == expected,
                f"Patch 25.5 moved a selection it does not claim in the "
                f"{census} census: {name} by {delta}, expected {expected}")
    return current


def _issue398_successor(registry: dict, previous: dict, census: str) -> dict:
    """Issue #398: a pure retirement, with two deliberate survivors.

    Patch 24.13 needed a combined contract because some explicit-C sites moved
    to another backend. Nothing moves here. Every consumer of the retired
    spelling is converted onto frozen replay, so the invocation is not
    re-pointed -- it stops existing -- and the explicit-C drop and the census
    total fall by the same number. `reclassified_invocation_count` is
    registered as 0 and asserted against the destinations, so a patch that
    quietly re-pointed a site at cranelift and called it a retirement fails.

    Two explicit-C invocations survive on purpose: the poison probe in
    scripts/phase12_5_route_architecture.sh and the `c` alias probe in
    scripts/phase22_opening.sh, both inverted to assert the spelling is now
    REFUSED. A census cannot tell an inverted probe from a live consumer --
    both read as explicit_c -- so each is registered by path and command
    together with the rejection it asserts, and both are checked against the
    file. Deleting a probe to make the count come out fails the length check;
    letting one go back to expecting success fails its marker.

    The two censuses are filtered differently and carry different totals, so
    each has its own retired count, and the difference between them is
    registered as the number of retired rows the relay census excludes. They
    have to agree: if they do not, one of them is measuring something else.
    """
    successor = registry.get("phase398_retained_spelling_removal", {}).get(
        "phase22_invocation_successor")
    if successor is None:
        return previous
    key = {"relay": "relay_inventory", "unfiltered": "summary"}[census]
    current = successor.get(f"current_{key}")
    require(successor.get("contract_version") ==
            "phase398_invocation_retirement_successor_v1" and
            successor.get(f"previous_{key}") == previous and
            isinstance(current, dict) and
            successor.get("partial_or_unregistered_retirement") == "rejected",
            f"Issue #398 {census} invocation successor drifted")
    require(current["unclassified_count"] == previous["unclassified_count"]
            == 0,
            f"Issue #398 must leave the {census} census fully classified")

    retired = successor.get(
        "relay_retired_explicit_c_count" if census == "relay"
        else "unfiltered_retired_explicit_c_count")
    excluded = successor.get("relay_excluded_retired_count")
    reclassified = successor.get("reclassified_invocation_count")
    require(all(isinstance(value, int) for value in
                (retired, excluded, reclassified)) and retired > 0,
            "Issue #398 registered a transition that retires no explicit-C "
            "invocation")
    require(successor.get("relay_retired_explicit_c_count", 0) + excluded ==
            successor.get("unfiltered_retired_explicit_c_count", 0),
            "the two Issue #398 censuses disagree about the size of the "
            "removal: "
            f"{successor.get('relay_retired_explicit_c_count')} + {excluded} "
            f"!= {successor.get('unfiltered_retired_explicit_c_count')}")

    drop = (previous["selection_counts"].get("explicit_c", 0) -
            current["selection_counts"].get("explicit_c", 0))
    destinations = ("explicit_bootstrap_emitter", "explicit_cranelift")
    rise = sum(current["selection_counts"].get(name, 0) -
               previous["selection_counts"].get(name, 0)
               for name in destinations)
    require(rise == reclassified == 0,
            f"Issue #398 retires the spelling rather than re-pointing it, but "
            f"the {census} census shows {rise} invocations arriving at "
            f"{destinations}")
    require(drop == retired,
            f"the Issue #398 {census} explicit-C drop is {drop}, not the "
            f"{retired} registered as retired")
    require(previous["total"] - current["total"] == retired,
            f"the Issue #398 {census} census total must fall by exactly the "
            f"retired invocations: {previous['total']} -> {current['total']} "
            f"against {retired}")
    for name in set(previous["selection_counts"]) | set(
            current["selection_counts"]):
        if name == "explicit_c":
            continue
        require(previous["selection_counts"].get(name, 0) ==
                current["selection_counts"].get(name, 0),
                f"Issue #398 moved a selection it does not claim in the "
                f"{census} census: {name}")

    inversions = successor.get("retained_inversions", [])
    excess = successor.get("relay_pinned_explicit_c_excess", 0) \
        if census == "relay" else 0
    require(isinstance(excess, int) and
            current["selection_counts"].get("explicit_c", 0) ==
            len(inversions) + excess,
            f"the explicit-C invocations Issue #398 leaves in the {census} "
            f"census are not the registered inverted probes: "
            f"{current['selection_counts'].get('explicit_c', 0)} against "
            f"{len(inversions)} + {excess}")
    for row in inversions:
        path = ROOT / str(row["path"])
        # Matched through logical_commands, not against the raw file: the
        # census joins line continuations before it classifies, so a probe
        # written across three backslashed lines is one command to the number
        # this check guards and three lines to a plain substring search. The
        # check has to see what the count saw.
        commands = [command for _, command, _ in logical_commands(path)]
        require(str(row["command"]) in commands,
                "Issue #398 registers an inverted probe that is not in the "
                f"tree: {row['path']}")
        require(str(row["rejection_marker"]) in
                path.read_text(encoding="utf-8"),
                f"the retained explicit-C invocation in {row['path']} no "
                "longer asserts that the spelling is refused")
    return current


def validate_post_flip_relay_transition(
        registry: dict, rows: list[dict[str, object]]) -> tuple[str, dict]:
    """Require the exact landed six-site post-relay state."""
    rows = phase22_relay_inventory_rows(registry, rows)
    migration = registry.get("phase22_explicit_c_migration", {})
    relay = migration.get("cross_lane_relay", {}).get(
        "post_flip_review_relay", {})
    landed_authority = relay.get("landed_authority", {})
    require(landed_authority.get("status") ==
            "exact_post_relay_only" and
            landed_authority.get("owning_pull_request") == 264 and
            landed_authority.get("changed_path_count") == 2 and
            landed_authority.get("route_only_replacement_count") == 6 and
            landed_authority.get("changed_paths") == relay.get("paths"),
            "landed six-site relay authority drifted")
    landed = relay.get("landed_merge_evidence", {})
    require(landed == {
        "status": "merged_on_main",
        "owning_pull_request": 264,
        "base_sha": "5638c3596be450b75f2af905b982875f7863bc37",
        "exact_head_sha": "3ada756e209bfa0556895169870ae00f96d94022",
        "merged_main_sha": "a7adbcd186512a3b4fd99b953bb2bc30f6838c52",
        "pull_request_event": "pull_request",
        "successful_workflows": 6,
        "total_workflows": 6,
        "unfinished_workflows": 0,
        "non_success_workflows": 0,
        "unresolved_review_threads": 0,
        "relayed_review_thread": "PRRT_kwDOS1ExJc6dYPJO",
        "relayed_review_thread_status": "resolved_non_outdated",
    }, "landed relay merge evidence drifted")

    site_fields = ("path", "line", "recipe", "compiler_token", "command")
    expected_sites = {
        tuple(site[field] for field in site_fields)
        for site in relay.get("site_manifest", [])
    }
    live_sites = {
        tuple(row[field] for field in site_fields): row
        for row in rows
        if tuple(row[field] for field in site_fields) in expected_sites
    }
    # Patch 24.13 migrates two of the six relay sites off mir-to-c. The pinned
    # manifest still records where they were and what they said, which stays
    # true of Patch 22; the successor says what each became. A migration is
    # only accepted if the pinned site is ABSENT and its named replacement is
    # PRESENT -- deleting a relay site outright fails here, as does leaving the
    # mir-to-c spelling in place.
    effective_migration: dict[tuple, str] = {}
    migration = relay.get("phase24_13_site_migration")
    if migration is not None:
        require(migration.get("contract_version") ==
                "phase24_13_six_site_relay_migration_v1",
                "Patch 24.13 six-site relay migration successor drifted")
        migrations = migration.get("migrations", [])
        require(len(migrations) == migration.get("migrated_count") and
                migration.get("migrated_count") +
                migration.get("retained_mir_to_c_count") ==
                relay.get("consumer_count") == 6,
                "Patch 24.13 relay migration does not account for all six "
                "sites")
        # Patch 24.3b: `line` is a coordinate. Any insertion above a row
        # moves it, so a destination matched WITH its line turns an unrelated
        # edit elsewhere in the file into migration drift. The command text
        # is what the migration is about, so destinations are looked for in
        # the tree without it -- which is also strictly stronger on the
        # absence half: the pinned command must be gone from the whole file,
        # not merely off the line it used to sit on.
        placed = tuple(field for field in site_fields if field != "line")

        def site_key(site: dict) -> tuple:
            return tuple(site[field] for field in placed)

        live_placed = {site_key(row) for row in rows}
        # Patch 25.10b migrates one of 24.13's DESTINATIONS again: the
        # runner's negative path leaves the bootstrap emitter for the native
        # route. A migration record pins a destination rather than a state,
        # so re-migrating a site trips it while merely editing one does not.
        # 24.13's record stays exactly as written -- it is a true statement
        # about what 24.13 did -- and this is the newer link. Where a
        # successor claims one of 24.13's destinations, that destination is
        # required ABSENT and the successor's own destination PRESENT, so a
        # site that was quietly dropped still fails both halves.
        # 24.13 migrated TWO runner sites. 25.10b re-migrated the first (the
        # negative path); 25.10c re-migrates the second (the positive path),
        # which is what frees the emitter to be deleted. Each patch keeps its
        # OWN record: folding 25.10c into 25.10b's node would make that node
        # stop being a true statement about what 25.10b did, and the two were
        # measured separately -- 104 of 104 negative, 3 of 120 tests/ positive.
        # So the successor set is the union, and a site may be claimed by
        # exactly one patch.
        SUCCESSORS = (
            ("phase2510b_runner_negative_path",
             "phase2510b_relay_remigration_v1", "25.10b"),
            ("phase2510c_runner_positive_path",
             "phase2510c_relay_remigration_v1", "25.10c"),
        )
        remigrated: dict[tuple, dict] = {}
        remigrated_owner: dict[tuple, str] = {}
        for node_name, contract, label in SUCCESSORS:
            remigration = registry.get(node_name, {}).get(
                "relay_remigration", {})
            if not remigration:
                continue
            require(remigration.get("contract_version") == contract,
                    f"Patch {label} relay re-migration successor drifted")
            for entry in remigration.get("migrations", []):
                key = site_key(entry["pinned_site"])
                require(key not in remigrated,
                        f"Patch {label} re-migrates a site another patch "
                        f"already claimed: {entry['pinned_site']['path']}")
                remigrated[key] = entry
                remigrated_owner[key] = label
        claimed: set = set()
        for entry in migrations:
            pinned = tuple(entry["pinned_site"][field] for field in site_fields)
            moved = tuple(entry["migrated_site"][field] for field in site_fields)
            require(pinned in expected_sites,
                    f"Patch 24.13 migrates a site the manifest never pinned: "
                    f"{pinned[0]}:{pinned[1]}")
            require(site_key(entry["pinned_site"]) not in live_placed,
                    f"Patch 24.13 records {pinned[0]}:{pinned[1]} as migrated "
                    "but the mir-to-c site is still in the tree")
            require("mir-to-c" not in str(entry["migrated_site"]["command"]),
                    f"Patch 24.13 replacement for {pinned[0]}:{pinned[1]} "
                    "still spells mir-to-c")
            successor = remigrated.get(site_key(entry["migrated_site"]))
            if successor is None:
                require(site_key(entry["migrated_site"]) in live_placed,
                        f"Patch 24.13 records a replacement for {pinned[0]}:"
                        f"{pinned[1]} that is not in the tree")
                effective = entry
            else:
                claimed.add(site_key(entry["migrated_site"]))
                owner = remigrated_owner[site_key(entry["migrated_site"])]
                require(site_key(entry["migrated_site"]) not in live_placed,
                        f"Patch {owner} re-migrates {pinned[0]}:{pinned[1]} "
                        "but 24.13's destination is still in the tree")
                require(site_key(successor["migrated_site"]) in live_placed,
                        f"Patch {owner} records a replacement for the 24.13 "
                        f"destination at {pinned[0]}:{pinned[1]} that is not "
                        "in the tree")
                require("bootstrap-emitter" not in
                        str(successor["migrated_site"]["command"]),
                        f"Patch {owner} replacement for {pinned[0]}:{pinned[1]} "
                        "still spells bootstrap-emitter")
                effective = successor
                moved = tuple(successor["migrated_site"][field]
                              for field in site_fields)
            expected_sites.discard(pinned)
            expected_sites.add(moved)
            effective_migration[site_key(effective["migrated_site"])] = \
                effective["migrated_selection"]
        require(claimed == set(remigrated),
                "a re-migration successor claims a site Patch 24.13 never "
                "migrated to")
        placed_expected = {tuple(site[i] for i, field in
                                 enumerate(site_fields) if field != "line")
                           for site in expected_sites}
        live_sites = {
            tuple(row[field] for field in site_fields): row
            for row in rows
            if tuple(row[field] for field in placed) in placed_expected
        }
    # Issue #398 retires the four relay sites 24.13 left spelled mir-to-c.
    # They are not migrated to another backend: they stop invoking a compiler
    # at all and replay a frozen record instead. The migration contract above
    # cannot express that, because it requires a replacement INVOCATION to be
    # present in the census, and a converted site makes none.
    #
    # So the retirement asserts against the FILE rather than the census: the
    # pinned command must be absent from its path AND the named replay marker
    # must be present in it. A site that was merely deleted satisfies the first
    # half and fails the second -- the "vanished passing as converted" failure
    # this phase keeps having to rule out.
    retirement = relay.get("phase398_site_retirement")
    retired_sites: set = set()
    if retirement is not None:
        require(retirement.get("contract_version") ==
                "phase398_six_site_relay_retirement_v1" and
                retirement.get("partial_or_unregistered_retirement") ==
                "rejected",
                "Issue #398 six-site relay retirement successor drifted")
        retirements = retirement.get("retirements", [])
        require(len(retirements) == retirement.get("retired_count") and
                retirement.get("retired_count") +
                retirement.get("surviving_site_count") ==
                relay.get("consumer_count") == 6,
                "Issue #398 relay retirement does not account for all six "
                "sites")
        live_keys = {tuple(row[field] for field in site_fields) for row in rows}
        for entry in retirements:
            pinned = tuple(entry["retired_site"][field]
                           for field in site_fields)
            require(pinned in expected_sites,
                    "Issue #398 retires a site the manifest never pinned: "
                    f"{pinned[0]}:{pinned[1]}")
            require(pinned not in live_keys,
                    f"Issue #398 records {pinned[0]}:{pinned[1]} as retired "
                    "but the invocation is still in the tree")
            text = (ROOT / str(pinned[0])).read_text(encoding="utf-8")
            require(str(entry["retired_site"]["command"]) not in text,
                    f"Issue #398 records {pinned[0]}:{pinned[1]} as retired "
                    "but the retired command is still written there")
            require(str(entry["replacement_marker"]) in text,
                    f"Issue #398 retires {pinned[0]}:{pinned[1]} without the "
                    "frozen replay that replaces it")
            expected_sites.discard(pinned)
            retired_sites.add(pinned)
        placed_expected = {tuple(site[i] for i, field in
                                 enumerate(site_fields) if field != "line")
                           for site in expected_sites}
        live_sites = {
            tuple(row[field] for field in site_fields): row
            for row in rows
            if tuple(row[field] for field in placed) in placed_expected
        }
    require(len(expected_sites) == len(live_sites) ==
            relay.get("consumer_count") - len(retired_sites) and
            relay.get("consumer_count") == 6 and
            sorted({str(site[0])
                    for site in expected_sites | retired_sites}) ==
            relay.get("paths"),
            "six-site relay path or site manifest drifted")

    summary = scan_summary(rows)
    # Every relay site was explicit C when Patch 22 closed. A site 24.13
    # migrated must now read as the selection its successor names -- checked
    # per site, so a migrated site that landed on some third backend fails
    # here, and an unmigrated site that drifted off explicit C fails too.
    expected_site_selection = {}
    for key in live_sites:
        expected_site_selection[key] = "explicit_c"
    for key in live_sites:
        placed_key = tuple(key[i] for i, field in enumerate(site_fields)
                           if field != "line")
        if placed_key in effective_migration:
            expected_site_selection[key] = effective_migration[placed_key]
    # Patch 25.10c split this compound assertion. It conjoined a per-site
    # selection map with a whole-inventory summary, so a failure said only
    # "not the exact landed six-site post-relay state" and named neither the
    # site that moved nor which half disagreed. Finding the row that moved is
    # the first thing anyone needs.
    live_selection = {key: str(row["selection"])
                      for key, row in live_sites.items()}
    if live_selection != expected_site_selection:
        differing = sorted(
            f"{k[0]}:{k[1]} live={live_selection.get(k, '<absent>')} "
            f"expected={expected_site_selection.get(k, '<absent>')}"
            for k in set(live_selection) ^ set(expected_site_selection)
            or {k for k in live_selection
                if live_selection[k] != expected_site_selection.get(k)})
        require(False,
                "live invocation selections disagree with the landed "
                "post-relay state: " + "; ".join(differing[:6]))
    require(summary == effective_relay_inventory(registry, landed_authority),
            "the relay inventory summary is not the landed six-site "
            f"post-relay state: live={summary} expected="
            f"{effective_relay_inventory(registry, landed_authority)}")
    return "landed_post_relay", landed_authority


def transition_projection_rows(
        rows: list[dict[str, object]], registry: dict) -> list[dict[str, object]]:
    """Return the landed generated projection for the exact relay."""
    relay = registry["phase22_explicit_c_migration"]["cross_lane_relay"][
        "post_flip_review_relay"
    ]
    site_fields = ("path", "line", "recipe", "compiler_token", "command")
    expected_sites = {
        tuple(site[field] for field in site_fields)
        for site in relay["site_manifest"]
    }
    projected: list[dict[str, object]] = []
    for row in rows:
        copy = dict(row)
        key = tuple(copy[field] for field in site_fields)
        if key in expected_sites:
            copy.update({
                "selection": "explicit_c",
                "consumer_class": "landed_six_site_stdlib_C_or_diagnostic_relay",
                "owner": "stdlib",
                "expected_artifact": "generated_C_or_diagnostic",
                "expected_transition": "exact_six_site_explicit_mir_to_c_relay",
                "falsifier": "partial_extra_path_drift_or_unrelated_inventory_change",
            })
        projected.append(copy)
    return projected


def validate_landed_relay_command_substitution_rejection(
        registry: dict, rows: list[dict[str, object]]) -> None:
    """Prove same-selection changes cannot bypass the landed command manifest."""
    # Issue #398 retires the four tests/e2e_codegen_assertions.gst relay sites
    # this harness used to mutate. The property does not retire with them: it
    # has to hold for whatever the manifest still expects, so the probe moves
    # onto the two sites that survive -- the tests/test_runner.gst rows Patch
    # 24.13 migrated onto the bootstrap-only entry. Leaving the harness pinned
    # to a retired row would have made it pass by finding nothing to mutate.
    retired = registry.get("phase22_explicit_c_migration", {}).get(
        "cross_lane_relay", {}).get("post_flip_review_relay", {}).get(
            "phase398_site_retirement")
    if retired is None:
        anchor_path = "tests/e2e_codegen_assertions.gst"
        anchor_token = "codegen_helper_pod_move.gst"
        substitutions = (
            ("codegen_helper_pod_move.gst", "codegen_helper_linear_move.gst"),
            ("--backend mir-to-c", "--backend c"),
            ("2>&1", "2>/dev/null"),
        )
    elif registry.get("phase2510b_runner_negative_path") is None:
        anchor_path = "tests/test_runner.gst"
        anchor_token = "mut cmd := std.Concat"
        substitutions = (
            # a different backend, the retired spelling coming back, and an
            # edit that changes nothing about the selection at all
            ("--backend bootstrap-emitter", "--backend cranelift"),
            ("--backend bootstrap-emitter", "--backend mir-to-c"),
            ("std.Concat(", "std.Concat( "),
        )
    elif registry.get("phase2510c_runner_positive_path") is None:
        # Patch 25.10b takes the negative path native, so `mut cmd :=` no
        # longer spells the emitter and every substitution above became a
        # no-op on it -- which this harness reports rather than passing
        # vacuously. The property is unchanged; it moves onto the compile
        # path, the one relay site still invoking the emitter.
        anchor_path = "tests/test_runner.gst"
        anchor_token = "mut cmd_comp := std.Concat"
        substitutions = (
            # a different backend, the retired spelling coming back, and an
            # edit that changes nothing about the selection at all
            ("--backend bootstrap-emitter", "--backend cranelift"),
            ("--backend bootstrap-emitter", "--backend mir-to-c"),
            ("std.Concat(", "std.Concat( "),
        )
    else:
        # Patch 25.10c takes the POSITIVE path native too. The branch above
        # called itself "the anchor until the positive corpus can go native",
        # and that is now -- though not the way it expected. It was waiting on
        # phase13_generic_source_to_mir; what actually happened is that the
        # corpus split in two. 117 of 120 tests/ positives still have no
        # native route, so the runner is no longer BUILT, and the site stops
        # invoking the emitter because the emitter is gone.
        #
        # So neither runner path spells the emitter and all three emitter
        # substitutions became no-ops. The property is unchanged -- mutate a
        # live relay row's selection and the guard must notice -- but there is
        # no emitter row left to mutate FROM. The probe mutates the native
        # spelling instead, and the second case is the important one: it puts
        # the RETIRED spelling back, which must still be caught.
        anchor_path = "tests/test_runner.gst"
        anchor_token = "mut cmd_comp := std.Concat"
        substitutions = (
            ("--backend cranelift", "--backend mir-to-c"),
            ("--backend cranelift", "--backend bootstrap-emitter"),
            ("std.Concat(", "std.Concat( "),
        )
    for old, new in substitutions:
        probe = copy.deepcopy(rows)
        # Patch 24.3b: find the probe row by what it IS, not where it sits.
        # The old lookup pinned `line == 33`, so any edit above that fixture
        # broke the harness instead of the guard. The token below is present
        # in exactly one row before mutation; duplicates fail loud, and a
        # substitution that no longer applies fails rather than passing
        # vacuously on a no-op replace.
        candidates = [
            row for row in probe
            if row["path"] == anchor_path and
            anchor_token in str(row["command"])
        ]
        require(len(candidates) == 1,
                "landed relay probe row is missing or duplicated")
        target = candidates[0]
        require(old in str(target["command"]),
                f"probe substitution no longer applies: {old}")
        target["command"] = str(target["command"]).replace(old, new)
        try:
            validate_post_flip_relay_transition(registry, probe)
        except SystemExit:
            continue
        require(False,
                f"landed relay command substitution was accepted: {old}")


def validate_relay_retirement_rejection(
        registry: dict, rows: list[dict[str, object]]) -> None:
    """Prove a retired relay site cannot pass by vanishing, or by coming back.

    The retirement makes two claims and each needs its own falsifier. That the
    invocation is gone is checked by putting it back: the pinned row is added
    to the census and the transition must reject it. That a frozen replay took
    its place is checked by pointing the registered marker at text the file
    does not contain -- which is what a site that was simply deleted would
    look like -- and the transition must reject that too.
    """
    relay = registry.get("phase22_explicit_c_migration", {}).get(
        "cross_lane_relay", {}).get("post_flip_review_relay", {})
    retirement = relay.get("phase398_site_retirement")
    if retirement is None:
        return
    retirements = retirement.get("retirements", [])
    require(bool(retirements), "Issue #398 relay retirement is empty")
    entry = retirements[0]

    resurrected = copy.deepcopy(rows)
    resurrected.append({
        **{field: entry["retired_site"][field] for field in
           ("path", "line", "recipe", "compiler_token", "command")},
        "selection": "explicit_c",
        "consumer_class": "already_explicit_or_parser_probe",
        "owner": "stdlib",
        "expected_artifact": "generated_C_or_diagnostic",
        "expected_transition": "exact_six_site_explicit_mir_to_c_relay",
        "falsifier": "partial_extra_path_drift_or_unrelated_inventory_change",
    })
    try:
        validate_post_flip_relay_transition(registry, resurrected)
    except SystemExit:
        pass
    else:
        require(False,
                "a retired relay invocation was accepted back into the tree")

    probe = copy.deepcopy(registry)
    probe["phase22_explicit_c_migration"]["cross_lane_relay"][
        "post_flip_review_relay"]["phase398_site_retirement"][
            "retirements"][0]["replacement_marker"] = (
                "a replay this file does not contain")
    try:
        validate_post_flip_relay_transition(probe, rows)
    except SystemExit:
        pass
    else:
        require(False,
                "a retired relay site was accepted without the frozen replay "
                "that replaces it")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase22_opening")
    require(isinstance(record, dict), "Patch 22.1 authority is missing")
    require(record.get("contract_version") == "phase22_opening_v2",
            "contract version drifted")
    require(record.get("status") == "patch22_1_complete" and
            record.get("next_patch") == "22.2",
            "status or successor drifted")
    require(record.get("observed_main_sha") ==
            "c157c86674624fd298c2f65e98ed8f4df85cb175",
            "opening evidence base drifted")
    require(record.get("phase21_closure_authority") ==
            registry.get("phase21_closure", {}).get("version"),
            "Phase 21 closure link drifted")

    cli = record.get("current_cli")
    require(cli == {
        "bare_route": "mir_to_c",
        "bare_artifact": "C_source_on_stdout",
        "explicit_mir_to_c_route": "mir_to_c",
        "explicit_c_alias": "rejected_unknown_backend",
        "explicit_cranelift_requires_output": True,
        "backend_selection_stage": "after_shared_resolver_parser_and_typechecker",
        "fallback_policy": "forbidden",
    }, "current CLI baseline drifted")

    package = record.get("current_package")
    require(package == {
        "make_target": "phase10-native-package",
        "install_target": "install",
        "artifacts": ["gust", "gust-native-backend", "gust-runtime-package.a"],
        "driver_discovery": "absolute_GUST_NATIVE_BACKEND_DRIVER_then_executable_sibling",
        "path_search": False,
        "auto_build_or_download": False,
    }, "package baseline drifted")

    postflip = registry.get("phase22_postflip_qualification", {})
    postflip_complete = (
        postflip.get("contract_version") ==
        "phase22_postflip_qualification_v1" and
        postflip.get("status") == "qualification_complete"
    )
    for surface_name in ("documentation_surfaces", "workflow_surfaces"):
        surfaces = record.get(surface_name)
        require(isinstance(surfaces, list) and surfaces,
                f"{surface_name} is missing")
        for row in surfaces:
            require(all(row.get(field) for field in (
                "id", "path", "current_state", "marker", "owner",
                "expected_transition",
            )), f"{surface_name} row is unclassified: {row!r}")
            path = ROOT / row["path"]
            marker_present = (path.is_file() and
                              row["marker"] in path.read_text(encoding="utf-8"))
            transitioned_by_postflip = (
                postflip_complete and
                "22.7" in row["expected_transition"]
            )
            require(marker_present or transitioned_by_postflip,
                    f"{surface_name} marker drifted: {row['id']}")

    live_rows = scan_invocations()
    rows = phase22_relay_inventory_rows(registry, live_rows)
    summary = scan_summary(rows)
    migration = registry.get("phase22_explicit_c_migration")
    require(isinstance(migration, dict),
            "explicit-C migration authority is missing")
    validate_post_flip_relay_transition(registry, live_rows)
    validate_landed_relay_command_substitution_rejection(registry, live_rows)
    validate_relay_retirement_rejection(registry, live_rows)
    require(summary["unclassified_count"] == 0,
            "an executable compiler invocation is unclassified")
    require(all(row["owner"] and row["expected_artifact"] and
                row["expected_transition"] and row["falsifier"] for row in rows),
            "an executable compiler invocation lacks owner, artifact, transition, or falsifier")

    suite = registry.get("phase21_complete_guard_suite", {})
    classification = suite.get("classification", {})
    handoff = record.get("native_capability_handoff")
    require(handoff == {
        "authority": suite.get("contract_version"),
        "inventory_total": suite.get("inventory", {}).get("total"),
        "required_native_case_count": classification.get("required_native_case_count"),
        "compile_deferral_count": sum(
            classification.get("compile_deferral_reason_counts", {}).values()),
        "oracle_precondition_failure_count":
            classification.get("oracle_precondition_failure_count"),
        "runtime_divergence_count": classification.get("runtime_divergence_count"),
        "default_policy": "unsupported_native_features_fail_clearly_without_C_fallback",
        "cleanup_destination": "22.5_pre_flip_default_cohort_qualification",
    }, "Phase 21 native-capability handoff drifted")

    stability = record.get("stability_qualification")
    require(stability == {
        "operator_decision": "2026-08-29_one_time_exact_final_main",
        "required_successful_runs": 1,
        "workflow": "Cranelift Historical Full",
        "required_head": "exact_merged_final_post_flip_implementation_main",
        "required_job_population": "complete_registry_derived_population_all_success",
        "maximum_unresolved_material_review_findings": 0,
    }, "stability-qualification authority drifted")

    require(record.get("unclassified_failures") == [],
            "Patch 22.1 leaves an unclassified failure")
    boundary = record.get("boundary", {})
    require(boundary and all(value is False for value in boundary.values()),
            "opening evidence widened into implementation")

    task = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 22.1 — Opening Default-Route and Consumer Inventory — DONE" in task,
            "TASK.md does not mark Patch 22.1 DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 22.1 guard levels drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "Patch 22.1 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Level 1 opening guard")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "dedicated workflow does not own both opening guards")
    for path_filter in ("'reset-heavy-guards-workflow.sh'", "'tests/*.gst'",
                        "'justfile*'"):
        require(workflow.count(path_filter) == 2,
                f"dedicated workflow does not own both path filters for {path_filter}")
    require(REVIEW.is_file(), "generated opening review is missing")
    review = REVIEW.read_text(encoding="utf-8")
    inventory = scan_summary(rows)
    stable_markers = (
        f"- Contract: `{record['contract_version']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Live successor executable compiler invocations: `{inventory['total']}`",
        f"- Unclassified invocations: `{inventory['unclassified_count']}`",
        "- Relay state: `exact_post_relay_only`",
        "## Stability qualification",
        "- Required successful runs: `1`",
        "- Required head: `exact_merged_final_post_flip_implementation_main`",
        "- Maximum unresolved material review findings: `0`",
    )
    require(all(marker in review for marker in stable_markers),
            "frozen generated opening review semantic markers drifted")
    require(review == render(record, live_rows, registry),
            "generated opening review is stale")
    return record


def render(record: dict, rows: list[dict[str, object]], registry: dict) -> str:
    live_rows = rows
    rows = phase22_relay_inventory_rows(registry, live_rows)
    opening_inventory = record["invocation_inventory"]
    _, landed_authority = validate_post_flip_relay_transition(registry, live_rows)
    # The review reports the census this tree actually has, advanced by any
    # registered successor, so its header and its table describe the same
    # state. `validate` compares these markers against the live scan, so a
    # pinned header here would report 306 invocations above a 199-row table.
    inventory = effective_relay_inventory(registry, landed_authority)
    projected_rows = transition_projection_rows(rows, registry)
    handoff = record["native_capability_handoff"]
    stability = record["stability_qualification"]
    lines = [
        "# Cranelift Phase 22 Opening — Default Route and Consumer Inventory",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` and the live",
        "repository invocation scan by `scripts/phase22_opening.py project`.",
        "Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Opening-baseline executable compiler invocations: `{opening_inventory['total']}`",
        f"- Live successor executable compiler invocations: `{inventory['total']}`",
        f"- Unclassified invocations: `{inventory['unclassified_count']}`",
        f"- Relay state: `{landed_authority['status']}`",
        f"- Landed owning PR: `#{landed_authority['owning_pull_request']}`",
        "",
        "## Current CLI and package",
        "",
        f"- Bare route: `{record['current_cli']['bare_route']}`",
        f"- Bare artifact: `{record['current_cli']['bare_artifact']}`",
        f"- Explicit `mir-to-c`: `{record['current_cli']['explicit_mir_to_c_route']}`",
        f"- Explicit `c`: `{record['current_cli']['explicit_c_alias']}`",
        f"- Cranelift requires `-o`: `{str(record['current_cli']['explicit_cranelift_requires_output']).lower()}`",
        f"- Package artifacts: `{', '.join(record['current_package']['artifacts'])}`",
        "",
        "## Documentation and workflow surfaces",
        "",
    ]
    for row in record["documentation_surfaces"]:
        lines.append(
            f"- `{row['id']}` — `{row['current_state']}`; transition "
            f"`{row['expected_transition']}`"
        )
    for row in record["workflow_surfaces"]:
        lines.append(
            f"- `{row['id']}` — `{row['current_state']}`; transition "
            f"`{row['expected_transition']}`"
        )
    lines += [
        "",
        "## Landed successor invocation summary",
        "",
    ]
    for key, value in inventory["selection_counts"].items():
        lines.append(f"- Landed selection `{key}`: `{value}`")
    for key, value in inventory["consumer_class_counts"].items():
        lines.append(f"- Landed consumer class `{key}`: `{value}`")
    lines += ["", "## Landed exact relay commands", ""]
    relay = registry["phase22_explicit_c_migration"]["cross_lane_relay"][
        "post_flip_review_relay"
    ]
    for site in relay["site_manifest"]:
        lines.append(
            f"- `{site['path']}:{site['line']}` — `{site['command']}`"
        )
    lines += ["", "## Landed successor executable invocation inventory", ""]
    # Patch 24.3b: the inventory table names what each row IS, not where it
    # sits. The Line column made every insertion above a row rewrite this
    # generated review; each row stays identified by path, recipe, selection
    # and command. The relay section above keeps its stored coordinates:
    # that record is frozen evidence, not a live scan.
    lines.append("| Path | Recipe | Selection | Class | Owner | Expected artifact | Expected transition | Falsifier |")
    lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for row in projected_rows:
        lines.append(
            f"| `{row['path']}` | `{row['recipe']}` | "
            f"`{row['selection']}` | `{row['consumer_class']}` | "
            f"`{row['owner']}` | `{row['expected_artifact']}` | "
            f"`{row['expected_transition']}` | "
            f"`{row['falsifier']}` |"
        )
    lines += [
        "", "## Phase 21 native-capability handoff", "",
        f"- Complete inventory: `{handoff['inventory_total']}`",
        f"- Required native cases: `{handoff['required_native_case_count']}`",
        f"- Compile deferrals: `{handoff['compile_deferral_count']}`",
        f"- Oracle precondition failures: `{handoff['oracle_precondition_failure_count']}`",
        f"- Runtime divergences: `{handoff['runtime_divergence_count']}`",
        f"- Default policy: `{handoff['default_policy']}`",
        f"- Cleanup destination: `{handoff['cleanup_destination']}`",
        "", "## Stability qualification", "",
        f"- Operator decision: `{stability['operator_decision']}`",
        f"- Required successful runs: `{stability['required_successful_runs']}`",
        f"- Workflow: `{stability['workflow']}`",
        f"- Required head: `{stability['required_head']}`",
        f"- Required job population: `{stability['required_job_population']}`",
        "- Maximum unresolved material review findings: "
        f"`{stability['maximum_unresolved_material_review_findings']}`",
        "",
        "Patch 22.1 changes no route. The invocation inventory is a transition",
        "checklist: Patch 22.2 makes C-dependent consumers explicit while bare",
        "Gust still emits C; later patches own omitted native output, packaging,",
        "the default flip, seed reconvergence, and stability evidence.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "scan", "validate", "project", "check-review",
    ))
    args = parser.parse_args()
    rows = scan_invocations()
    if args.command == "scan":
        print(json.dumps(scan_summary(rows), indent=2, sort_keys=True))
        return
    if args.command == "project":
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        record = registry.get("phase22_opening")
        require(isinstance(record, dict), "Patch 22.1 authority is missing")
        REVIEW.write_text(render(record, rows, registry), encoding="utf-8")
        validate()
        print(f"{GUARD_L1}: project ok")
        return
    record = validate()
    if args.command == "check-review":
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        require(REVIEW.read_text(encoding="utf-8") ==
                render(record, rows, registry),
                "generated opening review is stale; run project")
    else:
        print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
