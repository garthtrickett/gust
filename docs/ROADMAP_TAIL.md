# Roadmap tail — Phases 20 to 25

`TASK.md` holds the active Cranelift phase. Phases 20 through 23 are completed
history. Phases 24, 24.5 and 25 are not active, and this document preserves the
remaining arc without competing with the live roadmap.

**What this document is.** The roadmap tail as recorded, so the C-retirement
priority declared in `docs/VISION_RECONCILIATION.md` §7 has a written plan behind
it rather than a citation to a missing file. **It is a record, not a schedule**,
and it does not create work for any lane. Phase content belongs to the owning
lane's roadmap when that lane opens the phase; this exists so the shape is not
lost in the meantime.

**Not authoritative over an open phase.** When a lane opens a phase, `TASK.md`
or its successor is authoritative and this file becomes background.

Open GitHub issues are routed in `docs/ISSUE_ROADMAP.md`. That register makes
every issue visible in a Markdown roadmap without injecting unrelated work into
an active phase. Issue rows must be promoted into the owning active roadmap
before implementation begins.

---

## The organising principle

> **Make the safe path convenient rather than making the type system more
> expressive.**

Worth recording separately because it is the rule that decides arguments this
document does not anticipate. It is the same rule OD-2 applied when it kept
§13's ban on user-written generic functions and moved query derivation into the
compiler, and the same one §55.1 applies when it puts three derived facts behind
one query site. Expressiveness is what a language adds when it cannot make the
right thing easy; every time that trade appears, this rule says which way to take
it.

---

## Phase 20 — Whole-program differential qualification

**Purpose:** move from feature fixtures to representative software.

Compile real multi-file Gust programs, and standard-library and runtime
components. Exercise nested control flow and mixed feature combinations. Compare
observable output and exit status, resource cleanup and filesystem effects, and
failure diagnostics. Run fuzzed or generated MIR through both backends. Stress
large functions and modules. Measure compile time and peak memory. Run long-lived
and concurrency-related programs. Establish a known-differences inventory, and
reject any unclassified backend divergence.

> A feature can work in isolation and still fail when composed with ten others.
> **This phase is where composition becomes the primary test unit.**

**Exit gate:** the declared qualification corpus is green through both backends,
with zero unexplained semantic divergences.

## Phase 21 — Cranelift self-hosting qualification

**Purpose:** prove the native backend can compile the compiler and its essential
runtime.

Progression: compiler support libraries, then selected compiler modules, then the
full compiler built with the existing compiler; use the Cranelift-built compiler
to compile test programs, then to rebuild the compiler again; compare stage
outputs or defined reproducibility properties.

Work: keep the compiler within supported language features, migrate features its
own compilation exposes, handle very large functions and registries, validate
compiler memory usage and bootstrap diagnostics, establish stage-one/stage-two
equivalence criteria, and decide whether binary identity is required or semantic
reproducibility suffices.

**Exit gate:** a Cranelift-built Gust compiler rebuilds itself and passes the
complete required guard suite, without generated C for the stages being qualified.

## Phase 22 — Default backend flip

**Purpose:** make Cranelift the default **without deleting MIR-to-C**. A small
routing change backed by the previous phases.

```
gust source.gst                      → Cranelift by default
gust --backend cranelift source.gst  → same native route
gust --backend c source.gst          → retained MIR-to-C oracle
```

Safeguards: no silent fallback from Cranelift to C; unsupported native features
fail clearly; explicit C stays byte-identical to the pre-flip default; rollback
requires explicit backend selection rather than hidden recovery; packaging
includes the native worker and runtime; help, docs, CI and install flows reflect
the new default; telemetry, if used, distinguishes native failures clearly.

**Exit gate:** one authoritative `Cranelift Historical Full` run on the exact
merged final post-flip implementation main completes its full registry-derived
job population successfully, with no unresolved material review findings.

## Post-Phase 22 assurance and issue-health checkpoint

Before Phase 23 freezes and de-emphasises the MIR-to-C oracle, run the
report-only assurance-foundation maintenance routed by
`docs/ISSUE_ROADMAP.md`: repair or retire stale evidence under issues #110 and
#240, then use those concrete failures as pilot inputs for
`docs/SEMANTIC_CHANGE_ASSURANCE.md` Phases A and B. This checkpoint may repair
control-plane evidence; it may not change language semantics, native lowering,
or the Phase 23 deprecation decision.

After that report-only work, resolve issue #105 in a separate bounded compiler
patch. Reject only a second declaration in the same lexical scope, preserve
parent-scope shadowing and disjoint-block reuse, and correct the overbroad
whole-function guidance in `GEMINI.md`. Do not let removal of generated C hide
the language diagnostic gap.

