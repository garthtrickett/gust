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
`inversions` enforce an additive successor to renewed main `39e37696`. The three
original `9df2eb10` archives remain unchanged; separate v2 archives bind the
actual renewed predecessor. The delegation order is identity, renewal, then
frozen predecessors. The renewal registry row and all foreign rows remain unchanged. Current
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
A separate internal proof-fact native control retains twelve original successful
checks and adds four presentation checks (sixteen `1` lines, exit zero). It
covers that distinction against a known
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
launcher and continue under the unchanged 4 GiB release launcher. The two
allocator workflows use the bootstrap route. The release workflow retains its
exact authenticated cold 4 GiB product build; a preceding bootstrap would warm
that build and invalidate its evidence. All three qualification steps stay at
4 GiB. Profile-mixup, missing-trigger, skipped cold-build and warmup refusals
cover the actual workflow bytes. Frozen release assertions still run against
their checked predecessor view.

## Phase20 lifecycle evidence successor

The two old declaration/assignment call anchors are retired additively.
Current physical source and validator pins remain mandatory. A pure structural
checker verifies pre-insertion capture, immutable identity/presence/uncertainty,
nearest-declaration and exact-path lookup, strict assignment validation and
conservative ordinary-alias mutation. The existing Phase20 authority, fixtures,
parameter transport, inert observer and workflow checks remain executable.
Twenty-two mechanism inversions, seven legacy checks and five decoded archive
checks require expected-assertion rejection. An exact new predecessor archive
retains the old validator; existing frozen archives are unchanged. These source
checks supplement native controls and do not themselves prove runtime safety.

## Primitive Arena field observations

Restore mutable primitive lifecycle observations in a separate per-declaration
Scope map. Immutable allocator proofs and resource dependency/invalidation
functions do not read that map. Field assignments retain the RHS primitive
identity, owned Struct value copies snapshot recorded descendants, and ancestor
replacement explicitly invalidates unmatched descendants. Exact empty observations
reject lifecycle operations rather than falling through to stale/root facts.
Arena value aliases retain primitive identity; this adds no reference target,
callee effect, loop, resource ownership, brand, ABI or OD23 inference.

The owning matrix additionally compiles a native parser/typechecker unit and
requires 18 controls: field Free/use, overwrite, self/value copy, copy snapshots,
known/unknown replacement, Arena value aliases, lexical shadows, nested fields
and prefix-neighbor isolation. The unit executes; its source snippets never
lower or execute. All 45 existing cases, 12 original internal proof checks and the two
visibly unqualified implicit-call payloads remain required unchanged. Preparation
and source enrollment are not native qualification; fresh build, owning guards,
matrices, pins, fixed point, R5 and authoritative CI remain mandatory.

The alias-reassignment snippet is a compound rejection: the unchanged primitive
immutable-binding rule rejects assignment before error recovery also observes
the required use-after-free. Require both the exact legacy immutable error and
one use-after-free diagnostic, with no missing, duplicate or unrelated output.
The identical predecessor snippet emits both diagnostics too. This case proves
rejection only; supported transport is covered by alias declaration, field
overwrite and value-copy cases. Earlier private substring-level evidence is
retained separately and is not the maintained strict matrix result.

## Closed CI dependency revisions

The current allocator publication reached the pinned-toolchain installation
step before compilation. A newer runner's installed `libc6-i386` requires its
matching newer libc; the unchanged `--no-remove` transaction correctly refused
to remove it and its existing lib32/Clang dependents. A read-only local solver
reproduced that refusal. This is an environment failure, not a native case pass
or an allocator rejection.

The correction keeps all sixteen canonical dependency pins unchanged. The
separate `ci-toolchain-compatibility.json` locks the matching amd64 revisions of
`libc6-i386` and `libc6-dbg`, authenticated against the original snapshot's signed
Ubuntu package index. Only identities already installed on that runner are
selected. The complete transaction must simulate without removals, new package
identities or unselected revisions, then retain `--no-remove` during the real
ephemeral-runner installation. Exact pre/post installed populations and versions
are checked; shared-host packages are never installed or changed. Both owning
workflows retain the transaction records independently of their native artifacts.

Controls use a real, non-installed Debian archive to exercise digest, metadata
and architecture refusals, plus missing/foreign package and solver/population
refusals. The old installer is retained in a new exact-main predecessor archive;
all earlier frozen archives, product limits, runtime resolution and signature
authority remain unchanged. Prepared metadata and a successful solver plan are
not installation or qualification. Current-source review, enrollment, native
qualification, artifact parity and authoritative CI remain mandatory.

## Frozen lifecycle diagnostic parity

The owning PR Fast Arena.Free parity guard rejects the current candidate when
an internal acquisition identity is printed instead of the frozen source name.
The rejection itself and its `ArenaUseAfterFree` code agree; exact diagnostic
bytes still must agree. Keep that guard and its frozen oracle unchanged.

Lifecycle state therefore carries a presentation-only name captured from its
first typed Arena binding. Aliases retain that name. Distinct shadow identities
may have the same source-facing name while keeping separate lookup keys,
dependency sets and lifecycle states. An unnamed state retains the raw-identity
fallback. Display metadata never participates in proof or invalidation.

The original twelve internal assertions remain byte-for-byte before four added
checks for the source-facing name, alias stability, independent same-named
shadows and unnamed/absent fallback. The report identifies the original twelve
and four presentation checks separately; all sixteen must execute successfully.
Source preparation does not clear the failed CI guard: fresh compiler, exact
frozen parity, matrices, pins, product/R5/fixed point, reviews and CI are required.
