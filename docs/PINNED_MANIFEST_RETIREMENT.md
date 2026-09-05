# Retiring pinned manifests

**Status:** **Option B adopted by the operator, 2026-09-05.** Describes the end
state Patch 24.2p began. Closes the general form of issue #288.
Owner: Cranelift lane (the guards are its authority).

**Decision:** replace pinned manifests **by class of thing** (Option B below).
Option A — dropping them with nothing in their place — was considered and
**rejected**; it is recorded here with its reasoning so it is not re-proposed.

## At a glance

**Pin generated artifacts. Assert content on living ones.**

A digest over a file is a valid test only when the file is *supposed* to be
byte-stable. Applied to a document that must evolve, it does not detect tampering
— it forbids work.

## What the pins were for, stated fairly

A closed phase leaves evidence: registries, manifests, fixtures, roadmap records.
The legitimate requirement is **"this closed phase's evidence has not been quietly
rewritten."** That requirement is real and must survive whatever replaces it.

Whole-file digests were the chosen proxy, and the proxy is **"no file in this
manifest changed at all."** Those coincide only while the files are frozen. They
stopped coinciding the moment the manifest enrolled living documents.

## What went wrong, measured

- **578 of 2377 tracked files** carry a whole-file SHA-256 row.
- Enrolment is by **content pattern** — any file matching `MIR-to-C|mir_to_c|mir-to-c` —
  so **the blocked set cannot be derived from a path list.** Two readers with full
  source access predicted wrongly which files were safe to edit.
- It blocked **every shape** of Stdlib work: a `justfile` recipe, a workflow, a
  parity script, test fixtures, and a single documentation sentence.
- It is **self-referential**: a parity script must name both backend routes to
  test both, and naming them enrols it. *A patch cannot test both backends
  without becoming part of the surface that forbids new files.*
- **Five instances** were patched individually before the class was addressed.
- In one 24-hour period of intensive work it caught **zero** real regressions;
  every firing was a false positive on legitimate work.

**Read that last figure honestly.** One window is not a proof, and the
counterfactual — regressions never attempted because the pins existed — is
invisible. It is evidence that the cost is high and visible while the benefit is
low and unobserved. It is not evidence the benefit is zero.

For contrast, the one place digest pinning **works**: `gust_v4.c`. Its digest was
predicted 13 hours and three patches ahead of publication and landed byte-exact.
It is generated output, frozen by nature, and pinning it is correct.

## Option A — drop it with nothing in its place — **REJECTED**

Rejected 2026-09-05, and recorded with its reasoning so it is not re-proposed.
Three things break immediately:

1. **The Level-3 launch claim becomes unverifiable.** `docs/CRANELIFT_LAUNCH.md` §1
   requires *"no selected native route silently falls back to C."* Without the
   six-site relay manifest there is no evidence for it, and the launch policy is
   explicit: *"If any item is missing, delay outreach or lower the claim."*
2. **The bootstrap chain loses its audit.** The seed is the artifact that lets an
   outsider verify the compiler was not tampered with. Unpinned, that is gone.
3. **Closed-phase evidence becomes silently rewritable** — the original,
   legitimate requirement, discharged by nothing.

**The technique is wrong. The obligations are not.** Drop the mechanism, keep
every guarantee.

## Option B — replace by class of thing — **ADOPTED**

This is the decided path. Each pinned row is classified and given the mechanism
that matches what it is actually protecting.

| Class | Example | Mechanism |
|---|---|---|
| Generated artifact | `gust_v4.c` | **Whole-file digest.** Correct here; keep. |
| Living document | roadmaps, `justfile`, docs | **Markers** — content that cannot survive gutting what it names. |
| Growing inventory | invocations, text surfaces | **Owner-scoped append** — a lane's own additions admitted, others rejected. |
| Structural property | "every rule row has a status" | **Structural rule** — a pattern over rows, indifferent to any row changing. Carries a minimum-unit floor, because "every unit satisfies P" is vacuously true of zero units. |
| Behavioural guarantee | route selection | **Assert the property, not the census.** |

The last row matters most. *"There are exactly 319 invocations"* is a proxy.
**"Every invocation carries an explicit selection, never `implicit_default`"** is
the guarantee actually worth having — and it is **stronger**, because the census
never prevented adding a route-ambiguous invocation.

## Rules for the replacement

- **A relaxation that cannot fail is a deleted test.** For every pin removed,
  prove a real tamper still fails.
- **Markers must not survive gutting the content they name.** An `F6 —`
  identifier is the model; a bare topic word is the anti-pattern.
- **Never marker a line you intend to edit.** Marker the obligation it serves.
- **Enumerate the whole pinned set before changing any of it.**
- **Test every guard that pins a file,** not the one your patch edits.

## What the replacement costs

Not free, and the estimate should say so:

- **Markers must be chosen deliberately**, one file at a time, and a weak marker
  is worse than none because it looks like protection. One shipped as a bare
  topic word and would have passed while the content it named was gutted.
- **Structural rules needed a mechanism extension** beyond substring matching —
  a row-pattern check. That was built and landed in Patch 24.2r, so all five
  mechanisms in the table above now exist. Patch 24.3b is application of shipped
  mechanisms rather than application plus design.
- **Every retirement needs its inversion proved**, which is a build per pin class.

## Migration

1. **Patch 24.2p** — six named living surfaces plus a Stdlib-owned append scope.
   **Landed** in #334 on 2026-09-05. Unblocked Stdlib S1.9, which had been red on
   twenty Cranelift-owned workflows while being minimal, correct and green on its
   own guard.
2. **Patch 24.2q** — closed a half-freeze the first step left behind: `TASK.md`'s
   digest was projected but its `match_counts` were not, so the Cranelift roadmap
   was editable only while never changing how often it said "MIR-to-C".
   **Landed** in #335.
3. **Patch 24.2r** — the documentation lane's six documents, plus the structural
   rule mechanism. **Landed** in #337.
4. **Patch 24.3b** — sweep the remainder: classify each surviving manifest row by
   the table above, apply the matching mechanism, and prove the inversion for
   each. **Scheduled**, at Phase 24 closure.

**Why 24.3b sits at Phase 24 closure rather than now.** 474 of the 578 manifest
rows are classified `archive_candidate` and carry `"removal_phase": "24"`.
Migrating them now would be careful work on rows this phase is about to delete.
At closure the manifest has shrunk to roughly 104 survivors, and sweeping a
hundred classified rows is a different-sized job from sweeping six hundred.

**Why not later than Phase 24.** Phase 26 is the largest phase in the roadmap and
touches a great many files; carrying live pins into it means paying this tax
repeatedly on the most expensive phase.

**Order matters: do not run a broad migration while the pins are still active.**

## What you give up

You lose *"any change to this file is detected."* You keep *"any change that
removes the property is detected."*

Residual risk: a marker too weak to notice a gutting. Real, and the reason markers
are chosen deliberately and inverted. Content **added** rather than removed is not
caught — that is what review is for, and always was.
