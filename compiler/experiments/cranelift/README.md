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

At Phase 9D closure, the manifest tracked all 33 compiler-owned ingestion
emitters and all seventeen frozen Phase 9B translator seeds. The first bounded
post-9C cohort migrated `add_i32` and `positive_i32_branch`; ten seams used the
canonical shared lowering architecture, twenty-three remained classified as
compiler-owned bespoke lowering, and no seam remained metadata-preservation-
only. The three metadata lanes used the same parser, validator, Rust MIR model,
body lowerer, and object emitter as executable scalar lanes.

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

Phase 9E is closed as
`phase9e_closed_cfg_and_block_parameter_completeness`. Its bounded goal was to
make typed CFG edges and typed block parameters first-class in the canonical
compiler-owned MIR ingestion path. The phase opened from the frozen Phase 9D
inventory of 33 ingestion seams: ten canonical shared-lowering seams,
twenty-three bespoke seams, no metadata-only seam, and seventeen frozen
translator seeds.

Twelve existing non-call CFG seams are Phase 9E migration candidates: the
three local-CFG lanes, two basic block-parameter update/merge lanes, four
variable-arity materialization lanes, and three block-parameter-to-local
materialization lanes. The eleven remaining call/import seams are explicitly
deferred to the next phase. Phase 9E is i32-only and may add typed edge
arguments, merges, backedges, variable arity, and block-parameter-to-local
materialization, but it may not add calls, runtime imports, strings, structs,
arrays, resource execution semantics, or production backend routing.

New Phase 9E semantic evidence must use canonical
`gust.compiler_mir_ingestion.v1` fixtures through
`compiler-mir-ingestion-object`; historical lane commands may remain only as
thin migration adapters. The Phase 9D bypass freeze remains active. The
closure target is 22 canonical seams and exactly eleven frozen call/import
bespoke seams, with MIR-to-C still primary and Cranelift still disabled by
default.

The first Phase 9E cohort is complete. `block_local_branch`,
`block_local_update_branch`, and `block_two_local_update_branch` still validate
their frozen compiler-owned fixtures, but their commands now enter canonical
fixture parsing, validation, `CompilerMirLoweringFunction`, shared body
lowering, and shared object emission. None of those commands constructs an
`ObjectModule` or invokes `TinyMirBlockFunction` lowering. At completion of
that cohort, the inventory stood at thirteen canonical seams and twenty frozen
bespoke seams; the total remained 33 and the translator-seed inventory remained
frozen at seventeen.

The typed block-parameter representation milestone is complete. Canonical
blocks now carry ordered typed parameter declarations, and every jump or branch
edge owns an ordered argument list. Edge arguments can currently be i32
literals, function parameters, locals, current-block parameters, or a
current-block parameter plus an i32 literal. Canonical fixtures may also return
a block parameter, branch on a block parameter, or materialize one into a
local.

The parser remains backward-compatible with existing canonical fixtures by
treating omitted block-parameter and edge-argument counts as zero. Validation
rejects entry-block parameters, duplicate or non-int block parameters,
cross-block references, unknown sources, and edge arity or type mismatches. Its
worklist reachability pass is cycle-safe.

The shared block-parameter lowering core is now active. It creates every
Cranelift block before emitting bodies, appends typed destination parameters
before any predecessor edge, resolves ordered edge arguments in source order,
and uses the same path for forward edges and backedges. Block-parameter
returns and conditions lower directly from values bound in the current
destination block, and `seal_all_blocks` remains after all block bodies so
backedges are known before sealing.

The generic `compiler-mir-ingestion-object` command now proves literal,
function-parameter, local, block-parameter, and block-parameter-plus-literal
edge transport, independent branch-arm arguments, block-parameter returns, and
a native countdown backedge. At the end of the shared-core milestone,
`LocalI32SetBlockParam` was still validation-only; the dedicated
block-parameter-to-local materialization cohort below activates its shared
lowering. The shared-core inventory at that milestone remained thirteen
canonical seams and twenty frozen bespoke seams.

