#!/usr/bin/env bash
# Patch 25.5: exercise the ported runtime through the C ABI.
#
# Compiling and exporting the right symbol names proves neither that a
# ported function does the right thing nor that its struct layouts match.
# This links a C caller against the crate and runs it, which is the contract
# every existing caller actually depends on.
#
# It caught nothing on first run -- 18/18 passed -- but it is the only thing
# standing between "the symbols are there" and "the runtime works", and the
# port has already produced one silent ABI defect (os_ArenaAlloc declared
# i32 against a size_t parameter) that only a type check found.
set -euo pipefail
cd "$(dirname "$0")/.."
ARCHIVE=src/runtime-rs/target/release/libgust_runtime_rs.a
# ALWAYS rebuild. The `[ -f "$ARCHIVE" ] ||` guard that used to be here
# silently tested the PREVIOUS build after a source edit -- a green run
# that says nothing about the code you just changed, which is the exact
# failure this harness exists to catch.
cargo build --release --manifest-path src/runtime-rs/Cargo.toml
out=$(mktemp -d)/abi_smoke
"${CC:-cc}" -O1 -pthread src/runtime-rs/abi-tests/abi_smoke.c "$ARCHIVE" -o "$out"
"$out"
