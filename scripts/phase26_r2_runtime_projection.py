#!/usr/bin/env python3
"""Check the additive R2 call-region runtime export authority."""

import hashlib
import re
from pathlib import Path

import phase26_r1_runtime_projection as r1


ROOT = Path(__file__).resolve().parents[1]
PROJECTION = ROOT / "compiler/experiments/cranelift/src/approved_r2_runtime_exports.txt"
RUST = ROOT / "src/runtime-rs/src/ffi_call_region.rs"
HEADER = ROOT / "src/runtime/core_headers.h"
MAKEFILE = ROOT / "Makefile"
VERSION = "gust.r2.ffi_call_region_runtime_projection.v1"
SYMBOLS = (
    "os_FfiCallRegionAcceptResult",
    "os_FfiCallRegionFree",
    "os_FfiCallRegionInputAddress",
    "os_FfiCallRegionOutputAddress",
    "os_FfiCallRegionReadOutput",
    "os_FfiCallRegionTryCreate",
    "os_FfiCallRegionWriteInput",
)
PHASE25_ROOTS_SHA256 = "da7f301037ab8c809aa2b5917e9b864169d9478ac6f1e7af4961ab88004af309"
RUST_SIGNATURES = {
    "os_FfiCallRegionTryCreate": ("input_len: i32, output_cap: i32, out: *mut *mut FfiCallRegionV1,", "i32"),
    "os_FfiCallRegionWriteInput": ("region: *mut FfiCallRegionV1, index: i32, value: u8,", "i32"),
    "os_FfiCallRegionInputAddress": ("region: *const FfiCallRegionV1", "*const u8"),
    "os_FfiCallRegionOutputAddress": ("region: *mut FfiCallRegionV1", "*mut u8"),
    "os_FfiCallRegionAcceptResult": ("region: *mut FfiCallRegionV1, count: i32,", "i32"),
    "os_FfiCallRegionReadOutput": ("region: *const FfiCallRegionV1, index: i32, out: *mut u8,", "i32"),
    "os_FfiCallRegionFree": ("region: *mut FfiCallRegionV1", ""),
}
C_SIGNATURES = {
    "os_FfiCallRegionTryCreate": "int32_t os_FfiCallRegionTryCreate(int32_t input_len, int32_t output_cap, struct FfiCallRegionV1 **out);",
    "os_FfiCallRegionWriteInput": "int32_t os_FfiCallRegionWriteInput(struct FfiCallRegionV1 *region, int32_t index, uint8_t value);",
    "os_FfiCallRegionInputAddress": "const uint8_t *os_FfiCallRegionInputAddress(const struct FfiCallRegionV1 *region);",
    "os_FfiCallRegionOutputAddress": "uint8_t *os_FfiCallRegionOutputAddress(struct FfiCallRegionV1 *region);",
    "os_FfiCallRegionAcceptResult": "int32_t os_FfiCallRegionAcceptResult(struct FfiCallRegionV1 *region, int32_t count);",
    "os_FfiCallRegionReadOutput": "int32_t os_FfiCallRegionReadOutput(const struct FfiCallRegionV1 *region, int32_t index, uint8_t *out);",
    "os_FfiCallRegionFree": "void os_FfiCallRegionFree(struct FfiCallRegionV1 *region);",
}


def check() -> None:
    if r1.PROJECTION.read_text() != r1.expected():
        raise SystemExit("frozen R1/Phase 17 public runtime projection drift")
    expected = VERSION + "\n" + "\n".join(SYMBOLS) + "\n"
    if PROJECTION.read_text() != expected:
        raise SystemExit("R2 runtime projection differs from exact reviewed ABI")

    rust = RUST.read_text()
    header = HEADER.read_text()
    make = MAKEFILE.read_text()
    def roots(name: str) -> list[str]:
        marker = name + " = \\\n"
        if make.count(marker) != 1:
            raise SystemExit("runtime root list missing or duplicated: " + name)
        return make.split(marker, 1)[1].split("\n\n", 1)[0].replace("\\\n", " ").split()

    predecessor = roots("PHASE25_RUNTIME_RS_EXPORTS")
    predecessor_digest = hashlib.sha256(("\n".join(predecessor) + "\n").encode()).hexdigest()
    if predecessor_digest != PHASE25_ROOTS_SHA256 or len(predecessor) != len(set(predecessor)):
        raise SystemExit("frozen Phase 25 runtime roots changed")
    addition = roots("PHASE26_R2_RUNTIME_RS_EXPORTS")
    if addition != list(SYMBOLS) or set(predecessor) & set(addition):
        raise SystemExit("R2 runtime roots differ from the exact additive seven")
    if make.count("CURRENT_RUNTIME_RS_EXPORTS = $(PHASE25_RUNTIME_RS_EXPORTS) $(PHASE26_R2_RUNTIME_RS_EXPORTS)") != 1:
        raise SystemExit("effective runtime roots are not the predecessor union R2")
    exports = predecessor + addition
    for site in (
        "$(foreach sym,$(CURRENT_RUNTIME_RS_EXPORTS),-u _$(sym))",
        "$(foreach sym,$(CURRENT_RUNTIME_RS_EXPORTS),-exported_symbol _$(sym))",
        "$(foreach sym,$(CURRENT_RUNTIME_RS_EXPORTS),-u $(sym))",
        "$(foreach sym,$(CURRENT_RUNTIME_RS_EXPORTS),--keep-global-symbol=$(sym))",
        "expected=$$(printf '%s\\n' $(CURRENT_RUNTIME_RS_EXPORTS) | sort)",
    ):
        if make.count(site) != 1:
            raise SystemExit("narrowed runtime link or exact export check omitted: " + site)
    for name in SYMBOLS:
        definitions = re.findall(
            r"#\[no_mangle\]\s+pub unsafe extern \"C\" fn " + name +
            r"\s*\((.*?)\)\s*(?:->\s*([^\{]+))?\s*\{", rust, re.S)
        if len(definitions) != 1 or tuple(" ".join(part.split()) for part in definitions[0]) != RUST_SIGNATURES[name]:
            raise SystemExit("R2 Rust runtime definition missing or duplicated: " + name)
        if header.count(C_SIGNATURES[name].split(name, 1)[0] + name) != 1 or \
           " ".join(C_SIGNATURES[name].split()) not in " ".join(header.split()):
            raise SystemExit("R2 C ABI declaration missing or duplicated: " + name)
        if exports.count(name) != 1:
            raise SystemExit("R2 narrowed runtime export missing or duplicated: " + name)
    print("R2 call-region runtime projection matches exact Rust/C/narrowed ABI")


if __name__ == "__main__":
    check()
