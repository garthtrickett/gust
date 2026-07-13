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

Phase 9F is closed as
`phase9f_closed_canonical_calls_and_imported_runtime_boundary`. It opened from
33 total ingestion seams: twenty-two canonical shared-lowering seams, eleven
bespoke call/import seams, no metadata-only seam, and seventeen frozen
translator seeds. Steps 1 and 2 migrated no seams.

The exact eleven migration candidates remain the complete Phase 9F set:
`block_param_local_call_branch`, `block_param_imported_call_branch`,
`block_param_imported_call_return`, `block_param_imported_materialize_branch`,
`block_param_imported_materialize_return`,
`block_param_imported_predicate_update_branch`,
`block_param_merge_arm_update_imported_call_branch`,
`block_param_merge_arm_update_imported_call_return`,
`block_param_merge_dual_imported_joined_return`,
`block_param_merge_imported_branch_joined_return`, and
`block_param_merge_imported_call_return`. All eleven now validate their frozen
lane fixtures, construct `CompilerMirLoweringModule`, and emit through
`lower_compiler_mir_ingestion_module_to_object`; none remains on
`TinyMirParamBlockFunction` or lane-owned `ObjectModule` emission.

`gust.compiler_mir_ingestion.v1` remains frozen, single-function, and call/import-free.
`gust.compiler_mir_ingestion.v2` is the only new canonical schema allowed to represent modules, imports, and calls.
At Phase 9F opening, the generic `compiler-mir-ingestion-object` command
began dispatching both versions. v1 continues through its frozen
single-function object path. v2 first gained parse/validation-only behavior,
then Patch 3 enabled import-free local-call modules, Patch 4 enabled direct
imported-host calls, and Patches 5 through 7 completed materialization,
merge-arm, joined, and dual-join call graphs through the shared module emitter.

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

The Phase 9F v2 schema/parser/validator milestone is complete. The canonical
`gust.compiler_mir_ingestion.v2` form owns a module name, imported host
declarations, defined exported-entry and module-local functions, explicit
ordered i32 signatures, and `LocalI32SetCall` statements. Calls resolve through
typed `LocalFunction` or `ImportedFunction` targets and accept literal,
function-parameter, local, block-parameter, and block-parameter-plus-literal
arguments.

The v2 validator freezes separate source-function, imported-function, emitted
backend-symbol, and imported link-symbol namespaces. It rejects duplicate
imports or local functions, conflicting import-link signatures, emitted/import
symbol collisions, unknown callees, wrong arity, non-i32 signatures,
undeclared call destinations, calls to exported entry functions, recursive or
mutually recursive local call graphs, invalid linkage, indirect targets, and
call/import records in v1. The schema fixture proves caller-before-callee
ordering, multiple defined functions, multiple imports, direct local calls,
direct imported calls, ordered arguments, and result materialization into
declared locals.

Patch 3 enables v2 object emission for validated import-free local-call
modules. The shared module emitter declares every exported-entry and
module-local function before defining any body, so caller-before-callee source
ordering is supported. Exported entries use Cranelift export linkage,
module-local helpers use local linkage, and direct local calls lower through
the shared call-aware canonical body builder.

At Patch 3 completion, modules containing imported functions still rejected
before output creation. That rejection is retained as historical milestone
evidence; Patch 4 below activates imported-host declarations and direct
imported-call emission. v1 remains single-function and call/import-free.

The block-param local-call branch seam is the first Phase 9F migration. Its
legacy lane-specific fixture parser is now only a compatibility adapter: after
validating the existing fixture, it constructs `CompilerMirLoweringModule` and
calls the shared module emitter. It no longer owns a lane-specific
`ObjectModule`, `TinyMirParamBlockFunction`, or bespoke function-definition
path.

Patch 4 completes the imported-function emitter and direct imported-call
cohort. The shared module emitter declares each unique imported link symbol
with Cranelift import linkage before defining any function body. Multiple
canonical source import names may share one imported `FuncId` only when the
validator has already proved that their link symbol and ordered i32 signature
match. Every defined function receives imported `FuncRef` values before the
call-aware body builder lowers `ImportedFunction` calls.

The checked-in Phase 9F schema fixture now provides native object evidence for
two statically linked imported host functions combined with caller-before-
callee local calls. Native C shims satisfy the unresolved host symbols only at
test link time. No dynamic symbol lookup, runtime loader, production runtime
route, or default-backend change is introduced.

