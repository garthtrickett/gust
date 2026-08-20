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

**Written 2026-08-20 against `b47d0049`.** Verified blockers cite
`docs/ONE_WAY_LEDGER.md`, which carries the reproductions.

---

## The program

An issue tracker's "list issues assigned to me" handler. Recognisable, boring,
and it is where the canonical failure lives.

```gust
// The tenant is resolved by the platform before application code runs
// (VISION.md §9) and is immutable for the request.

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

func list_my_issues(session: Session) Result[std.Vector[Issue], ListError]
    uses db.read<Issue>
{
    guard user := session.user() else {
        return Err(ListError.NotAuthorized);
    }

    // `from` is tenant-scoped by construction. There is no way to spell this
    // query that omits the workspace predicate — that is VISION.md §56, and it
    // is why the leak is not expressible rather than merely discouraged.
    mut issues := from(Issue)
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
3. **The unscoped query has no spelling.** `from(Issue)` carries the workspace
   predicate; there is no builder method that removes it.

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

    mut issues := raw_sql("SELECT * FROM issues WHERE assignee = $1", user.id)?;
    return Ok(issues);
}
```

Required diagnostic — the error, not a lint and not a scanner finding:

```
error: query is not tenant-scoped
  --> issues.gst:9:20
   |
 9 |     mut issues := raw_sql("SELECT * FROM issues WHERE assignee = $1", user.id)?;
   |                   ^^^^^^^ constructs a query over `issues` with no workspace predicate
   |
   = note: `Issue` is a workspace-scoped entity (declared at schema.gst:14)
   = note: every query over a workspace-scoped entity must be constructed
           through `from(Issue)`, which applies the predicate
   = help: rewrite as `from(Issue).where(assignee == user.id)`
   = help: if this query is deliberately cross-tenant, it requires the
           `db.cross_tenant<Issue>` capability, which must be declared in the
           signature and approved in the manifest
```

The second help line matters as much as the rejection: `VISION.md` §53 and §97
require cross-tenant access to be *possible*, *declared*, and *approved* — not
impossible. A rule with no escape hatch gets routed around.

---

## What must be true for this to compile

Ordered by dependency. Status verified 2026-08-20; evidence in
`docs/ONE_WAY_LEDGER.md`.

| # | Requirement | Status | Owner |
| --- | --- | --- | --- |
| 1 | Brand identity carried by type, not identifier spelling | **VIOLATED** — ledger D-1 | Phase 19 (`TASK_PHASE19.md`), staged |
| 2 | `Result[T, E]` as a builtin, with `?` propagation | **ABSENT** — ledger E2 | **unowned** |
| 3 | `Option` constructible without `unsafe` | **PARTIAL** — ledger E1 | Stdlib (Track A0 scope) — issue #102 |
| 4 | Implicit context in application code (`using ctx`) | **ABSENT** | **unowned** — `compiler-plan.md` Phase 5.3 |
| 5 | `uses` clauses parsed and checked across the call graph | **ABSENT** — ledger E10 | **unowned** — VISION §0.7 Track A |
| 6 | Entity declarations that mark an entity workspace-scoped | **ABSENT** | **unowned** — VISION §56 |
| 7 | Compiler-owned query derivation (`from`, `.where`, `.all`) | **ABSENT** | **unowned** — VISION §55, OD-2 |
| 8 | Tenant scope tracked through query construction; unscoped rejected | **ABSENT** | **unowned** — VISION §56, OD-8 |
| 9 | A Postgres capability to execute the query against | **ABSENT** | **unowned** — VISION Part XI |
| 10 | Panic scoped to the request, not the process | **VIOLATED** — ledger E3 | `TASK_STDLIB.md` CR-3, issue #91 — unscheduled |

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

Rows 1 and 3 are genuine prerequisites rather than scope creep — row 1 because
the memory model is approximated by string matching until it lands, row 3 because
OD-9 cannot be tested against a surface that requires `unsafe` to construct an
`Option`.

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

## What this does not require

Recorded so the table is not read as a licence to build the platform:

- No HTTP server. The handler can be driven from a test harness.
- No Wasm, no frontend, no templates, no SAM, no gustrpc.
- No jobs, cache, realtime, or supplier system.
- No deployment platform, and no second target — one Linux x86-64 host is enough.
- No auth implementation; `Session` can be a struct handed in by the harness.

`VISION.md` §0.16 defers all of it, and the demo does not need any of it.
