# Phase26.2 — lexical allocator proof identities

This prerequisite repairs proof metadata that conflated distinct nested arena
bindings with the same source name. It follows the merged direct-invalidation
check; it does not implement the held deferred-execution-order correction.

A lexical declaration has its own allocator proof identity. Aliases preserve the
actual identity; a nested declaration cannot resolve to an outer binding merely
because the names match. Function formal contexts are substituted from checked
actual arguments. An unresolved origin stays unresolved. Known annotations and metadata-resource assignments cannot replace a required
allocator context with a different live binding. Ordinary observed aliases may
mutate; their origin facts conservatively become uncertain and never refine back
to known. Acquisitions made before the mutation retain their original facts.

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
43-case source/support population, compiler and emitted artifacts. Twenty-one
negative controls must fail at the shared frontend with their exact diagnostic
before a deliberately unavailable backend driver can compile them. Ten safe
native controls compile and execute with each recorded exact stdout and exit
zero. Twelve field/parameter/branch controls prove frontend admission only by reaching the refusing
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
Exact archived ancestor subsets are fixed points of the successor, so composing
it with an older normalizer cannot restore newer coordinates. Historical images
still require current physical pins. Mixed, omitted, duplicated and substituted
ancestor rows reject; foreign rows survive for their own validator to check.

The existing allocator18 matrix, resource guards, full affected-pin enumeration,
actual first-release regression, native emitted-object fixed point, independent
reviews and exact-head authoritative CI remain publication gates. A narrow build
and the external draft matrix alone do not satisfy those gates. Full26.2,
deferred exit ordering and the remaining Phase26 rows stay OPEN.

The successor controls retain annotation and copied-resource uncertainty,
whole-aggregate field-origin comparisons, and one-sided branch/loop obligations
when an unrelated allocator is invalidated. Discharged branch/loop controls must
still admit. The source language's existing brand restrictions do not supply an
equal-root-set/swapped-field-origin construction; no new brand relationship is
invented to manufacture one. Unknown-root copy controls do not by themselves
isolate an explicitly unknown field from fallback to an equally unknown root.
A separate internal proof-fact native control requires six exact successful
checks (six `1` lines, exit zero) and covers that distinction against a known
root and an absent-field fallback, without asserting that mixed metadata is a
public source construction.

The original unmerged assignment-only `ProtectedValue` alias rejection exceeded
26.2A's metadata opt-in: unannotated compiler values must bypass resource escape
enforcement. Its original source and result stay preserved. The maintained
negative now acquires a resource through the mutated alias and requires allocator
invalidation to fail; the original assignment-only form is an admission control.
A self-assignment must not recover a known origin, and an earlier acquisition
must retain its original dependencies. Scalar projections cannot inherit the
allocator of their containing AST/collection storage. Unknown synthetic IDs
remain uncertain bookkeeping and are never compared as known unequal origins.
Arena bindings and captured metadata-resource constraints remain strict.

Proof presence is independent of its identity string. An explicitly unknown
empty-identity field cannot fall back to a known root, and declaration
initialization cannot replace that observed uncertainty with its type's brand.
The internal control tests both paths and the absent-fact positive counterparts.

Ordinary compiler collection/value annotations preserve the initializer's
observed context without granting new resource authority. A mismatch or unknown
origin remains tainted for later acquisitions. Existing type/brand compatibility
is unchanged; Arena, metadata-resource and resolved reference contexts retain
their strict lexical constraints. The maintained collection admission control
and annotation-to-resource refusal supplement self-source checking of all
imported compiler functions.