The basic single-parameter CFG cohort is now canonical. The historical
`block_param_update_branch` and `block_param_merge_update_branch` commands
still validate their frozen compiler-owned fixtures, then delegate to canonical
`gust.compiler_mir_ingestion.v1` fixtures and shared object emission. The first
lane proves function-parameter transport, block-parameter update, and
block-parameter branching. The second proves independent branch-arm values,
a parameterized merge block, and block-parameter return. Neither command owns
an `ObjectModule` or invokes `TinyMirParamBlockFunction` lowering.

The countdown loop remains the bounded canonical backedge proof through the
generic ingestion command. It transports an i32 value around a typed backedge
and relies on delayed block sealing after all predecessor edges are emitted.
The live inventory is now fifteen canonical seams and eighteen frozen bespoke
seams, with all seventeen translator seeds still frozen. The next milestone is
the variable-arity block-parameter cohort.

The variable-arity block-parameter cohort is now canonical.
`block_param_dual_materialize_return`,
`block_param_triple_materialize_return`,
`block_param_quad_materialize_return`, and
`block_param_quint_materialize_return` still validate their frozen historical
fixtures, then delegate to call-free canonical CFG fixtures through shared
object emission. Those canonical fixtures carry ordered block-parameter and
edge-argument lists of arity two through five. In every fixture the final
argument position drives both the branch decision and returned result, giving
native evidence that argument order is preserved rather than collapsed into
hardcoded dual, triple, quad, or quint lowering variants.

The historical fixtures contain local/imported call materialization records,
but those records remain compatibility-input validation only. Phase 9E adds no
call, import, or runtime-boundary lowering; each adapter preserves the existing
native arithmetic result with a bounded canonical CFG equivalent. None of the
four commands owns an `ObjectModule` or invokes `TinyMirParamBlockFunction`
lowering.

The live inventory is now nineteen canonical seams and fourteen frozen bespoke
seams, with the total still 33 and all seventeen translator seeds still
frozen. The next milestone is the block-parameter-to-local materialization
cohort.

The block-parameter-to-local materialization cohort is now canonical.
`block_param_local_materialize_return`,
`block_param_local_materialize_branch`, and
`block_param_local_first_dual_materialize_return` still validate their frozen
historical fixtures, then delegate to bounded call-free canonical fixtures
through shared object emission. `LocalI32SetBlockParam` now copies the current
block parameter into a declared i32 local before later local updates,
local-based branches, edge transport, or local returns.

The first migrated lane proves block-parameter-to-local copy, a local literal
update, local-based branch selection, a second block-parameter-to-local copy,
and local return. The second proves a local-based branch followed by direct
block-parameter return. The local-first dual lane models its historical
local-helper and imported-add sequence as explicit local literal updates while
keeping call and import records as compatibility-input validation only.

All three historical commands are thin canonical adapters and no longer own an
`ObjectModule` or invoke `TinyMirParamBlockFunction` lowering. The live
inventory is now twenty-two canonical seams and exactly eleven frozen bespoke
call/import seams, with the total still 33 and all seventeen translator seeds
still frozen. Every bounded non-call Phase 9E migration candidate is now on the
shared canonical path. The next milestone is the CFG completeness matrix,
strict rejection expansion, and exact Phase 9F call/import freeze.

The CFG completeness, strict-rejection, and Phase 9F freeze milestone is now
complete. The canonical matrix fixes five statement kinds, eight terminator
kinds, five ordered edge-argument kinds, block-parameter arities zero through
five, and the forward-jump, independent-branch-arm, parameterized-merge,
typed-backedge, and block-parameter-to-local CFG shapes. A compiled matrix
fixture traverses the shared parser, validator, block model, edge resolver, and
object emitter, while a separate void fixture closes the return-form matrix.

Strict rejection is exercised through both `compiler-mir-validate-fixture` and
`compiler-mir-ingestion-object`. Fourteen malformed forms cover unsupported
statements, terminators, and edge arguments; illegal entry, duplicate, or
non-int block parameters; cross-block references; unknown local and function
parameter sources; whole-edge and independent-branch-arm arity mismatches;
invalid block-parameter-to-local materialization; a return-free cycle; and an
unreachable block. Every object-command rejection is required to occur before
its output directory or object file exists.

