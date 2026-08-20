# Agent topology — how many agents, in which roles, and why that number

`AGENTS.md` says what a lane may do. It does not say **how many lanes there
should be, what runs them, or how they talk to each other.** This document
covers that gap. Where the two overlap, `AGENTS.md` wins; nothing here changes a
lane rule.

Written 2026-08-20 by the docs/vision lane, from the arrangement actually
running that morning rather than from a proposed one. Section 1 is
observation, sections 2 onward are argument.

**The short answers, for a reader who wants them before the reasoning.** Three
working lanes, because three disjoint ownership domains exist. One of them holds
semantic authority and that one does not shard. During a heavy CI wave, one lane
pushes and the others work without pushing. There is one monitor, it is a
schedule rather than an agent, it is stateless by construction, and it decides
nothing. **There is no manager and there should not be one** — §6. The thing
people reach for a manager to fix is a registrar, which is bookkeeping.

---

## 1. What is actually running

> **This is the section that rots by design.** It is an observation inside a
> governance document, and it was already wrong within ninety minutes of being
> written. Re-read it from the daemon before relying on it; the roles in §3 are
> the durable part.

Read from the Paseo daemon and the GitHub API at **2026-08-20 09:57 UTC**.

| Agent | Started | Lane | State |
| --- | --- | --- | --- |
| `1a71cf2` | 2026-08-16 | Cranelift — semantic authority | **running**, 4 days |
| `d7c8637` | 2026-08-20 01:01 | documentation | **running** |
| `ccf58f6` | 2026-08-19 | stdlib (see below) | **idle since 08:52Z** |
| `Check In` ×1 per 5 min | schedule `d90c43b7` | monitor | each dies after ~2 min |

**Two working agents, not three — and three lanes with work in flight.** That gap
is the finding, and it was invisible in the first revision of this table.

**The stdlib lane is represented by an open PR and no live agent.** `ccf58f6`
opened **#115** on `codex/stdlib-level3-citation` at 08:51:55Z and went idle at
08:52:39Z — under a minute later. Its title ("take stock of this doc and how it
will affect our .md files") does not name the lane it ended up working in, so
neither the agent list nor the PR list alone shows that the stdlib lane has an
unattended change in flight. **It took joining the two to see it**, which is
precisely the §6 argument for a registrar restated as an observation.

This is also the lifecycle defect §7 names, caught in the wild: an idle agent is
indistinguishable from a stalled one, and `ccf58f6` recorded no terminal state.
Whether #115 is finished, blocked, or forgotten is not answerable from anything
on disk.

**The Cranelift lane holds three PRs at once**, which is worth recording against
§2's Constraint B: #109 (Phase 18 *closure*, 30/30 green, `MERGEABLE/CLEAN`,
held), #107 (30/30 green but `CONFLICTING/DIRTY`, needs a rebase nobody has done),
and #100 (30 runs, 0 complete — the wave currently occupying the shared runners).
**One lane, three waves, and the two finished ones are blocked on something other
than their own CI.**

**The monitor is not an agent. It is a schedule that creates a new agent every
five minutes and archives it on finish** (`*/5 * * * *`, `target.type:
new-agent`, `archiveOnFinish: true`). Sixteen distinct monitor agents appear in a
single 24-hour listing, each alive about two minutes. §5 turns on that detail.

**There is no manager.** Nothing assigns work, orders merges, or resolves
cross-lane conflicts. §6 argues that is correct and names the thing that is
genuinely missing instead.

## 2. The safe parallel count is not a count of agents

The obvious way to ask "how many agents can we run" is to count agents. That
unit is wrong, and it is wrong in the direction that looks reasonable —
`docs/ONE_WAY_LEDGER.md` records the same class of mistake four times in this
repository's own measurements.

Two agents editing disjoint files do not collide however busy they are. Two
agents editing the same semantics collide on their first push. **What actually
contends is not agent count but three specific scarce things**, and each caps a
different quantity:

### Constraint A — the shared semantic zone is a lock, so exactly one lane may hold it

`docs/SHARED_SEMANTIC_ZONE.md` lists the concepts no lane may change alone and
assigns a default owner to each. Every row defaults to the Cranelift lane. That
is not a coincidence of staffing; it follows from the invariant, since a backend
must never independently reconstruct decided semantics.

