# Event-driven monitoring

**Status:** proposed. Compatible with `AGENTS.md` § Monitoring policy; see *Precedence*.

## For a lane, in four lines

1. Background every long command, then **end your turn**.
2. If you end a turn with work in flight, **say so**: *"Waiting on `<task-id>`; not stalled. Pulse me when it lands."*
3. **Do not run a cron pulse on yourself.** The monitor wakes you when something happens.
4. **A pulse is a prompt to check, never evidence.** Re-derive before any irreversible action.

Everything below is why.

## The rule

**Poll in exactly one place. Everything else wakes because something happened.**

A lane does work and ends its turn. A single monitor holds one cron heartbeat,
polls the state that emits no events, and converts *"this changed"* into a direct
message. The lane experiences only real events; the polling is paid once,
centrally, by the cheapest participant.

## Why, in the terms the existing policy uses

`AGENTS.md` requires a five-minute pulse because **"silence during a long wait is
not acceptable even when nothing has changed"**, and **"do not silently poll."**
Both are right and this document keeps them.

It changes only *who* polls. A lane woken solely by real change is never silent
about a change. A monitor that reports every tick — including *"nothing changed"*
— is never silently polling. Five-minute self-pulsing achieves the same end by
making every lane poll itself, which costs N times more and yields N
independently-derived numbers that can disagree. Not hypothetical: a monitor and
a lane once read 3 vs 2 runs on the same PR, and a monitor reported 100 runs
where the true population was 137.

## The three primitives, and what each is worth

| Primitive | Kind | Reliable? |
|---|---|---|
| `create_heartbeat` (cron) | time-driven | Yes. The only dependable wake. |
| Background task completion | event-driven | **No.** Wakes an agent *still in a turn*; an idle agent is not resumed. |
| `send_agent_prompt` + `notifyOnFinish` | event-driven | Yes. Every lane report has arrived this way. |

There is no webhook, no interrupt, no way for CI to wake an agent, and no way to
call an MCP tool from a shell script. Anything absent from this table does not exist.

**Row two is the trap.** A lane that backgrounds a build, correctly ends its turn,
and waits for the completion notification waits forever. This stranded finished
work three times, once for 38 minutes.

## Lane rules

1. **Do not self-pulse on a cron.** It duplicates the monitor, costs a full turn
   per tick, and produces a second set of counts that can diverge.
2. **Never hold a turn open waiting.** That is what hangs a lane — four
   occurrences, every one a foreground `just guard-*`.
3. **Background every long command,** then end the turn.
4. **Say when you are waiting.** From outside, *"waiting on a build"* and
   *"stalled"* are indistinguishable. One sentence removes the ambiguity, and it
   is the highest-value line here: both lanes adopted it after three
   stranded-work incidents, and that class of incident stopped.
5. **A pulse is a prompt, not evidence.** Monitors are wrong regularly — four
   times in 24 hours, each a measurement taken in one scope and applied in
   another. **Lanes caught every one.** That is the arrangement working, not
   failing, and it only works if you re-derive.
6. **For a known wait, arm a self-deleting conditional heartbeat.** This is the
   expected practice, not a last resort. You know you started a five-minute
   build; the monitor does not. Arm a heartbeat with the *condition* you are
   waiting on, act when it is met, and **delete it in the same turn**. One lane
   used exactly this to merge a PR on a fully green population, record the merged
   SHA, and retire its own heartbeat.

   This is not the standing five-minute self-pulse, and the difference is the
   whole point: it is **conditional**, **scoped to one wait**, and **removes
   itself**. A permanent unconditional pulse duplicates the monitor forever; this
   costs one turn, when the thing you are waiting for actually happens.

   Match its interval to what you are waiting on: a local build is 5-8 minutes, a
   full CI population here is ~40. Polling a 40-minute population every five
   minutes is waste with extra steps.

## Monitor rules

