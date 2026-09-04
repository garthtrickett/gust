# The Demo Target Program

`docs/VISION.md` §0.7 says the deliverable is one artifact: an agent-generated
multi-tenant application where the cross-tenant data leak *does not compile*.
`TASK.md` runs targets, objects, and linkers. `TASK_STDLIB.md` runs the safe
stdlib surface.

Nothing connects them. The roadmaps are bottom-up, the vision is top-down, and
there is no file where they meet.

This is that file. It is the smallest program that demonstrates the §0.4 claim,
written as it should look when it works. **It does not compile today**, and the
gap between it and the compiler is the actual remaining work — enumerated in the
table below, with an owner per row.

## How to use it

- It is a target, not a test. Nothing runs it and no guard asserts on it.
- When a row's blocker clears, delete the row and update the program if the
  syntax settled differently.
- When it compiles and the negative case is rejected, §0.7's deliverable exists
  and this file is replaced by the real fixture.
- The publication package then adds the incident-based companion specified in
  `docs/DEMO_EXPLOIT_AUTOPSIES.md`. Those autopsies demonstrate shipped
  guarantees; they do not add speculative prerequisites to the program below.

This target is the **mechanism stage** only. A containment-stage claim also
requires ambient bypasses to be closed, runtime capabilities to be enforced,
and native or supplier code to be independently isolated. A production-shaped
claim additionally requires trusted tenant establishment, pinned schema
acquisition, realistic Postgres execution, traces, deployment evidence, and an
independent attack. Passing this file's positive and negative cases does not by
itself pass either later stage.

The first production-shaped deployment uses **one PostgreSQL schema per
workspace**. Its isolation proof is about trusted connection acquisition,
schema/search-path pinning, and pool reset. A shared-schema/tenant-column variant
is a separate architecture with predicate-provenance and RLS obligations; it is
not silently interchangeable with this target.

**Written 2026-08-20 against `b47d0049`.** Verified blockers cite
`docs/ONE_WAY_LEDGER.md`, which carries the reproductions.

---

## The program

An issue tracker's "list issues assigned to me" handler. Recognisable, boring,
and it is where the canonical failure lives.

```gust
// The tenant is resolved by the trusted host before application code runs
// (VISION.md §9). Establishing that context is outside the typed-query
// guarantee; ordinary Gust code cannot forge the Scope value it supplies.

type Issue[ctx] struct {
    id:          IssueId,
    workspace:   WorkspaceId,
    title:       str,
    assignee:    UserId,
    closed:      bool,
}

type ListError enum {
    NotAuthorized,
    Database { detail: str },
}

// The signature states two things: what it returns, and what authority it needs.
// `uses db.read<Issue>` is the entire containment claim (VISION.md §17).

func list_my_issues(session: Session, scope: Scope[Workspace]) Result[std.Vector[Issue], ListError]
    uses db.read<Issue>
{
    guard user := session.user() else {
        return Err(ListError.NotAuthorized);
    }

    // This illustrative spelling passes non-forgeable typed Scope provenance
    // into the compiler-owned query. Patch 21.3 owns the final surface syntax.
    mut issues := from(Issue, scope)
        .where(assignee == user.id)
        .where(closed == false)
        .order_by(id)
        .limit(50)
        .all()?;

    return Ok(issues);
}
```

**Every method call in it must be compiler- or platform-provided, and that is
not a stylistic choice.** Verified 2026-08-20 at `b47d0049`: a user cannot define
a method on their own type — there is no receiver syntax in
`compiler/parser.gst` and no test defines one (`docs/ONE_WAY_LEDGER.md` E15). So
`session.user()` must come from the platform, and the `from(Issue).where(…).all()`
chain must be the compiler-owned derivation §14 and §55 describe, not a builder
someone writes in Gust.

That is consistent with §14, which already says the query builder "is not
implemented in the user-facing language — it is a compiler feature with a typed
surface". It is recorded here because a demo written in method-call style invites
the assumption that a user could write those methods, and today they could not
write any method at all.

Three properties, and each is load-bearing:

1. **No `ctx`.** The handler runs in the request context; it does not name an
   arena, allocate into one by hand, or free one. See `VISION_RECONCILIATION.md`
   §3.4.
2. **`uses db.read<Issue>` is the reviewable artifact.** It is business-level
   authority, not `network.request<host>` (§18). Widening it shows up in a diff.
