# Messaging

**The document to read before a meeting.** Positioning currently lives in three
places — `docs/VISION.md` §2, `docs/STRATEGY_REVIEW.md` §6, and
`docs/BUSINESS_STRATEGY.md` — so anyone writing a pitch has had to already know
all three. This is the index.

**How it is built, and the rule that keeps it honest:** **quote the lines, point
at the arguments, and never restate a fact about the compiler.** A slogan does not
drift; an argument is better read at its source; and a claim about what the
compiler does today rots the moment someone lands a patch. Where this document
needs such a fact, it cites `docs/ONE_WAY_LEDGER.md` rather than repeating it.

---

## 1. The position

> **The complete application platform that humans direct and machines can
> reliably understand.**

One line under it, if one is wanted: **build the company, not the stack.**

The internal north star is different and should stay internal: *the language
designed for one developer and one million users.* It is a good compass and a bad
pitch — it claims universality before a single use case has been won.

**Supporting form:** one language, one application model, one compiler, one
deployable system.

*Source: `docs/STRATEGY_REVIEW.md` §6.*

---

## 2. Who is in the room

Three roles, and only one of them is the buyer.

| Role | Who | What they experience |
| --- | --- | --- |
| Chooses | The end user | A toggle and a guarantee |
| Writes | The model | Gust, because it was trained to |
| **Carries the risk** | **The platform** | **Fewer incidents attributable to generated code** |

**Nobody in that table reads Gust.** Sell to the third row. The first row's
willingness to pay is near zero until after a breach.

*Source: `docs/VISION.md` §2. Prospect count — ten to fifteen globally — at §0.8.*

---

## 3. The claim, and its exact boundary

> **The compiler rejects compiler-owned typed queries whose scoped-entity
> obligations are not discharged by matching trusted tenant provenance.**

**Say `enforce`, `check`, `reject`. Never say `prove`.** That is a rule, not a
style preference — `docs/VISION.md` §79 sets it, because this is static
enforcement backed by generated conformance tests, not formal verification. **One
misplaced "proven" converts a defensible claim into one a competent reviewer can
retire in a sentence.**

**The claim does not cover** caches, messages, jobs, object storage, non-query
reads, multi-step flows, unsafe/raw SQL, or establishment of the trusted request
context. Saying so first is stronger than being caught by it. **The claim is
about the compiler-owned typed-query path, so make it about that path.**

*Source: `docs/VISION.md` §56 and §56.2; the boundary at §56.2's closing note.*

---

## 4. The three questions you will be asked

### "Why not just train the model to write scoped queries?"

The strongest objection, and it falls out of our own thesis — if the lever is the
generator, fixing the generator is cheaper than adopting a language.

> **A model that reliably writes scoped queries is a probabilistic control. A
> compiler that rejects unscoped ones is a deterministic one — and the party
> carrying the risk cannot buy a probability.**

A platform that has trained the leak rate down to one in ten thousand has
improved its product and has **not** changed what it must say to a customer after
an incident, to an auditor, or in a contract.

**Say next: training and Gust are complements.** The generator gets better *and*
the output is checked. Anyone who frames this as *our compiler versus your model*
has picked a fight with the buyer's core competence.

*Argument in full: `docs/BUSINESS_STRATEGY.md` §2.1.*

### "Why not row-level security?"

**Concede first — RLS is real enforcement, in the database, today, with no new
language.** Then the distinction:

> **RLS rejects the row. Gust rejects the program.**

A query that forgets scoping still ships and still runs; it is caught only if the
policy is present, correct, and enabled on every table. One missing policy on one
table leaks every tenant at once.

**Be able to raise this unprompted.** The first competent buyer will, and a pitch
that has not metabolised it will not survive that meeting.

*Argument in full: `docs/BUSINESS_STRATEGY.md` §2.*

### "Why a new language? What about the ecosystem?"

The ecosystem objection assumes human authors. **Reframe rather than argue the
premise:** the guarantee is not for the writer, it is for the operator of the
writer.

