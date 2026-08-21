# Proposed edits to `AGENTS.md` — **APPLIED 2026-08-21**

> **All three are applied and this file is now a record rather than a proposal.**
> Edit 1 (routing) and Edit 2 (continuation ladder) are in `AGENTS.md`; Edit 3
> (the bootstrap-seed row) is in `docs/SHARED_SEMANTIC_ZONE.md`. Edit 2 was
> applied with one addition not in the draft: **a bound on step 2**, because a
> continuation ladder can otherwise turn "blocked" into "generates plausible
> documentation indefinitely" — a failure this lane was a live example of rather
> than a hypothetical one. Kept for the reasoning; the applied text is
> authoritative.

# Proposed edits to `AGENTS.md` — as drafted

Two edits so lanes keep working autonomously and stop only at a genuine
decision-tree node. **Drafted rather than applied**: both change how every agent
routes work and behaves when blocked, which is the class of change one
participant does not make alone. Apply verbatim or amend.

Drafted 2026-08-20 by the documentation lane, against `73fc566d`.

---

## Edit 1 — the routing line in **Lanes**

**Why.** The current line makes *every* ambiguous task a stop, without
distinguishing "I do not know whose work this is" from "I do not have the
authority to decide this". The first is a routing question a lane can usually
answer; the second is the operator's. Conflating them produces stops that cost a
turn and return no decision. The anti-convenience rule is kept intact — it is
load-bearing and unchanged in substance.

**Replace:**

> If the requested work does not clearly belong to one lane, stop and ask. Do not
> pick a lane by convenience.

**With:**

> If the requested work does not clearly belong to one lane, do not pick a lane by
> convenience. Route it by ownership: the file it changes, and the authority it
> needs. `docs/SHARED_SEMANTIC_ZONE.md`'s default-owner column settles most cases
> in one read, and `docs/AGENT_TOPOLOGY.md` §3 describes what each lane owns.
>
> Stop and ask the operator only when the question is one of **authority**, not of
> difficulty. `docs/VISION.md` §0.15 is the test: an open decision is a
> decision-tree node, and everything else is lane work. Escalate when an OD's
> status would change, when an action is irreversible and outward-facing, when it
> spends money or promises a third party, or when it crosses a boundary the
> operator set.
>
> A new question of OD size is **registered, not escalated** — add the row, record
> a proposal marked as a proposal, and continue on other work. Where two designs
> both satisfy every stated constraint, pick one, record why, and note what would
> falsify the choice.
>
> **When two lanes both believe they own something, stop — and do not split it.**
> Each lane implementing the half it can see is how defect D-2 happened.

---

## Edit 2 — after the report format line in **Stop conditions**

**Why.** Every condition in that list is a genuine escalation and the list is
well scoped. What is missing is what happens *next*. "Stop and report" currently
reads as "stop", and on 2026-08-20 that produced two visible costs: the stdlib
lane opened #115 and went idle forty-four seconds later with no terminal state,
and `TASK_STDLIB.md` records that the lane "idles after S1.3" as a fact rather
than as a problem to route around. **A blocked task almost never blocks a lane.**

**After:**

> Use the seven-point report format from the Shared coordination zone section.

**Add:**

> **Stopping the task is not stopping the lane.** Having filed the report,
> continue down this ladder without waiting:
>
> 1. the next unblocked item in the active roadmap;
> 2. documentation the lane owns — including recording what the blocked attempt
>    established;
> 3. the standing unblocked work: `docs/UNBLOCKED_CONTAINMENT_WORK.md`, and the
>    specification rows in `docs/DEMO_TARGET_PROGRAM.md`;
> 4. if none applies, **record a terminal state** in the shared state file, naming
>    what was finished and what is being waited on.
>
> Only step 4 is stopping, and it is a written act. An agent that goes idle without
> it is indistinguishable from one that stalled, which costs whoever looks next a
> real investigation.
>
> **Refusing is not stopping either.** A lane that declines work outside its
> boundary has finished deciding, and descends the same ladder immediately.

---

## Edit 3 — a bootstrap-seed row for `docs/SHARED_SEMANTIC_ZONE.md`

**Why.** The zone table has twenty rows and **none of them is the bootstrap
seed** — the one artifact that is unambiguously singular, that cannot be merged,
and that two lanes provably both reach. `TASK_STDLIB.md` records "yes — dual
compiler and seed regeneration" on three separate CRs, so the Stdlib lane already
knows it touches the seed; nothing tells it what that obliges.

`AGENTS.md` documents the seed well — four regeneration triggers, its own commit
and PR, never hand-edited, never folded into a capability patch. **What is
missing is an owner.** Validation says run `make bootstrap` for
bootstrap-sensitive changes, which is whoever made the change; the seven-point
report asks *whether* a change affects bootstrap, which is a flag rather than an
assignment. Two lanes can therefore both be mid-bootstrap on different changes
with no rule broken.

**Add to the zone table:**

> | The bootstrap seed (`gust_v4.c`) and fixed-point convergence | `AGENTS.md` "Bootstrap seed"; `README.md` "The Non-Rust Bootstrap Chain" | Cranelift | `make bootstrap` asserts stage 2 and stage 3 byte-identical |

**And below the table:**

> **The seed is a serialized resource, not merely a shared one.** Any lane may
> *run* `make bootstrap` to validate its own change — that is ordinary validation
> and needs no coordination. **Regenerating and committing the seed is the
> Cranelift lane's**, in its own commit and PR per `AGENTS.md`, because there is
> no meaningful merge of two bootstrapped compilers: a second regeneration in
> flight does not conflict textually, it silently supersedes.
>
> A lane whose patch requires a regeneration stops and reports it as item 7 of the
> seven-point format, and **continues down the ladder** rather than regenerating
> itself.

**Why Cranelift rather than "whoever needs it".** It already owns every semantic
row the seed encodes, and a regeneration is the observable consequence of those
semantics changing. Assigning it elsewhere would put the artifact and its causes
in different lanes.

## What these do not change

- **The stop conditions themselves.** All nine are real escalations, all are
  cross-lane rather than operator-facing, and none is loosened.
- **The lane table.** Adding the documentation lane is a separate question,
  recorded at `docs/AGENT_TOPOLOGY.md` §3.
- **Any boundary.** Neither edit widens what a lane may touch. Edit 1 narrows
  *when* to ask, not *what* may be done without asking.