The eleven remaining bespoke seams are now tagged
`phase9f_frozen_call_import_scope`. They are exactly the deferred local-call,
imported-call, imported-materialization, imported-predicate, and imported-merge
lanes recorded in the manifest. They retain `TinyMirParamBlockFunction` and
lane-owned object emission until Phase 9F explicitly opens call/import
canonicalization; Phase 9E does not admit call or import kinds into canonical
`gust.compiler_mir_ingestion.v1`.

The inventory remains 33 total seams, 22 canonical shared-lowering seams,
eleven frozen Phase 9F call/import bespoke seams, no metadata-only seam, and
seventeen frozen translator seeds. MIR-to-C remains primary and experimental
Cranelift remains disabled by default.

Phase 9E is closed on this evidence. All twelve bounded non-call migration
candidates use canonical parsing, validation, `CompilerMirLoweringFunction`,
shared CFG lowering, and shared object emission. The five statement kinds,
eight terminator kinds, five edge-argument kinds, arities zero through five,
merge, backedge, and block-parameter-to-local forms are frozen with strict
pre-output rejection for malformed fixtures.

No new Phase 9E semantic work may bypass canonical ingestion or expand the
call/import boundary. Phase 9F is the next contract and is reserved for
canonicalizing the exact eleven frozen call/import seams. Production routing
is unchanged.

Phase 9F is open as
`phase9f_open_canonical_calls_and_imported_runtime_boundary`. It opens from 33
total ingestion seams: twenty-two canonical shared-lowering seams, eleven
bespoke call/import seams, no metadata-only seam, and seventeen frozen
translator seeds. Steps 1 and 2 migrate no seams.

The exact eleven migration candidates are frozen as the complete Phase 9F set:
`block_param_local_call_branch`, `block_param_imported_call_branch`,
`block_param_imported_call_return`, `block_param_imported_materialize_branch`,
`block_param_imported_materialize_return`,
`block_param_imported_predicate_update_branch`,
`block_param_merge_arm_update_imported_call_branch`,
`block_param_merge_arm_update_imported_call_return`,
`block_param_merge_dual_imported_joined_return`,
`block_param_merge_imported_branch_joined_return`, and
`block_param_merge_imported_call_return`. Until each seam's explicit migration
patch, it remains frozen on `TinyMirParamBlockFunction`,
`define_tiny_mir_param_block_graph_exported_function`, and lane-owned
`ObjectModule` emission.

`gust.compiler_mir_ingestion.v1` remains frozen, single-function, and call/import-free.
`gust.compiler_mir_ingestion.v2` is the only new canonical schema allowed to represent modules, imports, and calls.
The generic `compiler-mir-ingestion-object` command may eventually dispatch
both versions, with a v1 fixture wrapped internally as a one-function module,
but this opening patch adds no v2 parser, validator, or call emission.

Phase 9F is bounded to direct local-function calls and direct imported-function
calls with ordered i32 arguments, one i32 return value, and every result stored
in a declared i32 local before use by the existing CFG, block-parameter, merge,
or materialization operations. Imported host symbols are statically linked and
supplied by native test shims.

Indirect calls, function pointers, variadic calls, callbacks, recursion,
mutually recursive local functions, void calls, multiple return values,
strings, pointers, structs, arrays, resources or runtime objects, dynamic
loading, symbol lookup, exceptions, unwinding, and production backend routing
remain excluded. All closed Phase 9E non-call semantics remain unchanged.
MIR-to-C remains primary, Cranelift remains disabled by default, and no
production runtime route is enabled. The closure target is 33 canonical shared
seams, zero bespoke seams, zero metadata-only seams, and the same seventeen
translator seeds.

The checked-in lockfile for this crate is owned by:

```bash
cargo generate-lockfile --manifest-path compiler/experiments/cranelift/Cargo.toml
```