And the dependency claim is narrower and truer than the slogan it replaced:
**not "no package manager" — no *uncontrolled dependency graph*.** Versioned
platform, curated modules, explicit vendored code, reproducible builds, declared
capabilities. **No transitive resolution, no lifecycle scripts, no network access
during builds, no mutable registry state.**

*Sources: `docs/STRATEGY_REVIEW.md` §3–§4; `docs/VISION.md` §70, §72, §98.*

---

## 5. What can honestly be said today

**The single most important section, because the fastest way to lose a technical
buyer is a claim their engineer disproves in the room.**

Do not copy a dated implementation summary into meeting material. Refresh it
from `docs/ONE_WAY_LEDGER.md`, the active roadmaps, exact merged commit, and
closure artifacts immediately before the meeting.

- **Do not describe the effect system in the present tense.** There is no `uses`
  keyword in either lexer.
- **Do not turn OD-8's bounded positive verdict into application-wide tenant
  isolation.** It covers the predefined compiler-owned typed-query suite and
  explicitly excludes the paths listed in §3 above.
- **What is real today** is the compiler, the arena and brand model, the resource
  and move semantics, the native backend work, and a self-hosted bootstrap.
- **Regenerate the ledger counts before the meeting.** They move, and a stale
  number here would be exactly the kind of unchecked fact this document warns
  against. Count rows in
  `docs/ONE_WAY_LEDGER.md` whose status cell contains `**HOLDS**`, `**PARTIAL**`,
  `**VIOLATED**`, `**DEFERRED**` or `**ABSENT**` — one status per table row — and
  use those numbers instead of these.

**The honest frame for a demo-stage conversation:** this is a well-specified
hypothesis with a working compiler underneath it, a bounded typed-query verdict,
and independent technical, generation, commercial, and defensibility gates.
That is stronger than a polished overclaim, **and it is the frame the ledger
makes available and almost nobody else can offer.**

---

## 5.1 What to show

**The artifact is the rejection diagnostic**, not a running application. A compile
error is thirty seconds of nothing happening and it needs a narrator — that cost is
recorded and accepted at `docs/WEB_SLICE_0.md` §4, where the demo question was
decided. **Plan the narration; do not hope the error speaks for itself.**

**Bring the ledger.** `docs/BUSINESS_STRATEGY.md` §4 argues it is the diligence
asset, and it is the one thing here a competitor cannot cheaply imitate:

> A project that scores its own claims against its own compiler and publishes where
> it falls short is making a credibility claim no pitch deck can make. **It converts
> *we believe* into *we checked, and here is where we were wrong*.**

**Do not show the full-stack loop.** It is more legible and it proves the weaker
claim, and legibility is worth less to someone assessing a liability than to a
conference audience. It is sequenced after the demo, deliberately.

## 5.2 What to measure after the demo

The first side-by-side is a selected mechanism demonstration. Call it that. Do
not turn one chosen TypeScript failure into a prevalence claim or say it proves
Gust beats a production-strength generator stack.

The next evidence artifact is `docs/GENERATION_SECURITY_BENCHMARK.md`: the same
frontier agent builds realistic multi-tenant applications against conventional
Next.js/Postgres, a hardened RLS-and-security-gate baseline, and Gust. Lead with
**secure functional completion under a fixed agent budget**, then show the
separate security, task-completion, iteration, token, latency, and human-repair
results.

**Do not say the benchmark exists today.** Its protocol is adopted; its Gust arm
still waits on effects, typed queries, tenant analysis, a Postgres capability,
and traces. The benchmark must also be allowed to show that the hardened
TypeScript arm is good enough or that Gust is too costly for a model to use. If
it cannot hurt the thesis, it cannot help the pitch.

## 5.3 Post-Cranelift launch

The coordinated Cranelift outreach occurs only after Phase 25 and the complete
tail in `docs/ROADMAP_TAIL.md` close. `docs/CRANELIFT_LAUNCH.md` owns its claim
ladder, proof package, upstream factual review, outreach waves, and falsifiers.