**Exit gate:** all three issue rows have current-main closure evidence, every
retained guard states an invariant that still exists, and Phase 23 does not
begin with a known broken or obsolete MIR/MIR-to-C evidence owner or an
unresolved same-scope declaration diagnostic.

## Phase 23 — MIR-to-C deprecation

**Purpose:** stop treating C as a normal supported backend while preserving it as
a temporary oracle.

Mark `--backend c` deprecated. Remove it from default CI matrices. Keep one
focused compatibility and differential lane. Freeze its accepted feature surface.
Prevent new features from being implemented only in MIR-to-C. Move remaining
differential testing toward an archived reference corpus. Document the removal
timeline. Audit downstream users that still require generated C.

**Exit gate:** no supported production or release workflow requires MIR-to-C.

## Phase 24 — Generated-C backend retirement

**Purpose:** remove MIR-to-C from the active compiler.

### Phase 24 opening preflight — make compiler meaning explicit

Before removal begins, complete one narrow preflight that prevents hidden test
configuration from being carried into the reduced compiler:

- replace typechecker behaviour selected by source filename fragments such as
  `test_tcs_` and `test_index_` with an explicit compiler-owned mode where a
  compatibility fixture genuinely needs one, or with one canonical rule where
  it does not;
- add characterization tests that freeze the accepted and rejected behaviour on
  both sides of the current filename-selected branches before replacing them;
- inventory concrete stdlib and runtime names recognized directly by compiler
  code, and classify each occurrence by semantic role and eventual intrinsic
  owner; and
- do not begin the broader typechecker, Cranelift-driver, registry or CI
  restructuring in this preflight.

The invariant is simple: changing a source file's name must not change what the
program means. The activated Phase 24 roadmap will own the exact patch boundary
and evidence; this record does not activate it.

**Preflight exit gate:** no accepted or rejected Gust meaning depends on a test
filename substring, current behaviour is characterized explicitly, the
string-recognized intrinsic inventory is complete, and no broader architecture
change has been folded into the correction.

Then remove backend selection for C and the generated-C publication paths.
Archive or delete the implementation, preserving historical fixtures only where
useful. Replace differential guards with frozen expected-behaviour tests. Remove
C compiler discovery from normal compilation, and C-specific error classes and
temporary files. Retire obsolete C routes, guards, registry rows, historical
commands and workflows rather than preserving dead machinery for its own sake.
Update package contents and documentation. Prove no active route references the
retired backend.

Deletion comes before consolidation deliberately. Phase 24 should expose the
smaller architecture that actually remains instead of spending time refactoring
code and evidence that this phase will remove.

> The closure should say **Gust no longer emits C as a compiler backend.** It
> should *not* claim the repository contains no C.

**Exit gate:** normal builds, tests, packages and releases contain no generated-C
backend path.

## Phase 24.5 — Compiler architecture consolidation

**Purpose:** make the reduced, native compiler easier to reason about before its
bootstrap chain depends on that structure.

This is a bounded, behaviour-preserving consolidation phase, not an open-ended
rewrite and not a feature phase. It begins only after Phase 24 has deleted the
retired backend surface, and Phase 25 does not begin until it closes.

Work in dependency order:

1. assign compiler-owned semantic or intrinsic IDs during resolution and make
   later compiler stages dispatch on those IDs rather than concrete stdlib or
   runtime spellings;
2. replace manual save-and-restore of function-checking state with one atomic
   `FunctionCheckFrame` boundary;
3. split `TypeEnvironment` into focused subcontexts with explicit ownership and
   narrow interfaces;
4. decompose expression and statement checking along semantic seams while
   preserving their characterized behaviour;
5. split the Cranelift command monolith into domain modules behind a typed
   command registry, keeping production lowering separate from historical
   evidence commands;
6. express historical registry contracts as declarative phase specifications
   consumed by generic validation and projection machinery; and
7. consolidate CI setup and generate thin workflow wrappers only after Phase 24
   has removed obsolete workflows, while preserving every still-required
   evidence identity and independent gate.

The phase may reorganize ownership and representation of existing compiler
facts. It may not introduce new Gust semantics, MIR meaning, ABI or layout,
runtime symbols, stdlib API, backend fallback, weaker evidence or repository-rule
exceptions. Each slice must remain bootstrap-safe and independently reviewable.

**Exit gate:** the surviving compiler has explicit intrinsic identity and
function-checking state boundaries, focused typechecking and command modules,
declarative registry validation, and non-duplicative CI orchestration; the full
required evidence remains green and the self-hosted compiler still converges.

