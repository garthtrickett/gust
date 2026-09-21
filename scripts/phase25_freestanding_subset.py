#!/usr/bin/env python3
"""Patch 25.3: the freestanding Gust subset the runtime must be written in.

D2's first obligation, and the one O3 assigned an owner. The runtime IS
`str`, `Vector`, `HashMap` and the arena, so runtime code cannot use them:
no `std.Concat`, no `std.Clone`, no `ctx[...]`. That subset -- raw pointers,
scalars, loops, `extern func` -- plausibly exists and is usable, but nothing
defined or enforced it, so a stray `std.Clone` in a runtime file would
compile and recurse.

ENFORCEMENT IS BY RELOCATION, NOT BY GREP. This matters more than the rule.
A guard that greps runtime `.gst` files for `std.Clone` is a name test
standing in for a behaviour test: it passes for anything aliased, spelled
differently, or reached one call deep. An object carrying a relocation
against a runtime export violated the subset however it was spelled. Same
mechanism D2's third obligation specifies for `os_ArenaAlloc`, so the two
guards are one technique applied twice.

The forbidden set is DERIVED from the runtime's own exports rather than
hardcoded, so a new runtime function is forbidden the moment it exists.
A hardcoded list would go stale silently, which is the defect #436's
`\\.a\\b` diagnosis and #445's rotted harness both were.

A `#[freestanding]` module attribute would be stronger -- it fails at
compile time with a good message instead of at guard time with a symbol
name -- but it is new language surface and therefore an OD-register
question for Phase 26. O3's rule is: derivable constraint is lane work, new
language surface escalates. This is derivable, so it stays here.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Where a Gust-authored runtime object would land once 25.5 starts moving
# files. Empty today; the guard says so rather than passing silently.
FREESTANDING_OBJECTS = ROOT / "build" / "phase25-freestanding"

# The captured name must allow MIXED CASE. A lowercase-only capture
# silently missed os_ArenaAlloc -- the single most important symbol in
# the forbidden set -- and this guard's own assertion caught it.
EXPORT_RE = re.compile(r'^[A-Za-z_][A-Za-z0-9_ *]*?\b([a-z_][A-Za-z0-9_]*)\s*\(', re.M)


# The forbidden set derived from src/runtime/*.c SHRINKS as Patch 25.5 moves
# those files to Gust -- it would empty itself precisely as this guard became
# active, which is the one moment it must not. So today's set is pinned as a
# floor and the live derivation must stay a superset of it. Migrating a file
# removes its C source, not the obligation not to call into it.
FORBIDDEN_FLOOR = frozenset(['gust_context_switch', 'gust_fiber_create', 'gust_fiber_entry_wrapper', 'gust_fiber_exit', 'gust_fiber_free', 'gust_fiber_switch', 'gust_scheduler_destroy', 'gust_scheduler_init', 'gust_scheduler_spawn', 'gust_shard_loop', 'gust_yield', 'os_ArenaAlloc', 'os_Arena_Free', 'os_Arena_New', 'os_Arena_Validate', 'os_Args', 'os_CloseDir', 'os_ExecutablePath', 'os_FileExecutable', 'os_FileExists', 'os_GetEnv', 'os_GetThreadScratch_raw', 'os_HashMapClear_impl', 'os_HashMapContains_impl', 'os_HashMapRef_impl', 'os_HashMapRemove_impl', 'os_LogError', 'os_LogInt', 'os_LogStr', 'os_MockPayload', 'os_NativeObjectFormat', 'os_NativeTargetTriple', 'os_OpenDir', 'os_PathAbsolute', 'os_PathDir', 'os_ReadDir', 'os_ReadFile', 'os_RemoveFile', 'os_RunProcess', 'os_ScratchAlloc', 'os_ScratchReset', 'os_SetThreadScratch', 'os_System', 'os_WriteFile', 'os_copy_c_string_to_arena', 'os_path_join', 'os_read_stream_to_arena', 'os_slice_to_c_string', 'std_Channel_Alloc', 'std_Channel_Recv_impl', 'std_Channel_Send_impl', 'std_Clone_str', 'std_GenerationalSwap', 'std_Mutex_Alloc', 'std_Mutex_Lock_impl', 'std_Mutex_Unlock_impl', 'std_PoolAlloc_impl', 'std_PoolFree_impl', 'std_is_alpha', 'std_is_digit', 'std_is_whitespace', 'std_parse_int', 'std_str_byte_at', 'std_str_eq', 'std_str_find', 'std_str_slice', 'std_str_split', 'std_str_trim'])


# The subset asks "does runtime code call UPWARD", not "does runtime code
# call the runtime". A flat forbidden set answers the second question, and so
# would reject a Gust scratch.c for calling os_ArenaAlloc -- which is the
# intended layering, not a violation. Derived from the C sources, not
# proposed: arena depends on nothing, five files depend only on arena, and
# fiber depends on scratch. No mutual pairs, so the order is a real DAG.
LAYERS = {
    "arena": 0,
    "scratch": 1, "collections": 1,
    "strings": 2, "host_io": 2, "file_io": 2,
    "fiber": 3,
}

# Injected by codegen into every `while` loop and every recursive function
# (codegen.gst:4018, :3870), unconditionally and with no suppression flag.
# It is defined in fiber.c -- layer 3 -- so EVERY freestanding object calls
# upward through no choice of its own, and a Gust arena.c with one loop would
# close arena -> fiber -> scratch -> arena. Exempted here so the layer check
# reports what the author controls; Patch 25.6 is what actually removes it,
# which is why 25.6 now precedes 25.5.
CODEGEN_INJECTED = frozenset({
    # Emitted into every `while` loop and recursive function
    # (codegen.gst:4018, :3870). Patch 25.6 replaced the inline
    # `--gust_loop_ticks` decrement with this call, because a thread-local
    # data symbol cannot be exported from stable Rust.
    "gust_tick",
    # What gust_tick calls when the tick expires. Still reachable from
    # emitted code, so still not the author's choice.
    "gust_yield",
    # Emitted into every slice, vector, pool index and HashMap miss --
    # 1,963 sites in the seed before Patch 25.6 replaced the inline
    # printf/exit pairs with this one call.
    "gust_check_fail",
})


# Pinned for the same reason FORBIDDEN_FLOOR is, and the omission was the
# same bug one level down. The floor stopped the forbidden SET emptying
# as Patch 25.5 deletes src/runtime/*.c, but the layer LOOKUP still read
# those files: measured, with them gone every symbol_layer() returned -1,
# and -1 is treated as a violation, so the guard would have rejected
# every migrated file at the moment migration began.
SYMBOL_LAYERS = {'gust_context_switch': 3,
 'gust_fiber_create': 3,
 'gust_fiber_entry_wrapper': 3,
 'gust_fiber_exit': 3,
 'gust_fiber_free': 3,
 'gust_fiber_switch': 3,
 'gust_scheduler_destroy': 3,
 'gust_scheduler_init': 3,
 'gust_scheduler_spawn': 3,
 'gust_shard_loop': 3,
 'gust_yield': 3,
 'os_ArenaAlloc': 0,
 'os_Arena_Free': 0,
 'os_Arena_New': 0,
 'os_Arena_Validate': 0,
 'os_Args': 2,
 'os_CloseDir': 2,
 'os_ExecutablePath': 2,
 'os_FileExecutable': 2,
 'os_FileExists': 2,
 'os_GetEnv': 2,
 'os_GetThreadScratch_raw': 1,
 'os_HashMapClear_impl': 1,
 'os_HashMapContains_impl': 1,
 'os_HashMapRef_impl': 1,
 'os_HashMapRemove_impl': 1,
 'os_LogError': 2,
 'os_LogInt': 0,
 'os_LogStr': 2,
 'os_MockPayload': 2,
 'os_NativeObjectFormat': 2,
 'os_NativeTargetTriple': 2,
 'os_OpenDir': 2,
 'os_PathAbsolute': 2,
 'os_PathDir': 2,
 'os_ReadDir': 2,
 'os_ReadFile': 2,
 'os_RemoveFile': 2,
 'os_RunProcess': 2,
 'os_ScratchAlloc': 1,
 'os_ScratchReset': 1,
 'os_SetThreadScratch': 1,
 'os_System': 2,
 'os_WriteFile': 2,
 'os_copy_c_string_to_arena': 2,
 'os_path_join': 2,
 'os_read_stream_to_arena': 2,
 'os_slice_to_c_string': 2,
 'std_Channel_Alloc': 3,
 'std_Channel_Recv_impl': 3,
 'std_Channel_Send_impl': 3,
 'std_Clone_str': 2,
 'std_GenerationalSwap': 0,
 'std_Mutex_Alloc': 3,
 'std_Mutex_Lock_impl': 3,
 'std_Mutex_Unlock_impl': 3,
 'std_PoolAlloc_impl': 1,
 'std_PoolFree_impl': 1,
 'std_is_alpha': 2,
 'std_is_digit': 2,
 'std_is_whitespace': 2,
 'std_parse_int': 2,
 'std_str_byte_at': 2,
 'std_str_eq': 2,
 'std_str_find': 2,
 'std_str_slice': 2,
 'std_str_split': 2,
 'std_str_trim': 2}


def symbol_layer(symbol: str) -> int:
    """The layer of the file defining a runtime symbol, or -1 if unknown.

    The pin is consulted first so migration cannot erase the answer. The
    live scan remains for symbols added after this pin was taken.
    """
    if symbol in SYMBOL_LAYERS:
        return SYMBOL_LAYERS[symbol]
    for path in sorted((ROOT / "src" / "runtime").glob("*.c")):
        text = path.read_text(encoding="utf-8", errors="replace")
        if symbol in EXPORT_RE.findall(text):
            return LAYERS.get(path.stem, -1)
    return -1


def object_layer(obj) -> int:
    """The layer a freestanding object belongs to, from its stem.

    The stem IS the contract: an object must be named for the runtime file
    it replaces, because that is what places it in the order. Patch 25.5
    emits these, so the naming rule is stated in the failure message rather
    than left for someone to infer -- measured, `gust_strings.o` making a
    perfectly legal downward call was reported as calling the runtime it
    implements, which would send the reader hunting a violation that is not
    there.
    """
    return LAYERS.get(obj.stem, -1)


def defined_symbols(obj) -> set:
    """Symbols the object itself defines."""
    names = set()
    for line in run_tool(["nm", "--defined-only", str(obj)], obj).splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[-2] in {"T", "D", "B", "R"}:
            names.add(parts[-1])
    return names


def upward_calls(obj, referenced: set, forbidden: set) -> list:
    """Calls to the object's OWN layer or higher -- the real violation.

    A downward call is the layering working. An unplaced object (-1) is
    judged strictly: everything runtime it touches is a violation, because
    an object whose layer nobody declared cannot be shown to respect one.
    """
    mine = object_layer(obj)
    # A module may call what it DEFINES. That is ordinary composition, not a
    # layering violation: std_str_trim calling std_str_slice is how the C
    # writes it too, and both live in strings.
    #
    # This narrows a check added in response to review. The finding was that
    # `nm -u` misses a symbol an object both defines and calls -- true, and
    # the relocation table fixes it. But the conclusion drawn from it, that
    # such a call is a violation, was wrong: the question the subset asks is
    # whether a module calls UPWARD into the runtime, and its own functions
    # are not upward of themselves. Measured: without this, a Gust strings.o
    # was rejected for calling the std_str_slice it defines, which is the
    # first thing Patch 25.5 needs to write.
    own = defined_symbols(obj)
    bad = []
    for symbol in sorted(referenced & forbidden):
        if symbol in CODEGEN_INJECTED or symbol in own:
            continue
        theirs = symbol_layer(symbol)
        if mine < 0 or theirs < 0 or theirs >= mine:
            bad.append(symbol)
    return bad


def runtime_exports() -> set:
    """Every symbol the runtime exports -- the set runtime code may not call.

    Three sources, unioned, because no single one survives the migration:
    the remaining C sources; the built runtime archive if present, which
    keeps its name and shape while its contents change language (25.4); and
    the pinned floor, which is what stops the set shrinking to nothing.
    """
    found = set()
    for path in sorted((ROOT / "src" / "runtime").glob("*.c")):
        text = path.read_text(encoding="utf-8", errors="replace")
        found.update(EXPORT_RE.findall(text))
    found = {s for s in found if s.startswith(("std_", "os_", "gust_"))}
    found |= archive_exports()
    return found | set(FORBIDDEN_FLOOR)


def archive_exports() -> set:
    """Symbols the built runtime archive defines, whatever language wrote them."""
    archive = ROOT / "build" / "gust-runtime-package.a"
    if not archive.is_file():
        return set()
    out = run_tool(["nm", "--defined-only", str(archive)], archive)
    names = set()
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[-2] in {"T", "D", "B", "R"}:
            names.add(parts[-1])
    return {s for s in names if s.startswith(("std_", "os_", "gust_"))}


def run_tool(cmd: list, obj: Path) -> str:
    """Run a binutils command, refusing to read failure as an empty result.

    An object this guard cannot inspect is not an object with no violations.
    Ignoring the exit status made a malformed or unsupported file report
    clean, which is the failure mode the guard exists to prevent.
    """
    out = subprocess.run(cmd, capture_output=True, text=True)
    require(out.returncode == 0,
            f"{cmd[0]} failed on {obj.name} (exit {out.returncode}); an "
            "object that cannot be inspected must not be reported clean: "
            f"{out.stderr.strip()[:200]}")
    return out.stdout


def referenced_symbols(obj: Path) -> set:
    """Symbols the object REFERENCES, read from its relocation table.

    `nm -u` lists undefined symbols only, so an object that both defines a
    forbidden export and calls it shows nothing -- the call is resolved
    within the object and never becomes undefined. Measured: a translation
    unit defining and calling std_Clone_str yields an empty `nm -u` and an
    R_X86_64_PLT32 relocation against std_Clone_str. The relocation table is
    what the contract always meant by "calls into the runtime".
    """
    names = set()
    for line in run_tool(["readelf", "-rW", str(obj)], obj).splitlines():
        parts = line.split()
        if len(parts) >= 5 and parts[0][:1].isdigit() and "R_" in parts[2]:
            sym = parts[4].split("@")[0]
            if sym and not sym.startswith("."):
                names.add(sym)
    return names


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"guard-cranelift-phase25-freestanding-subset: {message}")
        raise SystemExit(1)


def report() -> dict:
    objects = sorted(FREESTANDING_OBJECTS.glob("*.o")) if FREESTANDING_OBJECTS.is_dir() else []
    return {
        "version": "phase25_freestanding_subset_v1",
        "forbidden_symbols": sorted(runtime_exports()),
        "freestanding_objects": [p.name for p in objects],
        "violations": {
            p.name: upward_calls(p, referenced_symbols(p), runtime_exports())
            for p in objects
        },
    }


def unplaced_objects(objects) -> list:
    """Objects whose stem names no runtime file, so no order can judge them."""
    return sorted(o.name for o in objects if object_layer(o) < 0)


def validate() -> None:
    record = report()
    forbidden = set(record["forbidden_symbols"])
    # The set must be derived and non-empty, or the guard forbids nothing.
    require(forbidden,
            "no runtime exports found in src/runtime/*.c, so the forbidden "
            "set is empty and this guard would pass anything. The derivation "
            "is broken, not the tree -- the runtime exports symbols today.")
    require("os_ArenaAlloc" in forbidden or "os_Arena_New" in forbidden,
            "the arena allocator is absent from the derived forbidden set; "
            f"got {sorted(forbidden)[:6]}... The derivation is matching the "
            "wrong thing.")
    objects = (sorted(FREESTANDING_OBJECTS.glob("*.o"))
               if FREESTANDING_OBJECTS.is_dir() else [])
    stray = unplaced_objects(objects)
    require(not stray,
            f"freestanding objects {stray} are named for no runtime "
            f"file, so the layer order cannot judge them. Name each "
            f"object for the file it replaces -- one of "
            f"{sorted(LAYERS)} -- because the stem is what places it "
            "in the order. Reported separately from a layering "
            "violation: a misnamed object is a naming bug, and "
            "calling it a violation sends the reader hunting one "
            "that is not there.")
    offenders = {k: v for k, v in record["violations"].items() if v}
    require(not offenders,
            "freestanding runtime objects call the runtime they implement: "
            f"{offenders}. A runtime function that reaches os_ArenaAlloc or "
            "std_* recurses through the thing it is defining.")
    if not record["freestanding_objects"]:
        print("guard-cranelift-phase25-freestanding-subset: ok "
              f"({len(forbidden)} forbidden symbols derived). No freestanding "
              "objects exist yet -- 25.5 produces the first. This guard is "
              "armed and vacuous until then, deliberately and visibly.")
        return
    print("guard-cranelift-phase25-freestanding-subset: ok "
          f"({len(record['freestanding_objects'])} objects, "
          f"{len(forbidden)} forbidden symbols, no violations)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["report", "validate"])
    args = parser.parse_args()
    if args.command == "report":
        print(json.dumps(report(), indent=2, sort_keys=True))
    else:
        validate()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
