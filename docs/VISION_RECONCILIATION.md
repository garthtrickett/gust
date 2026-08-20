# Vision Reconciliation

`docs/VISION.md` is one of nine documents that describe what Gust is. The other
eight are handoff and critique documents that live outside the repository. They
do not agree with each other, and in six places they do not agree with
`docs/VISION.md`. Those six are §3 below.

They also do not agree with the compiler. That is a separate question with a
separate answer: `docs/ONE_WAY_LEDGER.md` tracks each design rule against what
the compiler does, with a reproduction per row. As of 2026-08-20, 9 of 32 rules
hold; the rest are partial, violated, deferred, or describe unbuilt platform.

This document reconciles them. It records, for each conflict: what each source
says, which one survives, and why. Where a conflict is a semantic question it
does **not** decide it — it routes it to the owner named in
`docs/SHARED_SEMANTIC_ZONE.md`.

It exists because "the vision" is currently reconstructed from memory by whoever
read the most recent handoff document, and two agents reading different subsets
reach different designs. A conflict that is written down once is cheaper than a
conflict rediscovered per lane.

**Verified 2026-08-20 against `b47d0049` (`main`).** Every claim about the
implementation below has a command that reproduces it. Claims about the
*documents* cite the document.

## Status of this document

Advisory. It has no authority over `docs/VISION.md`, `docs/SHARED_SEMANTIC_ZONE.md`,
or either roadmap, and it grants no lane permission to implement anything. Where
it recommends a decision, the recommendation is labelled as one and the owner is
named.

---

## 1. The source documents

| Document | In repo | Standing |
| --- | --- | --- |
| `docs/VISION.md` | yes | Authoritative for product, language principles, and §-numbered rules cited by `SHARED_SEMANTIC_ZONE.md`. |
| `README.md` | yes | Authoritative for the failure-mode argument and the two-backends rationale. |
| `platform-decisions.md` | no | **Was a duplicate of `docs/VISION.md`** modulo markdown formatting, plus §0.7 "Track A0" which only VISION.md had. That equivalence ended on 2026-08-20: VISION.md now carries the Part status markers (§0.17), the §0.1 and Part IV readership qualifications, the §21 OD-1 record, and the verified notes on §0.6, §23, and §32. Where the two differ, **VISION.md is authoritative and the upload is stale**. Do not treat it as a second source, and do not reconcile VISION.md back toward it. |
| `escaping-perpetual-underclass.md` | no | Outside critique, strategic. No design authority; several recommendations already adopted. |
| `advice.md` | no | Outside critique, tactical. Source of the four-ring layer model (§4 below). |
| `async.md` | no | Async/concurrency proposal. **Conflicts with `VISION.md` §21.** See §3.2. |
| `compiler-plan.md` | no | FFI/provenance/layout ordering, plus the self-hosting bootstrap discipline. Largely superseded by `TASK.md` phases 13–19. |
| `mir-to-cranelift.md` | no | Roadmap tail, phases 18–25. Consistent with `TASK.md`. |
| `general-ecosystem.md` | no | **Retired.** See §3.3 and Appendices A–B. |
| `gust-fullstack.md` | no | Full-stack architecture — gustrpc, Reactive SAM, Lit-style templates. Speculative; matches VISION Parts IX and XIII. |
| `full-stack-slice-0.md` | no | Executable spec for the smallest full-stack loop. Speculative but well scoped; use verbatim when Part IX is committed. |

---

## 2. The one-sentence vision

The corpus contains four competing one-liners. The one that survives, because it
is the only one that is simultaneously true, falsifiable, and not a market
prediction:

> **Gust is Go's simplicity applied to a whole application: the arena instead of
> the collector, the capability instead of the import.**

with the corollary that carries the dependency model:

> **You can leave the garden. The moment you do, the compiler names the guarantee
> you gave up.**

Why the alternatives lose:

- *"Built for software written by machines and never read by people"*
  (`VISION.md` §0.1) is a market hypothesis with a resolution date (OD-9), not a
  vision. `VISION.md` §0.1 now says so itself. See §3.1.
