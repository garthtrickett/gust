#!/usr/bin/env python3
"""Check the R1 exact public-runtime projection against Phase 17 authority."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
PROJECTION = (
    ROOT
    / "compiler/experiments/cranelift/src/approved_runtime_exports.txt"
)
VERSION = "gust.r1.public_runtime_projection.v1"


def expected() -> str:
    registry = json.loads(REGISTRY.read_text())
    inventory = registry["opening_snapshots"]["phase17"]["helper_inventory"]
    classifications = {
        row["helper_id"]: row
        for row in registry["phase17_runtime_authority"]["helper_classifications"]
    }
    symbols = []
    for row in inventory:
        if (
            row["reachability"] != "runtime_public_surface"
            or row["symbol_kind"] != "exact_c_symbol"
        ):
            continue
        classified = classifications[row["id"]]
        if classified["symbol_identity"] != row["symbol_identity"]:
            raise SystemExit("Phase 17 public runtime classification drift")
        symbols.append(row["symbol_identity"])
    if len(symbols) != len(set(symbols)):
        raise SystemExit("duplicate Phase 17 public runtime spelling")
    return VERSION + "\n" + "\n".join(sorted(symbols)) + "\n"


if __name__ == "__main__":
    if PROJECTION.read_text() != expected():
        raise SystemExit("R1 public runtime projection differs from Phase 17 authority")
    print("R1 public runtime projection matches Phase 17 authority")
