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
an unresolved late Free receiver, and a continue that destroys an allocator
already visible at loop entry without a next-iteration lifetime proof. These refuse
with `ResourceDeferredUnresolved`. This is a compiler proof limitation, not a
claim that every such program is unsafe. Registration-time producer arguments
are never substituted for their unknown later values. Promoting these cohorts
requires its own generic execution-time dependency proof and controls.

The 29-case matrix preserves all eight original source payloads and expectations.
Four original unsafe orders remain compile-only negatives. Four original safe
orders and ten additional positive controls may execute only after compilation
with the current-source compiler. Eleven further negatives include aliases,
loop cleanup order and continuation, conditional field origins, return
transport, and the explicit unsupported cohorts. Four internal native metadata
assertions prove observation snapshot isolation, restoration, agreement and
one-sided-field uncertainty; synthetic identities never address real allocators.
Negative controls use a refusing driver and must diagnose before its handshake;
they never compile or execute a suspect native program. The matrix records
exact inputs, tools, compile diagnostics, positive ELFs, outputs and statuses.

Static mechanism/oracle inversions are only source checks. Acceptance also
requires actual current-source controls, rollback failure, full additive
enrollment and discovered validators, committed independent reviews, bootstrap,
strict104/180s, protected4GiB production/public R5 and native fixed point,
local/CI byte/provenance checks, exact-head eligible CI and a checked merge.
No earlier compiler or historical case pass qualifies this source.
