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
Storage loads and initialized-index checks share one object-local call for reads
and Set, keyed only by resolved field offsets and element stride. Append growth/allocation/copy is likewise shared in an object-local helper,
using only existing allocator and memcpy declarations and preserving mutation
order. Function identities, explicit extern symbols and synthetic imports cannot
use the compiler-private helper namespace; compile-only controls enforce that
boundary before object definition. Both existing artifact owners remain enforced, including the stricter
10-MiB native-rebuild ceiling as well as R2's versioned compiler-program ceiling.

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

The retained R2 forged-length source now rejects at the frontend with the
metadata-authority diagnostic, before driver discovery or canonical publication.
Original and renamed controls use a driver sentinel; rejection inversions refuse
wrong-stage diagnostics, signal failures and any output artifact. The copied-alias
source retains its worker rejection and canonical projection. Both frozen
canonical worker mutation tests remain independently required by the R2 guard.

PR Fast partitions native rebuild authority and bundle-validation smoke into
one additional instance of its existing guarded matrix. Both original commands
remain mandatory, in order, with a prepared executable native package. The final
job waits for every matrix instance. Level 1 keeps its 120-minute ceiling and
the isolated shard keeps the existing 60-minute ceiling; guard assertions and
internal deadlines are unchanged. This changes scheduling and the aggregate
partition after a measured two-hour cancellation, rather than raising a deadline
or caching a prior result. Exact workflow and omission/substitution inversions
protect the relocation and its build gate, package prerequisite and fan-in.

The optional constant folder checks annotation/value presence before reading
them. Inferred declarations retain the existing constant-evaluation proof,
including the typed-query no-op terminal route; explicit annotations keep their
type check. Generated scalar source compilation remains qualified separately.
Other optional source recognizers similarly check initializer presence before
reading declaration slots. Loops that ignore unmatched declarations skip an
absent initializer; fixed patterns that require an initializer decline that
candidate. This preserves existing staged non-collection records, including the
threading owner's argument record, while leaving source disposition to its
existing supported owner or explicit pre-driver deferral.

The additive registration recomputes live source-site hashes and verifies
exact predecessor projections. Text projection binds only registered changed/added paths and passes other
rows unchanged to their existing validators. Historical registry fields and spelling-review
bytes remain frozen. Native bootstrap compares emitted objects at its fixed
point; no removed C seed is reconstructed. GitHub exact-head checks remain the
authoritative validation and are required before the checked Stdlib handoff.
