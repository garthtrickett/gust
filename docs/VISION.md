# Gust — The Agentic Software Vertical

**Product, Language, Runtime, and Platform Decisions**

> **What this document is.** A well-specified hypothesis with nine open questions. Two of them — **OD-9** (can a model write Gust) and **OD-8** (is the scoping analysis sound) — can invalidate the thesis outright, and both resolve inside the next four months. The prose is confident because vague prose cannot be attacked; the uncertainty is real and lives in §0.15. Read that table before treating any of this as settled.
>
> **The plan is four months long.** Build the demo (§0.7). Do not pick a business until it exists (§0.8). Everything past §0.16 is a specification of a system that is deliberately *not* being built yet — it exists so that demo-stage decisions do not foreclose it, and most of it should never be built by us.

---

# Part 0 — Strategy

## 0.1 Thesis

**Gust is built for software that is written by machines and never read by people.**

Humans own intent, authority, and outcomes. The compiler owns everything in between.

Nearly every language design decision since the 1970s optimises for human reading. As teams stop reading the code they ship, that constraint lifts and most of the design space reopens.

The claim is about **readership**, not authorship. Authorship shifting to machines is the visible change. Readership collapsing is the one that breaks the stack, because review is the trust mechanism everything downstream depends on, and you cannot review what nobody reads.

**What this thesis licenses, and what it does not.** It is a claim about the market and about build order: it says to invest in the artifacts that replace reading — manifests, lockfile diffs, traces, structured diagnostics, conformance checks — ahead of the artifacts that assist reading. It is **not** a licence for ceremony in the language, and it must not be cited as one.

Three reasons it cannot carry that weight. This document contradicts itself if it does: §0.12 lists three artifacts humans *do* read, §58 calls migrations "the one artifact still read by humans", and Part XX exists to produce traces for someone to look at. Humans read code at exactly the moments Gust is sold for — incident response, review of an authority change, security diligence. And it does not hold for the machine either: every redundant token is a token that can be wrong, so OD-9 gets harder as per-function boilerplate grows, not easier.

The operative rule is therefore narrower than "nobody reads it":

> **Explicit exactly where the explicitness is the artifact. Inferred everywhere else.**

Explicit, because someone reads them: authority, ownership, error propagation, resource lifetime. Inferred or desugared, because nobody reads them and a mistake is a compile error anyway: context threading, codec plumbing, dispatch tables.

See `docs/VISION_RECONCILIATION.md` §3.1, which records the conflict between this section and `README.md` and how it resolves.

## 0.2 The problem: a flood that aggregates nowhere

People build applications by asking an AI. The AI writes the code. Nobody reads it. A meaningful share of those applications ship a bug where every user can see every other user's data — missing tenant scoping, the canonical failure of generated software.

**These are not CVEs, and that difference is the whole opportunity.**

A CVE aggregates. It gets an identifier, lands in a vulnerability database, triggers automated alerts, appears in compliance reports. Somebody counts, and the count creates pressure.

A generated app that forgets to scope its queries gets none of that. No advisory, no identifier, no registry, no patch to apply. It is one company's bad week, and the next one is a different company's bad week. Nothing anywhere turns a thousand of those into a number.

So the pain is real, growing, and **invisible** — not because it is small, but because nobody is counting. That has two consequences, and they point in opposite directions:

- **Bad:** there is no market pressure yet, so nobody is shopping for this.
- **Good:** whoever starts counting defines the problem (§0.9).

## 0.3 Why a language and not a scanner

The reflexive response to a security panic is the thing you can buy next quarter: scanning, policy, insurance, a checklist. A language is a two-year decision.

Structural fixes still win, every time:

| Bug class | What ended it | Elapsed |
|---|---|---|
| SQL injection | Parameterised queries — structural | ~15 years |
| XSS | Auto-escaping templates — structural | ~10 years |
| Memory unsafety | Rust, plus government pressure — structural | ~40 years |

Scanners were sold throughout all three. None of them ended the problem. The structural fix did — and took a decade or more each time, because ending a bug class meant changing millions of individual developers, one codebase at a time.

**Here you have to change roughly ten generators.**

The centralisation of code production is the genuinely new variable and the strongest argument in this document. One provider flips their build surface to a verified mode and millions of applications change in a single release. No previous structural fix had that lever.

> Every strategic decision should be judged on whether it moves us closer to being what a generator emits by default.

## 0.4 What Gust sells: containment, not correctness

Agent-authored software fails in two ways:

- **Unauthorized** — it touches something it should not. Leaks data, calls the wrong service, exfiltrates a secret. *Catastrophic per incident, rare in volume.*
- **Incorrect** — it does the wrong thing within its authority. Charges the wrong amount, drops the record. *Survivable per incident, constant in volume.*

Capability enforcement solves the first completely. Nothing in this document — or in any shipping system — solves the second.

By volume, incorrect vastly exceeds unauthorized. So why does this document spend most of its length on capability? **Because capability is tractable and intent is not.** Capability enforcement is a solved design problem; Austral and WASI demonstrate it works. Intent checking — mechanically confirming a program does what was asked — is an open research problem nobody has solved at application scale. Leading with the unsolved half is how you never ship.

State the claim precisely:

> **Gust makes agent-authored code containable. Containment is shippable now. Correctness is the frontier.**

Containment means the blast radius is bounded, declared, and visible in a diff. It does not mean the program is right. Anyone who reads this document and concludes Gust makes agent code trustworthy has been oversold, and the document is at fault.

Three consequences: the demo sells containment and must say containment; the intent layer (Part XXI) is roadmap, not launch, and blocks v0.5 rather than v0.1; and the long-term thesis needs both — containment alone is a good security product with a ceiling.

## 0.5 The four layers

**1. Language — agent-writable, machine-verifiable.** Explicit effects, no ambient authority, one canonical way to express intent. Small surface, minimal idiom drift. Verbosity is free when no human types or reads it, so everything is explicit and nothing is inferred.

**2. Runtime — verifiable execution substrate.** Capability manifests, no install-time execution, content-addressed reproducible builds. Determinism is the precondition for everything above and below it.

**3. Framework — the full-stack surface.** So agents have a canonical target and a buyer has something recognisable to adopt.

**4. Platform — the loop.** Generate, compile, run, trace, revise. Structured traces are the artifact; iteration count is a quality input.

Only layers 1 and 2 matter before the demo. Layers 3 and 4 are how an acquirer productises it.

## 0.6 Where it stands today

Grounded in the repository, not aspiration.

| Area | State |
|---|---|
| Contexts and arenas | Deeply built |
| Linear resources, destructors, move/borrow tracking | Substantial |
| Ownership and region-based memory | Working |
| MIR, Cranelift backend, ABI, runtime imports | Working, under active development |
| Test suite | Several hundred files |
| **Effects in function types (§17, §18)** | **Absent** |
| **Static tenant scoping (§56)** | **Absent** |
| **Typed Postgres query derivation (§55)** | **Absent** |
| **Model fluency in Gust** | **Absent** |

**Everything built is table stakes. Everything missing is the product.**

The memory model, resources, and arenas are the conventional core of a systems language — a great deal of work, done fast, and Austral already demonstrated the design is tractable. It is throughput-bound work and the demonstrated throughput is high.

The four absent items are different in kind: less code, more design, and design does not compress the way implementation does. Making tenant-scope enforcement *sound* rather than approximately right is where the risk now lives.

The risk profile has shifted, not shrunk: from *can they build a compiler* — answered — to *can they design an effect system and a sound scoping analysis*.

**Measured 2026-08-20 at `b47d0049`.** 711 `.gst` compiler files, 103,789 lines; 260 test programs; Phase 18 at 13 of 20 patches. "Several hundred files" above is 260, and is a count of test programs rather than of assertions.

**One qualification on "everything built is table stakes."** It reads as though the built rows are settled. In `docs/ONE_WAY_LEDGER.md`, four of the design rules they rest on are recorded as violated and one was withdrawn to match the compiler. None of the five is currently scheduled:

