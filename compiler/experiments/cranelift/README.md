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
emission. Historical commands may remain as thin wrappers, while new
translator-seed lanes require an explicit abstraction-gap exception.
Production routing, default-backend changes, C-backend retirement, full calls
and runtime imports, strings, structs, arrays, resource execution semantics,
and complete block-parameter coverage remain outside Phase 9D. MIR-to-C stays
primary and Cranelift stays disabled by default.

The inventory and architecture milestones remain complete. The manifest still
tracks all 33 compiler-owned ingestion emitters and all seventeen frozen Phase
9B translator seeds. After the Phase 9C rebase, eight seams use the canonical
shared lowering architecture, twenty-five remain classified as compiler-owned
bespoke lowering, and no seam remains metadata-preservation-only. The three
metadata lanes now use the same parser, validator, Rust MIR model, body lowerer,
and object emitter as the executable scalar lanes.

The canonical architecture is frozen and implemented as:
`parse_compiler_mir_fixture` -> `validate_compiler_mir_fixture` ->
`CompilerMirLoweringFunction` -> `build_compiler_mir_ingestion_body` ->
`lower_compiler_mir_ingestion_function_to_object`. The versioned
`gust.compiler_mir_ingestion.v1` schema covers one function, integer
parameters, `int` or `void` return, locals, blocks, the shared scalar statement
and terminator set, canonical metadata records, and expected native exit
status. `ReturnVoid` is supported only for a validated `void` function.
Parsing rejects duplicate, unknown, malformed, and unsupported fields before
any Cranelift module or object can be created.

`compiler-mir-validate-fixture` exercises this boundary without emitting an
object. The generic `compiler-mir-ingestion-object <input.mir> <output.o>`
command reads canonical fixture contents, parses and validates them, recognizes
canonical metadata policy, and only then enters shared lowering and object
emission. Validation failure still happens before output-directory or object
creation.

The frozen seven Phase 9C lane commands are now thin compatibility adapters.
They first validate their historical compiler-owned fixture contract, then
feed canonical fixture contents through the same parser, validator, Rust MIR
model, metadata recognizer, shared body lowerer, and object emitter used by the
generic command. Provenance, resource, and native-boundary records use the
common `kind`/`attachment`/`policy`/`payload` representation and are explicitly
ignored with proof for code generation; they do not claim runtime semantics.
The old fixture formats remain accepted only to preserve frozen Phase 9C and
Phase 9B evidence. New work must use the canonical format directly. The next
milestone is the first bounded post-9C canonical migration cohort and the
beginning of bypass-path freeze work.

The checked-in lockfile for this crate is owned by:

```bash
cargo generate-lockfile --manifest-path compiler/experiments/cranelift/Cargo.toml
```
