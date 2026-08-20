# Refinements review — what to adopt, what conflicts, what to register

A refinements list covering async, concurrency, RPC, the language service, SAM,
templates, dependencies, native libraries, platform layering, execution strategy,
and positioning. Reviewed 2026-08-20 against the decisions taken that day.

Sorted by what a reader needs to do about each: **nothing (already decided the
same way)**, **register (a real gap)**, **resolve (a contradiction)**, or **adopt
(a correction that is simply better)**.

---

## 1. Already decided the same way — confirmations, not changes

These arrived at today's conclusions independently, which is worth recording
because independent convergence is the best evidence available that a decision is
right.

- **"Treat pending async work as a linear resource"** — abandoned work is an
  error unless awaited, spawned, cancelled, or transferred. **This is OD-11
  exactly** (`docs/VISION.md` §20.1–20.2): the scoped spawn returns a linear task
  handle discharged only by join, cancel, or transfer.
- **"Make task ownership a language invariant"**, not a convention — §20 plus
  OD-11's move-checker enforcement. §20.2's diagnostic is the invariant made
  visible.
- **"Make task handles linear"**, not freely copyable — same.
- **"Keep suspension separate from failure"** — §21's direction and §11.1's rule
  that `?` means *may fail* and nothing else.
- **"Three distinct concepts — child task, supervisor, durable job"**, and do not
  model a durable job as a variant of spawn — §21 states this, and §20.2 shows
  supervisors falling out of `Transfer` rather than needing a third primitive.
- **"SAM recommended, not required"** — CLI tools should not be forced into it.
  Consistent with Part IX and §38.1.
- **"Keep gustrpc transport-independent"** — `docs/WEB_SLICE_0.md` records the
  same, with `http-json` as Slice 0's single transport.
- **"Browser owns browser behaviour; Gust owns state, validation, logic,
  rendering decisions, routing"** — Slice 0's allowed/forbidden glue lists.

---

## 2. Register — real gaps, nothing in the repository covers them

**Sibling failure semantics.** What happens when one child task fails is
undefined. Recommended default: **cancel siblings, wait for cleanup, propagate
the failure**, with alternative scope policies such as collect-all offered
explicitly rather than left implicit. §20 says failures propagate through
`Result` and says nothing about siblings. **This belongs in §20 and is not a
detail** — it is the difference between a scope that cleans up and one that
leaks on the first error.

**Cancellation as data requires explicit syntax.** Ordinary code propagates
cancellation automatically; *observing* it must be deliberate, so cancellation
cannot be swallowed by accident. Nothing in the repository says this.

**Asynchronous cleanup.** Both `defer file.close()` and
`defer await connection.shutdown()` must work, and **async cleanup must complete
even while cancellation is in progress.** This interacts directly with CR-5: the
missing destructor-declaration syntax has to accommodate a destructor that
suspends, and a design that assumes synchronous destructors will have to be
reopened. Worth stating **before** CR-5 is implemented rather than after.

**Inert-by-default async — and OD-11 created this question without answering
it.** The list proposes that calling an async function creates suspended work
rather than starting it. Under transparent suspension there is no async function
type for that rule to attach to, so the general form is moot — **but the specific
form is live**: §20.2 writes `s.Spawn(fetch_user(req.id))`, and nothing says
whether `fetch_user(req.id)` is evaluated at the call site or packaged for the
scheduler. Those differ observably when the argument expression has effects.
**This is a genuine open question created by OD-11's own syntax.**

**Transport annotations.** `rpc service LanguageService @local` versus
`@remote`, expressing deployment intent in the declaration so deployment can be
validated without changing application code. Fits the effect-restriction model of
§17 — a transport is exactly the kind of restriction an effect already carries.

**Document versioning in the language service.** Every editor request carries a
document version, and every edit names the version it was generated against, so
stale edits cannot be applied. Small, and the kind of thing that is very
expensive to retrofit.

**Language service before custom editor.** Parser, diagnostics, formatter, symbol
navigation, semantic inspection — integrated with existing editors first. A
custom editor only once the language service is excellent. This bears on **OD-9**:
the language service is the surface a model reads, and it is buildable long
before an editor.

---

## 3. Resolve — one real contradiction

**The list keeps `await`. OD-1 removed it.**

The async section says *"`await` means this operation may suspend"* and the RPC
section says *"even if a call feels like a normal function, remote or
cross-process operations should still require `await`. Do not hide latency."*
`docs/VISION.md` §21's direction, set 2026-08-20, is **transparent suspension
with no colouring** — "suspension needs no keyword because it is always owned."