The practical reading: **semantic authority is a single lock, held by one lane,
and it does not shard.** A second lane cannot be given "some of" arena brands or
"part of" the resource model without producing exactly the divergence D-2
records — two compilers disagreeing on one rule.

So: **at most one lane may be a semantic-authority lane.** Adding a second does
not add throughput; it adds a merge conflict with a compiler in it.

### Constraint B — CI capacity caps *pushing*, and it is denominated in runs

This is the constraint that actually bit on 2026-08-20. Seven PRs were open
simultaneously; a two-run PR sat fully queued for over an hour, and a
Level 3 job ran for nearly two.

A docs push costs **2** `pull_request` runs. A compiler push costs tens. Counting
"three agents" therefore says nothing useful about load — **the same three agents
can cost 6 runs or 200 depending on which paths they touch.**

**The honest form of this constraint is empirical, not arithmetic.** The runner
pool's concurrency is not published anywhere the lanes can read, so a formula
dividing by it would be a number dressed as a derivation. What can be measured is
behaviour, and the measurement is unambiguous: with seven PRs open, a two-run PR
did not start for over an hour, and re-pushing during that period displaced the
lane's own earlier wave rather than overtaking anyone else's.

The rule that falls out is therefore stated as a practice with its evidence
attached, not as a computation:

> **During a heavy-CI wave, one lane pushes and the others work without pushing.**
> Verified by the failure of the alternative on 2026-08-20.

Working and pushing are different activities, and conflating them is what produced
the starvation. A lane can produce thirty commits and hold them; that costs
nothing and loses nothing, provided they are committed rather than merely
intended. **It is the push that costs**, and a lane that treats "I have work
ready" as "I should push" converts its own progress into everyone's queue depth.

### Constraint C — a domain with no owner is not a lane, it is a collision

A new lane is only safe if it has a genuinely disjoint ownership domain. Three
exist today: compiler semantics, library surface, documentation. A fourth agent
has two options, and both are bad: duplicate an existing owner, or work inside
the zone and contend for Constraint A's lock.

**So the ceiling is set by how many disjoint domains exist, not by how many
agents are affordable.** The way to raise it is to carve a real domain — one
with its own files, its own CI paths, and no zone dependency — not to start
another agent.

### The resulting rule

```
working lanes      ≤ number of disjoint ownership domains        (today: 3)
semantic lanes     = 1                                            (a lock)
pushing lanes      ≤ CI concurrency ÷ heaviest runs-per-push      (today: ~1)
monitors           = 1 schedule, any number of ephemeral agents   (§5)
managers           = 0                                            (§6)
```

Three working lanes is therefore not a budget decision. It is the number of
disjoint domains that currently exist, and it would be the answer at any funding
level.

---

## 3. The roles

Ordered by how much of the zone each one needs, because that is what determines
how often it blocks.

**Semantic authority lane — one, currently Cranelift `1a71cf2`.**
Owns every row in the shared semantic zone: type identity, layout, brands, ABI,
resource and move semantics, MIR operation meaning, the runtime symbol surface,
target and link policy. It is the only lane that may change decided semantics,
and therefore the only one that can be blocked by nothing but itself. Because it
holds the lock, **its throughput sets the project's throughput**, and every rule
here that looks like it favours this lane is really protecting that.

**Library lane — one, Stdlib.**
Owns library surface built from already-public primitives. Blocks often and by
design: `docs/SHARED_SEMANTIC_ZONE.md`'s stop-and-report protocol exists because
this lane keeps discovering that a library problem is a semantics problem. Its
correct behaviour when blocked is to **file a CR and switch tasks**, not to
implement a narrower version inside the lane. `MutexGuard` is the worked example.

> **The documentation lane is not in `AGENTS.md`.** That file's Lanes table names
> two — Cranelift and Stdlib — and a docs/vision lane has been running for a full
> day and holds thirty-plus unpushed commits. This is a live inconsistency in the
> file that defines lane routing, and it has a practical edge: `AGENTS.md` says
> "if the requested work does not clearly belong to one lane, stop and ask", and
> with only two lanes listed, every documentation task is formally ambiguous.
>
> **Recorded here rather than fixed here.** Adding a row to that table changes how
> every agent routes work, which is exactly the class of change the zone protocol
> says one participant does not make alone. It needs the operator, or the lane
> that owns `AGENTS.md`. Flagged as the first thing to resolve after this document
> is read.