This does not postpone all relationship development. At each credible material
milestone, `docs/EVIDENCE_LED_OUTREACH.md` governs evidence cards, recipient
research, individualized drafts, operator rewrite and approval, the relationship
ledger, and feedback routing. Phase 20–24 may therefore support narrow private
technical contact, but not a coordinated public Cranelift campaign.

The launch target is a Level-3 statement: the self-hosted compiler builds and
runs through the native path and normal supported bootstrap no longer requires
generated C or a host C compiler, with the Rust adapter and optional
foreign-runtime boundary stated honestly. Use only the exact wording supported
by the final closure evidence.

Do not announce a “world first,” “no Rust,” whole-language coverage, formal
verification, blanket memory safety, or production readiness. The event earns
technical credibility and relationships; it does not establish the governed web
stack, OD-9, adoption, product-market fit, or acquisition demand.

## 6. What not to say

- **"Proven" or "verified"** — §79. Enforce, check, reject.
- **"Zero third-party runtime dependencies."** Say *most Gust applications
  require no developer-managed runtime dependencies.* Longer and true beats short
  and falsifiable.
- **"No package manager."** Replaced by §4 above; the old line invites *"then how
  do I use anything?"* and names no real failure.
- **"Walled garden."** Say *one blessed path, with narrow and explicit
  interoperability boundaries* — or *closed implementation, open escape hatches.*
- **"We certify our suppliers."** Not until OD-5's commercial half is settled.
  `docs/VISION.md` Part XVI carries this warning directly: **saying it is cheap;
  being it is a payroll line.**
- **Any comparison to Rust or Go as the competitor.** It flatters us and it is a
  category error — nobody choosing between Gust and Rust is the buyer in §2.
- **A Cranelift historical “first” claim without the exact category and upstream
  confirmation.** “One of the first” still requires private factual review;
  ordinary search is not enough.
- **“Gust contains no Rust.”** The compiler frontend may be Gust while a narrow
  Rust adapter integrates Cranelift and runtime components may remain.

---

## 7. If you have sixty seconds

> Most application code is now written by models, and it is read by almost nobody.
> The failure that matters is not a crash — it is a query that quietly forgets
> which tenant it belongs to, ships, and leaks everyone at once.
>
> You can train that down. You cannot train it away, and *rarely* is not a
> sentence you can put in a contract or give to an auditor.
>
> **Gust is building a compiler-owned typed-query path where a scoped entity
> without matching trusted tenant provenance does not compile.** The guarantee
> is narrow and deterministic rather than a policy someone must remember.
>
> The compiler exists and is self-hosted. OD-8 has a bounded positive verdict for
> its predefined typed-query attack suite; agent fluency, the production-shaped
> containment system, buyer demand, and defensibility remain separate gates.

**That last paragraph is not a hedge — it is the differentiator.** Everyone in
this market is claiming; the credible move is being specific about what is not
built yet and when it will be known.

---

## 8. Sources

| For | Read |
| --- | --- |
| Market positioning, who buys, timing | `docs/VISION.md` §2, §0.8, §0.9 |
| Lines and framing | `docs/STRATEGY_REVIEW.md` §6 |
| Buyer question, competitor, objections, risks | `docs/BUSINESS_STRATEGY.md` |
| Continuous individualized outreach and relationship learning | `docs/EVIDENCE_LED_OUTREACH.md` |
| Post-Phase 25 technical launch and outreach | `docs/CRANELIFT_LAUNCH.md` |
| The claim and its boundary | `docs/VISION.md` §56, §56.2 |
| External-language rule | `docs/VISION.md` §79 |
| What is actually true today | `docs/ONE_WAY_LEDGER.md` |
| Open decisions and their status | `docs/VISION.md` §0.15 |

**This document indexes; it does not decide.** Where it and a source disagree,
the source wins — and where it and someone who has had a customer call disagree,
**the call wins.**
