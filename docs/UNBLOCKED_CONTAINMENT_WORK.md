# Containment Work That Does Not Wait on the Platform

`docs/ONE_WAY_LEDGER.md` records 44 design rules, of which 9 hold. Most of the
rest are absent because the platform they describe is unbuilt, and correctly
deferred.

**Two are not.** Both are containment properties `docs/VISION.md` states as
product claims, both are expressible against the compiler exactly as it stands
today, and neither is scheduled by any roadmap. This document exists so they stop
being footnotes in an evidence section.

It proposes; it does not decide. Each entry names what exists, the smallest
change, and the ownership question it raises.

**Written 2026-08-20 against `b47d0049`.** Every claim about the compiler has a
citation; none of it was built or benchmarked.

---

## Why these two and not the other thirty-five

The test is `docs/VISION.md` §0.12, which names three artifacts humans actually
read, and asks which could exist before the platform does:

| Artifact | Needs | Available today |
| --- | --- | --- |
| Capability manifest | effects (§17) | **No** — no `uses` keyword (E10) |
| Lockfile diff | packages, manifests (§70, §72) | **No** — no package concept (row 38) |
| Execution trace | regions, typed errors | **Yes** — both exist |

And separately, §81's secrets claim splits into two mechanisms of which one
already ships:

| Half of §81 | Needs | Available today |
| --- | --- | --- |
| `secret.use<"stripe">` | effects | **No** |
| "no readable string representation" | a type-system property | **Yes** |

That is the whole selection criterion. Everything else in the ledger marked
`ABSENT` waits on a database, an HTTP server, a job runner, or an effect system.

---

## Proposal 1 — type opacity (§81's other half)

**The claim.** §81: "Secrets are opaque linear values. They have no readable
string representation in safe code. Secrets cannot be logged, serialized,
formatted, returned to clients, or compared except through approved operations."

Its rationale is one of the strongest containment arguments in the document:

> an agent cannot leak a secret into a log line or an error message, because the
> type does not permit it. Among the most frequent mistakes in generated code and
> among the most expensive.

**What exists.** The *linear* half is done — `#[linear]` is parsed as a layout
attribute (`compiler/parser.gst:869-872`), carried on `StructDecl`
(`compiler/ast.gst:77`), and registered via `env_register_struct_linear_metadata`
(`compiler/typechecker.gst:6801`). `#[repr(C)]` and `#[packed]` use the same
path, so the attribute mechanism is established and has three users.

**What is missing.** Nothing marks a type as unformattable.
`grep -ciE 'opaque|no_format|not_formattable' compiler/typechecker.gst` returns
0, and `std.Format` accepts whatever it is given.

**The smallest change.** A fourth layout attribute alongside the existing three:

1. **Parse** — one more arm in the attribute chain at
   `compiler/parser.gst:869-872`, identical in shape to `linear`.
2. **Carry** — one field on `StructDecl`, mirroring `is_linear_resource`.
3. **Register** — one map on `TypeEnvironment`, mirroring `struct_linear_resource`
   (`compiler/typechecker.gst:737`).
4. **Reject** — at the formatting dispatch sites, which are already centralised:
   `compiler/typechecker.gst:1962-1963` and `:3810` resolve `std_Format`,
   `std.Format`, `std_FormatInt`, and `std.FormatInt` by name. One check there
   covers the formatting surface.

Message shaped like S1.1's, byte-identical across both typecheckers, with a guard
mirroring `guard-stdlib-s1-str-equality-diagnostic`.

**What it does not do.** It does not implement secrets. It does not stop a value
being written to a file, sent over a channel, or read byte-wise — those need
effects and row 33's channel-transfer semantics. It closes exactly one hole: a
value whose type says "not printable" cannot reach a formatting call.

That hole is worth closing on its own terms, because §81 identifies logging a
secret as among the most frequent and most expensive mistakes in generated code,
and this is the half of the defence that does not wait on Part V.

**Ownership question — raised formally as `TASK_STDLIB.md` CR-10.**