- *"The ultimate language for the age of AI"* is unfalsifiable and, per
  `escaping-perpetual-underclass.md`, claims universality before anything has
  been won.
- *"No package manager"* is the wrong noun. See §5.

The Go framing is load-bearing rather than decorative. Go's achievement was not
goroutines or interfaces; it was **deleting the argument** — one formatter, one
error convention, one build tool, no inheritance. Every "one way to do it" rule
scattered through `VISION.md` Part IV is that same move, and
`docs/ONE_WAY_LEDGER.md` is the collated form.

---

## 3. The conflicts

### 3.1 Who reads the code

| Source | Position |
| --- | --- |
| `README.md` | "Grug-brained simplicity". LLMs write Gust well *as a consequence* of a design aimed at human locality, not as its premise. |
| `VISION.md` §0.1, Part IV | Software is "never read by people"; therefore "verbosity is free"; therefore effects are annotated on every function with no inference. |
| `advice.md` | "AI can tolerate awkward syntax. Humans still debug production systems, review diffs, reason during incidents. Optimize for human comprehension first and machine manipulation simultaneously." |

**Resolution: the readership claim is a market observation, not a design licence.**

It is sound as a statement about where the industry is going and about what to
build first — containment, manifests, traces, structured diagnostics. It is not
a licence for ceremony, for three reasons:

1. `VISION.md` contradicts itself if read as a design licence. §0.12 lists three
   artifacts humans *do* read. §58 calls migrations "the one artifact still read
   by humans". §5 of this document describes a guarantee ledger that only works
   if someone reads it. Part XX's traces exist to be read.
2. Humans read code at exactly the moments Gust is sold for: incident response,
   review of an authority change, and security diligence.
3. It does not even hold for the machine. Every redundant token is a token that
   can be wrong. OD-9 gets *harder* as per-function boilerplate grows, not easier.

The rule that replaces "verbosity is free":

> **Explicit exactly where the explicitness is the artifact. Inferred everywhere
> else.**

Explicit, because someone reads them: authority (effects), ownership, error
propagation, resource lifetime. Inferred or desugared, because nobody reads them
and getting them wrong is a compile error anyway: context threading (§3.4),
codec plumbing, dispatch tables.

Applied to `docs/VISION.md` 2026-08-20: §0.1 and Part IV now carry this
qualification. Nothing else changed.

### 3.2 Async — coloured or transparent (OD-1)

| Source | Position |
| --- | --- |
| `async.md` | C# surface syntax: `async func`, `await`, `?` for failure. Rust state-machine lowering. Structured scopes, `spawn`, `race`, supervisors, linear task handles. Written as settled. |
| `VISION.md` §21 | *Prefers avoiding* function colouring; wants capability calls to suspend transparently; flags green threads / WASM stack switching as the cost. Open as OD-1. Written as settled in the other direction. |
| Implementation | Neither. See below. |

**What actually exists, verified:**

```
$ grep -c '"async"\|"await"\|"spawn"\|"scope"' compiler/lexer.gst src/lexer.rs
0
$ grep -n 'std\.Spawn\|std\.Channel\|std\.Yield' docs/STDLIB_SURFACE_INVENTORY.md
```

There are no async, await, spawn, or scope keywords in either lexer. Concurrency
is a library surface: `std.Spawn`, `std.Channel`, `std.ChannelNew`, `std.Mutex`,
`std.Yield`, over the cooperative fibers in `src/runtime/fiber.c`.

That is worth stating plainly, because it is the opposite of what both design
documents want:

> **The concurrency model Gust has implemented is detached `std.Spawn` plus
> channels — the Go model that `async.md`, `advice.md`, and `VISION.md` §20 each
> independently reject.** There is no structured scope, no task ownership, and no
> cancellation propagation.

**Recommendation (not a decision — owner is the Cranelift lane via
`SHARED_SEMANTIC_ZONE.md`, "Fiber scheduling contract"):**

> Take Go's suspension model. Reject Go's task model.

