# Gust Web Slice 0 — recorded, and reconciled against the 2026-08-20 decisions

`gust-fullstack.md` was a source document and is not in this repository;
`docs/VISION_RECONCILIATION.md` lists it as "no" in the source table. Slice 0
appeared in no file here. This records it, and — more usefully — says which parts
today's decisions **confirm**, which parts they **block**, and the one place
Slice 0 and `docs/VISION.md` §0.14 **contradict each other**.

**This is a record and a reconciliation. It decides nothing** and schedules no
work for any lane.

---

## The thesis, and the loop

> **Gust can own the full app contract from backend to browser.** No duplicated
> TypeScript types, no hand-written API schema, no manual client wrapper, no WIT
> on the main path. Generated glue is allowed. **The app contract is Gust.**

```
one shared Gust type → one gustrpc contract → generated backend dispatcher
  → native Gust handler → generated frontend client stub → Gust Wasm frontend
    → generated browser glue → visible DOM update
```

The demo is a typed ping: click a button, the Wasm frontend calls the native
backend through generated code, gets `Result[PingOutput, AppError]`, renders it.
**Boring as an app, and that is the point** — the claim is architectural.

**What it must prove:** shared types usable by both sides; a service definition
that generates *both* the backend dispatcher and the frontend stub; a native
backend binary; a Wasm frontend; and a call that updates the DOM with no
app-specific hand-written JavaScript.

**What it must not try to prove yet:** SAM controller, template compiler,
routing, auth, database, forms, validation, subscriptions, streaming, binary
transport, WIT, SSR, hydration, component model, asset pipeline, deploy CLI.

**Build order** (fifteen steps, each independently checkable): skeleton → type
scanner → JSON encoders → JSON decoders → manifest → handler without HTTP →
dispatcher without HTTP → native HTTP server → static page → minimal Wasm →
click into Wasm → Wasm requests fetch → glue performs fetch → response back into
Wasm → DOM update from typed result. **Steps 6 and 7 deliberately run before the
HTTP server**, so the contract is provable without the platform.

---

## Four things today's decisions confirm

These were arrived at independently, which is the strongest evidence either side
is right.

**1. The fetch pattern is already §21.1's answer to OD-4.** Slice 0 has the Wasm
side *return a command* — `BrowserCommand.FetchRpc { … }` — and the JS glue
perform the fetch and call back in. That is exactly "client code dispatches
actions and returns effects, never awaits", which §21.1 recommends because
**Safari has not shipped JSPI**. Slice 0 needs no stack switching, no Asyncify,
and no suspension in the browser at all. **It was designed before that constraint
was checked and does not violate it.**

**2. The ugly codec names are OD-2 done correctly.** `encode_Result_PingOutput_AppError`
is monomorphic generated code, not a generic function. OD-2 resolved that the
compiler derives typed surfaces and §13's ban on user-written generic functions
stands; a generated per-instantiation encoder is precisely that. **Slice 0's note
that "the names can be ugly at first — correctness matters more than beauty" is
the right instinct**, and under OD-2 the ugliness is structural rather than
temporary.

**3. The forbidden-RPC-types list is §38.1's conclusion from the other side.**
Slice 0 forbids raw pointers, references, `Arena`, `DbConnection`,
`DbTransaction`, `FileHandle`, `DomNode`, thread and resource handles, function
pointers, and opaque native pointers from crossing the boundary, and requires
generation to *fail* with `gustrpc error: type <T> cannot cross the RPC boundary`.
§38.1 reached the same rule from SAM state: **the model may not contain linear
resources**, because anything replayable, clonable or swappable must be plain
data. Two different problems, one constraint. That is what a real invariant looks
like.

**4. The JSON writer it needs is already specified.**
`docs/UNBLOCKED_CONTAINMENT_WORK.md` specifies seven functions — `json_escape`,
`json_str`, `json_int`, `json_bool`, `json_null`, `json_member`, `json_object`,
`json_array` — deliberately schema-agnostic, and re-verified 2026-08-20 as still
having **no equivalent anywhere in `compiler/`**. Slice 0's step 0.3 and the
trace proposal need the same code. **Whoever writes it unblocks both.**

---

## What blocks it, in order of how much

| Blocker | State | Where |
| --- | --- | --- |
| `Result` and `?` | absent; `Result` is hand-rolled by the compiler | §11.1, ledger E2 |
| A native HTTP server | request and task contexts do not exist | ledger E16, §24's correction |
| The Wasm target | OD-4 open; §21.1 recommends the no-suspension client | §41 |
| `rpc service` syntax | new language surface, therefore compiler work under OD-2 | §55.1's precedent |
| JSON codecs | specified, unwritten | `UNBLOCKED_CONTAINMENT_WORK.md` |

Slice 0 anticipates the fourth: it offers a fallback of ordinary declarations
that tooling recognises, while keeping `rpc service AppRpc { … }` as the intended
surface. **That is the right shape** — prove the loop with the fallback, and keep
the intended syntax visible so the demo explains what it will become.

**The contract hash is worth keeping even though it does nothing yet.** Slice 0
generates `contract_hash.txt` and sends `x-gustrpc-contract`, with the backend
ignoring it initially. §108 requires a versioned schema for the same reason:
**version from the first commit, because the moment anything consumes it, it is
an interface.**

---

## The contradiction — two different first demos

`docs/DEMO_TARGET_PROGRAM.md` states the demo's exclusions in one line:

> **No Wasm, no frontend, no templates, no SAM, no gustrpc.**

And `docs/VISION.md` §0.14 makes the demo *one agent-generated multi-tenant
handler* whose lead claim is §56 — the unscoped program does not compile. **Slice
0 is a different demo of a different claim**: not "this program is contained" but
"this contract is one language end to end". Neither is a subset of the other. The
containment demo needs no browser; Slice 0 needs no tenant scoping.

**This is not resolved here, and it should not be resolved by whichever document
is read first.** Recorded as the question:

> **Which claim does the first public demo make — containment, or the unified
> contract?** They need different work, and §0.14's four-month plan currently
> funds only the first.

Two observations that bear on it without settling it. **§0.4 argues containment
is the differentiator and correctness is the roadmap**, which favours the §0.14
demo. But **§0.11 lists distribution (OD-10) as unanswered**, and a full-stack
loop is the more legible artifact to a wider audience — Slice 0 is a thing you can
*show*, in a way a rejected query diagnostic is not.

If both are wanted, the honest sequencing is that they share almost no
prerequisites: the containment demo needs effects, scope tracking and query
derivation; Slice 0 needs `Result`, HTTP, Wasm and codecs. **Running both is two
projects, not one project with two outputs.**