The carve-out in `docs/SHARED_SEMANTIC_ZONE.md` covers "a diagnostic that
**rejects** a program the compiler currently miscompiles, provided no accepted
program changes meaning". This proposal satisfies the second clause and not the
first: no existing type carries the attribute, so nothing accepted changes
meaning — but the programs it would reject are not miscompiled today, they are
correct.

So it is neither clearly in nor clearly out, and CR-10 states both readings in
the seven-point format rather than assuming one. The recommendation there,
weakly held, is to treat it as in-zone for the *decision* and out-of-zone for the
*work*, following how CR-1 was handled: the owner rules on whether the attribute
exists and what it is called, and implementation then proceeds as ordinary
Stdlib-lane work under that ruling.

It touches no MIR, no ABI, no layout computation, and no runtime symbol; the
attribute is consumed entirely in the frontend, so codegen never sees it.

---

## Proposal 2 — a provenance trace (§108's expressible subset)

**The claim.** §108 wants every run to emit a structured, versioned,
machine-readable trace, and calls it one of the three things humans actually
read. Most of its contents need the platform: capability sets, exercised effects,
denied authority, query predicates.

**Two of its bullets do not.** §108 asks a trace to record "allocation and
context lifetimes at region granularity" and "typed error values with propagation
path". Regions and typed errors both exist.

**What exists — more than the section assumes.** The compiler already computes a
provenance record per expression and per variable:

```gust
// compiler/typechecker.gst:5-24
type OriginSet[ctx] struct { map: std.HashMap[str, int, ctx] }

type AddressOriginMetadata struct {
    is_safe_arena: int,
    is_raw_derived: int,
    is_sandbox_derived: int,
    is_unknown: int
}

type ExpressionProvenance[ctx] struct {
    resolved_type: ast.Type[ctx],
    address_origin: AddressOriginMetadata,
    legacy_origins: Index[OriginSet[ctx], ctx]
}
```

All nine origin categories from `compiler-plan.md` are live and in use: `safe`,
`local_stack`, `arena`, `scratchpad`, `ffi`, `sandbox`, `raw_unknown`,
`borrowed_field`, `container_element`. `TypeEnvironment` carries
`variable_origins`, `return_origins`, and
`current_function_return_origins` (`compiler/typechecker.gst:637,748,757`).

This is *stronger* than what §108's two bullets ask for. It is not merely region
lifetime; it is where every address came from, classified.

**The instrumentation points already exist too.** `typechecker_log_trace` has 40
call sites and an empty body (`compiler/typechecker.gst:8618-8619`). Whatever
else is required, the places to emit from are present and are maintained through
bootstrap.

**The smallest useful change.** Emit a machine-readable record, behind a flag,
containing per function: each variable, its resolved type, its origin
classification, and its arena brand; plus the declared error type and its
propagation path. JSON, with a schema version field, because §108 requires a
versioned schema and because the absence of any machine-readable compiler output
is also row 40's finding.

**Why this is worth more than its size.** `docs/VISION.md` §0.5 layer 4 and
`docs/VISION_RECONCILIATION.md` §4 both argue the machine interface is the moat —
that syntax is cheap for a model to learn and structured compiler understanding
is not. Nothing in that layer exists today (rows 40, 42). This would be the first
piece, it would be built from analysis the compiler already performs, and it
would give `docs/DEMO_TARGET_PROGRAM.md` something to show that is not a
rejection message.

**Ownership question.** Emitting a new artifact from existing analysis changes no
program's meaning and adds no semantics. But it is compiler output, and if the
record is ever consumed by a guard it becomes an interface. **Treat the schema as
the durable part and version it from the first commit.**

---

## Scope discipline

Both proposals are bounded by the same rule `docs/VISION.md` §0.7 Track A0 sets:
work that makes something newly *writable* or newly *inspectable* using
mechanisms that already exist, never work that adds expressive power.

Explicitly out of scope for both:

- effects, `uses` clauses, or any capability surface — that is Track A;
- a `Secret` type, key storage, or rotation — that is Part XV;
- run-time tracing of a *program*'s execution, as opposed to compile-time facts;
- anything touching MIR, ABI, layout, or the runtime symbol surface.

If either proposal starts to need one of those, it has left this document and
belongs in the owning lane's roadmap under the stop-and-report protocol.