1. **One cron heartbeat, ten minutes.**

   **A fire is DROPPED if you are mid-turn at the slot boundary. It does not
   queue.** Measured 2026-09-05: three of ~14 slots lost in one session, every
   one while a turn was running, plus two doubles ~40 seconds apart as a slot
   landed just after a long turn ended. **The configured cron is therefore an
   upper bound on frequency, not the cadence you get.**

   That inverts the obvious reasoning. A ten-minute cron is not "poll harder" —
   it raises the probability a fire lands at all. Gaps stretch to 40 and 60
   minutes *precisely when you are busiest*, which is exactly when a lane is
   most likely to be stranded. Choosing a cadence you would be happy with if it
   always fired leaves you with a much worse one in practice.

   **The corollary matters as much as the cadence: keep ticks short.** A long
   turn costs the next fire. Report what changed and stop; do not do project
   work inside a tick when it can wait for a prompted turn.

   None of this makes the tick the primary mechanism. It is still a fallback —
   every lane that ends a turn wakes you through `notifyOnFinish`, and the tick
   only matters when a lane goes idle *without* telling you. Push detection to
   where the knowledge is (lane rule 6); the lane knows how long its build takes
   and you do not.
2. **Each tick, poll what emits no events:** open PRs and their exact-head
   `event=="pull_request"` populations, background task output files, the
   process table, worktree dirty state, pending permissions, disk.
3. **Convert change into a pulse.** Never pulse on a tick alone.
4. **Report every tick, including "nothing changed."** That is what keeps this
   from being a silent poll.
5. **Pulse-worthy events:** a CI population resolves or goes red; a background
   task a lane awaits completes; a named trigger a lane declared fires; a lane
   is idle without a written terminal state; a pending permission appears.
6. **A bounced message is not delivered.** `already has an active run` means the
   lane never saw it. Re-deliver.
7. **State your cadence to the lanes**, so a waiting lane knows the worst case.

## Failure modes

| Symptom | Detection | Remedy |
|---|---|---|
| Hung turn | `activeTurn.startedAt == updatedAt` to the millisecond, minutes old, process alive, no subprocess | `cancel_agent`, re-prompt. Nothing on disk is lost. |
| Stranded work | Lane idle, background task complete, nothing pushed | Pulse. Prevented by lane rule 4. |
| Bounced pulse | `already has an active run` | Re-deliver next tick. |
| Unreadable context | `get_agent_status` returns without `lastUsage` | Retry next tick; do not assume the last value. |
| Dead lane reading `running` | No process for `--resume=<sessionId>` | Derive session IDs from the agent list; never hardcode. |

## The single point of failure

**If the monitor stops, nothing wakes anyone.** Lanes sit idle and correct,
indefinitely. Mitigation: a lane may hold one long-interval heartbeat — hours,
not minutes — purely as a dead-man switch. That is a safety net, not a second
monitor, and it must not re-derive what the monitor already supplies.

## Precedence

`AGENTS.md` says: *"Always set a 5 minute pulse **when monitoring** local tests or
GitHub CI/CD."* The obligation is conditioned on monitoring. This document
reassigns monitoring to one agent, so a lane that has handed CI monitoring to the
monitor is not monitoring, and the rule does not fire for it. The monitor itself
is monitoring, and takes on the obligation the rule exists to enforce: never
silent, never a silent poll.

That is a reading, not an amendment. **Where a lane judges the rule still binds
it, the rule wins until the operator amends `AGENTS.md`.** A lane was asked to
drop a five-minute pulse on cost grounds and refused, citing this policy and a
direct operator instruction. The refusal was correct. **Cost is not authority.**

## Evidence

24 hours, three lanes, one monitor, eight merged patches:

- **4** hung turns, all foreground `just guard-*`; all recovered by
  cancel-and-re-prompt with no work lost.
- **3** stranded-work incidents from the unreliable completion notification;
  **0** after the waiting statement was adopted.
- **4** monitor errors from measurements applied outside their scope; **4**
  caught by lanes re-deriving.