- **Transparent suspension**, no colouring. This resolves OD-1 in the direction
  §21 already prefers, and it is the single largest reason Go reads as simple.
  The expensive half — a cooperative fiber scheduler — is already built and
  shipping.
- **Never detached.** Every task belongs to a lexical scope that cannot exit while
  a child is live; children are completed, awaited, cancelled, or transferred.
  Task handles are linear resources, which is machinery Phase 15 already has.
- **Three named concepts, per `advice.md`**: child task (structured, request-scoped),
  supervisor (long-lived), durable job (survives restart). Not one `spawn` with
  adjectives.
- **`?` means may fail; suspension is invisible** because it is always owned.
  `async.md`'s rule that failure and suspension must not merge survives — it just
  ceases to need a keyword.

The §21 fallback — coloured async on the client, transparent on the server — is
worse than either option, because two concurrency models in a language whose
premise is one of everything refutes the premise. If WASM stack switching (OD-4)
proves unaffordable, restricting client code to event-driven dispatch with no
suspension is the better trade, and it is what the SAM model in Part IX already
implies: client code dispatches actions and returns effects; it never awaits.

**Blocking prerequisite:** this cannot be scoped until `std.Spawn`'s current
semantics are recorded as either deprecated or as the low-level primitive under
the structured layer. Today they are neither.

### 3.3 The C library ecosystem — `general-ecosystem.md` is retired

`general-ecosystem.md` proposes wrapping roughly fifty C libraries — libcurl,
libmicrohttpd, OpenSSL, libpq, sqlite3, hiredis, libmongoc, libmysqlclient,
cJSON, libxml2, libyaml, protobuf-c, libsodium, libssh, libpng, libjpeg-turbo,
OpenCV, SDL2, GLFW, GTK, zlib, lzma, zstd, FFmpeg, PortAudio, TensorFlow, ONNX,
libtorch, libusb, libpcap, PCRE2, libiconv, gettext — as the Gust standard
library, on the argument that C already did that work correctly.

**It is retired, and it is retired because it is load-bearing in the wrong
direction, not because it is unambitious.**

- `VISION.md` §93: "Native code is forbidden by default."
- `VISION.md` §98: "In-process native code weakens memory-safety and
  process-integrity guarantees **for the entire application instance**."
- `README.md`: the entire stated rationale for the Cranelift backend is that C's
  abstract machine — pointer provenance, effective types, signed-overflow
  latitude — is hostile to the arena-and-index model.
- `mir-to-cranelift.md` phases 22–25 and `TASK.md`: the roadmap arc is *removing*
  generated C, down to the bootstrap seed.

The contradiction is not a matter of degree. If an application links OpenSSL
in-process, the sentence "no code executes authority it did not declare" is false
for that application, by `VISION.md` §98's own terms. The containment thesis and
the C-ecosystem plan cannot both be true, and containment is the one being sold.

What replaces the library table, in one sentence: *a Gust-owned capability
interface may be implemented by a certified adapter, out-of-process by default;
the application names the interface and never the library.* That is `VISION.md`
§4 and §5, already written.

Two ideas in the document are good, are not about C, and would have been lost
with it. They are extracted to **Appendix A** (arena-based SAM topology) and
**Appendix B** (data-oriented interface registry) below.

### 3.4 Explicit `ctx` versus "simple like Go"

Every code sample in the corpus threads a context by hand:

```gust
mut v := std.VectorNew(ctx);
mut s := std.Clone(ctx, name);
func encode_PingInput(value: PingInput, ctx: &Arena) -> str
```

This is the largest visible divergence from Go-shaped simplicity, it appears on
essentially every line of application code, and it is a direct risk to OD-9: a
model with no corpus must thread it correctly every time.

`compiler-plan.md` Phase 5.3 already specifies the fix — `with ctx { ... }`
blocks and `func f() ... using ctx`, desugared to today's explicit form before
the semantic passes, with an allowlist of arena-backed stdlib functions and a
hard exclusion for unsafe, FFI, sandbox, and resource code. It files this as
late, optional ergonomics.

