# Track A — the demo deliverable

**Status: INACTIVE.** This roadmap exists, owns its rows, and is not staffed.
See *Roadmap Activation* below for the measured condition that starts it.

**Lane:** unassigned until activation. Branch prefix `codex/tracka-`.

Workflow, Monitoring, Merge, Phase Completion, Runner, and Git Authorization
policies are defined once in `AGENTS.md` and apply to every lane. Ownership
boundaries and the shared coordination zone are defined in `AGENTS.md` and
`docs/SHARED_SEMANTIC_ZONE.md`. This document defines only what is specific to
Track A.

The Cranelift lane is described by `TASK.md` and the Stdlib lane by
`TASK_STDLIB.md`. Track A does not own, schedule, or validate any work in either
roadmap, and neither owns any work here.

## Why this document exists

`TASK_STDLIB.md` **CR-7** recorded that `docs/VISION.md` §0.7 names four Track A
items — `uses` clauses, effect checking across the call graph, typed Postgres
query derivation, and tenant scope tracked through query construction — as the
stated deliverable and the thing being sold (§0.4), **and that no roadmap owned
any of them.** `TASK.md` owns targets, objects and linkers; `TASK_STDLIB.md` owns
the safe stdlib surface. Both sit below the demo line, so the demo had no lane,
no patch sequence and no exit gate.

CR-7's own text asked for exactly this: *"none — this is a scheduling gap, not a
semantic one. What is needed is a Track A roadmap, in the form the other lanes
already use."*

**Operator ruling, 2026-09-06:** create the roadmap as a real named owner; do not
staff it yet. *"We can't really do the demo until stdlib and Cranelift are
further along."*

**This roadmap being the owner is what discharges CR-7.** A person is not a
phase, and the closure gate asks for *"every coordination request resolved,
scheduled, or deferred with a named owning phase."*

## Roadmap Activation

**Track A activates when demo prerequisite rows 2, 5 and 9 have named owners and
row 10 is scheduled.**

**Owned, not done.** The trigger is deliberately about ownership rather than
completion, because that is the point at which a patch sequence can be written
against something real instead of against four `ABSENT` rows. Waiting for the
prerequisites to be *finished* would make this roadmap a deferral wearing a
roadmap's clothes.

**Checked at each phase closure, alongside the `docs/ONE_WAY_LEDGER.md`
compliance figure**, so the question is asked on a schedule rather than when
someone happens to remember it.

On activation: assign a lane, write the patch sequence, and write the exit gate.
None of those exist yet, deliberately — a patch sequence written against unowned
prerequisites would be fiction.

## The prerequisite table

Authoritative copy lives in `docs/DEMO_TARGET_PROGRAM.md`. Reproduced here as the
activation condition's subject; **re-derive against that file rather than trusting
this snapshot**, which was measured at `bbba5cd9` on 2026-09-06.

| Row | Requirement | Status | Owner |
| --- | --- | --- | --- |
| 1 | Brand identity carried by type, not identifier spelling | HOLDS | closed — Phase 19 D-1 |
| 2 | `Result[T, E]` builtin with `?` propagation | ABSENT | **unowned — blocks activation** |
| 3 | An `Option` constructor — `Some(42)` | PARTIAL | Cranelift, CR-14 / PR #128 |
| 4 | Implicit context in application code (`using ctx`) | ABSENT | **excluded** — not a demo prerequisite per the 2026-08-20 placement directive |
| 5 | `uses` clauses parsed and checked across the call graph | ABSENT | **unowned — blocks activation** |
| 6 | Entity declarations marking an entity workspace-scoped | ABSENT | Cranelift, Phase 21 Track A 21.2+ |
| 7 | Compiler-owned query derivation (`from`, `.where`, `.all`) | ABSENT | Cranelift, Phase 21 Track A 21.3+ |
| 8 | Tenant scope tracked through query construction | ABSENT in this target | Cranelift, OD-8 resolved |
| 9 | A Postgres capability to execute the query against | ABSENT | **unowned — blocks activation** |
| 10 | Panic scoped to the request, not the process | VIOLATED | `TASK_STDLIB.md` CR-3, issue #91 — **unscheduled, blocks activation** |

**Four rows block activation: 2, 5 and 9 are unowned; 10 is owned but
unscheduled.** Rows 6, 7 and 8 already have an owner and do not block.

**Row 9 is why the ruling is right rather than merely convenient.** It shares
CR-5's blocker with `MutexGuard` — the S1.8–S1.11 series in `TASK_STDLIB.md`. The
demo is genuinely downstream of the stdlib work, not deprioritised behind it.

## What Track A will own on activation

The four §0.7 items, and nothing else:

1. `uses` clauses parsed and checked across the call graph
2. Effect checking across the call graph
3. Typed Postgres query derivation
4. Tenant scope tracked through query construction

Prerequisites remain owned by whichever roadmap owns them today. Track A does not
absorb them by existing.

## Provenance

`TASK_STDLIB.md` CR-7; `docs/VISION.md` §0.4, §0.7, §0.14;
`docs/DEMO_TARGET_PROGRAM.md`. Operator ruling 2026-09-06, activation trigger
confirmed the same day.