`block_param_imported_call_branch`,
`block_param_imported_call_return`, and
`block_param_imported_predicate_update_branch` are canonical compatibility
adapters in this cohort. Each still validates its frozen lane-specific input,
then builds `CompilerMirLoweringModule` with typed imported-host declarations,
`LocalI32SetCall` statements, and existing CFG/block-parameter operations
before invoking the shared module emitter. None owns a lane-specific
`ObjectModule`, `TinyMirParamBlockFunction`, or bespoke function-definition
path.

The inventory is now 33 total seams, 26 canonical shared-lowering seams, seven
frozen bespoke imported-call seams, zero metadata-only seams, and seventeen
frozen translator seeds. The remaining seams are the two imported-call
materialization lanes and five imported merge/branch graph lanes. MIR-to-C
remains primary, Cranelift remains disabled by default, and no production
runtime or backend route is enabled. The next milestone is the imported-call
materialization cohort.

Patch 5 completes the imported materialization and predicate cohort without
changing Patch 4 call lowering. The two imported-materialization compatibility
adapters now validate their frozen lane-specific fixtures, construct
`CompilerMirLoweringModule`, and invoke the shared module emitter. Imported
results are stored through `LocalI32SetCall`, transported to successor block
parameters through `LocalI32` edge arguments, branched through existing block
parameter forms, and returned either through an existing local or through the
transported block parameter.

`block_param_imported_materialize_return` and
`block_param_imported_materialize_branch` are newly canonical in this patch.
`block_param_imported_predicate_update_branch` remains canonical from Patch 4
and is retained in this cohort as the predicate proof: an updated block
parameter feeds an imported predicate call whose local result drives existing
branch lowering. No new call target, argument, result, import declaration, or
`FuncRef` lowering path is introduced.

The inventory is now 33 total seams, 28 canonical shared-lowering seams, five
frozen bespoke imported merge-call graph seams, zero metadata-only seams, and
seventeen frozen translator seeds. The remaining seams are
`block_param_merge_arm_update_imported_call_branch`,
`block_param_merge_arm_update_imported_call_return`,
`block_param_merge_dual_imported_joined_return`,
`block_param_merge_imported_branch_joined_return`, and
`block_param_merge_imported_call_return`. MIR-to-C remains primary, Cranelift
remains disabled by default, and no production runtime or backend route is
enabled. The next milestone is the merge-arm imported-call cohort.

Patch 6 completes the merge-arm imported-call cohort without changing the
Patch 4 call lowering. Both frozen lane-specific parsers now act only as
compatibility adapters: they validate the existing fixture, build
`CompilerMirLoweringModule`, and invoke the shared module emitter.

`block_param_merge_arm_update_imported_call_return` performs imported calls in
both branch arms, updates the materialized arm locals, passes those locals as
typed edge arguments into a parameterized merge, then uses a post-merge
imported result as the existing local return. The branch companion performs an
imported call in one arm while the other arm uses the existing block-parameter
to local update, transports both local values into the merge, and lets a
post-merge imported predicate result drive existing branch behavior.

The inventory is now 33 total seams, 30 canonical shared-lowering seams, three
frozen bespoke imported merge-call graph seams, zero metadata-only seams, and
seventeen frozen translator seeds. The remaining seams are
`block_param_merge_dual_imported_joined_return`,
`block_param_merge_imported_branch_joined_return`, and
`block_param_merge_imported_call_return`. MIR-to-C remains primary, Cranelift
remains disabled by default, and no production runtime or backend route is
enabled. The next milestone is the remaining imported merge graph cohort.

Patch 7 completes the joined and dual-join imported-call cohort without
changing the Patch 4 call lowering. The final three frozen lane-specific
parsers now act only as compatibility adapters: they validate the existing
fixtures, build `CompilerMirLoweringModule`, and invoke the shared module
emitter.

`block_param_merge_imported_call_return` transports independent branch-arm
values into a parameterized merge, materializes the imported result in a
declared local, and returns through that local.
`block_param_merge_imported_branch_joined_return` carries imported predicate
results through an existing post-merge branch, converges both return values at
an ordered block parameter, then performs the joined imported return call.
`block_param_merge_dual_imported_joined_return` proves the same joined graph
with distinct imported symbols for the predicate and final return calls.

The Phase 9F inventory is now closed at 33 total seams, 33 canonical
shared-lowering seams, zero bespoke seams, zero metadata-only seams, and
seventeen frozen translator seeds. All eleven historical Phase 9F commands are
thin compatibility adapters into the canonical v2
`CompilerMirLoweringModule` model and shared module emission. MIR-to-C remains
primary, Cranelift remains disabled by default, and
no production runtime or backend route is enabled.

