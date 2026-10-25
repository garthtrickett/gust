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
45-case `explicit-arena-anchors-v2` source/support population, compiler and
emitted artifacts. The original43 records are pinned unchanged. Twenty-two
negative controls must fail at the shared frontend with their exact diagnostic
before a deliberately unavailable backend driver can compile them. Eleven safe
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
A separate internal proof-fact native control requires twelve exact successful
checks (twelve `1` lines, exit zero) and covers that distinction against a known
root and an absent-field fallback, without asserting that mixed metadata is a
public source construction.

Allocator proof lookups use the complete explicit or registered type brand.
They do not erase a prefix before `__`: `left__brand` and `right__brand`
remain distinct lexical lookup keys. The additional internal controls check
both distinct dependencies and the unchanged full formal-brand key. Two added
explicit-Arena source controls retain acquisition through a protected alias,
destruction, native output `41`, allocator release and shadow-assignment
rejection when the caller brand name contains `__`; all original43 source
controls remain unchanged. The frozen
Phase20 legacy-cleaner inventory and canonical brand semantics are unchanged.

The first 45-case cohort failed its implicit qualified-brand positive before
worker admission: the legacy general call normalizer derives `brand` from
`left__brand`. The preserved904 frontend reproduces the same mismatch. Both
original implicit source/support payloads and expectations remain in
`cases.json` as **UNQUALIFIED** prerequisite evidence, excluded from successor
passing counts. The original matrix FAIL is unchanged. Generic implicit-call
normalization is separately routed as `P26-QUALIFIED-CALL-BRAND-NORMALIZATION`;
this prerequisite does not implement or qualify it.

The successor uses the existing explicit `&Arena` formal to anchor the source
call. Baseline frontend admission and current native execution establish that
route's admissibility. The internal exact-name assertions supply independent
regression coverage: a private copy restoring exactly the eight retired proof
wrappers compiles, then exits16 after ten successful outputs; the current copy
exits0 with all twelve. Thus native admission alone is not claimed to detect
suffix conflation. Neither the original implicit inference form nor a new brand
relationship is accepted by that comparison.

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

The scalar-projection and ordinary-collection native positives perform their
actual operations in meaningful branded helpers and use the results from main.
Every operation and exact output (`6` and `1`) is retained. Both forms execute
on the merged predecessor and corrected compiler; the faulty draft still rejects
the scalar assignment. The collection positive alone is an admissibility
control, while the compiler self-source and internal checks cover the actual
annotation/proof regressions. The original main-only constructions fail native
routing identically before and after this patch and remain preserved as failed
evidence. They are not qualified by the helper controls, and native routing is
unchanged. An additional aggregate-parameter proposal also remains outside the
qualified native cohort.

Dependency collection also preserves explicitly unknown lexical proofs. The
internal controls distinguish an explicit unknown, a known lexical origin, the
existing absent-formal convention, and a shadowing declaration with no fact.

The operator-approved 6 GiB execution override applies only to the clean N-1
bootstrap. Its independent launcher requires effective 6 GiB, zero swap and a
CPU quota at most two CPUs, strips Make overrides, and permits only canonical
`make gust` argument vectors. CI enters a transient scope and restores the
original non-root identity before repository code. Existing scoped execution
uses the same verified limits. Qualification commands are refused by this
launcher and continue under the unchanged 4 GiB release launcher. The three
owning workflows keep their qualification steps at 4 GiB; profile-mixup and
missing-trigger controls cover their actual physical bytes. Frozen release
workflow assertions still run against the checked predecessor view.