**These are not the same proposal and should not be merged quietly.** But they are
also not straightforwardly opposed, and the distinction is worth stating exactly:

- **Function colouring** — `async fn` propagating up every caller — is what OD-1
  rejected, and the list does not actually ask for it.
- **A call-site marker on cross-process boundaries only** is a narrower claim:
  local suspension stays invisible, and a *remote* call is marked because its
  failure modes and latency are qualitatively different from a local one. That is
  the classic argument against transparent RPC, and it is not the argument OD-1
  settled.

> **Registered as the question rather than resolved here: should a cross-process
> call be syntactically visible even under transparent suspension?** Answering
> *yes* does not reopen OD-1 provided the marker attaches to the *boundary* and
> never to the function type — the moment it appears in a signature and
> propagates, it is colouring and OD-1 governs.

---

## 4. Adopt — corrections that are simply better

**"No package manager" → "no uncontrolled dependency graph".** The goal was never
zero packages; it is a versioned platform, curated modules, explicit vendored
code, reproducible builds, and declared capabilities. §70 and §72 already
describe manifests, lockfiles, source hashes, signatures and capability
requirements — **so the repository already implements the accurate claim while
the slogan states the inaccurate one.** The slogan is also strictly weaker: "no
package manager" invites the reply *then how do I use anything*, while "no
uncontrolled dependency graph" names the actual failure being avoided.

**Four dependency categories**, each with its own lifecycle and compatibility
guarantees: platform modules, curated modules, vendored modules, foreign native
libraries. §98's guarantee boundary currently splits two ways; this splits four,
and the extra resolution is where the real differences are.

**"Zero third-party runtime dependencies" → "most Gust applications require no
developer-managed runtime dependencies".** Longer and true, which beats short and
falsifiable — one counterexample retires the absolute form, and §0.11's whole
posture is that a claim should survive being attacked.

**Hide which C library implements a capability.** `use sql.postgres`, not a named
client library; the platform owns safety, compatibility, upgrades, and
cross-platform behaviour. **This bears directly on §54.0's open choice** between
linking a C client and writing the wire protocol in Gust: if the implementation
is hidden behind the capability, that choice becomes reversible later rather than
baked into user code. **That materially lowers the cost of choosing the fast path
now** — worth noting, because §54.0 currently presents it as a decision with
lasting consequences.

**A focused initial platform list** — HTTP, PostgreSQL, SQLite, JSON, auth,
sessions, jobs, email, crypto, files, logging, metrics, testing, browser. Narrow,
and each item is load-bearing for "build a software company", which is a sharper
selection rule than "wrap the mature C libraries" and directly supports §98's
argument that a wide surface is what makes a guarantee unmeetable.

**Five-layer platform architecture** — core language, compiler services,
platform, application model, studio. Its purpose is stated well: **keep temporary
framework ideas out of the language core.** That is the same job
`docs/VISION_RECONCILIATION.md`'s ring model does, and the layer names are more
concrete than the ring numbers. Worth reconciling the two rather than carrying
both.

---

## 5. Execution strategy — and what it says about the demo conflict

> Build **vertically**, not horizontally. Core language → **one full-stack loop**
> → local language service → one production-quality application → AI-assisted
> semantic maintenance. Each stage proves a complete value proposition before the
> next subsystem starts.

**This is an argument in the open question `docs/WEB_SLICE_0.md` §4 records.**
That file states, without resolving, whether the first public demo makes the
containment claim (§0.14's multi-tenant handler) or the unified-contract claim
(Slice 0). **This list puts the full-stack loop second, immediately after the core
language** — which is a vote for Slice 0, on the general principle that a vertical
slice proves a complete value proposition and a horizontal one does not.

Recorded as input to that question, not as a resolution of it. The counter-argument
is unchanged and remains in §0.4: containment is the differentiator, and a
full-stack loop that contains nothing is a demo of a build system.

---

## 6. Positioning

**"One compiler-understood application system with multiple execution
environments."** Native servers, Wasm frontends, language services, supervisors
and durable jobs as deployment forms of one semantic model — rather than a
language *plus* a framework *plus* an editor *plus* an RPC system. This is the
framing that makes the parts stop looking like scope creep, and it is worth
adopting for that reason alone.

Internal: *the language designed for one developer and one million users.*
Public: *an AI-native application platform for building and operating serious
software with small teams.* Supporting: *one language, one application model, one
compiler, one deployable system.*

*"Build the company, not the stack"* is the strongest line in the set and the
only one that states a benefit rather than an architecture.