## Phase 25 — Bootstrap and residual C retirement

**Purpose:** remove the remaining C dependency from building and distributing
Gust itself.

Phase 25 opens only after the reduced compiler has completed Phase 24.5 and has
a stable, fully evidenced structure. Native-bootstrap work must not become the
mechanism by which the consolidation is attempted.

Replace the legacy C bootstrap stage and establish a native bootstrap seed
policy. Decide how bootstrap binaries are produced and verified. Rebuild the
compiler entirely through the native backend. Remove generated stage-one compiler
C files, and the requirement for a host C compiler from normal bootstrap. Rewrite
or separately package remaining C runtime components. Remove C shims and pthread
wrappers where practical. Audit build scripts, Nix packages, CI images and
release archives. Preserve an independently auditable bootstrap chain.

> A deliberately retained C runtime library may still exist after generated-C
> retirement. **Full C removal is a separate policy decision** and should happen
> only when each residual component has a justified replacement.

**Exit gate:** a clean machine builds and tests Gust through the supported native
bootstrap path without invoking a C compiler, except for explicitly documented
optional foreign-runtime components.

## Post-Phase 25 — technical launch and outreach

After Phase 25 **and every preceding tail checkpoint** are closed on merged
`main`, execute `docs/CRANELIFT_LAUNCH.md`. No Phase 20–24 milestone triggers the
coordinated public outreach campaign independently. Each authoritative milestone
may still trigger the evidence-card and recipient review in
`docs/EVIDENCE_LED_OUTREACH.md`; any resulting contact is narrow, private where
appropriate, and sent only by the operator after rewriting and approval.

The launch is an evidence and relationship checkpoint, not another compiler
phase. It packages exact release identity, one-command reproduction,
no-fallback and semantic evidence, exact-main Historical Full, native bootstrap
transcripts, limitations, and the honest Rust/optional foreign-runtime boundary.
Quiet upstream review precedes the public technical launch; strategic outreach
follows as a small, tailored listening programme rather than a mass announcement
or premature pilot request.

**Launch gate:** the post-tail Level-3 claim in
`docs/CRANELIFT_LAUNCH.md` is supported in full, or the launch is delayed. No
“first” claim is used without a precisely defined category and credible upstream
confirmation.

The tail therefore has two different outreach cadences: continuous
evidence-specific relationship development under
`docs/EVIDENCE_LED_OUTREACH.md`, and one coordinated Level-3 public launch after
the entire tail under `docs/CRANELIFT_LAUNCH.md`.

---

## The critical path

```
deferred feature migration
  → typed layout and memory
    → resource semantics
      → ABI and modules
        → explicit runtime
          → target/link hardening          (Phase 18)
            → whole-program qualification  (Phase 20)
              → self-hosting               (Phase 21)
                → default flip             (Phase 22)
                  → assurance/issue health (post-Phase 22)
                    → C backend deprecation  (Phase 23)
                      → generated-C removal  (Phase 24)
                        → compiler consolidation (Phase 24.5)
                          → bootstrap C removal (Phase 25)
```

Three claims about how early each outcome is reachable, recorded as stated:

| Outcome | Earliest realistic point |
| --- | --- |
| Gust stops emitting C by default for ordinary user programs | after Phase 22 |
| The MIR-to-C implementation can be deleted | after Phase 24 |
| Native-bootstrap work can begin on the reduced, stable compiler | after Phase 24.5 |
| Gust can claim its normal supported bootstrap does not require a host C compiler | after Phase 25 |

**Read these as ordering claims rather than dates.** None has a duration attached
and this document does not supply one; the value is that each outcome is pinned
to the phase that must precede it, so a premature claim is visibly premature.

---

## The two-lane interaction

`TASK_STDLIB.md` is authoritative for Stdlib S1. S1.0 through S1.7 are complete.
CR-2 and the narrower CR-11 through CR-13 are resolved; S1.8 through S1.11 are
blocked on compiler-owned CR-15. This section records only how that live state
meets the backend tail above.

- **S1.1 was worth doing standalone** regardless of lane scheduling, because
  `str == str` typechecked and emitted invalid C. It is done (#74).
- **The completed CR-2 handoff** unblocked S1.4 through S1.6 without letting the
  Stdlib lane define compiler semantics.
- **CR-15 remains a compiler-owned post-tail obligation.** It must be promoted
  into an activated Cranelift roadmap before S1.8 resumes; this record does not
  schedule it.

`docs/AGENT_TOPOLOGY.md` §2 is the constraint this has to respect: two lanes may
work in parallel, but during a heavy CI wave only one should push.
