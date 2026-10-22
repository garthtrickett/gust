# First compiler release FFI contract

**Planning decision: 2026-10-19. Implementation status: OPEN.**

The first compiler release will qualify useful zlib compression and
decompression through a pinned, compiler-owned native adapter on one named
host/target pair. It will enforce the declared ABI and existing unsafe and
provenance rules. The adapter and zlib belong to the release's trusted computing
base. Arbitrary native code can corrupt the process if it violates its contract.

This contract defines Phase 26.1's first-release scope. The broader D/E/F
requirements remain recorded as follow-up obligations in the
[Phase 26 roadmap](PHASES_26_AND_27.md#first-release-scope-and-execution).
No implementation, test, registry row, or phase status becomes complete through
this planning decision.

## 1. Supported use and trust

A developer must be able to build a Gust example that compresses supplied bytes,
decompresses them into a bounded destination, checks the status, and obtains the
original bytes. The same example must exercise empty input, incompressible input,
insufficient destination space, zero-capacity decompression of compressed empty
content, and malformed compressed input. A synthetic host that adds integers does not satisfy this integration gate.

The supported route is a release-supplied adapter with pinned source, library,
ABI description, and link inputs. It is platform code under
[VISION §93](VISION.md#93-native-code), including that section's signing,
versioning, conformance, and provenance requirements. Qualification must cover
the library as well as the small adapter. No application may turn its own
native object into platform code by choosing the same ABI.

Application-authored and third-party native escape hatches remain forbidden by
default in the deployed Gust product. VISION §§93 and 97 still require their
signed provenance, explicit capability, human approval, strong isolation, and
governance. A lexical `unsafe` block and a transient arena do not supply those
controls. This compiler contract does not activate that deployment feature.

## 2. Exact guarantee boundary

| Subject | Release requirement | Assumption or limit |
| --- | --- | --- |
| Calling foreign code | Every direct extern call has an explicit unsafe context and a complete, supported per-position policy. | An unsafe declaration is a trusted assertion about native behavior. |
| ABI | The canonical compiler plan records the exact target, widths, layout, direction, callee, and result policy. The native worker validates the plan before emission. | A correct Gust signature alone cannot establish that a different native binary honors it. |
| Origin and brands | At admitted adapter/wrapper paths, raw, external, isolated, and unknown addresses cannot acquire safe `Index[T,ctx]` or `&T[ctx]` authority. Existing non-laundering checks remain enforced. | A safe result requires an existing checked constructor or a reviewed copy into safe storage. |
| Null and bounds | Raw pointers carry no implicit non-null, live-allocation, length, or ownership guarantee. Existing known-null rejection remains enforced. | Raw pointer validity and actual allocation extent are unsafe obligations. A safe wrapper must establish its bounds independently. |
| Borrowing | Declared input/output direction and call duration are represented and checked for admitted source shapes. Ambiguous unsupported plans reject. | Native code must honor non-retention and write limits. A read annotation does not make `&T` immutable. |
| Output | Output is usable only after success and validation of its reported length against the real destination capacity. | Failed calls may have partially written the destination. No safe view may expose unwritten or unvalidated bytes. |
| Isolation | Existing isolated-call copies retain their lifetime and cleanup guarantees. | They do not prevent native memory corruption, syscalls, filesystem access, or retained aliases. |
| Cleanup | Existing qualified resource and native-release rules retain their guarantees on their named exits. | Native unwinding, `longjmp`, crashes, and termination are outside those guarantees. |

Static checking and generated tests are described as checks and rejection
behavior. A machine-checked formal safety proof or unmatched-language safety
claim is outside the release claim, following VISION §79.

## 3. ABI and packaging profile

The initial profile is `x86_64-unknown-linux-gnu`, little-endian ELF, with the
currently qualified native calling convention. Another host or target requires
its own artifacts and conformance evidence; GNU evidence does not qualify musl,
macOS, or Windows.

Use the live primitive layout authority in `compiler/mir_primitive_layout.gst`.
Gust `Int` is signed 32-bit in this profile. Byte is 8-bit and pointers are
64-bit. Never substitute Gust `Int` for C `long`, `unsigned long`, or `size_t`
by spelling or host coincidence.

The adapter exposes fixed-width signed 32-bit statuses and nonnegative byte
counts, plus explicitly declared byte-pointer positions. It checks conversions
into zlib's header-defined `uLong`/`uLongf` types and rejects any unrepresentable
result before conversion back. Public lengths and capacities are at most
`INT32_MAX`; a compression bound above that limit is an explicit error.
This profile requires no general unsigned-long language feature.

The normative native interface is:

```c
#include <stdint.h>
int32_t gust_zlib_bound(int32_t input_count);
int32_t gust_zlib_compress(const uint8_t *input, int32_t input_count,
    uint8_t *destination, int32_t capacity, int32_t level);
int32_t gust_zlib_decompress(const uint8_t *input, int32_t input_count,
    uint8_t *destination, int32_t capacity);
```

The corresponding planned Gust declarations use the existing policy spelling:

```gust
extern func gust_zlib_bound(input_count: int #[ffi(value)]) int #[ffi(value)];
extern func gust_zlib_compress(input: *byte #[ffi(borrow_read_call)], input_count: int #[ffi(value)], destination: *byte #[ffi(borrow_write_call)], capacity: int #[ffi(value)], level: int #[ffi(value)]) int #[ffi(value)];
extern func gust_zlib_decompress(input: *byte #[ffi(borrow_read_call)], input_count: int #[ffi(value)], destination: *byte #[ffi(borrow_write_call)], capacity: int #[ffi(value)]) int #[ffi(value)];
```

These declarations specify the required interface; byte-pointer borrowing is an
OPEN generic extension of today's aggregate-only borrow route. The approved
package contract associates input parameter 0 with count 1 and destination 2
with capacity 3 for the two data operations. The producer records those
associations in a versioned canonical byte-span plan; the worker cross-checks
them against the approved signature and actual argument positions. There are
no scalar-out pointers, output records, or native-owned returned pointers.
These direct borrow policies pass the caller-supplied addresses unchanged;
they never allocate, isolate, or copy buffers. The separate marshalling region
in §5 owns the safe wrapper's temporaries. Extending direct policies to byte
spans must preserve their existing meaning.

Every operation returns a nonnegative count on success, including zero for an
empty successful decompression. Negative returns -1 through -6 mean invalid
arguments, range error, insufficient destination, corrupt data, allocation
failure, and other native failure respectively. Record the exact zlib-to-adapter
mapping in the package. The wrapper decodes this declared result convention;
the compiler validates an ordinary signed scalar result. This is not
`#[ffi(native_error)]`, whose existing rule treats every nonzero result as an
error. zlib's internal `uLongf` output stays in the adapter, which checks it
before conversion and returns no usable output length on failure.

The release package must identify the adapter source revision/digest, zlib
version and source/archive digest, build options, target, exported symbols,
object or archive digests, license, and complete transitive link inputs.
The native worker selects only that approved package and its exact symbols.
Source code, environment flags, or an unapproved search path cannot append
arbitrary objects or replace a library. Missing, mismatched, or tampered
packages fail before execution. Runtime dynamic-library substitution must be
prevented or independently verified; checking only the adapter object is
insufficient. A statically linked, approved zlib archive is the initial route.

The signed package metadata binds that complete artifact set. Verification must
check an explicitly trusted release key or CI signing identity, the repository
and release identity, target, and artifact digests before loading/linking. Ship
the trust root and a reviewed withdrawal/replacement policy; reject bad,
unknown-signer, revoked, or mismatched packages. Offline verification uses a
pinned trust/revocation snapshot and states its freshness limit. Digests alone
are insufficient for the platform-code claim.

[OD-22's selected first-release trust policy](PHASE26_PACKAGE_TRUST_DECISION.md)
names the repository operator as signing/custody and withdrawal/replacement
owner, a dedicated production Ed25519 identity `gust-native-release-1`, and
worker-pinned trust snapshots with at most seven days of offline validity.
Actual public-key provisioning/enrollment and production artifact qualification
remain release gates; test roots do not supply that production identity.

zlib is optional for ordinary Gust programs and compiler/bootstrap builds.
Dedicated FFI release jobs require its approved package and fail if absent;
existing suite jobs and populations are preserved. Building a foreign adapter
with a C toolchain is an explicitly named optional foreign-component task and
supplies no evidence for a C-free compiler build.

The package/link mechanism is implementation work. The existing
`worker_owned_fixed_host_object_only_no_source_or_environment_linker_expansion`
registry policy remains intact for its historical cohort. Add a separately
versioned authority for the approved package; do not reinterpret the fixed test
host slot as a general native loader. Dependencies require the repository's
normal approval before they are installed or added.

## 4. zlib operations

The implementation publishes the declarations and header above together. All
operations use the same generic canonical ABI/policy mechanism; no compiler rule
may inspect a zlib function name or a particular application type.

| Operation | Inputs and outputs | Required behavior |
| --- | --- | --- |
| Compression bound | Input byte count; checked bound plus status | Normalize `compressBound` into the supported count range without truncation. |
| Compress | Read input span, disjoint writable destination span, level, actual output count, status | Use `compress2`; preserve a distinct success/failure result and the validated output count. |
| Decompress | Read compressed span, disjoint writable destination span, actual output count, status | Use `uncompress`; the caller supplies a hard output capacity. No allocation based solely on an untrusted advertised decompressed size. |

A span associates a byte pointer with its byte count or capacity in the declared
call contract. The compiler must validate the supported pointer ABI and policy
association. For raw inputs the caller remains responsible for backing storage,
liveness, extent, and disjointness. A safe wrapper obtains these facts from its
actual owned input/destination storage, performs the needed checks, contains the
unsafe call, and exposes only initialized successful output. It cannot invent
facts from a raw address or from an untrusted returned count.

The adapter must define zero-length behavior without dereferencing a null or
empty backing pointer; use distinct valid internal dummy storage for input
and output where the native call requires it. An empty span occupies no bytes
for overlap checking. Decompressing valid compressed empty content with capacity
zero must return success count 0. For a valid stream with nonempty output,
capacity zero returns insufficient-destination error -3. If zlib needs writable
space to distinguish these cases, use the adapter's internal dummy buffer and
validate the resulting length before any copy to the caller. These exact
observables belong to FFI-R3.

It must reject negative counts, count/capacity overflow, invalid
compression levels, null pointers for nonempty spans, and overlapping buffers.
Validate integer-address range overflow before comparing ranges; do not compare
unrelated C pointers relationally. These checks cannot establish that a non-null
raw pointer actually names an allocation. Count checks precede pointer
arithmetic. It must return a deterministic count or error on every exit.
No input pointer, output pointer, or Gust callback is retained after the call.
No borrowed native result pointer crosses back into Gust.

The adapter preserves distinct success counts and negative errors for invalid
input, insufficient output, allocation failure, and range errors; no failed call
produces a successful safe value. The zlib manual specifies the buffer and
in/out-length behavior of these functions, including possible partial output
on decompression failure.
[Native utility contract](https://zlib.net/manual.html)

This is compression functionality, not an archive parser, streaming API,
allocator callback interface, or decompression-resource sandbox.

## 5. Unsafe and safe interface obligations

The native implementer must match the declared C ABI, respect every span and
alias restriction, avoid retention, initialize outputs, and return without
unwinding across Gust. The package author must bind the actual binary and its
transitive dependencies to that contract.

The unsafe Gust caller must provide valid live backing memory, compatible
alignment and aliasing, correct counts, and a legal owner for the duration of
the call. A non-null check alone does not establish those facts. The caller
must inspect the result before consuming output.

A wrapper advertised as safe must discharge all caller obligations internally,
with safe caller inputs unable to violate its invariants. Its allocating context
is explicit. Safe output is constructed in caller-owned Gust storage; native
pointers, handles, and raw views never become branded values by annotation.
The selected safe storage representation is `std.Vector[byte, ctx]`. The
Stdlib lane owns this wrapper and its public API, after a merged compiler
handoff; this planning decision does not activate or edit its roadmap. Its
inputs are the input Vector, compression level or decompression capacity, and
an explicit output arena. Under the operator-selected
[OD-21 ticket representation](PHASE26_TAGGED_RESULT_DECISION.md), success carries
`Index[std.Vector[byte, ctx], ctx]` to a completed Vector in that output arena;
failure carries a classified error and no usable output Index. Publish the
Index only after successful copy-out and native temporary cleanup. The tagged
result must be expressible with existing enum support. The final
public type, function names and error-type spelling are Stdlib-owned; this does
not assume a builtin `Result` or `?` operator. The count/error ABI and these
invariants are fixed here.
The wrapper reads inputs through checked indexing and constructs output with
checked pushes. It never passes a Vector's backing store to native code or
assumes that storage is pinned.

**Compiler seam:** a separate call-scoped marshalling region surrounds the
direct extern call. It extends the existing one-call transient-arena allocation
and cleanup mechanism, not the global thread scratch allocator and not the
meaning of `borrow_read_call`/`borrow_write_call`. The typed producer records
runtime length operands, checked copy operations, the direct call and cleanup
schedule in a canonical plan; it does not copy runtime contents while compiling.
Generated code checks input length and output capacity, allocates two separate
call-owned byte buffers, copies input through checked source reads, and passes
those temporary addresses unchanged to the adapter. Partial allocation failure
skips the native call, frees all already allocated temporary storage, and
publishes no output. Zero lengths use the distinct dummy-storage rule in §4.

Generated output copy-out happens only after a nonnegative return at most the
actual destination capacity. It uses checked destination writes/pushes; an
error publishes no partially constructed result. The canonical marshalling plan
owns buffer sizes, association, copy direction, result validation, and cleanup
order; the native worker validates that plan without recognizing Vector or
zlib names. The direct extern's ABI/policy plan remains separate. There are no
user callbacks in either plan. Temporaries live until copy-out finishes, and
arena cleanup occurs once on every qualified normal/error exit. Nonlocal
native exits remain unsupported.

The direct byte-span extension and the separate marshalling region are OPEN
Cranelift prerequisites, with producer, worker, partial-allocation-failure,
zero-length, and cleanup evidence in FFI-R2. Their implementation design must identify the exact typed source operations and
existing allocation/runtime hooks before semantic edits. A new MIR meaning or
runtime symbol, if unavoidable, requires the shared-zone ownership decision
before implementation; this document does not authorize an improvised
intrinsic, new smart-pointer family, or raw stdlib workaround. The subsequent
Stdlib wrapper is a separate patch based on merged compiler support. Until
that handoff and wrapper pass, the low-level adapter is unsafe/experimental and
the safe-interface release gate remains OPEN.

Before calling the wrapper safe, perform a targeted audit of its exact Vector
operations and brand/arena/lifetime paths: checked reads, Push/reallocation,
return/move, allocation failure and cleanup. This is a prerequisite within
FFI-R4; it does not assume or close the later full Phase 26.5 collection audit.
Audit the wrapper through the same public interface its callers use, including
failure paths and copying/alias behavior. If these obligations cannot be met,
keep the interface explicitly unsafe and keep FFI-R4 and Phase 26.1 OPEN.
Do not introduce a raw-pointer workaround in safe stdlib collections.

## 6. Unsupported cases and existing behavior

The approved-package admission path rejects unregistered libraries/symbols, unknown or
incomplete per-position policies, unsupported target/ABI/layout, invalid span
associations, and incompatible policy combinations before driver discovery or
emission, as appropriate to the owning stage. Diagnostics name the unsupported
property and produce no executable for that program.

The new approved-package route does not admit variadic calls, C++ objects/exceptions, unions,
nested or packed application layouts, pointer-containing aggregate layouts,
arbitrary pointer-to-pointer outputs, callbacks, retained pointers, transferred
owners, or native-owned returned objects. A separate named gate must qualify
one of those features before this package can use it.

The worker-owned historical test-host route remains separate from approved-package
admission. Previously merged cohorts for packed layouts, ownership, retention, callbacks,
and status composition remain registered and tested with their original scope.
They are not removed or relabeled unsupported merely because this package does
not use them. Existing ordinary Gust programs and checked safe constructors
remain compatible. Any proposed new rejection of accepted source requires its
own generic semantic rationale and bootstrap evidence.

## 7. Required Phase 26.1 release evidence

All rows begin OPEN. Native fixtures and unpublished diagnostic prototypes are
inputs to the audit, not substitutes for the real-library acceptance rows.

| Gate | Required evidence | Owner |
| --- | --- | --- |
| FFI-R1 package and link authority | Signed package identity, verified trust root and artifact set, update/withdrawal policy, transitive archive pins, deterministic link and symbol/signature binding; missing/tampered/unknown-signer/revoked/wrong-target/environment-substitution negatives. | Cranelift |
| FFI-R2 ABI and byte spans | Published adapter header/declarations above; generic byte marshalling and wrapper storage/lifetime; exact signed widths, pointer ABI, span associations and per-position plan; renamed/type-distinct host controls and malformed canonical-plan rejections. | Cranelift |
| FFI-R3 useful native execution | Actual pinned zlib round-trip and all §1/§4 failure/empty/overflow/alias cases, output bounds and no false success, with a clean-machine reproduction. Synthetic fixtures supplement these cases. | Cranelift |
| FFI-R4 safety floor and public interface | Existing unsafe/non-laundering/known-null/resource checks remain; reachable origin-route dispositions below; merged safe wrapper, targeted audit of its Vector/brand/arena operations, acceptance/rejection and hostile input tests through its interface. A claimed new helper guard has a positive baseline and a targeted negative with the actual rejecting stage recorded. | Cranelift safety checks; Stdlib wrapper after merged compiler handoff |
| FFI-R5 regression and bootstrap | Full compiler suite, adjacent native/resource/layout regressions, unchanged predecessor projections, native emitted-object fixed point, exact-head required CI and resolved independent reviews. | Cranelift |
| FFI-R6 closure record | Required rows merged; authoritative closure guard and exact-final-main Historical Full successful, with actual owning jobs, artifact hashes, supported profile, limitations, and a runnable reproduction. | Cranelift |

Use the existing compiler 4 GiB and owning-guard 6 GiB caps, shared admission,
and query 4096-work/1-MiB and separate certificate budgets where those mechanisms
are exercised. A budget exhaustion must produce an explicit conservative
outcome; it cannot mint authority. No test may pass by increasing a cap,
resetting a query balance, bypassing its owner, or weakening an old guard.
Full new-query fit and public interface tests are required whenever release
behavior depends on the new generic proof engine. The 26.1 exit gate expressly
requires separate Cranelift capability/package patches followed by a
Stdlib-owned wrapper patch on merged support, then a closure patch. This is the
required per-patch split; the roadmap records the order and ownership.

### Origin and nullability scope

Inventory every path reachable through the admitted adapter and safe wrapper:
input construction, marshalling, the native call, output validation/copy,
cleanup, error propagation, and return. For each reachable conversion, record
its existing origin category, route, authority requirement, and positive or
negative owning test. Attempt direct, aliased, field/container, call/cast/return,
branch, recursive-cycle, and post-write escape where applicable to those paths.
Unknown facts cannot grant safe authority. A discovered safe-code soundness
hole remains a release blocker.

Preserve the existing owning-test population and inventory coverage across the
nine origins (`safe`, `local_stack`, `arena`, `scratchpad`, `ffi`, `sandbox`, `raw_unknown`, `borrowed_field`,
`container_element`) and seven routes (assignment, field, aggregate, container,
call, cast, return). The planning inventory may reference that full matrix, but
this release does not require 63 new inference mechanisms or one new test per
unreachable cross-product cell. Keep the release's reachable-path evidence map
separate from the general model. Accepted safe constructors and ordinary safe
language features must not be rejected to evade analysis.

The existing 63-cell general-model map stays OPEN until its original positive,
negative, reconciliation, recursion, and invalidation gates pass. Use the distinct
reachable-path release map rather than changing the general map's definition or
marking its cells complete from unsupported-case rejection. General precision for
computed nullability through every arbitrary control-flow shape is deferred.
Existing null rejection stays in force, and no raw-pointer type is advertised
as a non-null or live-allocation guarantee. Any safe operation that requires a
fact must check it, establish it through the qualified model, or reject the
operation. Conservative joins, recursive cycles, effects, and writes cannot
manufacture a safe origin.

## 8. Remaining work and deliberate deferrals

| Existing obligation | First-release disposition | Re-entry condition and owner |
| --- | --- | --- |
| D unsafe/per-position ownership, escape and target layout | Required for every admitted adapter position; preserve all existing cohorts. | FFI-R1/R2, Cranelift. |
| D real library build and link provenance | Required; current fixed test-host evidence is insufficient. | FFI-R1/R3, Cranelift. |
| E/F raw-to-safe non-laundering and existing null checks | Required throughout admitted and existing safe routes. | FFI-R4, Cranelift. |
| E/F full generic 63-cell precision, arbitrary flow and proof reconstruction | Follow-up OPEN; new precision is not a release dependency when the admitted interface is safe without it. | `26.1-GENERAL`, Cranelift; activate when a named supported operation needs it, with full original gates. |
| Full packed/nested/enum/by-value ABI coverage | Follow-up OPEN beyond the admitted flat scalar layouts and byte-pointer positions. | `26.1-ABI-EXT`, Cranelift; a named integration requires the layout, with canonical/target evidence. |
| General retention, ownership transfer, native callbacks, unwinding and cross-thread borrowing | Follow-up OPEN; existing narrow cohort evidence preserved. | `26.1-LIFECYCLE-EXT`, Cranelift; explicit lifecycle contract and positive/hostile tests before admission. |
| SQLite persistent CRUD and statement/result lifetimes | Follow-up OPEN and unsupported by this package. | `26.1-SQLITE`, Cranelift; satisfy the entry requirements below before implementation. |
| Application/third-party native escape-hatch governance and strong isolation | Separate product-policy dependency, still OPEN under VISION §§93–98. | `26.1-DEPLOY`, semantic/runtime and product owners; signed/capability/approval/isolation/revocation evidence before deployment admission. |
| Phase 26.2–26.6 resources, context, absence, stdlib audit and native bridge | Required by their existing exit gates; unchanged. | Existing owners and Phase 26 roadmap. |

SQLite's next-integration contract must handle open/prepare outputs and cleanup
on failure, finalize-before-close ordering, statement ownership, and copying
borrowed column data before invalidation. It must decode ROW/DONE separately
from failures; a blanket zero-success status rule is insufficient. Text/blob
binding must specify its copy/retention policy. Its destructor must not silently
lose a live handle after a failed close. These are concrete entry requirements,
not evidence of support from a version-number call.
[Open](https://www.sqlite.org/c3ref/open.html),
[step](https://www.sqlite.org/c3ref/step.html),
[close](https://www.sqlite.org/c3ref/close.html),
[column data](https://www.sqlite.org/c3ref/column_blob.html),
[binding ownership](https://www.sqlite.org/c3ref/bind_blob.html).

## 9. Claims and completion

After FFI-R1–R6 pass, permissible wording is:

> On the named GNU/Linux target, this Gust compiler release supports its pinned
> zlib adapter with checked ABI/policy metadata, explicit unsafe obligations,
> and audited safe byte-copy interfaces. Native code and its library remain
> trusted process code. Unsupported package plans reject explicitly.

The safe wrapper is required for the first-release completion claim. Until
its gate passes, call the low-level interface unsafe and experimental and keep
Phase 26.1 OPEN. Do not claim arbitrary C compatibility, native-code sandboxing, complete nullability
inference, formal verification, or safety other languages cannot match.

Phase 26.1 closes against these release gates and an explicit disposition of
its deferred obligations. All six Phase 26 rows remain OPEN at adoption of this
plan. Phase 26.6 still requires the final merged compiler's tagged, digest-pinned
native bridge, fixed-point evidence, supported hosts, and offline verification.
A successful Historical Full on an earlier main cannot close new source work.
The stronger no-host-C build claim retains its separate launch gate.

## 10. Evidence anchors

The baseline for this planning audit is merged main `df653a32`.
`compiler/typechecker.gst` owns extern policy classification;
`compiler/mir_primitive_layout.gst` owns primitive layout;
`compiler/mir_native_backend_full_program_source.gst` consumes validated native
plans. Current examples include `compiler/phase26_ffi_generic_direct_source.gst`,
`compiler/phase26_ffi_owned_return_source.gst`, and
`compiler/phase26_ffi_policy_vector_status_source.gst`. Their registry and
`scripts/phase26_ffi_*` guards qualify their named cohorts.

The unmerged generic E/F investigation has focused diagnostic evidence; it is
preserved and assessed against a concrete release need before more work is
scheduled. Its internal receipt/zero tests do not qualify a public adapter or
close the general map. No previously measured result is relabeled as a pass for
this new contract. Planning changes do not modify frozen predecessors,
release manifests, compiler semantics, library dependencies, or existing tests.
