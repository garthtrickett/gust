# Phase 26.1 checked collection prerequisite

This capability implements OD20 A–C for the existing native admitted profile.
It does not close R4's separately owned safe wrapper or the Phase 26.1 release.
The operator-delegated decision and OD21–23 are recorded in docs PR605.

Safe source cannot mutate registered collection metadata, escape its field
addresses, or fabricate a direct default collection. Scalar metadata reads and
existing constructor signatures remain available. Aggregate and arena-slot
staging can install a valid constructor result before use. Existing arena
allocation zeroes payloads; using an untouched collection record traps on its
null arena. Typed arena-slot access checks absence and extent before loading
the record. An inactive zeroed enum payload is not an active collection use.

Ordinary vector reads, Set, Pop, Clear and all three append paths share checked
storage machinery. Invalid initialized-element indexes, invalid state, empty
Pop, count overflow and allocation-byte overflow trap before access or invalid
mutation. This is process-level failure, with no unwind, deferred-cleanup or
request-containment guarantee. Optional lookups retain their existing absence
contract. Operands run once in existing order; final metadata and destination
checks follow the value operand. Runtime allocation exhaustion still aborts.

Growth uses widened arithmetic, the existing signed element-count limit and
actual arena byte capacity. No new signed-i32 allocation-byte ceiling applies.
Unsigned arena offsets retain their i32 ABI encoding. Machine check functions
are defined with local linkage in each object, not added to the runtime ABI.
Factoring them keeps the compiler within its unchanged artifact-size ceiling.

The typed producer records existing element resource classification on an
ordinary Pop Call. Copy-permitted removal preserves backing values, including
live reference values observable through copied handles. Resource transfer
retains prior clearing; public resource source admission remains explicitly
`deferred_p13_resource_runtime_semantics` before driver discovery. OD23 is OPEN
for resource-slot ownership/observation across copied handles before future
public admission. Component-only resource object emission is not evidence of
public support, permitted post-transfer observation or executable safety.
No malformed resource program was linked or executed.

Qualification is owned by `guard-cranelift-phase26-collection-validity`:

- original and renamed metadata-write, field-address and direct-default source
  diagnostics, with no output executable;
- the public valid constructor/borrow/Pop route and typed producer canonical
  roundtrip, object validation, linking and execution;
- zeroed versus initialized arena slots and nested fields, absent indexes and
  initialized returned aggregates; inactive enum payload through the existing
  typed component (public enum aggregate-argument admission stays deferred);
- Int/Byte/Bool growth, Set and copied-value Pop observations; live references;
  invalid read/Set boundaries and empty Pop; Push and Set value side effects;
- a pure, allocation-free 4-GiB-byte arithmetic success case and separate count
  and byte overflow failures. Isolated unique-package mutants remove each
  check and must fail its precise semantic assertion;
- local-linkage assertions and Pop receiver/layout/brand/operation mutations.

The additive registration recomputes complete live scan hashes and verifies
exact predecessor projections. Historical registry fields and spelling-review
bytes remain frozen. Native bootstrap compares emitted objects at its fixed
point; no removed C seed is reconstructed. GitHub exact-head checks remain the
authoritative validation and are required before the checked Stdlib handoff.
