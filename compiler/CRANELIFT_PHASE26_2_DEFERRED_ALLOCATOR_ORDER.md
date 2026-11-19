# Deferred allocator teardown proof

This increment validates the existing execution order. It does not emit or
reorder cleanup, change source ownership or brand meaning, add a MIR operation,
or select OD23 collection-slot observation semantics. Phase26 remains open.

Normal exit and break/continue unwind each exited frame's reverse explicit
defers before its automatic cleanup. Return evaluates and transfers its result,
runs all active explicit defers, and then runs transported automatic cleanup.
Returned-owner allocator dependencies stay independently live during that proof.

Effects retain their registration and their expression evaluation order. Only
registrations are reversed. A captured allocator receiver records the Scope
already declaring its root, rather than the inner scheduling Scope. A later
inner declaration cannot retarget it; assignment to the captured storage remains
late. Resource consumers use a declaration-specific storage key in the existing
value-fact map, so the existing snapshots and conservative joins retain the
storage's actual acquisition identity without looking up a shadow's spelling.
These reserved keys never become emitted operand/storage names or ownership
authority. Actual acquisition dependencies decide allocator overlap.

Exit simulation clones its owner facts. Return and loop-exit checks do not
discharge sibling facts. Actual normal exits publish only explicit-consumption
and allocator-lifecycle effects; automatic-cleanup emission still sees the
original live owners. Lifecycle maps are isolated across function, branch,
match, loop, guard and return checks, with possibly freed continuing paths
retained conservatively.

Three proof cohorts remain explicitly unsupported: a deferred consumer that
creates its owner from a late producer instead of captured existing storage,
an unresolved late Free receiver, and a loop backedge that destroys an allocator
already visible at loop entry without a next-iteration lifetime proof. These refuse
with `ResourceDeferredUnresolved`. This is a compiler proof limitation, not a
claim that every such program is unsafe. Registration-time producer arguments
are never substituted for their unknown later values. Promoting these cohorts
requires its own generic execution-time dependency proof and controls.

The first 32 cases preserve all eight original source payloads and expectations.
Four original unsafe orders remain compile-only negatives. Four original safe
orders and eleven additional positive controls may execute only after compilation
with the current-source compiler. Thirteen further negatives include aliases,
loop cleanup order and continuation, conditional field origins, return
transport, and the explicit unsupported cohorts. Four internal native output
groups cover observation snapshot isolation, restoration, agreement and
one-sided-field uncertainty; synthetic identities never address real allocators.

The complete 54-case matrix adds five positive controls and seventeen refusals
for late physical field receivers. Physical lifecycle observations retain the
existing allocator proof's presence and uncertainty bits through copies and
joins. They are distinct from immutable acquisition dependencies: a fresh
unbranded Arena field may be freed when no owner depends on it, but its observed
value cannot prove that a live or returned resource has an unrelated allocator.
Unknown factories remain unknown despite carrying nonempty diagnostic identities.

References to aggregate storage conservatively expose its child observations.
Exposure belongs to the declaring Scope and storage path, survives later field
writes, and joins by union. An indirect Arena or aggregate write whose target is
not represented records a sticky, scope-local uncertainty bit covering current
and future fields of aggregate values, checked references and raw pointers.
Copies retain that uncertainty and continuing-path joins preserve it. This is a local
proof limitation, not an alias relationship or new reference-immutability rule.
Existing primitive lifecycle identity observations remain available; deferred
Free additionally requires a known, unexposed late receiver. Direct Arena
references retain the existing binding constraints and lifecycle checks. The
unchanged clone-destination guard remains a required compatibility check.

The maintained primitive control `inner_writes_outer_holder` exposed a false
refusal when the new join combined both physical values even for `if true`.
Select physical observations only for an actual literal Bool node. Both arms
remain checked, and lifecycle maps and immutable resource dependencies keep
their existing conservative joins. Comparisons, names, calls, casts and integer
conditions do not select an arm. Exposure sets and indirect-write uncertainty
still union across both arms, even when a literal selects a physical value.
Fields absent on the selected arm remain explicit unknowns; they cannot regain
a declared origin through fallback.

All 54 existing case objects and the original primitive18 remain unchanged.
Additional internal parser/typechecker controls cover 18 literal/nonliteral,
one-sided, shadow, termination, exposure and indirect-write source cases. The
native metadata unit executes the checker on these sources in one process per
registered source/expectation pair; it never compiles or executes the represented
user programs. The original batched fixture exhausted fixed thread-local scratch
after printing three groups; that failure remains preserved without claiming
which source exhausted it. Runtime scratch, environment and budgets are unchanged.
Direct snapshot assertions retain the conservative taint and missing-field
properties. Default invocation retains the four output groups. All 18 source-mode
invocations require exit0, exactly one `1` line and empty stderr. Four separate
argument controls require exit2 and no output for bad arity, unknown mode,
unregistered source and mismatched expectation. Missing or failed rows fail
qualification; 19 successful checker-unit invocations and four argument refusals
are distinct from zero represented user-program executions.

Three initial fixture attempts stay verbatim under visibly unqualified
metadata. Direct Arena reassignment conflicts with the existing immutable
binding rule; a conditional break did not prove absence of a normal backedge;
and `VectorNew` did not exercise a directly represented caller lifecycle hook.
The active controls instead check the immutable-binding refusal and a distinct
late scalar assignment, make the break fixture's other path explicitly
terminating, and use the existing `ArenaAlloc` lifecycle hook after break.
No resource/cleanup output assertion is relaxed. The original constructor
route remains an unqualified separate compiler assessment, not safety evidence.
Negative controls use a refusing driver and must diagnose before its handshake;
they never compile or execute a suspect native program. The matrix records
exact inputs, tools, compile diagnostics, positive ELFs, outputs and statuses.

The existing allocator-identity recipe runs validation, inversions and the
native matrix; its owning workflow retains the matrix output. The additive
identity registry pins all four new files and both compiler calls. Only the
complete global invocation census projects these exact source-pinned calls;
the earlier lexical call and partial R3 normalization remain unchanged.
Missing, duplicated, substituted or reordered calls refuse; unrelated calls
remain visible. Existing predecessor adapters retain their original authority,
and foreign registry rows and product-limit files remain byte-identical.

Static mechanism/oracle inversions are only source checks. Acceptance also
requires actual current-source controls, rollback failure, full additive
enrollment and discovered validators, committed independent reviews, bootstrap,
strict104/180s, protected4GiB production/public R5 and native fixed point,
local/CI byte/provenance checks, exact-head eligible CI and a checked merge.
No earlier compiler or historical case pass qualifies this source.
