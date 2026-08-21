# Roadmap tail — Phases 20 to 25

`TASK.md` holds Phase 19. **Phases 20
through 25 were not in the repository.** `docs/VISION_RECONCILIATION.md` cited
`mir-to-cranelift.md` three times for "the arc across phases 18–25", and that file
is not here — it was a source document, never landed. This file closes that gap.

**What this document is.** The roadmap tail as recorded, so the C-retirement
priority declared in `docs/VISION_RECONCILIATION.md` §7 has a written plan behind
it rather than a citation to a missing file. **It is a record, not a schedule**,
and it does not create work for any lane. Phase content belongs to the owning
lane's roadmap when that lane opens the phase; this exists so the shape is not
lost in the meantime.

**Not authoritative over an open phase.** When a lane opens Phase 20, `TASK.md`
or its successor is authoritative and this file becomes background.

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

**Exit gate:** multiple release cycles, or an agreed stability window, complete
with Cranelift as default and no critical unresolved native regressions.

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

Remove backend selection for C and the generated-C publication paths. Archive or
delete the implementation, preserving historical fixtures only where useful.
Replace differential guards with frozen expected-behaviour tests. Remove C
compiler discovery from normal compilation, and C-specific error classes and
temporary files. Update package contents and documentation. Prove no active route
references the retired backend.

> The closure should say **Gust no longer emits C as a compiler backend.** It
> should *not* claim the repository contains no C.

**Exit gate:** normal builds, tests, packages and releases contain no generated-C
backend path.

## Phase 25 — Bootstrap and residual C retirement

**Purpose:** remove the remaining C dependency from building and distributing
Gust itself.

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

---

## The critical path

```
deferred feature migration
  → typed layout and memory
    → resource semantics
      → ABI and modules
        → explicit runtime
          → target/link hardening          (Phase 18, in progress)
            → whole-program qualification  (Phase 20)
              → self-hosting               (Phase 21)
                → default flip             (Phase 22)
                  → C backend deprecation  (Phase 23)
                    → generated-C removal  (Phase 24)
                      → bootstrap C removal (Phase 25)
```

Three claims about how early each outcome is reachable, recorded as stated:

| Outcome | Earliest realistic point |
| --- | --- |
| Gust stops emitting C for ordinary user programs | after Phases 13–21 |
| The MIR-to-C implementation can be deleted | after Phases 22–23 |
| Gust can claim it does not require C to build itself | after Phase 24 |

**Read these as ordering claims rather than dates.** None has a duration attached
and this document does not supply one; the value is that each outcome is pinned
to the phase that must precede it, so a premature claim is visibly premature.

---

## The two-lane interaction

`TASK_STDLIB.md` already records the Stdlib patch order and the CR-2 block: S1.0,
S1.1, S1.2, S1.3 and S1.7 are unblocked, S1.4 to S1.6 wait on CR-2, and **the
lane idles after S1.3** unless CR-2 is sequenced into the Cranelift roadmap. That
part is captured; this section records only how it meets the tail above.

- **S1.1 was worth doing standalone** regardless of lane scheduling, because
  `str == str` typechecked and emitted invalid C. It is done (#74).
- **At Phase 18 closure**, starting Stdlib on S1.0 → S1.3 → S1.7 while Phase 19
  and CR-2 run is a genuine two-lane period, and `justfile` contention is halved
  because CR-2 is one phase rather than fifteen patches.
- **After CR-2**, S1.4 to S1.6 unblock and the dual-lane model pays for itself.

`docs/AGENT_TOPOLOGY.md` §2 is the constraint this has to respect: two lanes may
work in parallel, but during a heavy CI wave only one should push.