**Documentation lane — one, currently `d7c8637`.**
Owns `docs/` and nothing else. Structurally the cheapest lane: it never needs the
zone lock, and it costs 2 CI runs per push against the compiler lane's tens.
**It is the lane that can always make progress**, which makes it the right place
to park work when CI is saturated — and the wrong place to put anything urgent,
because it holds no authority over code.

**Monitor — one schedule, unlimited ephemeral agents.** §5.

**Manager — none.** §6.

---

## 4. Paseo's part

Paseo is the substrate: it creates the agents, holds their working directories,
sets their permission mode, and runs the schedule. Everything above is a *policy*
statement; Paseo is what makes it a running arrangement.

What matters for topology:

- **Agents are long-lived processes with a `cwd`,** not jobs. `1a71cf2` has been
  alive for four days. Lane identity is therefore continuous, and a lane's
  accumulated context is a real asset — which is exactly why §8 insists it must
  never be the *only* copy of anything.
- **Schedules can target `new-agent`,** which is how the monitor works and why it
  is stateless.
- **Permission mode is per agent.** All current agents run `bypassPermissions`.
  That makes every boundary in `AGENTS.md` an *honour* boundary enforced by the
  agent's own judgement, not by the tool layer. §9 is the consequence.
- **Agents can enumerate and message each other.** Concretely: `list_agents` for
  discovery (id, title, status, `cwd`, last activity), `send_agent_prompt` to
  deliver a message into another agent's conversation, `get_agent_status` and
  `get_agent_activity` to observe one without interrupting it, and
  `list_pending_permissions` to see whether an agent is blocked rather than
  merely quiet. Every lane has all of them, against every other lane. **Prefer the
  observing calls to the messaging one**: knowing whether a lane is blocked is
  almost always what is wanted, and unlike a prompt it costs the other lane
  nothing.

The last point is the one to be careful with, and §8 states the rule.

---

## 5. The monitor, and why statelessness is a feature

The Check In schedule fires every five minutes, creates a fresh agent, and
archives it when it finishes. Its prompt is to contact the other agents and keep
them moving.

**Consequences of a new agent each tick:**

- It has **no memory of the previous tick.** It cannot accumulate a belief, drift,
  or carry yesterday's conclusion into today. Every tick re-derives state from
  GitHub and from disk. **A stateless observer cannot be persistently wrong** —
  it can only be wrong once, and the next tick is a fresh reading.
- It therefore **knows only what is on disk or in the API.** Anything a lane
  worked out and left in its conversation is invisible to it. This is the
  strongest argument for the write-it-down discipline in §8, and it is a
  mechanical argument rather than a stylistic one.
- It is **cheap to lose.** A monitor that dies mid-tick costs one tick.

**What the monitor must not be given:** decision authority. It is the least
informed participant by construction — two minutes of context, no history — and
it fires on a timer rather than on an event. A design that lets the
least-informed participant decide is inverted.

**An observed failure, recorded because it will recur.** Twice on 2026-08-20 a
monitor tick instructed the docs lane to write into `compiler/` and `tests/`,
paths the operator had explicitly placed off limits. The instruction was
plausible: the work was real and the lane was otherwise idle. The lane refused
both times, and both refusals were upheld.

> **A pulse cannot widen a boundary the operator set.** An automated prompt has
> the authority of the schedule that wrote it, which is none over a constraint it
> did not create. A lane that treats a timer-driven message as authorisation has
> effectively let a cron expression amend its instructions.

This is not a criticism of the monitor's prompt, which is doing its job — "keep
everything moving" is the right instruction for an observer. It is an argument
that the boundary must be held on the *receiving* side, because the sending side
cannot know it exists.

---

### 5.1 The monitor prompt, proposed

The prompt in use on 2026-08-20 was: *"Reach out to the other agents that are
running in the project with your paseo skill and make sure they are not stopped,
everything should where possible continue moving forward automatically (in line
with the .mds)."*