Phase 9G is open as
`phase9g_open_object_and_link_pipeline_hardening`. It inherits the closed
Phase 9F boundary: all 33 compiler-owned ingestion seams are canonical,
translator seeds remain frozen at seventeen, v1 and v2 syntax are unchanged,
MIR-to-C remains primary, Cranelift remains disabled by default, and no
production runtime or backend route is enabled.

Steps 1 and 2 changed only the contract, inventory, and guard surface. The
separate Phase 9G inventory does not add a compiler-MIR ingestion seam or
translator seed. It records the object/link owners inherited from Phase 9F,
including host-native default target construction, historical direct object
emitters, per-guard C shims, `CC_BIN`/`CFLAGS_VAL` link commands, native status
handling, and the unresolved-symbol `nm -u` probe.

Steps 3 and 4 make both canonical compiler-MIR object emitters transactional.
They finish lowering and object construction in memory, reject an empty object
buffer, and publish complete bytes through one shared helper. The helper writes
a hidden sibling temporary file with create-new semantics, flushes it, and
renames it to the final path only after the write completes. It removes a stale
owned temporary file before publication and cleans the owned temporary file
after any write or rename failure. Existing final artifacts therefore remain
untouched until a complete replacement is ready.

`CompilerMirObjectArtifactReport` records the final path and byte size. Parent
directories are created only after parsing, validation, metadata recognition,
lowering, and in-memory object emission complete. Parse or validation rejection
does not create the requested output parent, and failed publication leaves no
partial final object or sibling temporary artifact.

The opening warning baseline still includes the current PIE text-relocation
diagnostics. Phase 9G must harden emitted objects rather than hide those
warnings with a global `-no-pie` flag.
No linker ownership, target configuration, MIR syntax, translator seed, or
production route changes in this patch.

Steps 5 and 6 give both canonical compiler-MIR object emitters one explicit
native target owner: `build_compiler_mir_native_object_builder`. The target
contract records the native triple, architecture, pointer width, endianness,
object format, default calling convention, relocation model, and PIC state.
ELF, COFF, and Mach-O object formats with 32- or 64-bit pointers are admitted;
other native targets reject before `ObjectBuilder` creation.

Position-independent code is enabled in Cranelift with `is_pic=true` rather
than delegated to implicit defaults. The ELF guard links the multi-import
completeness object as a normal PIE, rejects text-relocation linker diagnostics
and `DT_TEXTREL`, and executes the linked artifact. No global `-no-pie` escape
hatch is added. MIR syntax, the 33/33/0/0/17 inventory, translator seeds,
default backend state, and production routing remain unchanged.

Steps 7 and 8 inspect complete object bytes before transactional publication.
The pinned `object` reader records binary format, architecture, endianness,
pointer width, object kind, section inventory, code-section presence, symbol
visibility, relocation targets, and duplicate symbol-table entries. Malformed,
truncated, code-section-free, or structurally inconsistent objects reject
before the sibling temp file or final object path is touched.

Each validated canonical MIR model derives an exact symbol contract before
emission: exported entries must be the complete globally visible definition
set, module-local functions must be defined with compilation-unit-local
visibility, and unresolved symbols must exactly match the declared imported
host link symbols. Import-free modules and local-only call graphs therefore
admit no undefined symbols, and unexpected exported helpers reject before
publication.

`compiler-mir-inspect-object` prints the structured report, while
`compiler-mir-verify-object-contract` re-derives the expected symbol contract
from a canonical fixture and verifies an existing object. `nm` is no longer the
source of truth for undefined symbols. It remains only an optional diagnostic
when structured inspection reports a mismatch.

MIR syntax, the 33/33/0/0/17 inventory, translator seeds, default backend
state, and production routing remain unchanged. The next milestone is the
canonical experimental link driver.

Steps 9 and 10 add one canonical experimental linker driver without migrating
existing native lanes yet. `gust.compiler_mir_link_request.v1` keeps linking
separate from object emission. A request names the final executable, preserves
the order of object inputs, selects either an optional C source or precompiled
host object, carries additional libraries and one-argument-per-record linker
options, selects the C compiler/link driver, applies explicit environment
overrides, and declares whether linking is expected to succeed or fail. A
failure expectation also names one exact stable `expected_failure_kind`.
Relative paths are resolved from the request file rather than from hidden
process state.