- **Brand identity** is inferred from identifier spelling, not from types, and the two compilers use different matching rules for it (D-1, D-2). Until Phase 19 lands, "ownership and region-based memory — working" is true of the design and approximate in the implementation.
- **Panic scope** (§34): a string bounds failure calls `exit(1)` and takes the process down rather than the request.
- **Shared ownership** is marked open as OD-3 while `std.Rc` already ships.
- **Concurrency** is detached `std.Spawn` plus channels — the model §20 rejects.
- **Integer overflow** is undefined behaviour on the default backend, not the trap §32 promises: `Type::Int` lowers to C `int`, where signed overflow is UB (issue #103).
- **The borrow model** is the withdrawn one. §26 was corrected on 2026-08-19 to the single mutable reference form that exists — `inout` is not a keyword in either compiler — so there is no longer a rule being violated, only a containment property that nothing delivers.

This does not change the conclusion that the absent items are the product. It changes what "built" is load-bearing for: the memory model is not yet sound enough to be *demonstrated*, which matters because containment is what is being sold (§0.4).

## 0.7 What to build next

Nothing but the demo. Two tracks, both starting in week one.

**Track A — the compiler.**

1. **`uses` clauses in signatures.** Effects declared on every function, no inference (§17).
2. **Effect checking across the call graph.** Undeclared authority is a compile error.
3. **Typed Postgres queries** via compiler-owned derivation (§14, §55).
4. **Tenant scope as a tracked property of query construction.** Unscoped queries rejected (§56).

**Track B — model fluency (OD-9).**

Synthetic corpus, evals, and whatever fine-tuning or prompt-level scaffolding it takes to make an agent write Gust well.

**This runs in parallel from week one, not after the compiler is finished.** It is the most underweighted item in this document. Nobody has made a frontier model fluent in a language with no corpus; you would be bootstrapping from a few thousand lines of your own examples. It may be harder than everything in Track A combined, and if it fails the readership thesis (§0.1) collapses outright — the entire argument is that nobody needs to learn Gust except the model.

Discovering that in month three is survivable. Discovering it in month fourteen is not.

**Then:** one recognisable multi-tenant application — issue tracker or support inbox — **agent-generated**. Not a todo list.

**Estimate: 2–4 people, 3–4 months, low single-digit millions — plausibly bootstrappable.**

Bootstrapping through the demo is worth real sacrifice, for two reasons. Arriving at a buyer conversation with no cap table, no board, and no clock is the strongest negotiating position available at this stage. And more practically, the motion after publication is slow (§0.8) — runway is what makes a year of waiting survivable rather than fatal.

### The deliverable

A published, third-party-reproducible side-by-side. The same specification handed to an agent targeting TypeScript and Postgres, and to an agent targeting Gust. The first reproduces the cross-tenant data leak. The second does not compile until it is fixed. Complete traces published: every capability declared, every one exercised, every authority attempt rejected.

That artifact is the entire asset at this stage. Everything else is scaffolding around it.

### Track A0 — the floor under both tracks

Two prerequisites sit underneath Track A and Track B rather than beside them.

**The native backend.** The README's "Two backends, and why" section argues the case: transpiling to C means inheriting C's abstract machine, and an arena-and-index model is precisely the pattern its rules punish. The Cranelift backend is what makes "the compiler carries the danger" true rather than aspirational. It is not a performance play and it is not deferrable to post-demo, because containment (§0.4) is what is being sold.

**A stdlib an agent can actually write against.** OD-9 asks whether a model can write Gust well. That question is not answerable while ordinary operations still require representation-aware code — comparing two strings, calling a method on a collection held by reference, cloning into an arena reached through shared state. An agent that must know that `str` is a slice struct is not being tested on fluency; it is being tested on compiler trivia. Every such workaround is also a line of corpus teaching the wrong thing.

Track A0 is scoped by a single question: **can an agent express this without knowing how the compiler represents it?** Work that answers yes belongs here. Work that merely makes the language richer does not, and the paragraph below still applies to it in full.

### Explicitly not next

- **More language surface.** Better generics, nicer syntax, richer patterns. The temptation will be constant and every week spent there is a week the demo does not exist. Track A0 is not an exemption from this: it is bounded by removing representation leakage from operations that already exist, never by adding expressive power. A stdlib change that makes something newly *possible* rather than newly *writable* is more language surface, and belongs here.
- **Any business.** See §0.8 — the decision is deliberately deferred.
- **Deployment platform, jobs, realtime, suppliers.** All post-demo.

## 0.8 The play

**Build the demo. Do not pick the business yet.**

That is the decision, and it is deliberate rather than indecisive. Every candidate business — containment substrate, an integrated product, regulated verticals, training environments — requires the identical next four months. There is no path that skips effects, tenant scoping, and model fluency.

More decisively: **OD-8 and OD-9 are thesis-invalidating and both resolve inside those four months.** If the scoping analysis has a hole, or a model cannot write Gust well, every downstream option dies simultaneously. Choosing a go-to-market before knowing whether the mechanism works is how a year gets spent on the wrong thing.

So the demo is not a step toward a strategy. **It is the instrument that selects the strategy.**

### Then, if the demo holds: the integrated product

The most likely second move is an integrated development-and-support product — issue tracking, support inbox, feature flags, team communication, git integration — built on Gust and agent-generated.

**Why this and not something else:**

- **The cost-structure argument is genuinely good.** All-in-one has always lost because building five good products was prohibitively expensive, producing either mediocre-at-five or excellent-at-one-and-creeping. If code is cheap, that changes. This is our own thesis producing its first commercial consequence, not an unrelated product idea.
- **It is the same work as v0.5.** The substrate — workspaces, identity, roles, permissions, objects, comments, notifications, search, audit — is Gust's framework layer (Parts III, X, XI) with a price attached. Not a detour.
- **The seams are the product.** Five separate tools means five identities, five permission models, five notification streams, and nothing that knows the whole story. Those vendors will never merge, so the seam is permanent unless someone builds across it. Pitch **one data model, several surfaces** — never "five tools in one," which invites the bloatware comparison.
- **No enterprise sales.** Self-serve, credit card, no procurement. This is a hard constraint (§0.16), not a preference to be argued out of.

**Build order:** substrate → feature flags → issues → support inbox → communication. **Integrate git hosting; do not rebuild it** — code review and CI are a decade of work for no differentiation, and teams will happily keep PRs elsewhere provided they are linked.

**Migration tooling is a first-class surface from day one.** Nobody evaluates an all-in-one on merits; they evaluate on whether four years of history comes with them. This is where comparable attempts die.

### If acquisition happens

Not a plan to execute, but the likely terminal outcome and worth being ready for.

**Buyers:** model providers with a build surface, and AI app-building platforms. Roughly ten to fifteen real prospects. They are not buying a compiler — they are buying **a known liability removed plus three years of calendar.**

| Their objection | The answer |
|---|---|
| "We can build this" | You can. In three years, with compiler engineers you are not hiring, while your whole org is pointed at models. |
| "We won't depend on a startup for a core surface" | Language spec and reference compiler are open. And the exit conversation is available from day one. |
| "Has anyone run this in anger?" | The product, in production, with paying customers and no cross-tenant incidents. |

That last row is why the product matters more than the demo eventually. *A genuinely complex production system, agent-generated in Gust, publicly inspectable, with no cross-tenant incidents* is stronger evidence than any case study, and it is obtained without a single procurement call.

**Open-core.** Open: language specification and reference compiler — credibility, adoption, and the answer to dependency risk. Proprietary: verified runtime, trace infrastructure, conformance tooling, scoping analysis implementation. Open-sourcing everything destroys the leverage.

### The motion

**Publish, do not pitch.** A reproducible artifact showing a data-leak class becoming a compile error circulates in the three communities that matter — compiler people, AI-safety researchers, app-builder engineers.

But *publish and wait* is not a plan. Passive publishing buys one good week and then silence. Four things make inbound actually happen:

**Two audiences, two artifacts.**

| Artifact | Audience | Function |
|---|---|---|
| **The demo** (§0.7) | Compiler people, AI-safety researchers, app-builder engineers | Technical proof |
| **The statistic** (§0.9) | Journalists, analysts, whoever at a platform has to answer for it | Makes the problem legible to people who will not read a compiler error |

The demo alone is a neat trick nobody has a budget line for. The statistic alone is a scary number that sells scanners.

**Named people, not the internet.** Once public, send it directly to specific engineers and researchers at each prospect. Not a pitch — *built this, thought you would find it interesting.* That is how it reaches an internal channel.

**Warm introductions beat everything.** Existing relationships are the cheapest asset available and worth more than any volume of posting.

**Expect a long lag.** An engineer sees it, mentions it internally, three or more months pass, someone reaches out. Do not reinterpret month two as failure.

**Parallel, never exclusive.** Every prospect at once, none told they are the only conversation. That is the entire pricing power.

### Options considered and rejected

Recorded so they are not relitigated, and so the reasoning is available if conditions change.

| Option | Verdict |
|---|---|
| **Verified RL environments for labs** | Good business, **Gust is incidental to it.** Determinism, sandboxing, and generated test suites are achievable from a formal spec plus a generator in any language. Only completeness of the derived negative-test set is genuinely Gust-shaped, and that is narrow. Someone should build this; it does not need a compiler. |
| **Regulated verticals** (healthcare, fintech internal tools) | **Probably the best business on paper and the wrong one for us.** Present-tense blocked demand, Gust genuinely essential — an auditor asking "how do you know user A cannot see user B's records" gets a categorically better answer from a compiler than from a policy file. Killed by 6–18 month sales cycles, SOC 2 and BAA overhead, and needing full v1.0 rather than the demo. Revisit only if the team composition changes. |
| **Scanner / statistic as a product** | Revenue sooner, and it manufactures the market pressure we are otherwise waiting for. But becoming the scanner company makes us the cheap fix rather than the structural one. Run it as marketing with a price tag (§0.9), never as the destination. |
| **Agent governance runtime for enterprises** | Existing budget line, large buyer set — but delivered over existing languages, so Gust is optional again, and it is a real enterprise sales motion. |
| **Containment substrate, publish and wait for acquisition** | The original plan. Survives as the *frame*, not the near-term activity — there is no urgent buyer today (§0.2), so waiting passively wastes the interval that the product would otherwise fill. |
## 0.9 Manufacturing the statistic

If nobody is counting (§0.2), the entity that starts counting defines the problem. Snyk built the npm vulnerability database and became the authority on npm risk. Chainguard made CVE counts in base images a number people report.

**Scan public AI-generated deployments. Publish the rate.** *"We examined N applications built with AI app builders. X% expose data across users."* Repeat quarterly.

This runs **alongside** the demo, months 0–3 (§0.14), done by someone who is not on Track A or B. Three reasons it earns a parallel track rather than waiting:

1. **Cheap and fast.** Weeks, not months, and it does not compete with compiler work for the same person.
2. **It is customer research.** It reveals whether tenant scoping actually dominates the bug distribution. If the top failure turns out to be exposed credentials, §56's centrality is wrong and we need to know before building the product around it.
3. **It makes us the named alternative before the moment arrives** — which decides who wins when it does.

Do this ethically: public deployments only, responsible disclosure to affected operators before publication, aggregate statistics rather than named victims. The credibility of the number depends entirely on how it was obtained.

**Do not become a scanner company.** The scanner is the argument, not the product. It is the cheap fix we expect the market to reach for first, and being known for it makes us harder to distinguish from it.

## 0.10 The numbers

Earlier drafts modelled direct-to-team SaaS, platform licensing, and first-party product margin. All three are withdrawn — each assumed a business chosen before the mechanism was proven, which is the error §0.8 exists to avoid.

**Cost to the demo:** 2–4 people, 3–4 months, low single-digit millions. Plausibly bootstrappable. **This is the only number that requires a decision today.**

**If the product path follows:** 18–24 months to something sellable even with agent leverage, most of it the substrate. Self-serve, $30–60 per user per month, plausible path to **$1–5M ARR in three to four years** if migration tooling works. A real company, not an outcome on its own, and won on product and integration rather than on anything Gust does — customers will not care what it is written in.

**If acquisition follows:** priced on strategic necessity, competitive tension between bidders, and how acute the liability feels at that moment. Genuinely wide range; the variable is almost entirely whether more than one buyer wants it.

### Honest odds

| Outcome | Probability |
|---|---|
| Thesis fails on OD-8 or OD-9; four months spent finding out | ~30% |
| A good compiler, a small product with some customers, no exit | ~50% |
| Product works, artifact is compelling, acquisition | ~20% |

Not a strong expected value in dollars. A very good one for four months of work at the demonstrated rate, and the downside is bounded in a way almost nothing in this space is.

**The number to hold onto is not the exit.** It is that the decision point is a few million over three to four months rather than $80M over four years, and that the 30% branch is the cheapest possible way to be wrong.

## 0.11 Principal risks

Ordered by what actually threatens the plan, not by how alarming they sound.

- **Model fluency (OD-9) — the top risk.** Nobody has made a frontier model fluent in a language with no corpus. If it fails, the readership thesis fails with it, because the whole argument is that only the model needs to learn Gust. Most underweighted item in this document, hardest to estimate, and the reason Track B starts in week one (§0.7).
- **A soundness hole in the scoping analysis (OD-8).** One counterexample kills the only claim we make. Someone adversarial must attack it before anything is published.
- **Distribution — unsolved.** For the product path this is as hard as the build, and there is currently no answer. Self-serve prosumer SaaS in a crowded category with no marketing budget. Think about it early rather than discovering it at launch.
- **The product eats the compiler.** Modest traction, support tickets, churn, a customer wanting SSO — and eighteen months later there is a small business and a stalled language. Most likely slow failure, and it does not announce itself. Mitigations: self-serve only, refuse every enterprise request, cap the feature surface deliberately, treat revenue as runway rather than a metric.
- **The freakout produces a scanner, not a language.** Incidents continuing is near-certain; the market reaching for a structural fix is not. **Budget for losing the first wave.** History says the second one arrives, slowly (§0.3).
- **Taste does not get cheaper.** Agents make code cheap; they do not make product decisions. Several surfaces means several sets of judgment calls about what to leave out, and the all-in-one graveyard is full of teams who got the code right and the decisions wrong.
- **Migration, not features, decides adoption.** Nobody evaluates an integrated product on merits — they evaluate on whether their history comes with them.
- **A buyer builds it in-house first.** Window roughly 24–36 months, now existential rather than competitive. Demonstrated velocity is the main defence.
- **No forcing function ever arrives.** The market may settle into permanent tolerance the way it did with compromised WordPress sites. §0.9 is the mitigation — manufacture the pressure rather than wait.
- **Model capability routes around the problem.** If models become reliably good at writing correct code inside capability wrappers over existing languages, the language-level advantage compresses.
- **Scope discipline.** §0.15 is the defence and must be enforced in review.
## 0.12 What humans actually do

If nobody reads the code, the source file is not the primary artifact. Three things replace it:

| Human owns | Artifact | Status |
|---|---|---|
| **Authority** — what may it touch | Capability manifest and lockfile diff (§17, §72) | Specified |
| **Outcomes** — what did it do | Structured execution trace (§108) | Specified |
| **Intent** — what should it do | *Nothing yet* | **Missing — Part XXI, OD-6** |

Gust's interface is the authority diff, not the editor.

**The failure mode inverts.** Human code fails from misunderstanding — the author missed a case. Types and review catch that. Agent code fails from **plausible-but-wrong**: it compiles, type-checks, reads well, and does something subtly different from what was asked. Types do not catch that. Review does not catch it if nobody reads. Only execution against stated intent does — which is why Part XXI exists and why §0.4 is careful about what is being claimed.

## 0.13 Prior art

Almost every component exists somewhere. The composition does not. Stating the deltas is cheaper than being told them.

| System | Overlap | Delta |
|---|---|---|
| **Austral** | Linear types, capability security, regions, no GC, no macros, universe system. Closest existing language. | Capabilities are **linear values threaded through call chains**, not effects declared in types. No full-stack surface, no platform. |
| **Unison** | Abilities in types, content-addressed code, cloud platform. | No application model, no tenancy, no capability governance. |
| **WASM Component Model / WASI P2** | Capability-based, deny-by-default, composable, language-agnostic, industry-backed. | Syscall-level, not domain-level. **Strongest competing path.** |
| **Convex** | Deterministic typed server functions, full-stack. | No effect system; TypeScript's ambient authority underneath. |
| **Darklang** | Deployless, immutable, full-stack, later repositioned around AI. | Same shape of bet, attempted, did not break through. A data point on adoption difficulty and on hand-built demos proving the wrong thing. |
| **Roc / Gleam** | Platform-effects model, no macros, small surface. | General-purpose; no capability governance. |
| **Pony** | Reference capabilities enforcing data-race freedom at compile time. | Actor model; no application platform. |
| **Nix / Bazel** | Content-addressed reproducible builds. | Table stakes, not a differentiator. |
| **Wasp** | Full-stack DSL designed to be AI-generated. | Generates React and Node; inherits ambient authority wholesale. |

**Why a language rather than a capability layer over existing ones.** WASI-plus-policy gets enforcement and sandboxing with agents writing languages the models already know — no cold start, no compiler team, faster. Any diligence process will raise it. Two things it structurally cannot give: **effect granularity** (syscall-level `network.request<"stripe.com"> + secret.use<"stripe_key">` versus domain-level `payments.charge` — and when the manifest is the artifact humans read, abstraction level *is* the product), and **whole-stack coherence** (one effect system across client, server, database and jobs, so an authority change shows in one diff).

**On Austral specifically.** Its existence is good news — an existence proof for the hardest technical bets here. Two consequences: do not defend Gust on language novelty, because that argument is lost; and have an answer to "why not fork it" — capability-as-value is the wrong foundation when the manifest is the primary human-readable artifact, plumbing tokens through a twelve-frame handler is untenable at application call depth, and most of this document is not language work.

## 0.14 Sequencing

**Months 0–4 — the demo.** §0.7, two tracks in parallel. Track A: effects, scoping, typed queries. Track B: model fluency. Then one agent-generated multi-tenant application. Publish.

**Months 0–3 — the counting, in parallel.** §0.9. Independent of compiler progress, done by someone who is not on Track A or B.

**Month 4 — the decision point.** OD-8 and OD-9 have resolved by now. If either failed, stop or re-scope; that is the 30% branch in §0.10 and it is the cheapest available way to be wrong. If both held, proceed.

**Months 4–24 — the product.** The substrate first (workspaces, identity, permissions, objects, notifications, audit — Parts III, X, XI), then feature flags, then issues, then support inbox. Git hosting integrated, not rebuilt. Migration tooling from day one. This is v0.5 shipped with a price attached.

**Months 4 onward — conversations.** Parallel, non-exclusive, inbound-led off the published artifact and then off the product running in production.

**Later, uncommitted:**

- **v1.0** — jobs, self-hosted parity, capability fakes, deterministic test scheduling, multi-tenant rollout, intent layer v1 (OD-6).
- **Post-1.0** — durable workflows, realtime, distributed cache, supplier certification, registry, editions and LTS.

Everything from v1.0 down is specified in this document so that demo-stage decisions do not foreclose it. None of it is committed, and most of it should never be built by us.

## 0.15 Open decisions

| # | Question | Blocks | Reference |
|---|---|---|---|
| **OD-9** | **Model fluency** — can an agent write Gust well, and how do we get there from no corpus? *Thesis-invalidating. Starts week one.* | Demo | §0.7 |
| **OD-8** | **Soundness of the tenant-scoping analysis** — adversarial review before publication. *Thesis-invalidating.* | Demo | §56 |
| OD-1 | Transparent suspension vs coloured async (server). **Recommendation recorded in §21**; decision owned by the Cranelift lane | Demo | §21 |
| OD-2 | Generic functions vs compiler-owned query derivation | Demo | §14, §55 |
| OD-10 | **Distribution for the product path** — currently unanswered | Month 4 | §0.11 |
| OD-3 | SAM state ownership under linear resources and no interior mutability. **`std.Rc` already ships**, so part of this was decided by implementation — see `TASK_STDLIB.md` CR-9 | v0.5 | §27, §38 |
| OD-4 | WASM stack-switching support and payload cost | v0.5 | §21, §41 |
| OD-6 | Form of the intent layer | v1.0 | Part XXI |
| OD-5 | Supplier certification staffing model | Post-1.0 | Part XVI |

There is no OD-7. The number is unused and nothing in the repository references it; it is recorded here so a reader who notices the gap does not go looking.

## 0.16 Non-goals

Gust does not attempt to be:

- a general-purpose systems language;
- a host for existing JavaScript, Python, or Rust ecosystems;
- a runtime for arbitrary untrusted third-party code in-process;
- a formal-verification system (§79);
- a guarantee of correctness — only of containment (§0.4);
- a scanner or security-analysis product (§0.9);
- a training-environment vendor (§0.8);
- a platform whose guarantees survive an unrestricted escape hatch (Part XVIII);
- an improvement to tooling that operates on code humans already maintain.

And two hard constraints on how the business is run, not merely things we prefer not to do:

- **No enterprise sales.** No procurement, no security questionnaires, no 6–18 month cycles. This rules out the regulated-vertical play (§0.8) despite it being arguably the better business, and that trade is accepted deliberately. A plan the team will not execute is worth zero.
- **No business decision before month four.** §0.8. The demo selects the strategy.

**One line:** the fix for AI-generated data leaks is structural, and for the first time in the history of this problem the lever is ten generators instead of ten million developers.

## 0.17 Part status markers

§0.16 defers most of this document, and then the remaining twenty Parts specify the deferred material in the same voice as the committed material. A reader cannot tell them apart, and two readers reach different conclusions about what is being built.

Every Part below therefore carries a status line. The markers are:

| Marker | Meaning |
| --- | --- |
| **COMMITTED** | Required for the §0.7 demo, or already built. Work here needs no further justification. |
| **DEFERRED** | Intended, scheduled after the demo (§0.14). Specified now so that demo-stage decisions do not foreclose it. Do not build yet. |
| **SPECULATIVE** | Specified so the design is coherent end to end. Not scheduled, and per §0.16 most of it should never be built by us. Treat as a constraint on today's decisions, not as a backlog. |

A status marker is not a quality judgement and does not weaken a Part's authority over its own subject. `SHARED_SEMANTIC_ZONE.md` cites §16, §26, §28, §29, and §34 as authoritative regardless of the marker on their Part.

Where a Part splits, the marker names the split by section. `docs/ONE_WAY_LEDGER.md` records, per rule, whether the compiler currently does what the Part says.

# Part I — Product

> **Status: COMMITTED.** §1–§2 are the claim being demonstrated. §3's platform ownership list is the target state, not the current one.

## 1. Product vision

Gust is a purpose-built programming language, compiler, and runtime for full-stack web applications that are written by machines and read by almost no one.

Human developers remain the owners, reviewers, and operators of the resulting systems. They are not expected to write the code, and increasingly not to read it. What they own is stated in §0.12: **intent, authority, and outcomes.**

Every decision should be read against one question: *does this make agent-authored code easier to generate correctly, cheaper to verify, and safer to deploy without anyone reading it?*

### Core promise

> **No code executes authority it did not declare, and the compiler enforces it.**

A function's type states both the values it transforms and the authority it requires. Undeclared authority is a compile-time error, not a runtime surprise. This holds regardless of who or what wrote the code.

### Lead claim

> **The most common way AI-generated applications leak data cannot be expressed in this language.**

Missing tenant scoping — an application querying the database without restricting to the current user — is the canonical failure of agent-authored software and the direct cause of repeated public data-exposure incidents. §56 makes an unscoped query a **compile error**. Not a lint, not a scanner, not a template someone might forget: the program does not build.

### The limit of the claim

Gust delivers **containment, not correctness** (§0.4). It bounds and declares what a program can reach. It does not establish that the program does what was asked. Every external statement must hold this line; the intent layer (Part XXI) is how the gap eventually closes, and it does not exist yet.

### What this makes possible

- **Reviewable without reading.** A diff's authority change is visible in its signatures and its lockfile. Review means reading what the code may now touch, not what it says.
- **Deployable.** Static least privilege is a claim a security team can verify rather than a promise they must trust.
- **Trainable.** Declared effects and deterministic builds make execution traces clean supervision signal (§112) — relevant to an acquirer who trains models.

### What Gust does not claim

Gust does not claim vulnerabilities cannot exist. It claims authority is declared, enforced, monitored, revocable, and auditable, and that the boundary at which each guarantee weakens is explicit (§98).

When untrusted code is correctly isolated, the guarantees continue to apply outside the affected trust boundary. If untrusted code can bypass isolation or obtain unrestricted process capabilities, the guarantee is lost for the wider runtime boundary.

## 2. Market positioning

### The lever is the generator

Ending a bug class has always meant changing millions of developers, one codebase at a time — which is why it has always taken a decade (§0.3). Code production is now centralising into roughly ten generators. Change what they emit and millions of applications change in a release.

**Gust is positioned to be what a generator emits when the application handles data worth protecting.** Every other positioning question follows from that.

### Who buys

Model providers with a build surface, and AI app-building platforms. Ten to fifteen real prospects globally (§0.8). They are not buying a compiler — they are buying a known liability removed and three years of calendar, and the realistic outcome is acquisition rather than a licence.

**Not the end user.** Someone shipping an internal tool does not wake up wanting capability enforcement, and willingness-to-pay is near zero until after a breach. That is precisely why Gust must arrive as a *mode of someone's product* rather than as a product: the user opts in because their app handles real data, and never learns what a capability is — or that Gust exists.

### The three parties

| Role | Who | What they experience |
|---|---|---|
| Chooses | The end user | A toggle and a guarantee |
| Writes | The model | Gust, fluently, because it was trained to |
| Carries the risk | The platform | Fewer incidents attributable to generated code |

Nobody in that table reads Gust. That is §0.1 as a product fact rather than a design principle.

### The market timing problem

There is no acute buying pressure today, because nobody is counting (§0.2). That is the central commercial risk and §0.9 is the answer: produce the statistic, be the named alternative before the moment arrives, and accept that the first wave of demand will go to scanners.

### Later markets

**Regulated and security-conscious organisations** are the natural second market once verification is proven — slower, larger, higher-friction, and the slowest to stop reading code. Not a market to organise around now.

### Supplier certification is a service, not the guarantee

Where this document describes approved suppliers, certification, and revocation (Part XVI), read those as commercial services layered on the compiler-enforced guarantee — never substitutes for it. Curation scales linearly with ecosystem size and concentrates liability; capability enforcement does neither.
## 3. Product philosophy

Gust provides one official way to build every common part of an application. Convergence is a correctness property, not an aesthetic one: fewer idioms means less drift in generated code, higher agent accuracy, and smaller review surface.

The platform owns UI and rendering, routing, client/server communication, server actions and APIs, authentication, authorization, database access, migrations, forms and validation, background jobs, scheduling and workflows, testing, deployment, configuration and secrets, and logs, metrics, tracing, and errors.

These are native Gust primitives rather than a collection of hidden third-party packages.

External suppliers are reserved for genuinely external services: payment providers, S3-compatible infrastructure, email and SMS delivery, AI APIs, maps, tax calculation, shipping.

Developers — and the agents writing on their behalf — call Gust-owned capability interfaces such as `payments`, `storage`, and `email`. They do not import supplier SDKs directly.

---

# Part II — Trust, Suppliers, and Infrastructure

> **Status: SPECULATIVE.** §0.7 puts suppliers and deployment after the demo. §5's "every application includes PostgreSQL and an S3-compatible store" is a design intent; no database or storage capability exists today.

## 4. Trusted suppliers

Trusted suppliers operate behind Gust-defined capability interfaces and isolation boundaries rather than shipping unrestricted packages into applications.

Preferred execution models, in order:

1. Remote capability services.
2. Sandboxed local adapters.
3. In-process components only when strictly necessary.

Gust owns the standard capability interfaces. Suppliers may implement those interfaces or propose reviewed and versioned extensions.

An approved capability may be vendor-hosted, hosted by Gust, customer-hosted, or deployed inside a self-hosted Gust installation. Regardless of hosting model, the implementation, configuration, provenance, and isolation model must remain certified by Gust.

## 5. Native infrastructure

Every Gust application includes PostgreSQL and an S3-compatible object store.

Applications access both through Gust-owned APIs. The underlying infrastructure may therefore be operated by Gust Cloud, AWS, MinIO, or another approved compatible provider.

Changing infrastructure providers must not require changing the application architecture.

## 6. Hosted and self-hosted deployment

Gust Cloud is the default and easiest production environment, but Gust is not cloud-only.

Self-hosted Gust installs the same runtime, control plane, policy system, capability model, observability system, and deployment system.

Hosted and self-hosted Gust must not diverge into different products.

## 7. First-use experience

Within approximately fifteen minutes, a developer — or an agent acting on their behalf — should be able to create and deploy a production-shaped full-stack application containing public pages, protected pages, authentication, a database schema and migration, forms and validation, server actions, object storage, email, background work, and logging and observability.

The agent-facing equivalent of this target is the loop latency budget in §107.

---

# Part III — Organisation, Workspace, and Tenancy

> **Status: COMMITTED (§9 tenancy) / SPECULATIVE (§8 organisation and billing).** Tenant resolution and automatic scoping are the lead claim (§56). The organisation, billing, and multi-workspace administration model is not demo scope.

## 8. Organisation and workspace model

The **organisation** is the administrative and billing boundary. It owns users and memberships, billing, security policies, trusted-supplier permissions, domains, and deployments.

The **workspace** is the application tenant and data-isolation boundary.

Simple customers receive one default workspace automatically. Larger customers may operate multiple isolated workspaces within an organisation.

Projects remain application-level data. They do not become a universal tenancy layer.

## 9. Built-in multi-tenancy

Multi-tenancy is native to the platform.

Before application code executes, the request hostname, subdomain, or verified custom domain resolves the active workspace.

Gust automatically scopes database access, object storage, jobs, caches, logs, and capability calls.

The tenant context is platform-owned and immutable for the lifetime of a request or job. Background jobs carry a signed tenant context. Cross-tenant administration requires an explicit privileged capability.

The default PostgreSQL isolation model is one schema per workspace. Stronger options are database-per-workspace and cluster-per-workspace.

---

# Part IV — Language Principles

> **Status: COMMITTED.** Ring 1. Frozen at 1.0 per §99. `docs/ONE_WAY_LEDGER.md` records which of these hold in the compiler today; §11's `Result` and `?` do not yet exist.

Every restriction in this Part serves two ends at once: it narrows the space of programs a human must reason about, and it narrows the space of programs an agent can generate.

Under the readership thesis (§0.1) these restrictions stop needing a defence. Macros, operator overloading, inheritance, and user-level generics are conveniences for a human writing code daily, and are either free or actively harmful to a machine generating it. The austerity is not a trade-off — it is the correct answer once reading is rare.

The corollary, stated carefully: **verbosity is cheap where the verbose thing is the artifact.** Where a conventional language would infer to save typing, Gust states things explicitly *when the explicit form is what a reviewer reads* — authority, ownership, error propagation, resource lifetime. The cost of inference there is paid by every reader of a diff, and the benefit accrues to a typist who no longer exists.

This is not a general licence. An earlier draft of this section read "verbosity is free" without qualification, and that is withdrawn: verbosity in plumbing nobody reads — context threading, codec boilerplate, dispatch tables — buys nothing and costs generation accuracy, because every redundant token is a token that can be wrong. §0.1 states the operative rule and `docs/VISION_RECONCILIATION.md` §3.1 and §3.4 record the reasoning.

## 10. Language and runtime model

Gust is a purpose-built language rather than a framework hosted inside another language.

The language directly understands client and server execution boundaries, database effects, authentication and authorization, capabilities and permissions, trusted suppliers, secrets, deployment boundaries, memory regions, and ownership.

> **Two of those nine exist.** Verified 2026-08-20 at `b47d0049`. Memory regions and ownership are real and deeply built — not as keywords but through the branded `&Arena` type (`compiler/ast.gst:38`, 519 references in the typechecker), brand-mismatch diagnostics (§25), and structural move tracking (`compiler/typechecker.gst:1761`).
>
> The other seven have no representation anywhere — no keyword, no type, no registered name: client and server boundaries, database effects, authentication and authorization, capabilities and permissions, trusted suppliers, secrets, and deployment boundaries. `docs/ONE_WAY_LEDGER.md` E10 and E16.
>
> The sentence is the target. Read as present tense it overstates the language by seven of nine, and it is the sentence most likely to be quoted as a summary of what Gust is.

Gust uses explicit ownership and region-based memory built around branded contexts such as `ctx`.

The goal is strong memory safety without garbage collection, unrestricted pointer use, or hiding ownership entirely.

## 11. Errors and absence

Recoverable failures use `Result[T, E]` and `Option[T]`. The language includes `?`-style propagation.

Ordinary operational failures must not use exceptions.

Safe references are non-null. Absence is represented with `Option[T]`.

`null` is restricted to raw pointers inside `unsafe`, FFI and ABI boundaries, and compiler-owned runtime representations such as a zero-length slice with a null backing pointer.

*Rationale: a single total failure convention makes generated error handling mechanically checkable for exhaustiveness rather than stylistically reviewed.*

## 12. Abstraction model

Gust does not support inheritance, broad trait systems, or arbitrary interface hierarchies.

The primary abstraction model is concrete structs, ordinary functions, composition, small explicit function tables, and Gust-owned capability interfaces.

Data is represented as structs and passed into functions.

Dynamic polymorphism should be used only where genuinely necessary and must remain explicit.

*Rationale: resolution is local. A call site tells you what runs, without whole-program hierarchy search — for a human reviewing a diff or a model predicting a token.*

A concrete design for "small explicit function tables" — a flat behaviour registry indexed by handle, rather than a vtable pointer per object — is recorded in `docs/VISION_RECONCILIATION.md` Appendix B. It is how this section can ban inheritance without giving up open polymorphism.

## 13. Generics

Gust follows a deliberately restricted Odin/C-style approach.

The initial generic system supports generic structs, generic enums, compiler-owned generic containers, typed wrappers, and a small number of foundational standard-library abstractions.

Gust does not support specialization, higher-kinded types, arbitrary trait bounds, associated-type systems, overlapping implementations, type-level programming, or generic metaprogramming.

## 14. Generic functions and compiler-owned derivation (OD-2)

User-written generic functions are not available initially.

The typed query builder (§55), typed RPC schemas (§44), and typed templates (§37) all require type relationships that ordinary structs and concrete functions cannot express. **These are compiler-owned derivations, not user-level generic programming.** The compiler computes result types for joins, projections, aggregates, and serialization boundaries; application code receives concrete generated types.

This resolves the apparent conflict between §13 and §55: the query builder is not implemented in the user-facing language. It is a compiler feature with a typed surface.

It also answers "why not build Gust as a library over an existing austere language" — the differentiating features require compiler support, and any language austere enough to be a good base bans the metaprogramming that would let you add them from outside.

**OD-2 remains open** on one point: whether a restricted form of user-written generic function is required before v0.1 for standard-library collection code, or whether compiler-owned containers cover it.

## 15. Compile-time execution

Gust bans user-defined macros, arbitrary compile-time execution, programmable syntax transformation, and build scripts capable of arbitrary filesystem or network access.

The compiler may provide bounded, compiler-owned derivations for standard platform needs such as serialization, validation, equality, database schemas, RPC schemas, and policy metadata.

Compiler-owned derivations must be deterministic, inspectable, and incapable of arbitrary code execution.

> Gust permits explicit runtime code and bounded compiler-owned derivation, but no user-programmable compile-time language.

*Rationale: no install-time or compile-time execution removes the single largest class of ecosystem supply-chain attack, and guarantees that reading a source file — when someone finally does — tells you what the program does.*

## 16. Operators and conversions

Gust does not support user-defined operator overloading. The operator set is compiler-owned.

There is no implicit numeric narrowing, no implicit lossy conversion, and no conversion based on user-defined dispatch.

Only obviously lossless widening conversions may be implicit. All other conversions require explicit checked operations.

---

# Part V — Effects and Capabilities

> **Status: COMMITTED.** The differentiator (§0.4) and Track A item 1. Entirely unimplemented — there is no `uses` keyword in either lexer (`docs/ONE_WAY_LEDGER.md` E10).

## 17. Effects in function types

A function's type describes both the values it transforms and the authority it requires.

Functions declare capabilities such as:

```
db.read<User>
db.write<Order>
storage.read
storage.write
email.send
payments.charge
secret.use<"stripe">
time.read
random.use
network.request<host>
```

**Effects are declared on every function, without exception.** Earlier drafts permitted inference on private functions; that is withdrawn. Full annotation makes diffs informative, traces correlatable, and generation more constrained. The cost is verbosity, and it is worth paying *here* specifically: the effect set is the artifact a reviewer reads (§0.12), so stating it is the point rather than an overhead. This is not the general "verbosity is free" claim, which Part IV withdraws — it is the case that claim was reaching for.

This enables static least privilege, containable agent-generated code, compiler-checked mocks, automatic deployment policies, and auditable authority changes.

## 18. Effect granularity

**This is Gust's primary technical differentiator.** Every other capability system — WASI, Austral, Pony, object-capability designs — operates at the syscall or resource level. Gust operates at the level of business authority.

Application code requests:

```
uses payments.charge
```

rather than:

```
uses network.request<"stripe.com">,
     secret.use<"stripe_key">
```

Low-level supplier requirements are held by the approved capability implementation.

This matters because of §0.12: when the manifest is the artifact humans actually read, abstraction level *is* the product. `payments.charge` is reviewable by someone who is not a systems engineer, and generatable by an agent reasoning in domain terms.

Effects may carry restrictions for resource type, operation, secret name, hostname, region, and workspace scope.

Function values preserve their effect sets. A function requiring fewer effects may substitute for a function type that permits more effects. Authority may only be delegated by explicitly narrowing an existing capability.

## 19. Unsafe and authority

`unsafe` is independent from capability authority.

An unsafe block does not grant access to databases, networks, secrets, storage, suppliers, or cross-tenant operations.

Unsafe code must still possess every required effect.

---

# Part VI — Concurrency, Tasks, and Transactions

> **Status: COMMITTED (§20–§21) / DEFERRED (§22 transactions).** OD-1 must resolve before the demo. What exists today is detached `std.Spawn` plus channels — the model §20 rejects; see §21 and `docs/ONE_WAY_LEDGER.md` E9.

## 20. Structured concurrency

Normal application concurrency is structured and request-scoped.

Spawned tasks belong to a lexical task scope. Leaving that scope must wait for completed children, cancel unfinished children, and prevent detached work from leaking.

Cancellation propagates from parent tasks to children. Task failures propagate through `Result`.

Fire-and-forget work is not permitted in normal request code. Durable background work uses jobs.

Channels may exist as a lower-level primitive. Actors are a library or platform pattern, not the universal concurrency model.

## 21. Suspension model (OD-1, OD-4)

**Preference:** Gust should avoid forcing all asynchronous code into a coloured async function hierarchy if capability calls can suspend transparently.

Concurrency remains explicit through task creation, task scopes, joins, cancellation, and timeouts.

**Open decision.** Transparent suspension implies green threads or effect handlers. Against a WASM browser target (§41) that means stack switching, with real cost in payload size, portability, and toolchain support, and it interacts directly with the ownership-across-tasks rules in §30.

The demo cut (§0.14) is server-only, which splits this cleanly: **OD-1 (server suspension) must resolve before the demo; OD-4 (WASM cost) defers to v0.5.**

**What exists today (verified 2026-08-20, `b47d0049`).** Neither model. There is no `async`, `await`, `spawn`, or `scope` keyword in either lexer. Concurrency is a library surface over the cooperative fibers in `src/runtime/fiber.c`: `std.Spawn`, `std.Channel`, `std.Mutex`, `std.Yield`. `std.Spawn` starts work that no scope owns, with no join requirement, no cancellation propagation, and no task handle — which is detached spawn plus channels, the model §20 rejects and the only one available. Recorded with reproductions in `docs/ONE_WAY_LEDGER.md` E9 and tracked as `TASK_STDLIB.md` CR-8.

**Recommendation, not a decision.** Take Go's *suspension* model and reject Go's *task* model: transparent suspension with no colouring, over a scheduler that already exists, with every task owned by a lexical scope that cannot exit while a child is live, and task handles as linear resources. Three named concepts — child task, supervisor, durable job — rather than one `spawn` with adjectives. `?` continues to mean "may fail"; suspension needs no keyword because it is always owned.

The fallback above — coloured async on the client, transparent on the server — is recorded here as the worse option. Two concurrency models in a language whose premise is one of everything refutes the premise; if OD-4 makes WASM stack switching unaffordable, restricting client code to event-driven dispatch with no suspension is the better trade, and Part IX's SAM model already implies it.

Ownership: this is a Ring 1 semantic decision. `docs/SHARED_SEMANTIC_ZONE.md` assigns the fiber scheduling contract to the Cranelift lane, so neither lane may act on the recommendation unilaterally. Reasoning in `docs/VISION_RECONCILIATION.md` §3.2.

## 22. Transactions

Transactions are lexical and typed:

```
transaction db as tx {
    ...
}
```

Database operations inside the block are statically bound to `tx`. Transaction handles and transaction-bound values cannot escape the transaction scope.

Nested transactions use explicit savepoints.

Transactions declare isolation level, timeout, and retry policy. Serialization conflicts and retry exhaustion return typed errors.

Automatic retries are allowed only for transaction blocks containing retry-safe database effects. The compiler rejects external effects — email, payments, arbitrary networking, supplier mutations — inside automatically retried transactions.

Gust provides post-commit hooks and a transactional outbox for reliable external effects after commit.

---

# Part VII — Resources, Ownership, and Memory

> **Status: COMMITTED.** The most heavily built Part. §26 was corrected 2026-08-19 to the single reference form that exists; §27 is marked OD-3 but `std.Rc` already ships (`docs/ONE_WAY_LEDGER.md` E8).

## 23. Value categories

**Copy values.** Integers, bytes, booleans, simple enums, IDs and indices, and explicitly copyable structs. A user-defined struct is copyable only when every field is copyable and the type is explicitly marked copyable.

> **Partly implemented.** Verified 2026-08-20 at `b47d0049`: the field-transitivity half holds, but there is no `copyable` marker in either lexer. Copy-versus-move is *inferred* structurally by `is_linear` (`src/typechecker.rs:219-250`) — primitives and indices copy; `Arena`, `RawPointer`, `Slice`, `ByteSlice`, `str`, and generics move; a struct moves iff any field does. The practical consequence is that adding one `str` field to a plain struct silently converts it from copy to move at every use site, with no annotation and no diagnostic — which is the change an explicit marker would catch at the declaration. `docs/ONE_WAY_LEDGER.md` E13.

**Context-bound views.** Non-owning views into storage associated with a branded context: `str`, slices, references. Copying a view copies the view descriptor, not its backing storage. A view cannot outlive its context.

**Owned values.** Owned collections and allocations move by default unless explicitly cloned into a destination context.

**Linear resources.** One owner, compiler-tracked lifecycle state. File or directory handles, secrets, transaction handles, capability handles, native resources, and structs containing linear fields.

## 24. Contexts and arenas

The language has one underlying branded context and arena mechanism.

The platform provides well-known context kinds: scratch, temporary lexical, request, task, job execution, application, and explicitly managed persistent contexts.

These are compiler/runtime-owned arena classes rather than separate ownership systems.

> **The first sentence of this section holds; the list of kinds does not yet.** Verified 2026-08-20 at `b47d0049`. There is one branded arena mechanism, and that is the load-bearing claim — `os.Arena.New` and `os.ArenaAlloc` are the general form, with a distinct thread-local scratch class (`os.SetThreadScratch`, `os.ScratchAlloc`, `os_ScratchReset` in `src/runtime/scratch.c`).
>
> Of the seven kinds named, two exist as distinct mechanisms: scratch, and the general arena that covers "temporary lexical", "application", and "explicitly managed persistent" — those three are not separate classes, they are an arena with a different lifetime. **Request, task, and job-execution contexts do not exist**, and cannot until the platform they belong to does (`docs/ONE_WAY_LEDGER.md` E16).
>
> The list is also under-inclusive: `std.GenerationalArena` with `std.GenerationalSwap`, and `std.ThreadLocalContext`, are shipped arena classes this section does not name.

## 25. Lifetime movement

A value from a shorter-lived context may enter a longer-lived context only through cloning into the destination context, serialization, or explicit ownership transfer.

Copying a view does not extend its lifetime.

Request-branded references cannot enter jobs, durable messages, longer-lived caches, application state, or persistent storage.

> **Enforced in principle, and no stronger than brand identity.** Brands are part of the type, so a value branded to one context is not assignable where another is expected, and the typechecker emits dedicated diagnostics — `[BrandMismatch]` for `Arena.get_ref` and `Arena.Set/Write` (`compiler/typechecker.gst:2661,2668,2676,2709`) and "Brand Nesting. Mismatched nested brand" (`:1716,:1740`). That is real.
>
> The qualification is that brand *identity* is currently derived from identifier spelling rather than from the type (`docs/SHARED_SEMANTIC_ZONE.md` D-1, owned by Phase 19). A rule enforced by comparing brands is only as sound as the way brands are identified. The specific prohibitions named here are additionally vacuous today, since jobs, durable messages, and persistent storage do not exist. `docs/ONE_WAY_LEDGER.md` E20.

## 26. Borrows

Gust has one reference form, `&T[ctx]`. It is context-branded, non-null, and lexical: a borrow cannot outlive its context.

**It does not carry mutability.** Writing through a reference — `(*r).field = value` — is permitted, and the write reaches the caller's value. Two `&T[ctx]` arguments may alias the same value and both write through it. There is no `inout`, no `&mut T[ctx]`, and no aliasing analysis.

This section previously described a two-form model — `&T[ctx]` as a shared immutable borrow, `inout T[ctx]` as exclusive mutation, shared mutable references prohibited — as though it were current. None of it was implemented, and it is corrected here rather than left as a claim the compiler does not make. `tests/test_shared_mutable_aliasing_observed.gst` pins the actual behaviour.

Public APIs must state context brands explicitly. There is no hidden lifetime inference across public boundaries.

**Deferred.** Restricting mutation through references, whether by reintroducing `inout` or by another mechanism, is future work and is not scheduled. It is a containment property (§0.4), so when it is taken up it needs a design decision and enforcement, not just a wording change. Until then, do not cite `&T[ctx]` as an immutability guarantee anywhere — in documentation, in review, or in a safety argument.

## 27. Shared ownership (OD-3)

Ordinary references remain borrowed and context-bound.

Where unavoidable, Gust may provide an explicit compiler-owned read-only shared ownership type such as `Rc[T, ctx]`.

Safe application code does not receive unrestricted interior mutability.

Shared mutation should instead occur through SAM state ownership, actors, transactions, or explicit synchronization primitives.

**Open (v0.5):** the SAM state model (§38) is where this rule meets the operation every application performs constantly. A worked end-to-end example — store, action dispatch, optimistic update, rollback — must be written and reviewed before client work begins.

## 28. Linear resources

Root resource types opt into resource semantics through explicit linear metadata, a `Resource[...]` representation, and registered destructor metadata.

> **The opt-in half is implemented.** A `#[linear]` layout attribute is parsed alongside `repr(C)` and `packed` (`compiler/parser.gst:869-872`), flows to `StructDecl.is_linear_resource`, and is registered by `env_register_struct_linear_metadata` (`compiler/typechecker.gst:6801`). Registered *destructor* metadata for user-defined types is the part that is missing (`TASK_STDLIB.md` CR-5), which is what blocks `MutexGuard`.
>
> Worth stating explicitly because the word is overloaded: this opt-in is separate from the structural linearity that governs move-versus-copy for ordinary values. `str` and slices are automatically linear for move tracking and are *not* automatically resources — which is exactly what the next paragraph claims. `docs/ONE_WAY_LEDGER.md` E20 and E13.

Linearity propagates transitively. Any struct containing a linear field is itself linear. Ordinary strings, slices, collections, and branded structs do not automatically become resources.

Compiler-tracked resource states: owned, borrowed, moved, closed, destructor scheduled.

The compiler must reject use after move, double move, double close, closing borrowed resources, moving borrowed resources, missing required cleanup, and escaping transaction- or context-bound resources.

## 29. Cleanup

Linear resources clean up automatically at lexical scope exit.

`defer` remains available for explicit ordering, rollback logic, additional non-default cleanup, and early scheduling.

Cleanup order:

1. Deferred actions execute in reverse registration order.
2. Remaining owned locals are destroyed in reverse declaration order.
3. A struct's explicit destructor body runs.
4. Remaining owned fields are destroyed in reverse field-declaration order.

Moved, closed, or already scheduled resources are never destroyed twice.

Automatic destructors must be infallible. Operations that can meaningfully fail — committing, flushing, finishing an upload, completing durable writes — must remain explicit and return `Result`.

Cleanup diagnostics may be recorded as suppressed information, but cleanup must not silently replace the active error or turn a successful return into an unrelated hidden failure.

## 30. Ownership across tasks and channels

Structured tasks may receive owned values, or borrows valid for the complete task scope.

Borrows should not be shared across tasks. This is a design rule, not an enforced one: references carry no mutability and there is no aliasing analysis to enforce it against (§26).

Channels transfer ownership of sent values.

> **Not enforced.** Verified 2026-08-20 at `b47d0049`: `Channel.Send` checks its argument against the element type and returns `Void` (`compiler/typechecker.gst:2823-2841`). No move is recorded at the send site, so the sender retains a usable binding to a value it has handed to another fiber. Together with §20's unenforced task ownership this means the two concurrency primitives that exist — `std.Spawn` and `std.Channel` — provide neither task ownership nor value ownership. `docs/ONE_WAY_LEDGER.md` E18; tracked with issue #101, since the fix is the same OD-1 decision.

Values containing context-bound references may cross into a task only when the receiving task shares a valid parent context.

Durable jobs and messages require fully owned serializable values. They cannot contain references.

---

# Part VIII — Core Type-System Details

> **Status: COMMITTED (§31, §33) / SPECULATIVE (§32) / COMMITTED-but-violated (§34).** §31 enums and matching, and §33 strings, exist. **§32's numeric model is entirely absent** — none of the six fixed-width integer types, no overflow trapping, no named arithmetic, none of the `Decimal`/`Money`/time types (`docs/ONE_WAY_LEDGER.md` E11). §34's panic scoping is violated: a string bounds failure calls `exit(1)` and takes the process down (E3).

## 31. Enums and matching

Gust initially supports payload-carrying tagged enums, generic enum templates, and compiler-owned integer-backed enums for FFI where necessary.

`match` initially supports enum cases, flat variant destructuring, and exhaustive checking.

Deferred: nested patterns, arbitrary literal patterns, match guards, arbitrary extractors.

All enum matching must be exhaustive.

*Rationale: exhaustiveness converts a whole class of generated-code omission into a compile error.*

## 32. Numbers

> **None of this section is implemented.** Verified 2026-08-20 at `b47d0049`: there is one integer type, `int`, and none of the six fixed-width types below exists in either lexer; there is no overflow handling anywhere in codegen or the typechecker; the named arithmetic operations and every one of the numeric and time types below are absent. `Type::Int` lowers to C `int`, where signed overflow is undefined behaviour — so the current behaviour at overflow is not wraparound but UB, which is the opposite end of the spectrum from the trap this section promises. Reproductions in `docs/ONE_WAY_LEDGER.md` E11; tracked as issue #103. The section is retained as the target, not as a description.

Gust supports compiler-defined fixed-width integer types: `i32`, `u32`, `i64`, `u64`, `isize`, `usize`.

**Integer overflow traps by default in all builds.** This carries a measurable runtime cost and is accepted deliberately: silent wraparound in agent-generated arithmetic is a correctness failure that no review process catches, least of all one where nobody reads the code.

Explicit named operations provide wrapping, saturating, and checked arithmetic — functions or explicit methods, not overloaded operators.

The compiler-owned standard library provides `Decimal`, `Money[Currency]`, `Instant`, `Duration`, `Date`, `LocalTime`, and `ZonedDateTime`.

Money values with different currencies cannot be combined without explicit conversion.

## 33. Strings and text

`str` is an immutable UTF-8 view branded by its backing context. It is not automatically an owned heap string.

Low-level length and slicing semantics are byte-based. Integer indexing must not pretend to return a Unicode character.

The standard library provides explicit APIs for bytes, Unicode scalar values, grapheme clusters, and validated UTF-8 slicing.

An owned text type such as `String[ctx]` may be provided for independently owned or mutable text.

Raw byte access requires explicit intent.

## 34. Panics

Ordinary failures use `Result` and `Option`.

User code may panic only for impossible states or violated invariants.

A panic terminates the current request, task, or job — not the complete deployment.

Runtime corruption or unsafe-memory failure may terminate the application process when containment is no longer trustworthy.

---

# Part IX — Client, UI, and RPC

> **Status: SPECULATIVE.** No Wasm target, templates, SAM runtime, or RPC layer exists. `full-stack-slice-0.md` is the scoped entry point when this is taken up; per §0.7 it is not now.

*v0.5 (§0.14). Not in the demo.*

## 35. Rendering model

Gust begins as a client-rendered application platform with typed RPC. The model is similar in spirit to tRPC for client/server communication and lit-html for rendering.

Execution locations are explicit and fixed:

- client functions run in the browser;
- server functions run in the server runtime;
- shared code must be pure, serializable, and capability-free.

Server functions generate typed client calls. The compiler rejects server-only capabilities in client code.

## 36. UI component model

Gust provides a typed, compiled implementation of the lit-html template model.

Components are ordinary functions returning `View`. Templates use typed HTML expressions and incremental DOM-part updates rather than a virtual DOM. Components compose by calling other component functions.

```
component Counter(model: CounterModel) View {
    html {
        <button on:click={Action.Increment}>
            Count: {model.count}
        </button>
    }
}
```

There is no virtual DOM, no JSX transformer, no runtime reflection, and no user-defined rendering macros.

## 37. Typed templates

Template type checking is a compiler-owned derivation (§14). Attribute types, event handler signatures, and interpolation types are checked against the component's model type at compile time.

## 38. SAM state model (OD-3)

The standard library includes a SAM-based state model.

- The **model** stores application state.
- **Actions** describe typed events and commands.
- **Acceptors** validate and apply state transitions.
- **Presenters** derive view state.
- **Effects** perform RPC, timers, storage, and subscriptions.

Event handlers dispatch typed SAM actions rather than directly mutating DOM state.

Local and remote state use the same action model while effects remain explicit.

See §27: the interaction between SAM state ownership, linear resources, and the prohibition on interior mutability is an open decision requiring a worked example before v0.5.

The argument that SAM is the *right* fit for an arena language — model in a long-lived arena, action payloads in a scratch arena, view in a frame-bound arena wiped in constant time, and therefore no cyclic widget graph and no listener leaks — is recorded in `docs/VISION_RECONCILIATION.md` Appendix A.

## 39. Browser access

Client code may use UI primitives, local state, SAM state machines, typed RPC clients, serializable values, pure shared functions, and approved browser capabilities.

Client code may not directly use databases, server secrets, payments, server email, server object storage, unrestricted filesystems, unrestricted networking, or server resources and references.

Direct DOM access and unrestricted browser APIs require explicit browser capabilities.

## 40. Forms, accessibility, and styling

Forms are typed, schema-validated, integrated with RPC validation, and accessibility-aware.

Styling uses compiler-owned scoped CSS. Global styles require explicit declaration.

## 41. Browser compilation target

Gust targets WebAssembly first, with a small JavaScript bridge for DOM integration. A JavaScript output backend may be added later for compatibility.

A basic application ships only the Gust UI runtime, compiled application client code, and required browser bindings.

It does not ship a package loader, supplier SDKs, runtime reflection, unused standard-library code, or a large general-purpose framework runtime.

Ahead-of-time compilation and tree shaking should make payload size proportional to used features. The design target for a basic application is tens of compressed kilobytes rather than hundreds.

See OD-4: the suspension model (§21) may impose payload cost on this target.

## 42. Routing and code splitting

Routing uses explicit typed route declarations rather than filesystem routing.

Typed routes improve refactoring, authorization, generated links, compiler inspection, and agent reasoning — an agent can enumerate the complete route surface from the source rather than inferring it from directory layout.

Code splitting occurs at typed route boundaries and explicit component boundaries. Lazy loading is explicit and compiler-managed.

## 43. Client persistence and offline support

Offline support and persistence use standard browser capabilities backed by approved storage such as IndexedDB.

Persistence is typed, versioned, tenant-aware where applicable, and explicitly declared.

## 44. RPC model

Queries, mutations, streams, subscriptions, webhooks, and public HTTP APIs share one typed action foundation while retaining distinct semantics.

- **Query** — read-only typed RPC. Safe reads may retry automatically.
- **Mutation** — state-changing RPC. Automatic retries require explicit idempotency.
- **Stream** — ordered best-effort server-to-client stream.
- **Subscription** — long-lived, resumable realtime feed.
- **Webhook** — externally invoked endpoint with verification and replay protection.
- **HTTP** — intentionally public REST-style or protocol-specific endpoint.

All boundary forms share schema-derived serialization, validation, authentication, tenant resolution, authorization, tracing, auditing, and structured `Result` errors.

*v0.1 ships the HTTP form only.*

## 45. RPC security and validation

RPC automatically handles input-schema validation, authentication context, immutable tenant context, authorization, CSRF protection, tracing, audit metadata, and structured errors.

Mutations support explicit idempotency keys.

## 46. Client cache and optimistic updates

RPC queries use a built-in normalized cache keyed by procedure identity, typed input, and tenant context.

Mutations dispatch optimistic SAM actions, retain rollback state, call the server, and reconcile against the authoritative result.

Subscriptions and streams update the same cache and dispatch ordinary SAM actions.

---

# Part X — Authentication and Authorization

> **Status: SPECULATIVE**, except that §52's "enforced in queries" is the same mechanism as §56 and is COMMITTED through it. The demo's `Session` can be a struct handed in by a harness.

*v0.5 (§0.14). The demo ships a stub sufficient to establish tenant identity.*

## 47. Identity model

Gust owns the identity, session, membership, recovery, MFA, and audit model.

Native authentication methods: passkeys, passwords, magic links, OAuth/OIDC, and enterprise SAML through an approved identity supplier.

A person has one global Gust identity with separate organisation memberships, workspace access, and roles and permissions.

External identity providers verify identity but do not define Gust authorization.

## 48. Sessions and devices

Anonymous users receive restricted workspace-scoped sessions.

Authenticated sessions are device-bound, revocable, short-lived, and backed by rotating refresh credentials.

Gust tracks active devices and supports session revocation.

## 49. Service accounts and API tokens

Service accounts are explicit non-human identities with scoped capabilities, expiry, and audit history.

API tokens are named, scoped, hashed, auditable, and revocable.

Agents operating against a deployed application are service accounts. They receive scoped capabilities and appear in the audit trail as themselves, never as the human who invoked them.

## 50. MFA and recovery

MFA supports passkeys, authenticator applications, and recovery codes.

Gust owns workflows for account recovery, session revocation, identity-provider linking, and impersonation.

The default authentication state is unauthenticated.

## 51. Authorization model

Authorization uses a constrained combination: roles grant permissions; policies decide access to specific resources.

Roles are ordinary application data. Gust provides standard primitives for identity, memberships, roles, and permissions.

Policies are declared centrally by resource. Routes and actions reference policies explicitly.

Policies may inspect user, organisation, workspace, ownership, relationships, request context, and capability scope.

## 52. Authorization enforcement

Every public query, mutation, stream, webhook, and job must have an explicit authorization decision.

Authorization is enforced at three layers:

1. Before application execution.
2. Inside generated database queries where policy predicates can be translated.
3. At runtime for decisions that cannot be expressed entirely in a query.

Gust injects immutable tenant filters and policy-derived row filters.

Field-level permissions use explicit readable and writable field sets.

## 53. Privileged identities

Explicit privileged capabilities are required for support access, administrator impersonation, service-account elevation, and cross-workspace operations.

Each privileged action requires a reason, an expiry, and complete audit logging.

Suppliers receive only policy-filtered, purpose-specific data views.

Policies are typed, testable, versioned with the application, shown in deployment diffs, and rolled out through ordinary releases.

When no policy exists or a decision is ambiguous, access is denied.

> No public operation executes and no data leaves its boundary without an explicit, auditable authorization decision.

---

# Part XI — Database and Migrations

> **Status: COMMITTED (§55–§56) / SPECULATIVE (§54, §57–§62).** Typed query derivation and tenant enforcement are Track A items 3 and 4. Migrations, backfills, and rollout are post-demo.

## 54. Database source of truth

PostgreSQL is the source of truth for the database schema.

Gust introspects PostgreSQL and generates base Gust types, similar to Kanel.

Application domain types may wrap generated database types but do not redefine the database schema.

## 55. Query model

Gust provides a typed Kysely-style query builder over generated database types.

**The query builder is a compiler-owned derivation (§14), not a user-level generic library.** Result type computation for filters, joins, aggregates, projections, and pagination is performed by the compiler. This is what allows a Kysely-class typed surface without the type-level programming facilities §13 excludes.

The query system supports typed filters, joins, aggregates, pagination, locking, inserts, updates, deletes, and transactions.

PostgreSQL-specific features are exposed through explicit typed extensions rather than unrestricted generic escape hatches.

Query results are strongly typed. Database schema changes regenerate types and produce compile-time errors where application code is no longer compatible.

## 56. Tenant and authorization enforcement

**This is the lead product claim (§1) and the whole point of the demo (§0.14).**

The compiler **statically enforces** that every database query is tenant-scoped. Queries that cannot be statically shown to carry tenant scope are rejected at compile time.

Missing tenant scoping is the canonical failure mode of agent-authored applications and the direct cause of repeated public data-exposure incidents across AI app-building platforms. Every other stack treats it as a configuration concern — row-level security policies, middleware, a template the generator might forget. Gust makes it a property of the type system: **the unscoped program does not compile.**

Authorization predicates are injected into queries where policies can be translated into database expressions. Where full translation is impossible, a runtime policy check is required.

This is static enforcement backed by generated conformance tests (§79), not formal proof. See §79 for the language Gust is permitted to use externally.

## 57. Raw SQL

Raw SQL is allowed only through an explicit privileged database capability.

Raw SQL carries reduced static guarantees, visible warnings, audit metadata, and deployment-policy review.

## 58. Migration model

Migrations use explicit Laravel/Kysely-style `up` and `down` files.

Every migration is registered in one central ordered manifest.

The compiler may suggest generated migrations, but developers review and own the final migration code. This review is not delegated to an agent by default: migrations are the one place where an incorrect generated diff is not recoverable by rollback, and therefore the one place the readership thesis does not apply.

## 59. Destructive migrations

Destructive changes require explicit annotation, deployment approval, backup verification, and compatibility checks.

Examples: dropping columns, narrowing types, deleting data, irreversible transformations.

## 60. Backfills

Backfills run as resumable, idempotent, observable jobs. They do not run as long blocking migration transactions.

## 61. Production migration strategy

Production migrations use expand-and-contract by default:

1. Add compatible schema.
2. Deploy compatible code.
3. Backfill data.
4. Switch reads and writes.
5. Remove obsolete schema later.

Compatible migrations do not stop serving traffic.

Rollback normally means rolling application code back while retaining a backward-compatible schema. Destructive schema rollback is not assumed to be safe.

## 62. Multi-tenant migration rollout

The control plane applies tenant migrations in bounded batches with progress tracking, retries, pause and resume, and per-tenant failure isolation.

Every application release declares a supported schema-version range. Jobs and supplier adapters also declare compatible schema ranges.

Deployment is blocked when application, database, job, and supplier requirements do not overlap.

> PostgreSQL defines the schema; Gust generates the types, provides typed queries, and manages explicit, compatibility-first migrations.

---

# Part XII — Jobs, Scheduling, Workflows, and Messaging

> **Status: SPECULATIVE.** §0.7 defers jobs and realtime explicitly.

*v1.0 and post-1.0 (§0.14). Not in the demo.*

## 63. Jobs

Jobs are typed server functions with explicit tenant context, effects, input schema, and retry policy.

Delivery is at-least-once. Jobs performing mutations must be explicitly idempotent.

Gust does not promise literal exactly-once execution. Exactly-once-like outcomes are achieved through idempotency, transactional state, uniqueness keys, and outbox delivery.

## 64. Job runtime

The runtime provides bounded exponential backoff, timeouts, cancellation, priorities, uniqueness keys, concurrency limits, dead-letter queues, and full execution history.

Jobs are enqueued transactionally through the database outbox.

## 65. Scheduling

Scheduled jobs use explicit schedules with clear timezone semantics.

Recurring schedules create individual auditable job executions.

## 66. Durable workflows

Durable workflows are typed state machines. They may wait for timers, events, approvals, or supplier responses.

Workflow state is persisted. Worker failure does not lose workflow progress.

## 67. Workspace fairness

Workspace fairness is enforced through quotas, weighted queues, concurrency caps, and noisy-neighbour protection.

## 68. Cache scopes

Native cache scopes: request, workspace, application, distributed.

Cached entries are typed and tenant-scoped. Request caches expire automatically. Cache keys include workspace identity automatically.

Database-backed query caches declare dependencies so Gust can invalidate them after writes. Manual invalidation remains available for derived and external data.

## 69. Realtime and event bus

Database-change subscriptions use a Gust-owned changefeed. Application events use a native typed event bus.

Supplier events enter through verified webhooks and approved capability adapters.

Streams provide ordered best-effort live delivery. Durable subscriptions provide at-least-once delivery and resumable cursors.

Messages are schema-versioned and tenant-scoped. Consumers must be idempotent.

Breaking message changes require a new schema version and a compatibility period.

---

# Part XIII — Packages and Application Structure

> **Status: DEFERRED.** §72's lockfile-and-manifest diff is one of the three artifacts §0.12 says humans actually read, and it is the mechanism behind the guarantee model in `docs/VISION_RECONCILIATION.md` §5. It is not needed to reject an unscoped query.

## 70. Modules and packages

A module is one source file. A package is one directory tree with a package manifest.

An application is a root package, its approved package graph, and its capability graph.

Packages may be reused across projects.

## 71. Package sources

Initial package sources: Gust standard packages, organisation-owned packages, and explicitly approved third-party Gust packages.

A public registry may be introduced later. Any public registry must use signed releases, immutable artifacts, and provenance verification.

The capability system (Part V) is what makes a public registry survivable. Approval is a service tier; enforcement is the guarantee. A package obtained from any source still cannot execute authority it did not declare.

## 72. Lockfiles and provenance

Lockfiles record exact source hashes, compiler compatibility, signatures, and capability requirements.

**Capability requirements appear in the lockfile diff.** A dependency update that widens authority is visible in review as a change to the manifest, not as a change buried in source. This is one of the three artifacts humans actually read (§0.12) and should be treated as a primary product surface, not a build detail.

Cyclic package dependencies are forbidden. Cyclic file imports within a package are also forbidden or tightly constrained.

## 73. Visibility

Visibility levels: private to the module by default, package-visible, application-visible, externally public.

> **Not implemented.** No visibility modifier exists in either lexer — `pub`, `private`, `public`, `internal`, and `export` are all absent — so there is no private-by-default and no package or application level. The half of this section that holds is the next paragraph: `import` exists and imports are explicit. `docs/ONE_WAY_LEDGER.md` E19.

Organisation and workspace access are authorization concepts, not source-code visibility levels.

Imports are explicit and deterministic. Wildcard imports, implicit runtime loading, and hidden dependency injection are prohibited.

## 74. Prelude

The default prelude contains only basic types, `Result`, `Option`, core collections, formatting, and core language functions.

Never silently imported: database access, networking, filesystem access, time, randomness, supplier capabilities.

> **The opposite is true today.** Verified 2026-08-20 at `b47d0049`: the whole `os.*` surface is available to every program with no import and no declaration — files using `os.ReadFile` and `os.System` import nothing at all. That surface includes `os.WriteFile`, `os.RemoveFile`, `os.ReadDir`, `os.GetEnv`, `os.Args`, `os.RunProcess`, and `os.System`, which spawns `/bin/sh -c` (`src/runtime/file_io.c:573`).
>
> Fairly stated, this is not a defect: Gust is a self-hosted toolchain that must invoke `cc`, read sources, and write objects, and no mechanism exists yet to scope that. But it means the current default is maximal ambient authority, which is what §0.4 sells the language as eliminating, and it closes only with the effect system in §0.7 Track A. `docs/ONE_WAY_LEDGER.md` E19.

---

# Part XIV — Testing and Determinism

> **Status: DEFERRED**, except §79's conformance checks, which §79 itself calls the primary defence against plausible-but-wrong output. Nothing here is required for the demo.

Determinism here is not a testing convenience. It is the property that makes execution traces usable as training signal (Part XX) and the only remaining check on behaviour when nobody reads the code. A non-deterministic run is a contaminated observation.

## 75. Test categories

Native test categories: unit, package integration, RPC, policy, migration, browser and component, tenant-isolation, and deployment smoke tests.

## 76. Capability fakes

Every declared capability can be replaced with a compiler-checked fake, recorded, or test implementation.

Tests can virtualize time, randomness, task scheduling, RPC, jobs, and supplier responses.

## 77. Deterministic scheduling

Structured concurrency uses a deterministic test scheduler. Tests may advance virtual time explicitly.

## 78. Database and policy testing

Database tests run against isolated transactions and disposable PostgreSQL environments.

Policy tests include generated deny cases, cross-tenant probes, and missing-policy cases.

Migration tests verify fresh installation and every supported upgrade path.

## 79. Compiler-generated conformance checks

The compiler generates checks for RPC serialization, policy coverage, tenant scoping, migration manifests, and supplier capability contracts.

**This is the primary defence against plausible-but-wrong output (§0.12)** and should be resourced accordingly — it is not a testing convenience, it is the mechanism that substitutes for reading. It is also the natural implementation substrate for the intent layer (Part XXI).

**Gust must distinguish static enforcement and generated testing from formal verification.** Internal and external language must say *enforce*, *check*, and *reject* — never *prove* — except where a genuine machine-checked proof exists. This applies to marketing, documentation, and compiler diagnostics alike.

---

# Part XV — Configuration and Secrets

> **Status: SPECULATIVE.**

## 80. Configuration

Configuration is typed, non-sensitive application input.

It supports defaults, environment-specific overrides, validation, and deployment-time checking.

## 81. Secrets

Secrets are opaque linear values. They have no readable string representation in safe code.

Secrets cannot be logged, serialized, formatted, returned to clients, or compared except through approved operations.

Secret access requires declared effects such as `secret.use<"stripe">`.

Public effect signatures expose logical secret names rather than provider-specific storage paths.

*Rationale: an agent cannot leak a secret into a log line or an error message, because the type does not permit it. Among the most frequent mistakes in generated code and among the most expensive.*

## 82. Rotation and providers

Secret rotation supports overlapping active versions. All access is audited. Expiry and rotation policies are platform-enforced.

Self-hosted secret providers must implement Gust's provider protocol and be certified for isolation, auditability, rotation, and access control.

---

# Part XVI — Supplier Governance

> **Status: SPECULATIVE.** §2 already says certification is a commercial service layered on the compiler-enforced guarantee, never a substitute for it.

*Post-1.0 commercial service tier (§2), not the core guarantee. Assumes a certification function with real staffing. OD-5 is unresolved; do not commit to supplier certification externally until it is.*

## 83. Supplier protocol

Suppliers implement versioned Gust capability contracts.

The protocol uses typed schemas, mutual authentication, tenant-scoped credentials, request IDs, deadlines, and signed provenance metadata.

Capability negotiation occurs during deployment rather than dynamically during ordinary requests.

## 84. Reliability contracts

Every capability defines timeout policy, retry policy, idempotency requirements, rate limits, circuit-breaker behaviour, fallback rules, and error taxonomy.

Default rules:

- reads may retry when safe;
- writes retry only with idempotency;
- payments and irreversible effects require explicit idempotency keys;
- fallback suppliers must be explicitly approved.

## 85. Data minimization

Gust constructs supplier-specific request views. Only declared fields may cross the supplier boundary.

Tenant identity is represented through scoped supplier tokens rather than unrestricted internal context.

Transferred data, retention, destination region, and purpose are declared and audited.

## 86. Supplier revocation

Revoked suppliers cannot receive new deployments or new credentials.

Existing applications enter a visible degraded or blocked state, depending on capability criticality.

Emergency revocation may immediately disable calls.

Compatibility adapters are owned by Gust or the supplier as part of certification. Ordinary application developers are not responsible for maintaining supplier integration compatibility.

---

# Part XVII — Deployment and Operations

> **Status: SPECULATIVE.** §0.7 defers the deployment platform. The demo needs one Linux x86-64 host.

## 87. Deployment unit

The deployment unit is an immutable application release.

A release may serve one or many workspaces. Workspace-specific configuration and data remain separate from release code.

## 88. Preview environments

Preview environments are isolated application deployments with disposable databases, storage, secrets, and tenant domains.

## 89. Production rollout

Production deployment supports immutable releases, health checks, canary rollout, workspace cohorts, automatic pause, rollback, and complete audit trails.

Migrations pass compatibility gates before traffic shifts.

Old and new clients, jobs, messages, and schemas must overlap during rolling upgrades.

## 90. Regions and scaling

Regions and data residency are organisation or workspace policies.

Resource classes and scaling limits are deployment declarations. Application code does not receive arbitrary process control.

## 91. Local development

Local development runs the same runtime and control-plane semantics through approved local implementations.

Local mode may reduce scale, but it must not weaken tenant isolation, authorization, effect checking, or capability enforcement.

## 92. Privileged operational actions

Privileged approval is required for destructive migrations, cross-tenant access, secret export, supplier changes, raw SQL, native code, unrestricted networking, data-region changes, and emergency production overrides.

---

# Part XVIII — Escape Hatches

> **Status: COMMITTED as policy, unimplemented.** §98's guarantee boundaries are load-bearing for the containment claim and are why `general-ecosystem.md` was retired (`docs/VISION_RECONCILIATION.md` §3.3). No escape-hatch machinery exists yet.

## 93. Native code

Native code is forbidden by default.

Permitted only through a signed adapter, an explicit native-code capability, and strong isolation.

A separate process or sandbox is preferred over in-process execution.

## 94. Arbitrary networking

Arbitrary networking is forbidden by default.

Approved capabilities use allowlisted hosts and protocols.

Unrestricted outbound networking requires a privileged capability such as `network.unrestricted`.

## 95. Files and processes

Application code cannot access arbitrary host files or spawn arbitrary processes.

> **Currently it can do both**, with no import and no declaration: `os.ReadFile`, `os.WriteFile`, `os.RemoveFile`, `os.RunProcess`, and `os.System` (which spawns `/bin/sh -c`) are ambient. See §74 and `docs/ONE_WAY_LEDGER.md` E19. This Part is marked COMMITTED as policy and unimplemented; this is the sharpest instance of that.

Approved filesystem access is sandboxed and path-scoped. Process execution requires an isolated worker capability.

## 96. Containers and binaries

Unapproved containers or binaries cannot run inside the normal Gust runtime.

They may run only as isolated external services with declared network, data, identity, and resource boundaries.

## 97. Escape-hatch governance

Every escape hatch requires explicit manifest declaration, human approval, defined scope, expiry, signed provenance, an isolation policy, a deployment warning, runtime monitoring, a complete audit trail, and revocation support.

**Human approval means human.** An agent may request an escape hatch; it may not approve one.

## 98. Guarantee boundaries

- A sandboxed external adapter weakens guarantees only inside the adapter and the data explicitly exposed to it.
- An unrestricted network capability weakens supplier and data-egress guarantees for the holder.
- Arbitrary filesystem or process access weakens host-isolation guarantees.
- In-process native code weakens memory-safety and process-integrity guarantees for the entire application instance.
- Any mechanism that can bypass Gust isolation invalidates the wider guarantee for that runtime boundary.

> Escape hatches are isolated products with explicit loss-of-guarantee boundaries, not ordinary language features.

---

# Part XIX — Versioning and Compatibility

> **Status: SPECULATIVE.** The Part already says post-1.0 and not a commitment.

*Post-1.0 (§0.14). Recorded so demo-stage decisions do not foreclose it. Not a commitment.*

## 99. Compatibility promise

After 1.0, Gust promises strong source compatibility within each language edition.

Compatibility is the default. Editions are the controlled escape hatch for rare syntax or semantic changes. Different editions must interoperate within the same ecosystem.

## 100. Version pinning

Projects pin a language edition and a platform release line.

Compiler, runtime, standard library, and platform APIs normally upgrade together.

## 101. Release channels

Gust maintains a fast stable channel and an LTS channel. Each LTS release receives security fixes for approximately three years.

## 102. Security upgrades

Gust Cloud may require urgent upgrades for critical vulnerabilities.

Required upgrades must include migration tooling, staged rollout, and a defined deadline.

## 103. Compiler-assisted migrations

Compiler-assisted migrations are a core product feature.

Deprecations progress through warnings, automated rewrites, published deadlines, and removal at an edition boundary.

Note that where code is regenerated rather than maintained, the migration story shifts: the primary path is often regeneration against the new edition, not rewriting old source. Design for both.

## 104. Interface versioning

Standard-library and capability interfaces use semantic versioning with compatibility adapters.

Supplier interfaces evolve through versioned contracts. Applications are not forced to upgrade immediately when a supplier interface changes.

## 105. Hosted and self-hosted compatibility

Hosted and self-hosted releases remain wire-compatible throughout the supported release window.

Rolling upgrades require versioned messages, backward-compatible database changes, resumable jobs, and clients compatible with at least the previous server release.

## 106. Governance

Language and capability evolution is governed through public proposals, compatibility reviews, and published migration plans. §0.8 commits to a credible neutral-governance path; this section is where that commitment becomes concrete.

After 1.0, Gust must not silently change program meaning, weaken memory-safety guarantees, weaken authorization guarantees, break stable wire formats, or remove stable features without a migration path and edition boundary.

> Compatibility is the default; editions are the controlled escape hatch.

---

# Part XX — The Agent Loop

> **Status: DEFERRED (§108–§109 traces and diagnostics) / SPECULATIVE (§110–§114).** The Part already draws this line: traces and structured diagnostics are demo scope, colocation is post-acquisition.

*The product surface of §0.5 layers 1 and 4. Traces and structured diagnostics are demo scope; colocation is post-acquisition.*

## 107. The loop

The unit of agent work is one iteration:

```
generate → compile → run → observe → revise
```

Everything in this document that constrains the language exists to make one of those five steps cheaper, faster, or more informative.

**Latency budget.** The target for a warm iteration on a small change is single-digit milliseconds of platform overhead — compile and execute excluded. Crossing a public network boundary at any point forfeits the budget, which is why inference and execution are colocated (§113).

Iteration count is a quality input, and for an acquirer who serves inference it is also a consumption input. A loop two orders of magnitude faster does not produce marginally better output; it makes classes of problem solvable that were previously abandoned at the attempt limit.

## 108. Execution traces

Every run emits a structured, machine-readable trace. The trace is a first-class artifact with a versioned schema, not a log format. It is one of the three things humans actually read (§0.12).

A trace records:

- the resolved capability set for the entry point;
- **effects actually exercised**, in order, with arguments elided to declared schemas;
- **declared-but-unused capabilities** — over-granted authority the agent can narrow without human input;
- **denied authority attempts** — the single most valuable signal for correcting generated code;
- database queries with injected tenant and policy predicates shown;
- task tree, scheduling decisions, and cancellation points;
- allocation and context lifetimes at region granularity;
- typed error values with propagation path;
- conformance-check results (§79) and, once it exists, intent-contract violations (Part XXI).

Traces are tenant-scoped and subject to the same data-minimization rules as supplier boundaries (§85).

## 109. Diagnostics as machine input

Compiler diagnostics have a structured form alongside the human form. A diagnostic carries the rejected construct, the rule violated, the minimal set of edits that would satisfy the rule, and a stable rule identifier.

The design constraint: a diagnostic must be sufficient for correction without re-reading the whole file. Diagnostics that require whole-program context to act on are defects.

## 110. Sandbox lifecycle

Agent execution runs in a pre-warmed sandbox with the application's capability set already resolved.

The sandbox boundary and the capability boundary are the same mechanism. Gust does not wrap an untrusted container around agent output and hope; the compiler has already established what the program can reach, and the runtime enforces exactly that set.

Sandboxes are disposable, content-addressed, and reproducible. Two runs of the same release with the same input produce the same trace, or the difference is itself recorded as a nondeterminism finding.

## 111. Reproducibility

Content-addressed builds, no install-time execution (§15), virtualized time and randomness (§76), and deterministic scheduling (§77) combine to make a run a clean observation.

A nondeterministic run is not a weaker signal; it is a contaminated one, and must be discarded rather than averaged.

## 112. Traces as training signal

Because authority is declared and execution is deterministic, every run yields a labelled example without human annotation:

- did the program compile;
- did it attempt authority it did not hold;
- did it hold authority it did not use;
- did it pass its generated conformance checks (§79);
- did it satisfy its declared intent contract (Part XXI) — *once that exists*.

These labels are mechanical, and they are produced as a byproduct of running the language rather than as a separate data programme. For an acquirer who trains models this is a second reason to want Gust (§0.8). It is a value driver in their diligence, not a thesis we need to prove, and the company should not be organised around it.

Note that until Part XXI exists, the labels are structural only. The most valuable label — *did it do what was asked* — is the one that is missing, which is the practical form of the argument in §0.4.

**Customer data governance is a hard prerequisite, not a follow-up.** Trace retention, tenant consent, opt-out, and the boundary between structural signal and customer content must be specified and contractually committed before any trace leaves a tenant boundary. Nothing in this Part authorizes use of customer application data for training.

## 113. Colocated inference and execution

The platform runs model inference and application execution on the same fabric.

What this buys:

- **Loop latency** — no public-internet round trip per iteration (§107).
- **Warm state** — content-addressed build cache and pre-warmed sandboxes local to the inference host.
- **Trace fidelity** — the observation is produced where it is consumed.

What it costs, stated plainly:

- Multi-tenant execution of agent-authored code is a hostile-workload threat model. A compiler bug becomes a sandbox escape.
- Serving inference and running customer workloads are different infrastructures. Colocation means building the second, not repurposing the first.
- The benefit is bounded by where application state lives. If the database and third-party APIs sit in another cloud, the fast half of a slow round trip has been optimized.

Colocation is an argument an acquirer can act on, not something we build. Recorded here because the language and runtime decisions above are what make it possible, and demo-stage choices should not foreclose it.

## 114. Agent identity and authority

An agent acting against a deployed application is a service account (§49) with scoped capabilities, expiry, and its own audit trail.

Agents may not approve escape hatches (§97), may not self-elevate capabilities, and may not widen the authority of a release without a human-approved manifest change appearing in the lockfile diff (§72).

Authority granted to an agent is narrowed, never inherited: an agent operating on behalf of a user receives a strict subset of that user's authority, scoped to the task.

---

# Part XXI — Intent and Specification (OD-6)

> **Status: SPECULATIVE.** Blocks v1.0, not v0.1 (§0.4). This is the unsolved half — correctness rather than containment — and leading with it is how nothing ships.

*Blocks v0.5, not the demo. Specified as a requirement, not a design — the form is unresolved. This is the difference between containment and correctness (§0.4).*

## 115. Why this Part exists

Gust enforces **authority** and records **outcomes**. It has no representation of **intent**.

You can enforce that an application cannot reach the payments API. Nothing in the preceding 114 sections tells you it charges the right amount.

Where humans read code, that gap is filled by reading: intent lives in the developer's head, is expressed in the source, and is confirmed by review. Under the readership thesis (§0.1) that mechanism is gone and nothing has replaced it. This is a hole in the trust chain, not a missing convenience.

The failure mode is stated in §0.12: agent-authored code fails from **plausible-but-wrong**. It compiles, type-checks, reads well, and does something subtly different from what was asked. No type system catches that. No capability system catches that. Only execution against stated intent does.

**This Part is the difference between Gust being a good security product and Gust being a category.** §0.4 makes that argument; this Part is where it would be paid off.

## 116. Requirements

Whatever form the intent layer takes, it must:

- **Be authored by humans, or reviewed by them.** This is the artifact that replaces reading. If it is generated unreviewed, the trust chain closes on itself and proves nothing.
- **Be executable or mechanically checkable.** Prose is not enough. The check must run in the loop (§107) and produce a signal in the trace (§108).
- **Be versioned with the application** and appear in deployment diffs, like policies (§53).
- **Be independent of implementation.** A regeneration that changes every line but preserves behaviour must still satisfy it. This is what makes regeneration-over-maintenance (§103) safe.
- **Compose with effects.** An intent contract on a function declaring `payments.charge` should be able to constrain what it charges, not merely that it may.
- **Fail loudly and locally.** A violation names the contract, the observed behaviour, and the minimal difference — sufficient for an agent to correct without whole-program context (§109).

## 117. Candidate forms

Unresolved. Three shapes worth prototyping during v0.1, decided before v0.5:

1. **Executable specifications** — typed example-based contracts checked on every run. Cheapest to build, weakest coverage, most legible to non-technical authors.
2. **Property declarations** — invariants over state and effects, checked by generated property tests (extending §79). Strongest coverage, hardest to author, natural fit with existing conformance machinery.
3. **Behavioural contracts on capability interfaces** — pre- and post-conditions attached to effect declarations. Best composition with Part V, narrowest scope.

Not mutually exclusive. The likely answer is a small core of (3) with (1) as the authoring surface and (2) as the depth option.

## 118. Relationship to the rest of the document

- **§79 conformance checks** are the closest existing machinery and the natural implementation substrate. They check structural properties today; this Part extends them to domain behaviour.
- **§108 traces** must carry contract results, or the loop cannot use them.
- **§112 training labels** gain their most valuable entry — *did it do what was asked* — only once this exists. Until then the labels are structural and the RL claim is correspondingly weaker.
- **§53 policies** are the model for authoring and versioning: declared centrally, referenced explicitly, shown in deployment diffs, denied by default when ambiguous.
- **§0.4** is the strategic argument for why this Part is the roadmap rather than the launch.

---

# Part XXII — Consolidated Architectural Rules

> **Status: index.** Restates rules from every Part above; each rule inherits its own Part's status. `docs/ONE_WAY_LEDGER.md` records which of them the compiler currently enforces.

1. Gust is built for software written by machines and never read by people — as a market observation about what to build first, not as a licence for ceremony in the language (§0.1).
2. Humans own intent, authority, and outcomes. The compiler owns everything in between.
3. Gust delivers containment, not correctness. Never claim otherwise.
4. No code executes authority it did not declare, and the compiler enforces it.
5. The unscoped query does not compile.
6. The lever is the generator, not the developer. Judge every decision against it.
7. Gust arrives as a mode of someone's product, never as a product users must choose.
8. The demo is the asset. Everything else is scaffolding.
9. Untrusted code must cross an explicit, isolated, auditable boundary.
10. Supplier certification is a service tier; capability enforcement is the guarantee.
11. Effects are business-level authority, not syscall-level permissions.
12. Effects are declared on every function. Nothing is inferred, because the effect set is the artifact a reviewer reads. ("Verbosity is free" as a general principle is withdrawn — Part IV.)
13. Gust owns the full-stack application model rather than assembling third-party frameworks.
14. PostgreSQL and S3-compatible storage are native platform infrastructure.
15. Workspace tenancy is resolved before application execution and automatically scopes platform operations.
16. Recoverable failures use `Result` and `Option`.
17. Gust favours concrete structs and functions over inheritance, broad traits, or complex generics.
18. There are no user macros and no arbitrary compile-time execution.
19. Typed queries, typed RPC, and typed templates are compiler-owned derivations, not user-level generic programming.
20. Structured tasks own concurrency; jobs own durable work.
21. Transactions are lexical, typed, and cannot leak authority.
22. Safe references are non-null and context-branded.
23. Gust distinguishes copy values, views, owned values, and linear resources.
24. `str` and slices are immutable context-bound views.
25. References are `&T[ctx]`: context-branded, non-null, lexical, and mutable. Restricting mutation through them is deferred (§26).
26. Linear-resource opt-in is explicit and propagates through containing types.
27. `defer` is LIFO; automatic destruction is reverse declaration order.
28. Destructors are infallible; fallible completion is explicit.
29. The UI uses typed lit-html-style templates with incremental DOM updates.
30. SAM owns state transitions and effects.
31. Client/server boundaries are explicit and communicate through typed RPC.
32. Authorization defaults to deny and is enforced before execution, in queries, and at runtime.
33. PostgreSQL defines the schema; Gust generates types and provides typed queries.
34. Migrations are explicit, manifest-ordered, and compatibility-first — and are the one artifact still read by humans.
35. Jobs are at-least-once and rely on idempotency for exactly-once-like outcomes.
36. Caches, messages, jobs, and capability calls are tenant-scoped.
37. Secrets are opaque linear values.
38. Supplier access is purpose-specific and data-minimised.
39. Hosted and self-hosted Gust share one product architecture.
40. Escape hatches always expose the exact boundary at which Gust's guarantees weaken.
41. Determinism is a product requirement, because a run is an observation.
42. Every run emits a structured trace; the trace is an artifact, not a log.
43. The sandbox boundary and the capability boundary are the same mechanism.
44. Agents are service accounts with narrowed authority and their own audit trail.
45. Conformance checks substitute for reading and must be resourced as such.
46. Gust says *enforce*, *check*, and *reject*. Gust does not say *prove*.

## Which of these the compiler enforces today

This list is the most quotable part of the document and the easiest to mistake for a description of the compiler. It is a statement of intent. `docs/ONE_WAY_LEDGER.md` carries the per-rule status with a reproduction; the summary, verified 2026-08-20 at `b47d0049`:

**Enforced.** 17 (no inheritance or traits), 18 (no macros or compile-time execution), 22 (references non-null — there is no `null` literal in either lexer), 24 (`str` has no mutation API at all), and enum-match exhaustiveness from §31, which is checked in both compilers and names the missing variant.

**Not implemented at all.** 4 and 5 — the two rules the product claim rests on. There is no `uses` keyword in either lexer and no query layer, so neither undeclared authority nor an unscoped query is currently rejected by anything. Also 11, 13, 14, 15, 19, 20, 29–36, and 38–45: the platform they describe does not exist (ledger E16).

**Partly true, and misleading as stated.** 16 — `Option` exists but `Result` is not a builtin and there is no `?` operator; the working convention is `guard … else` (E2). 26 — resource *opt-in* is explicit, but the move-versus-copy linearity that governs ordinary values is *inferred* structurally and unannotated, so adding a `str` field silently changes a struct's category (E13); the two mechanisms share a word and only one is opt-in. 27 — `defer` parses and scope-exit cleanup is validated, but only for `Resource[T]` and only in the self-hosted compiler (E7 addendum, D-6).

**Violated.** §34's panic scoping, reached from rule 28's neighbourhood: a string bounds failure calls `exit(1)` and terminates the process rather than the request (E3, issue #91). And §32's overflow trapping, which rule 3's "containment, not correctness" does not cover: overflow is undefined behaviour on the default backend rather than a trap (E11, issue #103).

Rule 46 is the discipline that makes this section necessary. A rule stated in the present tense that nothing enforces is the document saying *prove* while meaning *intend*.