3. **An unscoped typed query does not compile.** Each scoped root carries an
   obligation, and only matching non-forgeable typed Scope provenance can
   discharge it. Predicate spelling or an arbitrary request value cannot.

That third property is deliberately bounded. It does not establish safe cache
keys, message or job propagation, object-storage scoping, non-query reads,
multi-step identifier flows, raw SQL, or correctness of the host that created
the trusted `Scope`. Those paths require their own controls and evidence.

## The negative case

The same handler as an agent writes it when it has not been told about tenancy.
This is the program that must be **rejected**, and rejecting it is the demo:

```gust
func list_my_issues(session: Session) Result[std.Vector[Issue], ListError]
    uses db.read<Issue>
{
    guard user := session.user() else {
        return Err(ListError.NotAuthorized);
    }

    mut issues := from(Issue)
        .where(workspace == session.workspace_id)
        .where(assignee == user.id)
        .all()?;
    return Ok(issues);
}
```

Required diagnostic — the error, not a lint and not a scanner finding:

```
error: query lacks trusted tenant-scope provenance
  --> issues.gst:9:20
   |
 9 |     mut issues := from(Issue)
   |                   ^^^^^^^^^^^ creates a scope obligation for `Issue`
   |
   = note: `Issue` is a workspace-scoped entity (declared at schema.gst:14)
   = note: `session.workspace_id` is an ordinary value; matching predicate
           syntax does not prove trusted Scope provenance
   = help: supply a matching `Scope[Workspace]` derived from the trusted request context
   = help: deliberate cross-tenant access requires an explicit capability-gated
           marker visible at this query
```

The second help line matters as much as the rejection: `VISION.md` §53 and §97
require cross-tenant access to be *possible*, *declared*, capability-gated, and
visible at the call site — not impossible. Patch 21.3 owns the final typed-query
spelling and Patch 21.6 owns the final cross-tenant marker. These examples are
target pseudocode, not syntax authority.

Privileged raw SQL is an explicit boundary outside this guarantee. It is not
the negative case for the compiler-owned typed-query analysis and must not be
presented as though the compiler inspects arbitrary SQL text for tenant scope.

## The exploit-autopsy companion

Once this program and its negative case are reproducible, the published demo
also grounds Gust's wider containment story in recent incidents. Near
publication, search the preceding 12–18 months of TypeScript/npm, Python/PyPI,
and Rust/Cargo disclosures and select only cases whose exploit preconditions map
to an implemented Gust guarantee.

Each selected incident must show a faithful sandboxed reproduction in the
original ecosystem, the benign requirement it served, the equivalent safe Gust
attempt, the exact rejection or containment evidence, and the boundary at which
`unsafe`, unrestricted authority, or an external supplier weakens the claim.
The permitted verdicts are **prevented**, **contained**, **exposed**, or **not
covered**—never the generic claim that Gust “cannot be hacked.”

`docs/DEMO_EXPLOIT_AUTOPSIES.md` owns the selection rules, artifact format,
claim taxonomy, and publication exit gate. This remains a presentation and
evidence layer over the core thesis-invalidating demo: it must not delay finding
out whether tenant scoping is sound or whether agents can write Gust.

---

## What must be true for this to compile

Ordered by dependency. Status re-verified 2026-08-22; evidence in
`docs/ONE_WAY_LEDGER.md`.