The driver never constructs a shell command string. It validates every declared
input before creating an output parent, maps each structured field directly to
`std::process::Command`, reserves executable output control for itself, captures
stdout and stderr into deterministic sibling logs, and classifies the spawned
process as `linked` or `native_link_failure`. An expected native link failure is
a successful test outcome but never publishes an executable.

Executable publication is transactional. The linker receives only a hidden
same-directory temporary output path. A successful expected link must create a
nonempty temporary executable before rename to the final path. Spawn failures,
unexpected results, native-link failures, and publication failures remove that
owned temporary path while preserving existing final artifacts, all declared
input objects, and captured logs.

MIR syntax, object emission, the 33/33/0/0/17 inventory, translator seeds,
default backend state, and production routing remain unchanged. Existing
lane-owned linker commands are intentionally frozen until the later Phase 9G
migration patches.

Steps 11 and 12 define one stable pipeline taxonomy shared by canonical object
emission and linking. The eleven stages are `fixture_parse`,
`fixture_validation`, `mir_lowering`, `object_build`, `object_verification`,
`object_publication`, `link_input_validation`, `linker_spawn`, `native_link`,
`executable_publication`, and `native_execution`.

Every classified error emits the machine-readable line
`gust_pipeline_failure: stage=<stage> kind=<kind>` before the full human
diagnostic. Native linker stdout and stderr remain in the deterministic sibling
logs. Expected link failures now name an exact `expected_failure_kind`, so an
expected failure cannot pass merely because some unrelated linker error
occurred.

The stable link failure kinds are `unresolved_symbol`, `duplicate_symbol`,
`invalid_object`, `missing_input`, `unsupported_target`,
`linker_unavailable`, `linker_rejected_options`, `output_not_writable`, and
`unknown_native_link_failure`. Object and host-object inputs are structurally
inspected during link-input validation before the linker is spawned.

An unresolved imported host symbol is therefore always reported as
`native_link/unresolved_symbol`: canonical fixture parsing, validation, MIR
lowering, object construction, structural verification, and transactional
object publication have already succeeded. It is never relabeled as a fixture
or object-emission failure.

MIR syntax, the 33/33/0/0/17 inventory, translator seeds, default backend
state, and production routing remain unchanged. The next milestone is the
positive canonical link matrix.

The checked-in lockfile for this crate is owned by:
Patch 8 freezes the complete canonical call/import matrix and retires all
eleven historical bypasses. The checked-in completeness fixture combines local
and imported callees, zero/one/multiple arguments, every supported argument
source, return/branch/update/edge uses, calls across entry/arm/merge placement,
both caller/callee declaration orders, multiple imports, import reuse, and an
exported entry with a local helper.

The rejection matrix distinguishes parser or validator failures from native
link failures. Missing callees, bad arity or signatures, duplicate or
conflicting symbols, linkage and namespace collisions, undeclared
destinations, recursion, indirect or variadic syntax, unsupported returns, v1
call/import records, and non-contiguous v2 records reject before output
creation. A valid module with an unresolved imported host symbol still parses,
validates, and writes an object; only the native link fails.

All eleven historical call/import commands remain thin compatibility adapters:
they validate their frozen lane fixtures, build the canonical
`CompilerMirLoweringModule`, and call
`lower_compiler_mir_ingestion_module_to_object`. They do not construct an
`ObjectModule`, own Cranelift call or import declaration logic, or invoke the
legacy parameter-block graph emitter. The retained
`TinyMirParamBlockFunction` call variants are dead to new compiler-ingestion
work and remain frozen only for existing non-ingestion and translator
consumers. The final inventory remains 33 canonical shared seams, zero bespoke
seams, and seventeen translator seeds.

Patch 9 closes Phase 9F with all eleven exact call/import seams on the
canonical shared module path. `gust.compiler_mir_ingestion.v1` remains frozen
and call/import-free, while v2 exclusively owns module, import, and call
syntax. Local and statically imported calls share the same module model, call
body lowerer, and object emitter, with ordered i32 arguments and one declared
i32-local result.

Malformed canonical fixtures continue to reject during parsing or validation
before output creation. Unresolved host symbols remain successful parse,
validation, and object-emission cases that fail only at native link time. The
closed inventory is 33 canonical ingestion seams, zero bespoke seams, and
seventeen frozen translator seeds. MIR-to-C remains primary, Cranelift remains
disabled by default, and no production runtime or backend route is enabled.

The checked-in lockfile for this crate is owned by:

```bash
cargo generate-lockfile --manifest-path compiler/experiments/cranelift/Cargo.toml
```