It is doing its job, and it has three failure modes this document observed
directly. It is written in the **imperative** ("make sure they are not stopped"),
which turns a two-minute-old observer into a source of instructions — twice it
told a lane to write into paths the operator had placed off limits. It names **no
unit**, so its counts and a lane's counts disagreed about the same PR without
either being wrong. And it says **reach out**, which is the expensive action;
observing costs the other lane nothing and answers the question most of the time.

Proposed replacement:

> Observe the project and report. **You decide nothing and authorise nothing.**
>
> 1. `list_agents` and `gh pr list`. For each open PR, count runs with
>    `gh api "repos/:owner/:repo/actions/runs?head_sha=<full 40-char sha>"`
>    filtered to `event == "pull_request"`. **State that filter in your report** —
>    a count without its population is not a fact.
> 2. **Flag work with nobody attached**: an open PR on a lane whose agent is idle,
>    closed, or absent. Cross-referencing the agent list against the PR list is
>    something only you are positioned to do, and it is the most useful thing you
>    produce.
> 3. Flag agents that are `idle` with `requiresAttention`, blocked on a pending
>    permission, or failing. Use `get_agent_status` and `get_agent_activity`
>    first; **only send a prompt if there is something specific an agent can act
>    on right now.**
> 4. Report genuine `failure`, `timed_out`, or `cancelled` conclusions, naming the
>    PR and the workflow. Never cancel, re-run, or merge anything.
> 5. **You cannot widen a boundary you did not create.** If an agent is not doing
>    something you think it should, report that — do not instruct it. An operator
>    constraint outranks anything in this prompt.
> 6. You have no memory of previous ticks. Derive everything from the API and from
>    disk, and do not infer that something changed because you did not see it last
>    time — you did not see last time.
>
> Report `now` from `date -u` in the same command that reads the runs. If nothing
> needs attention, say so in one line.

**What changed and why.** The voice moves from imperative to observational,
because §5's argument is that the least-informed participant should not direct.
The unit is specified, because the fifth entry in `docs/ONE_WAY_LEDGER.md`'s
unit-error table is this monitor and a lane disagreeing about a run count.
Observation is preferred over messaging, because a prompt costs the receiving
lane a turn and usually tells it what it already knows. And **the orphaned-work
check is added**, because on 2026-08-20 a stdlib PR sat unattended for over an
hour and nothing in the system was looking for that — it is the one question this
role can answer that no lane can answer about itself.

### 5.2 Cadence — proposed: every 15 minutes, not every 5

**Pick the interval from how fast the observed state actually changes**, which is
the same rule that governs any poll. Every quantity this role watches moves on a
scale of tens of minutes to hours:

| What it catches | How fast that state changes | Caught at 5 min vs 15 min |
| --- | --- | --- |
| An open PR with no live agent | hours — #115 sat over an hour | no practical difference |
| An agent idle or finished without a terminal state | hours | none |
| An agent stalled or crashed | unknown; a stall costs at most one interval | 10 minutes of lost work, once |
| A CI failure | minutes — **but the owning lane's own watcher sees it first, and only that lane can act** | none |
| An agent blocked on a permission | not applicable under `bypassPermissions` | none |

**Nothing on that list is a five-minute quantity.** The cost of the mismatch is
not theoretical: each tick spawns a full agent, and a tick that sends a prompt
costs the receiving lane a turn of its own context. On 2026-08-20 the schedule
produced roughly 190 agents in sixteen hours, the large majority reporting that
nothing had changed.

**`*/15 * * * *`.** Three times cheaper, still bounds a stall at a quarter hour,
and every state above changes more slowly than that.

**A larger saving than the interval: the tick does not need a frontier model at
high effort.** Its work is API reads and one cross-reference. Lowering the model
or the thinking level cuts cost without reducing coverage at all, which the
interval cannot claim — halving the frequency does lose the ability to catch a
stall quickly, even if only marginally.

**One caveat, stated because it is the real reason the interval was five.** Part
of what the schedule did on 2026-08-20 was keep lanes from going idle, and that
is a different job from monitoring. If lanes need nudging to continue, the fix is
in their own instructions, not in the observer's frequency — **a schedule that
exists to prod is a schedule that will eventually prod someone across a
boundary**, which is exactly what happened twice. Fix the idling where it lives
and the monitor can be as slow as its slowest signal.

## 6. There is no manager, and there should not be one

