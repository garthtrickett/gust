# Gust Cranelift experiment

This crate is intentionally separate from the root Gust compiler crate.

It started as the Cranelift dependency beachhead for the experimental
backend path. Production Gust codegen must continue to route through MIR-to-C
until a later explicit step wires a real Cranelift backend.

Step 9 adds the first real Cranelift object emission smoke: a tiny exported
`tiny_cranelift_return_int` function that returns `1`. The justfile links that
object with a C shim only to execute the native smoke; the function body itself
is emitted by Cranelift.

Phase 9C is closed as a fixture-backed differential backend-development lane.
Its frozen seven candidates consume fixtures produced by `compiler/mir.gst`,
enter this isolated Cranelift crate, emit objects, link with native shims, and
match their MIR-to-C oracle statuses. Strict invalid-fixture rejection happens
before object emission, while provenance, resource, and native-boundary lanes
prove metadata preservation and recognition rather than claiming runtime
semantics. The Phase 9B translator seeds remain frozen historical coverage.

The reusable compiler-MIR lowering core remains intentionally narrow. Return
int, local-binding/read, block-jump, conditional-branch, and the first shared
CFG join use one object-emission and body-lowering path. The CFG milestone
branches from an entry block, updates one local in each successor, joins both
arms, and returns the joined local. Calls, resources, strings, structs, arrays,
runtime integration, and production routing remain outside this closed phase.
Phase 9D is open as `phase9d_compiler_owned_mir_ingestion_canonicalization`.
Its contract makes compiler-owned MIR ingestion the required architecture for
new experimental Cranelift semantic work: compiler MIR producer -> versioned
fixture -> parser -> validated Rust MIR model -> shared lowering -> object
emission. The first milestone is to inventory every existing ingestion seam and
freeze that architecture before adding new language coverage. Historical
commands may remain as thin wrappers, while new translator-seed lanes require
an explicit abstraction-gap exception. Production routing, default-backend
changes, C-backend retirement, full calls and runtime imports, strings,
structs, arrays, resource execution semantics, and complete block-parameter
coverage remain outside Phase 9D. MIR-to-C stays primary and Cranelift stays
disabled by default.

The checked-in lockfile for this crate is owned by:

```bash
cargo generate-lockfile --manifest-path compiler/experiments/cranelift/Cargo.toml
```