**Recommendation:** promote implicit context from optional ergonomics to a
prerequisite of the OD-9 experiment, keeping every restriction
`compiler-plan.md` places on it.

- Application code should not name an arena. The platform already owns the
  context kinds (`VISION.md` §24: scratch, request, task, job, application). A
  request handler runs *in* the request context; saying so once is enough.
- `VISION.md` §0.7 Track A0 already asks the equivalent question — "can an agent
  express this without knowing how the compiler represents it?" — and treats
  representation leakage as disqualifying. Threading `ctx` is the largest single
  instance of it and is not currently named as one.
- Safety is unaffected. It is desugaring, lowered before the passes that enforce
  anything.
- Compiler core, unsafe, FFI, and resource code stay explicit — which is exactly
  the rule from §3.1.

Testing OD-9 before this lands measures the wrong thing: it measures whether a
model can reproduce Gust's calling convention, not whether it can express intent.

### 3.5 Scope — the corpus specifies four products

Collectively the documents specify: (a) a systems language, self-hosted compiler,
and native backend; (b) a full-stack framework (gustrpc, SAM, templates, typed
Postgres); (c) a cloud platform (regions, preview environments, supplier
certification and revocation, LTS channels, governance); (d) an integrated SaaS
product (issues, support inbox, feature flags, team communication).

