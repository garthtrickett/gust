# Phase26.2 — lexical allocator proof identities

This prerequisite repairs proof metadata that conflated distinct nested arena
bindings with the same source name. It follows the merged direct-invalidation
check; it does not implement the held deferred-execution-order correction.

A lexical declaration has its own allocator proof identity. Aliases preserve the
actual identity; a nested declaration cannot resolve to an outer binding merely
because the names match. Function formal contexts are substituted from checked
actual arguments. An unresolved origin stays unresolved. Known annotations and
assignments cannot replace an allocator context with a different live binding.

Owned-resource dependencies are captured at acquisition or declaration, carried
through transfer, snapshots and joins, and retained across shadowed scopes.
Resource-field constraints are immutable projections, including parameter
projections through existing references and pointers. Whole-aggregate assignment
checks each field constraint. Returning an owned resource must satisfy the
function's existing formal contexts; a manually initialized local does not evade
that comparison by lacking an acquisition record. These are compiler proof
facts, not new source brands, ownership forms, runtime fields or ABI rules.
References and Index observations do not become resource owners. OD23 remains
OPEN and unselected.

## Qualification

`python3 scripts/phase26_2_allocator_identity_guard.py` binds the maintained
27-case source/support population, compiler and emitted artifacts. Thirteen
negative controls must fail at the shared frontend with their exact diagnostic
before a deliberately unavailable backend driver can compile them. Seven safe
native controls compile and execute with exactly `41\n` and exit zero. Seven
field/parameter controls prove frontend admission only by reaching the refusing
driver; they make no native execution claim. This preserves separate acceptance,
expected-refusal and different-refusal outcomes. Outputs are private to the
requested directory; an existing directory is never silently reused.

`python3 scripts/phase26_2_allocator_identity_registration.py validate` and
`inversions` enforce an additive successor to main `9df2eb10`. The exact archived
predecessor, old registry row and all foreign rows remain unchanged. Current
physical bytes are checked independently of the historical coordinates admitted
for repeated normalization. Operational state remains required and nonempty;
its prose is not a semantic byte pin. Mutations cover physical rollback, omitted
or duplicated owned census rows, foreign drift, added-file drift and attempted
OD23 admission. Normalization preserves foreign changes and is idempotent.

The existing allocator18 matrix, resource guards, full affected-pin enumeration,
actual first-release regression, native emitted-object fixed point, independent
reviews and exact-head authoritative CI remain publication gates. A narrow build
and the external draft matrix alone do not satisfy those gates. Full26.2,
deferred exit ordering and the remaining Phase26 rows stay OPEN.
