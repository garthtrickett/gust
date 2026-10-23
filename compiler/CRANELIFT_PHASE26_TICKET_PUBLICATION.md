# Generic post-cleanup ticket publication

This capability continues the activated Phase26.1 FFI-R4 prerequisite after
production trust PR609 (`0c8e31c9`). It implements the already selected OD21
Index representation using existing MIR, enum layout, Index ABI and cleanup
meaning. It does not implement a Stdlib API or close Phase26.1.

The source-produced scalar probe reached normal ScopeCleanup where the scoped
proof required Return. Ordinary local tagged helper returns also stopped in
the earlier scalar-only parameter/argument planner. The local admission gate
now recognizes an enum with exactly one branded Index variant and one Int
variant. Local Index parameters are admitted only in functions returning that
representation. Unrelated Index parameters, standalone Index returns, extern
positions and direct large aggregate payloads retain their previous rejections.

The worker independently checks the actual enum layouts and brand, constructor
bodies, reaching values, region operations and cleanup edges. Each constructor
has one fresh local, exact tag/payload writes and return. No constructor call,
allocation, Arena mutation, callback, alias or recursive effect is admitted.
Names of user types, variants, fields, helpers and local bindings are not
semantic authority.

Every failure returns the Int variant without ticket allocation/publication.
Acquisition failure has no owner cleanup; subsequent errors have exactly one
matching cleanup evaluated after their pure result. Success completes copy-out,
executes exactly one normal region cleanup, allocates one ticket in the exact
output Arena, stores the completed output and constructs the Index variant.
An impossible count contradiction remains an error variant, never success.
The compiler fixture's scalar codes are proof inputs, not the final public API
error mapping owned by Stdlib.

Caller proof retains the closed, finite direct-call graph and created/live Arena
requirements. A tagged result may be bound to a fresh local and exhaustively
matched as the final caller step. The success arm copies its bound Index, uses
checked get_ref on the proved actual output Arena and computes a pure scalar
from checked length/byte reads. The error arm computes a pure scalar from its
borrowed Int payload. Neither arm permits additional effects, Arena mutation,
ticket escape or shadowing of existing caller bindings. Return values must be
evaluated before caller Arena cleanup. Other caller shapes remain explicit
unsupported capability; there is no backend fallback.

Canonical returned generic values retain the output formal's layout brand.
The scoped call independently proves its actual Arena substitution; subsequent
reads must match that formal layout brand and get_ref must match that same
actual Arena. Equality of unrelated identifier strings is not the substitution
proof. Wrong-Arena, forged-index, tag/payload, early-publication and cleanup
mutations are rejected independently.

The owning guard binds its checked-in canonical fixture to actual Gust source,
runs source-backed hostile canonical mutations, and compiles/executes the exact
signed production package offline. Its matrix covers renamed identities,
decompressed byte content/order, empty input/output, incompressible data, corrupt
input, short output, invalid level and negative/oversized capacity. Success
sentinels distinguish an empty success from an error returning zero. Repeated
linking must produce the same static executable bytes. Production identity,
signed artifacts, epochs and actual expiry remain unchanged from PR609.

The additive registration preserves the complete frozen production/R4/R3/R2
predecessor rows, source pins, workflow commands and deadlines. Its compressed
public predecessor snapshot is independently SHA-256 pinned and works in a
shallow checkout. New source/projection pins and missing/conditional owning-step
inversions are enforced. Operational lane-state retirement remains unchanged.

No new MIR operation, lifetime/brand relationship, resource/drop/move meaning,
ABI/layout, runtime symbol, pointer conversion, resource admission or allocator
budget is added. Native producer changes use already supported source syntax;
native compiler fixed-point and exact-head owning CI remain required gates.
The separate merged Stdlib wrapper/audit, remaining R5/R6 qualification and
Historical Full on exact final merged main still gate Phase26.1 closure.
