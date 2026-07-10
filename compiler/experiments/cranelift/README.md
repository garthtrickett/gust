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
Phase 9D is closed as
`phase9d_closed_compiler_owned_mir_ingestion_canonicalized`. Compiler-owned MIR
ingestion is now the required architecture for new experimental Cranelift
semantic work: compiler MIR producer -> versioned fixture -> parser ->
validated Rust MIR model -> shared lowering -> object emission. Historical
commands may remain only as thin wrappers, while new translator-seed lanes
require an explicit abstraction-gap exception. Production routing,
default-backend changes, C-backend retirement, full calls and runtime imports,
strings, structs, arrays, resource execution semantics, and complete
block-parameter coverage remained outside Phase 9D. MIR-to-C stays primary and
Cranelift stays disabled by default.

The inventory and architecture milestones remain complete. The manifest still
tracks all 33 compiler-owned ingestion emitters and all seventeen frozen Phase
9B translator seeds. The first bounded post-9C cohort migrates `add_i32` and
`positive_i32_branch`; ten seams now use the canonical shared lowering
architecture, twenty-three remain classified as compiler-owned bespoke
lowering, and no seam remains metadata-preservation-only. The three metadata
lanes use the same parser, validator, Rust MIR model, body lowerer, and object
emitter as executable scalar lanes.

The canonical architecture is frozen and implemented as:
`parse_compiler_mir_fixture` -> `validate_compiler_mir_fixture` ->
`CompilerMirLoweringFunction` -> `build_compiler_mir_ingestion_body` ->
`lower_compiler_mir_ingestion_function_to_object`. The versioned
`gust.compiler_mir_ingestion.v1` schema covers one function, integer
parameters, `int` or `void` return, locals, blocks, the shared scalar statement
and terminator set, canonical metadata records, and expected native exit
status. The first post-9C cohort adds `LocalI32AddParam` so parameter arithmetic
also remains inside the canonical model rather than a `TinyMirFunction`
shortcut. `ReturnVoid` is supported only for a validated `void` function.
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
Phase 9B evidence. `add_i32` and `positive_i32_branch` now validate those
historical inputs and immediately enter canonical fixture parsing, validation,
model construction, shared lowering, and object emission. Their lane commands
no longer construct an `ObjectModule` or invoke a `TinyMir` lowerer.

The bypass freeze remains active after closure. Every canonical inventory seam
must use `CompilerMirLoweringFunction` and shared object emission; lane-owned
`ObjectModule` construction, new unregistered ingestion emitters, and new
translator seeds without an explicit abstraction-gap exception are rejected by
the Phase 9D guards. Existing bespoke paths remain frozen migration candidates,
not extension points.

Phase 9D closes with 33 registered ingestion seams: ten canonical shared
lowering seams, twenty-three frozen bespoke seams, no metadata-only seam, and
seventeen frozen translator seeds. The seven Phase 9C lanes remain rebased,
the two-lane post-9C scalar cohort remains canonical, invalid MIR is rejected
before object creation, and metadata policy is explicit. Phase 9E may expand
CFG and block-parameter completeness only through this canonical ingestion
architecture. It does not change production routing.

The checked-in lockfile for this crate is owned by:

```bash
cargo generate-lockfile --manifest-path compiler/experiments/cranelift/Cargo.toml
```