The question that prompted this document was whether a manager agent should exist
alongside the check-in schedule. The answer is no, and the reasoning generalises.

Sort everything a manager would do:

**Mechanical decisions** — which lane owns a file, what order PRs merge in, when a
gate passes, who rebases onto whom. Every one of these is better as **a written
rule than as an agent**, for a reason that has nothing to do with capability: a
rule is readable by a cold-starting agent at 3am, and an agent's decision is
readable only by whoever was in the conversation. `AGENTS.md`'s merge policy and
rebase discipline are already this, and they work.

**Product and semantic decisions** — should `std.Spawn` be deleted, is transparent
suspension right, does the generic ban stand. These are the operator's, and
`docs/VISION.md` §0.15 exists precisely so they are recorded in one place with
one status each.

There is no third category. **Every candidate manager decision is either a rule
that belongs in a document, or a decision that belongs to the operator.** An agent
in between would be a place where decisions get made without a durable record —
the exact failure the OD register was created to stop.

**The claim is worth testing against its hardest case, which is resource
arbitration.** When CI is saturated and three lanes each have work ready, "who
pushes next" feels like a live judgement call requiring current knowledge — the
strongest candidate for a third category. It is not one. *Which* lane pushes is a
rule ("the lane whose work unblocks the most other lanes; ties to the
longest-held branch"), and *whether the wave has drained* is an observation any
lane can make from the API in one call. Neither needs an agent with authority;
one needs a sentence in `AGENTS.md`, and the other needs a lane willing to look
before pushing. If a genuine third category is ever found, it belongs in this
section as a counterexample rather than in an agent.

**What *is* missing, and it is not a manager.** Nothing maintains the shared
coordination state. `/home/gust/code/GUST_LANE_STATE.md` began as one lane's
notes and became every lane's, and it is now **2,751 lines, append-only,
unstructured**. Its cold-start handoff — the single most important thing in it —
is buried in the middle, because the file is chronological and the handoff was
written late.

> A shared state file whose most important content is the hardest to find has the
> same defect as an OD recorded only in the document that prompted it. It is not
> that the information is missing; it is that finding it requires already knowing
> where it is.

The role that would fix this is a **registrar, not a manager**: maintain per-lane
state files with a short index, prune what is settled, and answer "who owns this
right now". That is bookkeeping, it decides nothing, and it is small enough that
a document plus a discipline may well cover it without an agent at all. Naming it
here so that the next person who feels the absence of a manager can check whether
what they actually want is a registrar.

---

## 7. Lane lifecycle, and the four-day agent

Topology is not only how many lanes exist at once; it is how one starts, hands
over, and ends. Three rules, each from something observed rather than imagined.

**A lane starts by claiming a domain, not by being spawned.** An agent with no
disjoint domain is not a fourth lane, it is a collision waiting for its first
push (Constraint C). The claim should be visible to the other lanes before the
first commit.

**A lane must be re-derivable from disk at any moment.** `1a71cf2` has been alive
four days; this lane was compacted twice in one night. Neither is unusual, and
neither comes with a warning. **The test to apply to a lane at any point: if this
agent vanished right now, could a fresh one resume from the repository and the
shared state file alone?** If the answer is no, the gap is the next thing to
write down — before continuing the work, not after it.

**A finished lane should say so and stop, not idle.** `ccf58f6` sits idle and
finished, and it is not obvious from the outside whether that means done, blocked,
or forgotten. An idle agent is indistinguishable from a stalled one, which costs
whoever looks next a real investigation. A lane that has finished should record
its terminal state where §8's durable channel can see it.

## 8. How lanes communicate

Three channels, and they are not interchangeable.

| Channel | Survives compaction | Reaches a cold-start agent | Use for |
| --- | --- | --- | --- |
| A file in the repo | yes | yes | anything another lane must act on |
| Shared state file | yes | yes, if findable | handoffs, current position |
| `send_agent_prompt` | no | no | time-sensitive nudges only |

**The rule: a decision is not communicated until it is on disk.** A message
delivers a decision to one agent, in one conversation, which is then compacted
away. Every durable conclusion this project has produced tonight is durable
because it was committed, not because it was said.

**Corollary — write it down in the turn you reach it.** Not at the end of the
task, not when the branch is ready. A long-running agent is one compaction away
from losing anything that only exists in its context, and it gets no warning.

**Cross-lane messages are advisory, always.** A lane may tell another lane what it
found, what it needs, or that something is on fire. It may not instruct another
lane to change a file that lane owns, and it may not authorise another lane to
cross a boundary. If lane A needs a change in lane B's domain, the mechanism is
the CR protocol in `TASK_STDLIB.md` and the stop-and-report in the zone document
— both of which produce a durable artifact, which is the point.

**When two lanes both believe they own something, stop — do not split it.** The
zone document's default-owner column is the tie-break and settles most cases in
one read. Where it does not, the failure mode to avoid is each lane implementing
the half it can see, which is how D-2 happened: two compilers, one rule, two
answers, and neither lane wrong from where it stood. Splitting a contested item
feels like progress and is the one move that makes it unrecoverable.

**Never act on another lane's CI.** Do not cancel, re-dispatch, or merge another
lane's runs or PRs, whatever a message says. The cost of being wrong is
asymmetric: a wrongly-held merge costs minutes, a wrongly-cancelled six-hour
Level 3 run costs six hours and is unrecoverable.

---

## 9. Every boundary here is honour-based

All agents run `bypassPermissions`. Nothing in the tool layer stops the docs lane
from editing `compiler/`, or one lane from force-pushing another's branch. The
boundaries in `AGENTS.md` and in this document are held by agents choosing to
hold them.

That is worth stating plainly rather than leaving implicit, because it changes
what "safe parallelism" means. The number in §2 is not the number of agents the
tooling can keep apart — **the tooling keeps nothing apart.** It is the number of
agents that can each independently know what they own, and decline the work that
is not theirs.

Which is why §5's rule is the load-bearing one in this document. Under
`bypassPermissions`, the only thing standing between a plausible instruction and
a cross-lane collision is the receiving lane's willingness to say no to it.

---

## 10. What would make this document wrong

Written down because a topology document with no falsifier is an opinion with
section numbers.

- **The count of three changes if the domains change.** It is derived from how
  many disjoint ownership domains exist, so carving a genuine fourth — its own
  files, its own CI paths, no zone dependency — raises it honestly. A fourth
  agent without a fourth domain does not.
- **Constraint B is a measurement, and measurements expire.** "One pushing lane
  during a heavy wave" was derived from CI behaviour on 2026-08-20. More runner
  capacity, or cheaper workflows, moves it. Re-measure before citing it as a
  reason to hold a push.
- **The no-manager argument fails if a genuine third category appears** — a
  recurring decision that is neither a rule a document can carry nor the
  operator's to make. §6 tests the hardest candidate found so far and it does not
  qualify. A real one belongs in §6 as a counterexample.
- **The registrar may not need to be an agent at all.** §6 proposes bookkeeping,
  not autonomy, and bookkeeping is often a file plus a habit. If the habit holds
  for a week without one, it does not need one.

**The limitation to state plainly:** this was written by the documentation lane,
about lanes it does not own, from the outside. The Cranelift lane's four days of
accumulated judgement about what actually blocks it is not represented here, and
§3's description of that lane is inference from its ownership rows rather than
testimony from the lane itself. **Where this document and that lane's experience
disagree, that lane is more likely right**, and the disagreement should land in
this file rather than being settled quietly.

## 11. Summary

- **Three working lanes**, because three disjoint ownership domains exist. Not a
  budget; a structural count.
- **One semantic-authority lane**, because the zone is a lock that does not shard.
- **One pushing lane during a heavy CI wave**, because the real unit is runs, not
  agents. Other lanes work and hold commits.
- **One monitor schedule**, stateless by construction, with no decision authority
  and no power to widen a boundary.
- **No manager.** Mechanical decisions become documents; product decisions go to
  the operator; there is no third kind.
- **A registrar is the genuine gap** — bookkeeping over shared state, deciding
  nothing.
- **Disk is the only real channel.** Messages are advisory and do not survive.
- **A lane must be re-derivable from disk at any moment**, because compaction and
  four-day sessions arrive without warning.
- **Every boundary here is honour-based**, since all agents run
  `bypassPermissions`. The count in §2 is not what the tooling can keep apart —
  it is what the lanes can decline.
