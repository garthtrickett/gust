# Proposed edits to `AGENTS.md` — drafted, not applied

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

## What these do not change

- **The stop conditions themselves.** All nine are real escalations, all are
  cross-lane rather than operator-facing, and none is loosened.
- **The lane table.** Adding the documentation lane is a separate question,
  recorded at `docs/AGENT_TOPOLOGY.md` §3.
- **Any boundary.** Neither edit widens what a lane may touch. Edit 1 narrows
  *when* to ask, not *what* may be done without asking.