| # | Requirement | Status | Owner |
| --- | --- | --- | --- |
| 1 | Brand identity carried by type, not identifier spelling | **HOLDS** — Phase 19 closed D-1; `docs/PHASE19_CLOSURE.md:6-17` records the generated closure and Historical Full run `32586399260` | **delivered** — Phase 19 / PR #163, closure registrar PR #164 |
| 2 | `Result[T, E]` as a builtin, with `?` propagation | **ABSENT** — ledger E2 | **unowned** — spec proposed at VISION **§11.1** |
| 3 | A constructor for `Option` — `Some(42)` rather than writing `.tag` and `.Some.val` | **PARTIAL** — ledger E1 | Cranelift lane — CR-14 / PR #128; generic enum construction, not an `Option` special case |
| 4 | Implicit context in application code (`using ctx`) | **ABSENT** | **NOT A DEMO PREREQUISITE** as of the 2026-08-20 placement directive — Phase 26.3 follows the C-retirement tail; see [Phase 26/27 demo scheduling](PHASES_26_AND_27.md#scheduling-consequence-for-the-demo). Spec at VISION **§24.1** |
| 5 | `uses` clauses parsed and checked across the call graph | **ABSENT** — ledger E10, but `FunctionSignature` already carries per-function obligations | **unowned** — VISION §0.7 Track A; spec proposed at **§18.1** |
| 6 | Entity declarations that mark an entity workspace-scoped | **ABSENT** | Cranelift lane — Phase 21 Track A, Patch 21.2 onward; VISION **§56.2** rule 1 |
| 7 | Compiler-owned query derivation (`from`, `.where`, `.all`) | **ABSENT** | Cranelift lane — Phase 21 Track A, Patch 21.3 onward; VISION **§55.1**. OD-2 resolved 2026-08-20: this is compiler work by decision, not a library someone could contribute |
| 8 | Tenant scope tracked through query construction; unscoped rejected | **ABSENT in this target program** | Cranelift lane — OD-8 resolved 2026-08-25 as bounded positive for the predefined compiler-owned typed-query suite; VISION **§56.2** records the design and verdict and **§56.1** the attack list. That evidence does not make this aspirational target compile or cover the named exclusions. |
| 9 | A Postgres capability to execute the query against | **ABSENT** | **unowned** — VISION **§54.0**, which finds this row shares CR-5's blocker with `MutexGuard` |
| 10 | Panic scoped to the request, not the process | **VIOLATED** — ledger E3 | `TASK_STDLIB.md` CR-3, issue #91 — unscheduled |

**OD-2's resolution on 2026-08-20 sharpens the ordering of this table, without
changing a single row.** With user-written generic functions excluded, every
typed surface here is compiler work by decision — row 7's query derivation, and
§44's RPC schemas and §37's templates behind it. None can be prototyped as a
library, contributed by a lane that does not own the compiler, or deferred to a
user.

So compiler throughput is the binding constraint on the whole table, and the
sequencing question becomes sharper than "what is unowned". Rows 5 through 8 are
Track A; rows 6 to 8 are the lead claim (§56). **If every surface competes for
one queue, the authority model has to be built before the convenience surfaces,
or it does not get built** — query derivation is demo scope, but effects are what
make containment true and are the harder design.

That is not an argument against the decision, which is the right one for reasons
§14 records. It is the reason these six unowned rows matter more after it than
before it.

Rows 5 through 8 are `docs/VISION.md` §0.7 Track A verbatim, and **none of them
has an owning roadmap.** `TASK.md` runs targets, objects, and linkers;
`TASK_STDLIB.md` runs the safe stdlib surface.

That is a statement of sequence, not a criticism of it. The declared priority is
retiring the **C backend in favour of Cranelift**, and Phase 18 is that work.
`README.md` gives the reason directly: transpiling to C means inheriting C's
abstract machine, and the arena-and-index model is precisely the pattern its
rules punish — so the native backend is what makes "the compiler carries the
danger" true rather than aspirational. `docs/VISION.md` §0.7 Track A0 says the
same, and calls it not deferrable to post-demo. Row 9 of this table depends on
it too: a Postgres capability needs a backend whose memory model the compiler
owns.

So this document does not argue for reordering anything. It records what the
demo needs, so that when the backend work closes, the remaining distance is
already written down and costed rather than rediscovered.

> **Two rows were restated 2026-08-20 after later findings.**
>
> Row 3 read "`Option` constructible without `unsafe`". That framing rested on a
> claim the ledger has since split: no `Some(42)` constructor exists — which is
> established and is the substance — while *requiring* `unsafe` to work around it
> was inferred from every `std.Option` test using one, and none of the six
> `unsafe`-demanding diagnostics concerns union tags. The row now names the
> established requirement, because a prerequisite phrased around an unverified
> claim would send someone to fix the wrong thing.
>
> Row 5 keeps its `ABSENT` status and gains what changes its cost.
> `FunctionSignature` already carries per-function obligations — `is_unsafe`,
> `is_extern`, `requires_unsafe_call` and two inert `requires_*` fields — so
> effects extend a struct with the right shape rather than introducing the
> concept. The status is what to build; the note is what it will take, and a
> table of unowned work is read for the second more than the first.

Rows 1 and 3 are genuine prerequisites rather than scope creep. Row 1 is now
delivered: Phase 19 removed identifier spelling as brand authority, and the
authoritative Historical Full run passed 17/17 jobs. Row 3 remains open because
OD-9 cannot be tested fairly against a surface that exposes `Option`'s layout
instead of providing a constructor.

## Two things that could ship before any of the above

Every row in the table waits on the backend or on Track A. Two containment
properties do not, and both are `docs/VISION.md` product claims:

- **Type opacity** — §81's "no readable string representation". The `#[linear]`
  attribute mechanism already exists and formatting dispatch is centralised, so
  this is a fourth attribute plus one check.
- **A provenance trace** — §108's "allocation and context lifetimes at region
  granularity" and "typed error values with propagation path". The compiler
  already computes a per-expression origin classification across nine categories;
  nothing emits it.

Neither needs effects, a database, or a native backend. Both are specified in
`docs/UNBLOCKED_CONTAINMENT_WORK.md`. They do not substitute for this program —
they are simply the parts of the claim that are reachable now.

> **All six unowned rows now have a written proposal, as of 2026-08-20.** The
> Owner column points at each. **They remain unowned** — a specification is not a
> schedule, and none of these rows moved status because someone described them.
> What changed is that the next person to pick one starts from a stated design
> and its open questions rather than from a blank row. Two of the six also came
> back with their difficulty revised: **row 4's former Phase 19 dependency is
> now resolved**, while **row 5 is easier than it looked** because
> `FunctionSignature` already carries the required shape.

## A proposed order for the six unowned rows

Recorded because OD-2 made it necessary: with every typed surface now compiler
work by decision, these six compete for one queue, and no document says in what
order. **This is a recommendation, not a decision** — the ordering argument is
written down so that choosing differently is a choice rather than an accident.

**1. Rows 6 and 8 — workspace-scoped entities, and scope tracked through query
construction.** These are §56, the lead claim. OD-8's predefined attack suite
has since produced a bounded positive verdict, but the target program and its
excluded cache/non-query/multi-step paths remain unimplemented here. **The
analysis belongs before convenience surfaces while it is still small enough to
attack.** Every row below adds code the analysis must then hold over.

**2. Row 5 — `uses` clauses and effect checking.** Track A item 1, and the thing
§81, §22, §52 and §108 each presuppose — one gap seen from four sections. It also
has the least uncertain path: `FunctionSignature` already carries per-function
obligations, so this extends a struct with the right shape rather than
introducing the concept.

**3. Row 2 — `Result` and `?`.** Core language, and unlike the platform rows it
blocks *writing* the demo rather than running it. The compiler hand-rolls
`Result` today (`compiler/errors.gst:17`), which is both the evidence it is
absent and the evidence it is expressible.

**4. Row 7 — query derivation.** Large, and it is the row OD-2 moved decisively
into the compiler. Worth doing after the analysis it must satisfy exists, not
before: a builder built first would have to be retrofitted to whatever §56's
scope tracking turns out to require.

**5. Rows 4 and 9 — implicit context, and a Postgres capability.** Row 4 is
ergonomic and matters most for OD-9, but it is desugaring and can land any time.
Row 9 is genuinely platform and the only row here that is not compiler work.

**The single ordering claim worth arguing about:** the authority model belongs
before the convenience surfaces. If compiler throughput is the binding constraint
— which OD-2 made true by decision — then anything built before effects and scope
tracking is code those analyses must later be made to hold over. That is a cost
that compounds, and it is the one sequencing error that cannot be undone cheaply.

## What this does not require

Recorded so the table is not read as a licence to build the platform:

- No HTTP server. The handler can be driven from a test harness.
- No Wasm, no frontend, no templates, no SAM, no gustrpc. **Confirmed as the first demo 2026-08-21** — the alternative, `docs/WEB_SLICE_0.md`'s full-stack loop, is sequenced after, because only this demo resolves OD-8 and OD-9. Reasoning at `WEB_SLICE_0.md` §4.
- No jobs, cache, realtime, or supplier system.
- No deployment platform, and no second target — one Linux x86-64 host is enough.
- No auth implementation; `Session` can be a struct handed in by the harness.

`VISION.md` §0.16 defers all of it, and the demo does not need any of it.