`VISION.md` §0.7 ("nothing but the demo"), §0.16, and `advice.md` ("build
vertically, not horizontally") all already say the right thing. The gap is that
`VISION.md` then specifies ~700 lines of the deferred material in the same voice
as the committed material, with no marker distinguishing them.

**Applied 2026-08-20:** every Part of `docs/VISION.md` now carries a
`COMMITTED` / `SPECULATIVE` / `DEFERRED` status line, and §0.16 carries the
legend. No prose was changed to do this.

### 3.6 Smaller conflicts

| Conflict | Resolution |
| --- | --- |
| `gust-fullstack.md` writes both `Result[T, E]` and `Result<T, E>` in one file | Bracket syntax. Trivial, but it is in a contract-defining document. |
| `full-stack-slice-0.md` defines `RpcResult[T,E]` beside `Result[T,E]` | One `Result`. The "one way" rule failing inside a document that argues for it. |
| `async.md` supervisors vs `VISION.md` §63 jobs vs `advice.md` durable jobs | `advice.md`'s three-way split: child task / supervisor / durable job. Adopted in §3.2. |
| `VISION.md` §55 typed queries vs §13 no user generics | Already resolved by §14 (compiler-owned derivation). Keep it visible — it is the answer to "why a compiler and not a library". |
| `compiler-plan.md` "freeze the language after Phase 6" vs VISION Parts IX–XVII | The freeze is Ring 1 only; the platform versions separately. Resolved by the ring model, §4. |
| `VISION.md` §27 says shared ownership "may" be provided as `Rc[T, ctx]`, open as OD-3 | `std.Rc`, `std.RcNew`, and `std.RcNode` are registered today (`docs/STDLIB_SURFACE_INVENTORY.md`). The decision was taken by implementation. §27 should be corrected or the surface justified. **Unresolved — routed to the Stdlib lane.** |

---

## 4. The ring model

From `advice.md`, adopted here because it resolves §3.5 and §3.6 mechanically:
every proposal is assigned to exactly one ring, and the ring fixes its stability
guarantee.

| Ring | Contents | Stability |
| --- | --- | --- |
| **1. Core language** | types, ownership and regions, errors, effects and capabilities, concurrency, modules, FFI boundary | Frozen at 1.0. Editions only. |
| **2. Platform** | HTTP, SQL, migrations, auth, jobs, mail, storage, crypto, telemetry, testing, UI runtime | One versioned release train. |
| **3. Application model** | routes, policies, schemas, tasks, transactions, client/server boundary, secrets, deployment resources — compiler-known | Versioned with the platform. |
| **4. Machine interface** | structured diagnostics, semantic index, edit protocol, patch verification, execution traces, behavioural diffing | Fast-moving. |

Two consequences worth stating:

- **Ring 1 must not contain web fashion.** SAM, Lit-style templates, and gustrpc
  are Rings 2–3. `compiler-plan.md` agrees ("prototype SAM as a normal library;
  promote into stdlib only after real-world validation").
- **Ring 4 is the moat.** Per `escaping-perpetual-underclass.md`, syntax is
  anti-moat — a model translates syntax cheaply. A compiler that answers *what
  routes exist, what does this handler touch, is this transactional, what changed
  semantically in this commit* is not cheaply reproduced. The corpus claims Ring 4
  heavily and specifies it thinly.

---

## 5. Dependencies and the guarantee boundary

`advice.md` supplies the framing ("replace *no package manager* with *no
uncontrolled dependency graph*"), `VISION.md` §98 supplies the mechanism
(guarantee boundaries). Combined:

> Gust has no dependency resolution. It has a versioned platform, certified
> capability providers, and explicit vendored source. **Every guarantee Gust makes
> is a function of which of those you used, and the compiler prints the
> difference.**

| Category | Example | Resolution | Guarantee |
| --- | --- | --- | --- |
| **Platform** | `use web`, `use sql.postgres`, `use jobs` | none — pinned by platform release | Full. |
| **Certified capability provider** | `storage` → S3 / R2 / MinIO; `payments` → Stripe | named interface, certified implementation, out-of-process | Full in-process. Egress narrows to declared purpose (§85). Revocable (§86). |
| **Vendored Gust source** | pinned revision, no transitive resolution, no build scripts, no network at build time | hash-pinned | Memory safety and containment hold; capabilities still enforced (§71). No support or migration assistance. |
| **Escape hatch** | in-process native code, `network.unrestricted`, arbitrary fs or process | signed adapter, human approval, expiry (§97) | **The named guarantee is forfeit, and the compiler says which.** |

### The mechanism that makes "forfeit" mean something

Three artifacts, all already specified in `VISION.md`, that should be built as
one feature rather than three:

1. **Capability manifest** (§17) — what the application may touch, in business
   terms: `payments.charge`, not `network.request<"stripe.com">`.
2. **Lockfile diff** (§72) — an authority *widening* shows up in review as a
   manifest change. The most important review surface in the design; currently one
   paragraph.
3. **The guarantee ledger** — proposed, does not exist. `gust guarantees` prints:

   ```
   memory safety        FULL       enforced by compiler
   containment          FULL       17 capabilities declared, 17 exercised
   reproducible build   FULL       content-addressed, 0 build scripts
   data egress          NARROWED   supplier:stripe — purpose "payments", 3 fields
   host isolation       FORFEIT    escape hatch "libvips" — in-process native,
                                   approved 2026-08-01, expires 2026-11-01
   ```

That output is the reviewable artifact §0.12 says humans actually read, and it
is what turns "you enter package-manager exploit hell" from a slogan into a
diff.

### On the phrase "no package manager"

Retire it. It reads as *you may not have functionality*, which is the version
`escaping-perpetual-underclass.md` identifies as fatal. The accurate claim is
narrower and stronger: **no resolver, no transitive graph, no lifecycle scripts,
no mutable registry, no network at build time.** All four are true, all four are
defensible, and none of them says you cannot have an image codec.

---

## 6. Where the implementation actually is

Verified 2026-08-20 against `b47d0049`. This section exists because four of the
nine documents describe the platform in the present tense.

**Built:** self-hosted compiler (712 `.gst` files, ~104k lines), arenas and
branded contexts, linear resources with move and borrow tracking, MIR, the
Cranelift backend through Phase 18, cooperative fibers with channels and
mutexes, 256 test programs, fixed-point bootstrap convergence, and the
lane/registry/guard governance in `AGENTS.md` and `docs/SHARED_SEMANTIC_ZONE.md`.

**Absent or divergent:**

| Required by | Thing | State |
| --- | --- | --- |
| §17, §18 | Effects in function types — *the differentiator* | No `uses` keyword in either lexer |
| §56 | Static tenant scoping — *the lead claim* | Absent |
| §55 | Typed Postgres derivation | Absent |
| OD-9 | Model fluency | Untested |
| Parts IX–XVII | HTTP, sockets, TLS, JSON, Postgres | None in `src/runtime/` |
| §20 | Structured concurrency | `std.Spawn` is detached; no scope keyword |
| §26 | Two-form borrow model | Corrected in VISION 2026-08-19 (#84): one mutable reference form, no aliasing analysis |
| §27 | Shared ownership as OD-3 | `std.Rc` already exists — see §3.6 |
| §34 | Panic terminates request, not deployment | `exit(1)` in `src/runtime/strings.c:20,30` |
| D-1, D-2 | Brand identity | Inferred from identifier spelling; `compiler/codegen.gst:658,762,896,1101`, `compiler/typechecker.gst:4953,5151`. Owned by staged Phase 19 |
| §32 | Fixed-width integers, overflow trapping, `Decimal`/`Money`/time types | **All absent.** One integer type, `int`, lowering to C `int` — so overflow is UB, not a trap. Issue #103 |
| §23 | `copyable` marker | Absent. Copy-versus-move is inferred structurally; adding a `str` field silently changes a struct's category |
| §29 | Automatic resource cleanup | Runs, but only for `Resource[T]` and only in the self-hosted compiler. The Rust compiler has none — zone defect D-6, issue #104 |

Found in the same sweep and worth recording as the counterweight — these hold:

| Section | Thing | State |
| --- | --- | --- |
| §31 | Enum match exhaustiveness | **Enforced in both compilers**, and both name the missing variant. `compiler-plan.md` still lists this as outstanding; it is done |
| §11 | Safe references non-null | Holds by construction — no `null`, `nil`, or `NULL` literal exists in either lexer |
| §12 | No inheritance, traits, or interfaces | Holds by construction — none of the keywords exists |
| §15 | No macros or compile-time execution | Holds by construction |
| §33 | `str` immutability | Holds — no mutation API and no element-assignment path |

The standard library is 20 `std_*` runtime symbols and 38 registered `std.*`
names (`docs/STDLIB_SURFACE_INVENTORY.md`, generated). It is not a place the
platform in Parts IX–XVII can be built yet.

**Effects, tenant scoping, and typed queries have no owning roadmap.** `TASK.md`
runs targets, objects, and linkers; `TASK_STDLIB.md` runs the safe stdlib
surface. Neither owns the three things `VISION.md` §0.7 calls the entire
deliverable.

This is sequencing rather than an oversight, and the sequence is deliberate. The
declared priority is retiring the C backend in favour of Cranelift, which is what
Phase 18 and the phases after it are. `README.md` argues the case: C's abstract
machine — pointer provenance, effective types, signed-overflow latitude — is
hostile to an arena-and-index model, so the native backend is what makes the
containment claim true rather than aspirational. E11 is a live example: integer
overflow is undefined behaviour today *because* of the C backend, and Cranelift
resolves that by having no such latitude to inherit.

`docs/DEMO_TARGET_PROGRAM.md` records what remains once that lands, so the
distance is written down and costed rather than rediscovered.
`TASK_STDLIB.md` CR-7 routes it.

---

## 7. The declared priority: retiring C

None of the nine documents states this as plainly as it needs to be, and it is
the single most useful thing to know when reading the rest of this file:

> **The current goal is retiring the C backend in favour of Cranelift.**

`mir-to-cranelift.md` describes the arc across phases 18–25 — target and linker
hardening, whole-program differential qualification, self-hosting through
Cranelift, the default-backend flip, then deprecating and finally deleting
MIR-to-C, and last the bootstrap seed. `TASK.md` is executing the front of it.
`README.md` supplies the argument for why it is not a performance project:

> Transpiling to C means inheriting **C's abstract machine**, not just its
> syntax: pointer provenance, effective-type rules, and signed-overflow latitude
> included. An arena-and-index model carves differently-typed objects out of one
> allocation and reconstructs pointers from a base and an offset, which is
> precisely the pattern those rules punish.

That is why this reordering is not up for debate in a reconciliation document.
Containment (§0.4) is the product, and containment expressed through a backend
that may legally optimise on the assumption your arithmetic never overflowed is
not containment.

### What it resolves, and what it does not

Worth separating, because it is easy to assume the transition fixes more than it
does.

**Resolved by the transition itself.** `docs/ONE_WAY_LEDGER.md` row 29 —
integer overflow is undefined behaviour rather than a trap — is a property of C,
not of Gust. Cranelift has no signed-overflow latitude to inherit, so the
weakest-possible-position problem goes away with the backend. `GEMINI.md` §C's
requirement that every variable in a function be uniquely named is the same
shape: it exists because the transpiler emits declarations into flat C function
scopes, and it is representation leakage that a native backend has no reason to
impose.

**Not resolved by it.** Everything the ledger records as `ABSENT` for want of
design rather than for want of a backend: effects (row 21), tenant scoping,
typed queries, `Result` and `?` (row 4), constructing an `Option` without
`unsafe` (row 3), structured concurrency (row 19), and §32's fixed-width types
and named arithmetic. A native backend does not write any of those.

The honest summary is that the transition is a precondition for the claim rather
than the claim. It makes the memory model true; it does not make the authority
model exist.

## Appendix A — Arena-based SAM topology

Extracted from `general-ecosystem.md` before its retirement (§3.3). This is the
argument for why Gust's memory model makes interactive UI *easier* rather than
harder, and it is the strongest answer to "why not write the frontend in
something else". Relevant to `VISION.md` §38 (OD-3).

Classical GUI architectures keep long-lived, mutually-referencing widget objects:
parents point at children, children at parents, listeners at both. In an arena
that is close to unworkable — you cannot free one node of a cyclic graph without
freeing the arena.

Unidirectional SAM removes the cycles by construction, and the three phases map
onto three arena lifetimes:

| Phase | Arena | Lifetime |
| --- | --- | --- |
| **Model** — flat, structured application state, reached by branded handles. No pointers to views. | long-lived application arena | process / session |
| **Action / proposal** — the event payload, presented to the model for a state change. | thread-local scratch arena | wiped immediately after dispatch |
| **View** — a pure function of state, `V = f(S)`. Draw commands, text layout, geometry. | frame-bound arena | wiped every frame in constant time |

What this buys, none of which requires a new language feature:

- **No circular references.** The view is a function of the model, so views never
  point at each other, at parents, or at siblings.
- **No listener leaks.** There are no subscriptions to forget to unsubscribe.
- **No `Rc<RefCell<T>>` equivalent.** Rust GUI libraries reach for shared interior
  mutability because the borrow checker rejects cyclic mutation; branded handles
  into an arena give temporal safety without refcounting.
- **Constant-time teardown, zero fragmentation.** The frame arena is reset with a
  single call.

## Appendix B — Data-oriented interface registry

Extracted from `general-ecosystem.md` (§3.3). This is the concrete implementation
of `VISION.md` §12's "small explicit function tables", and the reason §12 can ban
inheritance without giving up open polymorphism.

Conventional dynamic dispatch stores a vtable pointer inside every object, which
costs a dependent load per call, defeats inlining, and couples data layout to
behaviour. The alternative separates them:

- **Data** lives in flat, contiguous pools inside an arena, as plain structs with
  no embedded pointers. Cheap to copy, iterate, and sweep.
- **Behaviour** lives in a central registry — flat arrays of function pointers
  indexed by the value's handle, rather than one table per object.
- **Dispatch** is a single indexed lookup in the registry followed by a call,
  with the data pointer passed as an argument.

Properties that matter to Gust specifically:

- **Open polymorphism without inheritance.** Any module can register a new
  implementation against an existing interface.
- **Cache behaviour.** Function pointers and component data are both contiguous
  and predictable, instead of scattered across the heap.
- **Branded callback safety.** Brand the registry with the same context as the
  data and a stale handle cannot be dispatched — which is the failure mode
  (dangling callback) that makes dynamic dispatch dangerous in the first place.
- **Handles stay trivially copyable**, so polymorphic values remain integers and
  cross fiber boundaries without stack cost.
