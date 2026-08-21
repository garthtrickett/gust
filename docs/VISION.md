# Gust — The Agentic Software Vertical

**Product, Language, Runtime, and Platform Decisions**

> **What this document is.** A well-specified hypothesis with ten registered decisions: six open, two direction-set, and two resolved (§0.15). Two of the open decisions — **OD-9** (can a model write Gust) and **OD-8** (is the scoping analysis sound) — can invalidate the thesis outright, and both resolve inside the next four months. The prose is confident because vague prose cannot be attacked; the uncertainty is real and lives in §0.15. Read that table before treating any of this as settled.
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

**1. Language — agent-writable, machine-verifiable.** Explicit effects, no ambient authority, one canonical way to express intent. Small surface, minimal idiom drift. Explicit exactly where the explicitness is the artifact; inferred everywhere else (§0.1).

**2. Runtime — verifiable execution substrate.** Capability manifests, no install-time execution, content-addressed reproducible builds. Determinism is the precondition for everything above and below it.

**3. Framework — the full-stack surface.** So agents have a canonical target and a buyer has something recognisable to adopt.

**4. Machine Interface — the loop.** Generate, compile, run, trace, revise. Structured traces are the artifact; iteration count is a quality input.

Only layers 1 and 2 matter before the demo. Layers 3 and 4 are how an acquirer productises it.

> **Layer 4 was renamed from "Platform" on 2026-08-21.** Its content is unchanged. The old name collided: `docs/STRATEGY_REVIEW.md` §1 uses "Platform" for HTTP, SQL and auth — this document's *layer 3* — so a reader who knew one document and met the other was wrong with no error signal, because the sentence still parses. "Machine Interface" describes its contents; "Platform" for the loop did not. `docs/STRATEGY_REVIEW.md` §1 holds the mapping across all four layer models in circulation.

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

**This table is the register. It is the only place an OD is opened, closed, or
renumbered.** Other documents may *discuss* an OD and should link back here; none
of them may change its status. The `Stated in full` column names the one place
that carries the reasoning, so that this table stays an index and never becomes a
second, drifting copy of it.

| # | Question | Status | Blocks | Stated in full |
|---|---|---|---|---|
| **OD-9** | **Model fluency** — can an agent write Gust well, and how do we get there from no corpus? *Thesis-invalidating. Starts week one.* | **OPEN** | Demo | §0.7; blocked-on evidence in `TASK_STDLIB.md` CR-6 and `docs/ONE_WAY_LEDGER.md` E1 |
| **OD-8** | **Soundness of the tenant-scoping analysis** — adversarial review before publication. *Thesis-invalidating.* | **OPEN** | Demo | §56; sequencing in `docs/DEMO_TARGET_PROGRAM.md` |
| OD-1 | Transparent suspension vs coloured async (server) | **DIRECTION SET 2026-08-20** — transparent suspension unless a fatal blocker is hit; §21 defines what counts | Demo | §21; evidence in `docs/ONE_WAY_LEDGER.md` E9; escalation as `TASK_STDLIB.md` CR-8 |
| OD-2 | ~~Generic functions vs compiler-owned query derivation~~ | **RESOLVED 2026-08-20** — compiler-owned derivation; §13's ban stands | — | §14; consequences in §13 and `docs/DEMO_TARGET_PROGRAM.md` |
| OD-10 | **Distribution for the product path** | **OPEN** — first candidate recorded 2026-08-20 (`docs/STRATEGY_REVIEW.md` §6); **first *deployment* proposed separately at §6.1**, deliberately not an answer to this row | Month 4 | §0.11 |
| OD-3 | SAM state ownership under linear resources and no interior mutability | **OPEN** — leading direction proposed 2026-08-20 (§38.1); partly decided by implementation, `std.Rc` already ships | v0.5 | §27, §38; the discrepancy as `TASK_STDLIB.md` CR-9; evidence in `docs/ONE_WAY_LEDGER.md` E8 |
| OD-4 | WASM stack-switching support and payload cost | **OPEN** — recommendation recorded and then revised on checked support data, 2026-08-20 (§21.1) | v0.5 | §21, §41 |
| OD-6 | Form of the intent layer | **OPEN** — leading proposal recorded 2026-08-20 (§117.1): contracts on capabilities as the core, examples as the authoring surface, properties for depth | v1.0 | Part XXI |
| OD-11 | ~~The fate of `std.Spawn`~~ | **RESOLVED 2026-08-20** — bare form deleted; scoped spawn returns a linear task handle | Demo | §20.1 |
| OD-5 | Supplier certification staffing model | **DIRECTION SET 2026-08-20** — split the function: an agent does conformance, the operator does trust and commerce; pricing still open | Post-1.0 | Part XVI |

There is no OD-7. The number is unused and nothing in the repository references it; it is recorded here so a reader who notices the gap does not go looking.

**Numbers are append-only and never recycled.** OD-11 was opened on 2026-08-20 with OD-7 sitting vacant, deliberately. A recycled number reads correctly in every new document and silently wrong in every old one, and the failure is invisible precisely because the reference resolves. A permanent gap costs one sentence of explanation; a reused number costs a misreading nobody can see.

**This table is also the escalation list, and that is its second job.** A lane
working autonomously needs a test for *when to stop and ask*, and the test is
this register: **an open decision is a decision-tree node; everything else is
lane work.** Stated as a rule so a lane does not have to invent one:

**Escalate to the operator — stop and wait — only when:**

1. **an OD's status would change.** Opening, closing, or renumbering happens here
   and nowhere else, and no lane does it alone;
2. **the action is irreversible and outward-facing** — publishing, an external
   claim, revoking a supplier, deleting a shipped surface;
3. **it spends money or promises something to a third party;**
4. **it crosses a boundary the operator set**, which no pulse and no other lane
   can widen.

**Register and keep going — do not wait — when:**

- **the question is new but OD-sized** (thesis-affecting, cross-lane, or
  commercially binding). **Registering is not escalating.** Add the row, record a
  proposal marked as a proposal per §0.17, and move to other work. The operator
  answers when they answer, and the analysis is on disk in the meantime;
- **an existing OD blocks the task.** Record what the task needs from it, and
  take the next unblocked item;
- **two designs both satisfy every stated constraint.** Pick one, record why, and
  note what would falsify the choice. **A lane that asks "is this OK?" rather
  than "which do you want?" is asking for reassurance rather than a decision**,
  and that is the failure mode this rule exists to prevent.

The distinction that does the work: **escalate on *authority*, not on
*difficulty*.** A hard question a lane is competent to answer is lane work; an
easy question about what the operator wants is not.

**How to cite a status elsewhere.** Attribute it, never assert it: "§27 marks
this open" is safe, "this is open" is not. An attributed citation is wrong only
when it misquotes; an asserted one is wrong whenever the register moves and
nobody remembered the file. The distinction is not pedantic — a sweep on
2026-08-20 found §27 stale at the source and three documents citing it correctly,
which meant the error propagated with every citation intact.

**Why the register is centralised rather than distributed.** An open decision that
lives only in the document that happened to prompt it inherits that document's
readership, and the decisions here are exactly the ones that must not be resolved
by whoever reads the narrowest file. OD-3 is the worked example of the failure
mode: it was recorded open in §27, and `std.Rc` shipped anyway. Nothing lied —
the shipping lane simply was not reading §27. A register does not prevent that,
but it makes the discrepancy findable from one place, which is how CR-9 came to
be written at all.

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

**Numbered subsections carry a second, finer status, and it is not the same scale.** Ten `x.y` subsections were added on 2026-08-20, all of them design work on decisions that were open. A Part marker answers *is this scheduled*; a subsection marker answers *has anyone agreed to it*. A reader who applies the Part's COMMITTED marker to a subsection inside it will read an undecided proposal as settled policy, which is the same confusion §0.17 exists to prevent, one level down.

| Subsection wording | State | Who can change it |
| --- | --- | --- |
| **"— proposed"**, **"Recommendation for …"** | This lane's design work. **Nobody has ruled on it.** Written to be argued with. | Anyone with a better argument |
| **"Proposed leading direction"**, **"Leading proposal"** | The operator has indicated a preference. **Not closed** — the requirement it answers still stands. | The operator |
| **A decision stated with a date** | Decided. §0.15 carries the status; the subsection carries the reasoning. | The operator, by reopening the OD |

Two subsections fit none of these and should not be read as proposals: **§56.1** is a target list for a review §0.11 already requires, and **§20.1** records a resolved decision.

**The rule that keeps this honest: a subsection may not promote itself.** Rewording "proposed" to "leading" is a status change, and §0.15 is the only place a status changes. If a subsection's wording and the register disagree, the register wins.

## 0.18 Verification index

Which sections have been checked against the compiler, and where the evidence
is. `docs/ONE_WAY_LEDGER.md` holds the reproductions; this table is the index
into them, so a reader of any section can find out whether it describes the
compiler or describes the target.

**This table is derived from `docs/ONE_WAY_LEDGER.md`, not maintained by hand.**
The regeneration command, and two extraction traps that produce false positives,
are recorded in that file's Maintenance section. Regenerate it when evidence
sections are added or renumbered.

| Section | Subject | Evidence |
| --- | --- | --- |
| §11 | `Result`, `?`, non-null references | E2, E14 |
| §14, §16 | generics, operators, conversions | E15 |
| §17, §18 | effects — **the differentiator** | E10 |
| §20, §30 | structured concurrency, channel ownership | E9, E18 |
| §23, §28 | value categories, linear resources | E13, E20 |
| §25 | cross-context movement | E20 |
| §26 | borrows | E6 |
| §27 | shared ownership (OD-3) | E8 |
| §31 | enum exhaustiveness | E12 |
| §32 | numbers, overflow | E11, E15 |
| §34 | panic scope | E3 |
| §70, §72 | modules, packages, lockfiles | E21, E16 |
| §73, §74 | visibility, prelude | E19 |
| §75–§79 | testing and conformance | E22 |
| §81 | secrets | E26 |
| §93, §94, §95 | native code, networking, host access | E21, E19 |
| §99, §100, §103 | editions and migrations | E25 |
| §108, §109 | traces, diagnostics | E25, E23 |
| §111 | reproducibility | E24 |
| §15 | no compile-time execution | E24, and the `HOLDS` rows in E4 |

**Sections not listed are covered by their Part's status marker rather than
individually.** That is deliberate, not an omission. Most of them describe
platform surface — Parts IX through XII, XVI and XVII — and E16 verifies the
whole of it in one place: the runtime is eight C files, and no HTTP, SQL, RPC,
job, template, or supplier concept exists as a runtime symbol, a registered
name, or a keyword. Auditing those sections one at a time would restate E16
forty times.

Part 0 is also unlisted, for a different reason: it is strategy, and there is
nothing in the compiler to check it against.

**Counts, 2026-08-20 at `b47d0049`:** 44 rules tracked, of which 9 hold, 10 are
partial, 7 are violated, 1 is deferred, and 17 are absent. Read
`docs/ONE_WAY_LEDGER.md`'s "recurring pattern" note before drawing a conclusion
from those numbers — three of the practices this document asks for already exist
and are aimed at the compiler rather than at applications.

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

> **For a meeting, read `docs/MESSAGING.md`** — it indexes this section with `docs/STRATEGY_REVIEW.md` §6 and `docs/BUSINESS_STRATEGY.md`, and carries §79's external-language rule alongside what the ledger says can honestly be claimed today.

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

> **There is a second spelling of absence, and it is the one the compiler uses.** Verified 2026-08-20 at `b47d0049`. `null`, `nil`, and `NULL` are absent from both lexers, so the sentence above holds for *references*. But `empty` is a keyword and `empty[T]` is a sentinel meaning absent for `Index[T, ctx]` handles — 130 uses in the typechecker alone and 6 test programs, always in ordinary safe code, compared with `==` and `!=` exactly as a null check would be.
>
> `empty[T]` is arguably one of the "compiler-owned runtime representations" this paragraph permits, but it is not confined to a boundary: it is how the compiler's own source spells "no value", in preference to the `Option[T]` the previous paragraph nominates. Two spellings of absence coexisting is a one-way-to-do-it problem in its own right. `docs/ONE_WAY_LEDGER.md` E14, rows 32 and 45.

*Rationale: a single total failure convention makes generated error handling mechanically checkable for exhaustiveness rather than stylistically reviewed.*

### 11.1 What `?` must do — proposed

Row 2 of `docs/DEMO_TARGET_PROGRAM.md`. Verified 2026-08-20: **there is no `?` operator** — zero occurrences in `compiler/lexer.gst`. What exists is `Result` itself, hand-rolled by the compiler at `compiler/errors.gst:17`, which is simultaneously the evidence that the language lacks it and the evidence that it is expressible.

**The problem nobody has stated: `?` as everyone knows it depends on a facility §13 bans.** Rust's `?` converts the callee's error into the caller's error type through a generic trait implementation. Gust has no user-written generic functions, and OD-2 settled that it will not get them. So the conversion step has to come from somewhere else, and **that — not the propagation — is the whole design question.** Three ways out:

1. **One error type.** No conversion, because there is nothing to convert. `?` is then pure propagation.
2. **Compiler-owned conversion**, derived rather than user-written, on the OD-2 precedent.
3. **Explicit conversion at every `?` site.** Honest, and it defeats the point of having the operator.

**Recommendation: option 1, and the compiler is the evidence.** `compiler/errors.gst` declares a single `CompilerError[ctx]` with a `kind: ErrorKind` discriminant, not an error type per module. The most demanding real consumer of this language, free to structure errors any way it liked, chose one type and a tag. A design that generalises from that is generalising from practice rather than from taste.

**Where the error lives is already answered, and the answer is not the obvious one.** `Err` holds `Index[CompilerError[ctx], ctx]` — an **arena index**, brand-parameterised, not a pointer and not an inline value. That is what makes the type sound under §24: an error cannot outlive the arena it was raised in, because its handle is branded. The consequence for `?` is direct and worth stating before it is discovered: **an error propagating out of a callee must be allocated in an arena that outlives the callee**, so `Result[T, ctx]`'s brand is the caller's, not the callee's scratch. `Result` already carries the brand parameter that makes this expressible.

**Two constraints from elsewhere in this document.**

- **`?` means "may fail" and nothing else (§21).** It must not acquire a suspension meaning, which is what makes the transparent-suspension direction coherent — the operator stays about failure because suspension needs no operator.
- **It cannot fix absence.** §11's note records that `empty[T]` is the compiler's actual spelling of "no value", used 130 times in the typechecker in preference to `Option[T]`. `?` over `Result` does not touch that, and shipping `?` while two spellings of absence coexist would leave the smaller half of row 2 unfinished. `docs/ONE_WAY_LEDGER.md` E14, rows 32 and 45.

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

> **Confirmed 2026-08-20 by the resolution of OD-2 (§14).** This list is settled rather than provisional: user-written generic *functions* are excluded with the rest, and the surfaces that would otherwise need them are compiler-owned derivations. A feature request that requires generic functions is a request to reopen OD-2, not a request for an exception here.

## 14. Generic functions and compiler-owned derivation (OD-2)

User-written generic functions are not available initially.

The typed query builder (§55), typed RPC schemas (§44), and typed templates (§37) all require type relationships that ordinary structs and concrete functions cannot express. **These are compiler-owned derivations, not user-level generic programming.** The compiler computes result types for joins, projections, aggregates, and serialization boundaries; application code receives concrete generated types.

This resolves the apparent conflict between §13 and §55: the query builder is not implemented in the user-facing language. It is a compiler feature with a typed surface.

It also answers "why not build Gust as a library over an existing austere language" — the differentiating features require compiler support, and any language austere enough to be a good base bans the metaprogramming that would let you add them from outside.

**OD-2 is resolved, 2026-08-20: compiler-owned derivation, and §13's ban on user-written generic functions stands.**

The question was whether a restricted form of user-written generic function is required before v0.1 for standard-library collection code, or whether compiler-owned containers cover it. The decision is that they cover it. Generic *structs* and *enums* remain available; generic *functions* do not, and the derived surfaces — the query builder, RPC schemas, templates — stay compiler features with typed surfaces rather than libraries written in Gust.

What this commits the project to, stated plainly because it is a constraint and not only a simplification:

- **Every collection in the standard library must be expressible without generic functions.** If one is not, that is a reason to reopen this decision, not a reason to add a local exception. §13's value comes from being categorical.
- **Every derived type surface is compiler work.** There is no path where a library author supplies one, so the cost lands on the compiler team by construction — which is the trade §13 is buying.
- **The escape hatch is a new compiler-owned derivation, never a user generic.** A request that would be answered by "write it generically" is answered here by adding a derivation or declining the feature.

The evidence for feasibility is the compiler itself: `compiler/errors.gst:17` declares `Result[T, ctx]` as an ordinary generic enum, so a demanding real consumer needed a generic sum type and expressed it with the facilities users already have.

> **No compiler-owned derivation exists yet**, because everything §14 lists as derived — the query builder, RPC schemas, templates — is itself unbuilt. What the section gets right today is the negative half: user-written generic functions are genuinely unavailable, while generic structs and enums with monomorphisation work (`docs/ONE_WAY_LEDGER.md` E15).
>
> One data point for OD-2 from the compiler's own source: `compiler/errors.gst:17` declares `Result[T, ctx]` as an ordinary user-level generic enum. The compiler needed a generic sum type and expressed it with the facilities users have, which suggests generic *types* do cover a good deal without generic *functions*.

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

> **None of Part V is implemented, but the carrier exists.** Verified 2026-08-20 at `b47d0049`: there is no `uses` keyword in either lexer and no effect in this Part's sense is declared or checked. What does exist is the structural shape — `FunctionSignature` (`compiler/typechecker.gst:633-645`) already states per-function obligations alongside the types (`is_unsafe`, `is_extern`, `requires_unsafe_call`, `requires_layout_metadata`, `requires_sandbox_arena`), and one is enforced: calling an `extern` function outside `unsafe` is rejected. Two of the three `requires_*` fields are inert — never set, and one accessor never called — so they read as reserved for obligations nothing yet assigns. Adding effects extends a struct with the right shape rather than introducing the concept. `docs/ONE_WAY_LEDGER.md` E10. This is the differentiator (§0.4) and Track A item 1, and §0.6 already lists it as absent — annotated here too because every lesser section in this document now carries its status, and the section the product rests on should not be the one that reads as settled. `docs/ONE_WAY_LEDGER.md` E10.
>
> Its absence is what makes several other rows unfixable in isolation: §81's `secret.use<…>`, §22's rejection of external effects inside retried transactions, §52's pre-execution authorization, and §108's record of exercised and denied authority all presuppose it.

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

### 18.1 What effect checking must do — proposed

Row 5 of `docs/DEMO_TARGET_PROGRAM.md`, Track A item 1, and the thing §81, §22, §52 and §108 each presuppose. §17 and §18 say what effects *are*; nothing says what the checker *does*. This is a proposal.

**1. The declaration is part of the signature, and it is the whole set.** A function performs an effect only if its own clause names it. There is no ambient authority and no inference at a declaration boundary — §17 already withdrew inference on private functions, and this is the rule that gives that teeth.

**2. Call sites check by subsumption, in the direction §17 states.** A caller's declared set must cover every effect its callees declare. Fewer effects may substitute where more are permitted, never the reverse. This is the only propagation rule; there is no separate inference pass, because the sets are written down.

**3. Restrictions are part of the effect, not commentary on it.** `db.read<User>` and `db.read<Order>` are different effects. So are `secret.use<"stripe">` and `secret.use<"twilio">`, and `network.request<host>` for two hosts. Subsumption compares the restriction, so widening one — a function that read `User` now reading everything — is a signature change and shows up in a diff, which is the property §0.12 and §108 are actually buying.

**4. `main` is where authority enters, and the only place.** The platform grants the root set; every other set is a narrowing of something a caller already held. §17's "authority may only be delegated by explicitly narrowing an existing capability" is the same rule stated from the other end.

**5. `unsafe` grants nothing (§19).** An unsafe block still needs every effect it uses. Worth restating as a checker rule because it is the natural place for an implementation to take a shortcut.

**6. The compiler needs no new carrier.** `FunctionSignature` already states per-function obligations alongside types, with two `requires_*` fields inert. An effect set is another such field, and one of the existing ones — the `extern`-outside-`unsafe` rejection — is already the enforcement shape this needs. **This is why row 5 is cheaper than its position on the list suggests: the concept is new, the plumbing is not.**

**Open sub-questions, stated rather than assumed away.**

- **Do spawned tasks inherit the parent's effect set?** §20.2's `s.Spawn(f())` runs `f` elsewhere, so either the scope's set bounds it or the task carries its own. Inheritance is convenient and makes the spawn site useless for review; an explicit set is verbose at exactly the point where the concurrency is already dense. Not decided here, and it is a real question rather than a detail.
- **What do function values carry?** §17 says function values preserve their effect sets. That makes the effect set part of the type of a closure, and therefore part of every signature that takes one.
- **Where do supplier capabilities (§98) sit in the naming scheme?** `payments.charge` is business-level by design, but a supplier boundary is where business-level and vendor-level meet.

**How this composes with §56.2.** They are two obligations on one call, and they are independent. `uses db.read<Issue>` answers *may this function read issues at all*; the scope obligation answers *does this particular query carry the caller's tenant*. Neither implies the other, and a design that collapses them will be wrong in the direction that matters — an authorised read of the wrong tenant's data is the failure mode §56 exists to prevent.

## 19. Unsafe and authority

`unsafe` is independent from capability authority.

An unsafe block does not grant access to databases, networks, secrets, storage, suppliers, or cross-tenant operations.

Unsafe code must still possess every required effect.

---

# Part VI — Concurrency, Tasks, and Transactions

> **Status: COMMITTED (§20–§21) / DEFERRED (§22 transactions).** OD-1 has a **direction set as of 2026-08-20 — transparent suspension unless a fatal blocker is hit** (§21). What exists today is still detached `std.Spawn` plus channels — the model §20 rejects; see §21 and `docs/ONE_WAY_LEDGER.md` E9.

## 20. Structured concurrency

Normal application concurrency is structured and request-scoped.

Spawned tasks belong to a lexical task scope. Leaving that scope must wait for completed children, cancel unfinished children, and prevent detached work from leaking.

Cancellation propagates from parent tasks to children. Task failures propagate through `Result`.

Fire-and-forget work is not permitted in normal request code. Durable background work uses jobs.

Channels may exist as a lower-level primitive. Actors are a library or platform pattern, not the universal concurrency model.

### 20.1 OD-11 — the fate of `std.Spawn`

**The question.** `std.Spawn` starts work that no scope owns, returns no handle, and has no join or cancellation path (`docs/ONE_WAY_LEDGER.md` E9). Either it **gains a task handle** and becomes the low-level primitive beneath the structured layer, the way §20 already permits for channels — or it is **deprecated**, and a scoped spawn is the only spelling. Today it is neither, which is why §20 forbids fire-and-forget in request code while the only primitive available is fire-and-forget.

**Why it is opened now, and why it is small.** This was previously a sub-clause of OD-1: which fate `std.Spawn` deserved depended on whether suspension would be transparent or coloured. **OD-1's direction removed that dependency** (§21). Under transparent suspension, `std.Spawn` cannot be the low-level primitive *as it stands* — it hands back nothing, and a structured layer needs something to own. So the residue is a single binary question that the owning lane can answer without reopening the suspension model. It is registered rather than left implicit because a question that has narrowed enough to be answerable is exactly the kind that gets forgotten inside the larger one it came from.

**The leaning, not a decision.** Deprecation. §20 already routes durable background work to jobs and unowned work is not permitted in request code, so the use case a bare `std.Spawn` serves is one the design has already declined; keeping it means keeping two spellings for one concept, which is the thing §13 and `docs/ONE_WAY_LEDGER.md` exist to prevent. The argument the other way is real and should be made if anyone holds it: a handle-bearing `std.Spawn` gives the structured layer something to be built *out of*, and a language with no low-level primitive at all has to get the high-level one right on the first attempt.

#### Resolved, 2026-08-20 — the bare form is deleted; scoped spawn returns a linear handle

**Operator decision.** `std.Spawn` as it stands is removed. The scoped spawn is the only way to start a task, and it returns a **linear task handle** that must be joined, cancelled, or transferred before its scope exits.

The reason this is the right shape rather than merely the tidiest: §20's ban on detached work stops being a rule nothing checks and becomes **a move-checker obligation**, using Phase 15 machinery that already ships. And it answers the one real objection to deletion — that removing the bare form leaves nothing to build the structured layer out of. **A linear handle is that thing.** The primitive survives; what is deleted is the version of it that hands back nothing.

The ranking below is kept as the record of what was considered. Option 2 (demote to the runtime surface) remains the fallback if the scoped layer proves to need iteration — it is the same design with the handle non-public.

#### 20.2 The scoped API — illustrative sketch

Not yet implemented, and not a syntax proposal; it exists so the decision above is concrete enough to argue with.

```
fn handle(req: &Request[r], ctx: Ctx[a]) -> Result[Response[a]] uses net.fetch {
    scope s {
        let user  : Task[User, s]  = s.Spawn(fetch_user(req.id))
        let prefs : Task[Prefs, s] = s.Spawn(fetch_prefs(req.id))

        let u = user.Join()?          // consumes the handle
        prefs.Cancel()                // also consumes it
        Ok(render(u, ctx))
    }                                 // scope exit: every handle already consumed
}
```

Three things carry the design:

- **`Task[T, s]` is brand-parameterised on the scope.** A handle cannot outlive `s` for the same reason an arena-allocated value cannot outlive its arena — it is the mechanism §24 already has, not a new one.
- **`Join`, `Cancel`, and `Transfer` all consume the handle.** They are the only three ways to discharge it, and each takes it by move.
- **Scope exit is where the check lands.** A live handle at the closing brace is a compile error, in the same class as an unconsumed linear resource under §28.

```
error: task handle `prefs` is still live at scope exit
  --> handler.gst:9:5
   |
 5 |         let prefs : Task[Prefs, s] = s.Spawn(fetch_prefs(req.id))
   |             ----- created here
 9 |     }
   |     ^ scope `s` ends here with `prefs` unconsumed
   |
   = a task handle must be joined, cancelled, or transferred before its scope exits
   = §20: fire-and-forget work is not permitted in request code
```

**Consequences worth stating now.** `Transfer` is the interesting one: moving a handle out of `s` to a longer-lived scope is what a supervisor is, so §21's three named concepts — child task, supervisor, durable job — fall out of one mechanism plus where the handle ends up, rather than needing three primitives. And **`?` still means only "may fail"**: `Join` can propagate a task's failure through `Result` without suspension acquiring a keyword, which is what §21's direction requires.

#### The candidates, ranked

The two options above are the ones stated when OD-11 was opened. Both assume the handle must exist; **what they actually disagree about is whether the low-level primitive is *public*.** Naming that reframes the decision and admits a third answer that neither states.

**1. Deprecate the bare form; the scoped spawn returns a *linear* task handle.** One spelling. The handle must be joined, cancelled, or transferred before scope exit, so §20's "no detached work" is enforced by the move checker rather than by a rule nobody checks — and that machinery is Phase 15's, already built and shipping. This is option 2 done properly: the objection to deletion was that it leaves nothing to build the structured layer out of, and a linear handle *is* the thing it is built out of.

**2. Demote `std.Spawn` to the runtime surface.** It survives with a handle, but stops being application-facing — the structured layer becomes its only caller. This keeps every engineering benefit of option 1 while removing what is actually wrong with it, since the problem was never the handle but the second public spelling. The best available compromise, and the right answer if the scoped layer turns out to need iteration.

**3. Give it a handle, publicly — option 1 as stated.** Sound engineering, and the ranking cost is not technical: two public ways to start a task, permanently, in a language whose premise is one of each. Migration never completes because nothing forces it.

**4. Implicit scope from the arena brand.** No call-site change; a task is owned by the context it allocates in. Elegant, and Gust already has the branding. Ranked below the compromises because it ties task lifetime to *allocation* lifetime, which are genuinely different things — a task can outlive the data that spawned it and often should — and §30's ownership-across-tasks rules do not fall out of it. Clever on the wrong axis.

**5. Retain the bare form under `unsafe` or a privileged capability.** Part XVIII exists for exactly this shape of thing, so it is legitimate rather than absurd. But §20 already routes durable unowned work to jobs, so this adds an escape hatch for a use case the design has declined — an escape hatch nobody has yet asked for.

**Last: change nothing.** Recorded because it is the outcome that happens by default if the decision is not made, not because it is a candidate. It leaves §20 stating a rule the only available primitive violates.

**Owner: the Cranelift lane**, under `docs/SHARED_SEMANTIC_ZONE.md`'s "Fiber scheduling contract" row. **The decision above sets what to build; it does not authorise the patch.** Implementation is that lane's, and the removal of `std.Spawn` is a breaking change to a shipped surface, so it needs a deprecation path recorded in the owning phase's roadmap rather than a deletion. Reported as `TASK_STDLIB.md` CR-8 and issue #101. Status owned by §0.15.

## 21. Suspension model (OD-1, OD-4)

**Preference:** Gust should avoid forcing all asynchronous code into a coloured async function hierarchy if capability calls can suspend transparently.

Concurrency remains explicit through task creation, task scopes, joins, cancellation, and timeouts.

**Open decision.** Transparent suspension implies green threads or effect handlers. Against a WASM browser target (§41) that means stack switching, with real cost in payload size, portability, and toolchain support, and it interacts directly with the ownership-across-tasks rules in §30.

The demo cut (§0.14) is server-only, which splits this cleanly: **OD-1 (server suspension) must resolve before the demo; OD-4 (WASM cost) defers to v0.5.**

**What exists today (verified 2026-08-20, `b47d0049`).** Neither model. There is no `async`, `await`, `spawn`, or `scope` keyword in either lexer. Concurrency is a library surface over the cooperative fibers in `src/runtime/fiber.c`: `std.Spawn`, `std.Channel`, `std.Mutex`, `std.Yield`. `std.Spawn` starts work that no scope owns, with no join requirement, no cancellation propagation, and no task handle — which is detached spawn plus channels, the model §20 rejects and the only one available. Recorded with reproductions in `docs/ONE_WAY_LEDGER.md` E9 and tracked as `TASK_STDLIB.md` CR-8.

**Direction set, 2026-08-20: transparent suspension, unless a fatal blocker is hit.** This is an operator decision on the server question. It is recorded as a direction rather than a closure because it carries an escape hatch, and an escape hatch that is not defined is not a hatch — it is a way to reopen the decision at any time. What follows defines it.

**What counts as a fatal blocker.** Exactly three things, and the burden is on the finding, not on the direction:

1. **A capability call cannot suspend without unwinding a native frame.** The scheduler is cooperative fibers in `src/runtime/fiber.c`, and vendor capabilities (§98) call into native code. If a blocking native call sits on the stack at the suspension point, transparent suspension requires either non-blocking native APIs throughout or an offload pool — and if neither is affordable, suspension cannot be transparent because it cannot happen.
2. **Ownership across tasks (§30) cannot be made sound without colouring.** If the only way to check that a linear value does not cross a suspension point illegally is to make suspension visible in the type, then the colour is doing load-bearing safety work and the direction is wrong.
3. **Cranelift cannot emit code compatible with the chosen switching mechanism for the server target.** A backend limitation, not a design preference.

**What explicitly does not count.** *Implementation difficulty* — this was known to be the harder option when it was chosen. *WASM stack-switching cost* — that is OD-4, it defers to v0.5, and §0.14's demo cut is server-only. The strongest available argument against transparent suspension is therefore out of scope for the decision this direction settles, and may not be borrowed back into it.

**The recommendation this direction adopts.** Take Go's *suspension* model and reject Go's *task* model: transparent suspension with no colouring, over a scheduler that already exists, with every task owned by a lexical scope that cannot exit while a child is live, and task handles as linear resources. Three named concepts — child task, supervisor, durable job — rather than one `spawn` with adjectives. `?` continues to mean "may fail"; suspension needs no keyword because it is always owned.

### 21.1 Recommendation for OD-4 — do not buy the transform

Two ways to make a WASM function pause. **Rewrite the emitted module** so every function saves its own position and locals and can be re-entered later — an off-the-shelf build step, works in every browser today, and roughly doubles the binary. Or **use the platform's own stack switching**, which costs nothing in size and depends on the browser having it.

**Support, checked 2026-08-20 rather than assumed.** The platform feature is JSPI, standardised by the W3C WebAssembly CG at Phase 4 in April 2025. **Chrome shipped it in 137.** **Firefox has it in 139 but behind a flag.** **Safari has not shipped it and has not publicly committed to doing so** — it withdrew its objection in late 2025 and has someone assigned, which is progress and is not a ship date.

**That kills the argument this section was originally written on.** The first draft recommended waiting because the gap would age out. It will not: this is not old browsers lingering, it is **a vendor that has not implemented**, and vendor gaps do not expire on a schedule. On iOS the gap is total, because every browser there is WebKit. "Wait and the cost shrinks" was the wrong shape of argument, and it was wrong because it was asserted rather than checked.

**Revised recommendation: build the client to need no suspension, and treat both options as contingencies.**

§21's fallback — client code dispatches actions and returns effects, never awaits — is not a degradation of the SAM model, it is a description of it. SAM already separates effects into a named layer, which is architectural colouring rather than type-level colouring, and the browser's own event loop already handles that boundary. It is the only path that **works in every browser today at zero payload cost**, and it is now the recommendation rather than the fallback. Whether client code has suspension points that are not effects is the thing to measure once a real client program exists, and measuring it is cheaper than adopting either option.

If that measurement says client suspension is genuinely required, the ranking inverts from the original draft: **the transform becomes the bridge**, because it works on Safari now and JSPI does not, and JSPI becomes the thing to adopt when Safari ships. Paying the transform's payload cost is then a real cost for a real capability, rather than a standing tax paid pre-emptively.

**The correction is recorded rather than edited away** because the failure mode is the one this repository keeps finding: a claim that sounded like a fact ("browsers will have aged out") load-bearing an argument, never checked, and wrong in the direction that made the recommendation look easy. `docs/ONE_WAY_LEDGER.md` records the same shape in the unit-error section.

The fallback above — coloured async on the client, transparent on the server — is recorded here as the worse option. Two concurrency models in a language whose premise is one of everything refutes the premise; if OD-4 makes WASM stack switching unaffordable, restricting client code to event-driven dispatch with no suspension is the better trade, and Part IX's SAM model already implies it.

Ownership: this is a Ring 1 semantic decision. `docs/SHARED_SEMANTIC_ZONE.md` assigns the fiber scheduling contract to the Cranelift lane, so neither lane may act on the direction unilaterally. **A direction sets what to build toward; it does not reassign who builds it, and it does not authorise a patch outside the owning lane.** If a lane hits one of the three blockers above, that is a stop-and-report under the zone protocol, and the finding is recorded against OD-1 in §0.15 — not resolved inside the lane that found it. Reasoning in `docs/VISION_RECONCILIATION.md` §3.2.

## 22. Transactions

Transactions are lexical and typed:

```
transaction db as tx {
    ...
}
```

Database operations inside the block are statically bound to `tx`. Transaction handles and transaction-bound values cannot escape the transaction scope.

> **Not implemented.** `transaction`, `tx`, and `savepoint` are not keywords in the live lexer. This is platform surface (`docs/ONE_WAY_LEDGER.md` E16) — a transaction block is meaningless without a database, and nothing in it is checkable before one exists.

Nested transactions use explicit savepoints.

Transactions declare isolation level, timeout, and retry policy. Serialization conflicts and retry exhaustion return typed errors.

Automatic retries are allowed only for transaction blocks containing retry-safe database effects. The compiler rejects external effects — email, payments, arbitrary networking, supplier mutations — inside automatically retried transactions.

Gust provides post-commit hooks and a transactional outbox for reliable external effects after commit.

---

# Part VII — Resources, Ownership, and Memory

> **Status: COMMITTED.** The most heavily built Part. §26 was corrected 2026-08-19 to the single reference form that exists; §27 is marked OD-3 but `std.Rc` already ships (`docs/ONE_WAY_LEDGER.md` E8).

## 23. Value categories

**Copy values.** Integers, bytes, booleans, simple enums, IDs and indices, and explicitly copyable structs. A user-defined struct is copyable only when every field is copyable and the type is explicitly marked copyable.

> **Partly implemented.** Re-verified 2026-08-21 at `6bd02f9e`: the field-transitivity half holds, but there is no `copyable` marker in the self-hosted lexer. Copy-versus-move is *inferred* structurally by `typechecker_is_linear` (`compiler/typechecker.gst:1771`) — primitives and indices copy; `Arena`, `RawPointer`, `Slice`, `str`, and generics move; a struct moves iff any field does. The practical consequence is that adding one `str` field to a plain struct silently converts it from copy to move at every use site, with no annotation and no diagnostic — which is the change an explicit marker would catch at the declaration. `docs/ONE_WAY_LEDGER.md` E13.

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
>
> It is also missing one the design now wants. §38.1's pending action journal needs a class between scratch and application — actions must outlive the dispatch that created them and die well before the application does. By this section's own reasoning that is an arena with a different lifetime rather than a new mechanism, so the cost is naming it, not building it.

### 24.1 Implicit context — proposed, and it has an unnoticed dependency

Row 4 of `docs/DEMO_TARGET_PROGRAM.md`. Every function that allocates threads a context parameter today, and the demo handler drowns in it. The proposal is ordinary: a `using ctx` declaration binds one context for a scope, and calls inside it pass that context without spelling it at each site. Pure desugaring, no new mechanism.

**Why this is safe where implicit *authority* would not be.** §17 forbids ambient authority, and an implicit parameter looks like exactly the thing that rule prohibits. It is not, and the distinction is worth stating precisely: **an arena is a destination, not a permission.** It says where a value goes, never what a function may do. Effects stay explicit and stay declared, and no `using` clause may make one implicit. If a future proposal tries to bind a capability the same way, the argument here does not extend to it.

**The dependency nobody has noted.** `docs/SHARED_SEMANTIC_ZONE.md` D-1 records that both compilers infer brand identity from **identifier spelling** — a hardcoded list including `ctx`, `arena`, and `a` — and prepend `&` for anything matching, regardless of type. Implicit context makes that heuristic load-bearing in a way it currently is not: if the context is not written at the call site, the compiler must resolve which context is meant **by type and scope rather than by name**, and there is nothing left to pattern-match on.

> **Row 4 therefore depends on Phase 19**, which owns D-1, and the demo table does not say so. Built first, it would either entrench the spelling heuristic at more sites or require a brand resolution that is itself the Phase 19 work. That moves row 4 from "desugaring, can land any time" — which is how `docs/DEMO_TARGET_PROGRAM.md` ranks it — to *cheap, but not before Phase 19*. The ranking there should be read with this attached.

**One rule to fix now while it is free.** `using` binds exactly one context per scope and nested `using` shadows rather than merges. Two implicit contexts in scope would reintroduce by ambiguity precisely the question the explicit parameter answered by construction, and an ambiguity rule written after the feature ships is written under pressure to accept existing code.

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

> **Correction, 2026-08-20 — "may provide" is out of date.** It already does: `std.Rc`, `std.RcNew`, and `std.RcNode` ship today. This sentence is the source three other documents cite when they describe OD-3 as open (`docs/SHARED_SEMANTIC_ZONE.md` D-4, `docs/STDLIB_SURFACE_FINDINGS.md`, `docs/ONE_WAY_LEDGER.md` E8), so its staleness propagated accurately rather than being caught. **What shipped is not the whole of OD-3** — the type exists; whether it is the right answer for SAM state ownership under §38 does not follow from it, and that half is still open. Recorded as `TASK_STDLIB.md` CR-9; status owned by §0.15.

Safe application code does not receive unrestricted interior mutability.

Shared mutation should instead occur through SAM state ownership, actors, transactions, or explicit synchronization primitives.

**Open (v0.5):** the SAM state model (§38) is where this rule meets the operation every application performs constantly. A worked end-to-end example — store, action dispatch, optimistic update, rollback — must be written and reviewed before client work begins.

> **A leading direction was proposed on 2026-08-20** — confirmed base plus a pending action journal, stated in full at §38.1. The requirement above is unchanged: it names the design the worked example should be written against, and does not replace the example. Status owned by §0.15.

## 28. Linear resources

Root resource types opt into resource semantics through explicit linear metadata, a `Resource[...]` representation, and registered destructor metadata.

> **The opt-in half is implemented.** A `#[linear]` layout attribute is parsed alongside `repr(C)` and `packed` (`compiler/parser.gst:869-872`), flows to `StructDecl.is_linear_resource`, and is registered by `env_register_struct_linear_metadata` (`compiler/typechecker.gst:6801`). Registered *destructor* metadata for user-defined types is the part that is missing (`TASK_STDLIB.md` CR-5), which is what blocks `MutexGuard`.
>
> Worth stating explicitly because the word is overloaded: this opt-in is separate from the structural linearity that governs move-versus-copy for ordinary values. `str` and slices are automatically linear for move tracking and are *not* automatically resources — which is exactly what the next paragraph claims. `docs/ONE_WAY_LEDGER.md` E20 and E13.

Linearity propagates transitively. Any struct containing a linear field is itself linear.

> **Not for the `#[linear]` marker.** Verified 2026-08-20 at `b47d0049`. This holds for the structural linearity that governs move-versus-copy — `typechecker_is_linear` walks a struct's fields and returns linear if any field is. It does not hold for the opt-in above: `env_struct_is_linear_resource` has two consumers and neither walks fields, and `typechecker_is_linear` never consults the resource registry. A `#[linear]` struct whose fields are all `int` is linear by neither route, and a plain struct containing one does not become a resource. **The marker is opt-in per type and does not compose.** `docs/ONE_WAY_LEDGER.md` E20. Ordinary strings, slices, collections, and branded structs do not automatically become resources.

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

> **Opt-in, not automatic.** Verified 2026-08-20 at `b47d0049`. `Channel.Send` checks its argument against the element type and returns `Void` (`compiler/typechecker.gst:2823-2841`); it records no move itself. But `move` is a keyword and transfer at a send *is* enforced when the caller writes it — `tests/test_arena_moved_through_channel_invalid_rejected.gst` sends `move ctx` and the compiler rejects the use that follows.
>
> So this sentence describes a property of channels while the compiler provides a property of call sites: a caller who omits `move` transfers nothing, and nothing at the send site requires it. The remedy is to require `move` for non-copy sends rather than to build transfer semantics from nothing. Whether `chan.Send(x)` on a linear `x` without `move` is accepted is untested and is the fixture to write first. `docs/ONE_WAY_LEDGER.md` E18; tracked with issue #101.

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

> **None of this section is implemented.** Verified 2026-08-20 at `b47d0049`: the integer-ish scalars are `int` and `byte` — `byte` lowers to C `unsigned char` (`compiler/codegen.gst:1360-1362`) — and none of the six fixed-width types below exists in either lexer; there is no overflow handling anywhere in codegen or the typechecker; the named arithmetic operations and every one of the numeric and time types below are absent. `Type::Int` lowers to C `int`, where signed overflow is undefined behaviour — so the current behaviour at overflow is not wraparound but UB, which is the opposite end of the spectrum from the trap this section promises. Reproductions in `docs/ONE_WAY_LEDGER.md` E11; tracked as issue #103. The section is retained as the target, not as a description.

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

### 38.1 Proposed leading direction for OD-3 — confirmed base plus a pending action journal

**Operator proposal, 2026-08-20.** Recorded as the leading direction for the SAM half of OD-3. It is not a decision: §27's requirement of a worked, reviewed end-to-end example before v0.5 stands, and this is the design that example should be written against.

Keep two things. `confirmed: Model[app]`, mutated only by authoritative server results, and `pending: List[Action][pending_arena]`, the actions dispatched but not yet acknowledged. The model anyone reads is derived:

```
presented = fold(confirmed, pending)      // into the frame arena
```

- **Optimistic update** — push the action onto `pending`. Nothing is copied.
- **Rollback** — remove that action and refold. There is no "rollback state" to own, because the inverse of *append to a list* is *remove from a list*.
- **Reconcile** — replace `confirmed` with the server's result, drop the acknowledged action, refold the rest.

Acceptors are pure and move-in / move-out, so exclusivity is structural rather than checked:

```
fn accept(model: Model[a], action: &Action[s]) -> Model[a]
```

Nobody holds a long-lived reference to the model because none is ever handed out — the store lends it only for the duration of a call. **That sidesteps §26 entirely: it is not that aliasing writes are forbidden, it is that no alias exists.**

**Why it leads.** Rollback state is *actions*, which SAM already makes first-class, typed, and small — so §27's hardest case stops being a memory-ownership problem. It is the only candidate that handles several in-flight mutations correctly. Replayability forces the acceptor purity §38 already claims but cannot currently enforce. And it lands exactly on Appendix A's table: `confirmed` in the application arena, actions in a pending arena, `presented` in the frame arena wiped in constant time.

**Costs, stated rather than discovered later.** Refolding is O(|pending| × model size); cache `presented` and invalidate on any change to `confirmed` or `pending`, not per frame. Acceptors must be deterministic and replayable — a real constraint, and one worth having. Actions must outlive scratch, so they need a third arena class between scratch and application, which §24 does not name today. Per §24's own correction that is an arena with a different lifetime rather than a new mechanism, which is why the cost is cheap.

**What this does not settle.** OD-3's other half — whether an explicit compiler-owned `Rc` is the right general answer for shared ownership — is untouched. This direction narrows OD-3 to that question by removing the SAM case from it.

#### Backup 1 — shadow-arena snapshot, and the one to build first

`std.GenerationalArena` and `std.GenerationalSwap` already ship (`docs/STDLIB_SURFACE_INVENTORY.md`, "Names the typechecker registers"; `std_GenerationalSwap` resolves to `src/runtime/arena.c`). Two model arenas, current and shadow. An optimistic update clones the model into the shadow arena and applies the action there. Confirm swaps; rollback resets the shadow arena in constant time, with nothing to undo.

**Why it is second in design and first in build order.** It is the cheapest way to produce the artifact §27 actually demands — store, action dispatch, optimistic update, rollback, written and reviewed. It needs no new language surface and would settle the single-mutation case in days rather than months.

**Why it is not the shipping design.** One outstanding mutation at a time. Two in flight and it needs N buffers plus a scheme for interleaved acknowledgements — at which point it is a worse implementation of the direction above. **These two are not rivals: the shadow arena is a good implementation of the pending journal's derived buffer.**

> **Verified 2026-08-20, and the caution was right.** `std_GenerationalArena_Clone_*` is listed under "Helper rows with no runtime symbol" — and it is the *only* entry in that section. So the two halves of this option are in opposite states: **the rollback half is built** (`std_GenerationalSwap` has a runtime symbol), **the setup half is the gap** (clone-into-arena does not). That inverts "uses primitives that exist" by half, and it is a prerequisite to close before committing to this route rather than a discovery to make mid-way through it.

#### Backup 2 — a compiler-owned `Store[T, ctx]`

Admit the store is shared mutable state, name it, and contain it: one blessed type, not user-constructible, where dispatch takes exclusive access and read returns a borrow that provably cannot span a dispatch. §27 bans *unrestricted* interior mutability, and a single compiler-owned store arguably does not violate the letter of that.

**The most ergonomic option, and the honest one.** But "a borrow that cannot span a dispatch" is an aliasing rule, and §26 has no aliasing analysis and no mutable/shared distinction. So it converts a v0.5 client design question into unscheduled Ring 1 containment work. That makes it the wrong first move and the right fallback — specifically if the pending journal's refold cost proves prohibitive in practice, at which point the §26 work is worth paying for because something concrete has demanded it.

#### The conclusion that survives whichever wins

Every option forces the same constraint from a different direction: **the model may not contain linear resources.** Anything replayable, clonable, or swappable has to be plain data, so open sockets, subscriptions, and handles live in effects, not in state.

That is likely the actual answer to the question §38 asks. "SAM state ownership under linear resources" resolves not by making resources work inside the model, but by **ruling them out of it** — a real constraint on how applications are structured, and exactly the kind of thing discovered by writing the worked example rather than by specifying it.

*Recorded faithfully: the operator's note refers to options 1–4 and three are stated here. The fourth was not supplied and is not reconstructed — an invented option would be indistinguishable from a considered one.*

#### Suggested route

Build the shadow arena to produce the §27 artifact and clear the "before client work begins" gate; design toward the pending journal as the shipping model; hold `Store[T, ctx]` as the escape hatch, and pay for the §26 work only if something forces it.

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

> **Row 9 of `docs/DEMO_TARGET_PROGRAM.md` — a Postgres capability — is the only row on that list marked "not compiler work". §54.0 below argues that is the least accurate label on the table.**

## 54.0 The Postgres capability — proposed, and its prerequisites are not what the table says

`docs/DEMO_TARGET_PROGRAM.md` ranks this row as platform rather than compiler work, and this lane ranked it last on that basis. Both readings are wrong in the same direction: **it is the row with the most compiler prerequisites, not the fewest.**

**What it must provide.** A connection acquired from a capability, a way to execute what §55.1 derives, transactions, and release on scope exit. Nothing exotic — which is why it looked cheap.

**Prerequisite 1, and the one nobody has connected to it: a database connection must close, and there is no way to declare that it does.** `docs/SHARED_SEMANTIC_ZONE.md` D-4 records that resource *representation*, transfer state, and `defer` are all present, while destructor **declaration** is not: there is one built-in destructor and no source syntax to declare another. That is the gap `TASK_STDLIB.md` CR-5 states, and it is why `MutexGuard` is blocked.

> **A Postgres connection is `MutexGuard` with a socket.** It is a linear resource whose release must be enforced rather than remembered, and it is blocked by exactly the same missing feature. The two have been tracked as unrelated — one a stdlib ergonomics item, the other a platform item — and they are one prerequisite with two consumers. **Whoever unblocks `MutexGuard` unblocks this row**, and that is worth knowing before either is scheduled.

**Prerequisite 2 — effects (row 5).** Without `uses db.read<…>`, acquiring a connection grants ambient database authority, which is §17's failure mode rather than a partial implementation of it.

**Prerequisite 3 — the derivation (row 7).** Something must produce what this executes, and §55.1's three outputs are what a connection is handed.

**Prerequisite 4 — a native boundary, which is Phase 17/18 territory.** Talking to Postgres means either linking a client library or implementing the wire protocol in Gust. Either way it crosses the native boundary the Phase 17 runtime symbol surface and the Phase 18 link-mode and cross-compilation work govern. **That is the sense in which the row is "platform", and it is a small part of it.**

**One choice worth taking deliberately rather than by default.** Linking a C client is the fast path; implementing the wire protocol in Gust is slower and is the first real test of whether this language can write the code it intends to contain. `docs/VISION_RECONCILIATION.md` §7 puts C retirement at the top of the current priority list — that is about the MIR-to-C *backend* rather than a ban on C libraries, so linking a client does not violate it. But choosing the fast path here means the first vendor capability (§98) is a C dependency, and §98's whole argument is about what a dependency costs. **Take it as a decision with that stated, not as an implementation detail.**

**What this row actually is.** The first supplier capability under §98, and therefore the test of that model rather than an application of it. If the shape does not work for Postgres — the easiest, best-understood, most stable vendor surface available — it will not work for the ones that follow.


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

### 55.1 What the derivation must produce — proposed

Row 7 of `docs/DEMO_TARGET_PROGRAM.md`, and the largest single item on that list. OD-2 settled *who* derives — the compiler, because §13's ban on user-written generic functions stands. Nothing states *what* comes out of the derivation.

**The claim this section makes: a query site derives three things, not one, and they must come out of one derivation rather than three passes.**

At a site such as `from Issue where workspace == scope and state == Open`, the compiler must produce:

1. **The result type.** §55's existing commitment — filters, joins, aggregates, projections and pagination each transform it, computed by the compiler because users cannot express the computation.
2. **The effect requirement.** The entity determines what authority the query needs: reading `Issue` requires `db.read<Issue>`. The compiler derives the *requirement*; §18.1's rule 1 still applies, so the enclosing function must have **declared** a set that covers it. Derivation never widens a declaration — it only says what the declaration must contain.
3. **The scope obligation.** §56.2's provenance rule attaches here: which scoped entities the query roots at, and whether each obligation is discharged by a predicate flowing from a `Scope[…]` binding.

**Why one derivation and not three.** These three read the same query structure — the entity set, the join graph, the predicate list. Computed separately they can disagree about it, and the disagreement is silent because each pass individually succeeds. A join that the type derivation treats as one entity and the scope derivation treats as another produces a well-typed query with an unchecked obligation, which is §56.1's attack class 2 arriving through the back door rather than the front. **One walk over one structure, emitting three facts, cannot disagree with itself.**

**What is not derived.** The operator set (§16 is compiler-owned and closed), the predicate language, and any user extension of the builder. PostgreSQL-specific features arrive as explicit typed extensions (§55) rather than as a generic escape hatch, and the escape hatch that does exist is §57's privileged raw SQL — outside the derivation, and therefore outside all three of its guarantees. That is the honest cost of having an escape hatch and the reason §56.1 asks whether holding that capability is non-transitive.

**Where the results live.** Query results allocate, so a query needs a destination arena, and §11.1's finding applies unchanged: the rows must outlive the call that produced them, so the arena is the caller's rather than the callee's scratch. The brand parameter that makes this expressible is the same one `Result[T, ctx]` already carries.

**The sequencing consequence, restated because it is the practical one.** `docs/DEMO_TARGET_PROGRAM.md` places this row after scope soundness deliberately. A builder built before §56.2's obligation model exists would derive one of the three facts and have the other two retrofitted, and retrofitting a scope obligation into a finished derivation is how the presence-versus-provenance distinction gets quietly weakened — the retrofit will be tempted to match on syntax, because the structure it needed was not kept.

## 56. Tenant and authorization enforcement

**This is the lead product claim (§1) and the whole point of the demo (§0.14).**

The compiler **statically enforces** that every database query is tenant-scoped. Queries that cannot be statically shown to carry tenant scope are rejected at compile time.

Missing tenant scoping is the canonical failure mode of agent-authored applications and the direct cause of repeated public data-exposure incidents across AI app-building platforms. Every other stack treats it as a configuration concern — row-level security policies, middleware, a template the generator might forget. Gust makes it a property of the type system: **the unscoped program does not compile.**

Authorization predicates are injected into queries where policies can be translated into database expressions. Where full translation is impossible, a runtime policy check is required.

This is static enforcement backed by generated conformance tests (§79), not formal proof. See §79 for the language Gust is permitted to use externally.

### 56.1 The attack list for OD-8

§0.11 requires that someone adversarial attack the scoping analysis before publication. An instruction to "review it adversarially" with no target list produces a review that confirms what it was shown. This is the target list — the classes a reviewer should try to build a counterexample from, written before the analysis exists so that it cannot be shaped around what the analysis happens to catch.

**The class most likely to succeed, and it is not a bug.** "The unscoped program does not compile" is a **presence** claim: it says a tenant scope is *there*. It does not say the scope is the *caller's* tenant. A program that scopes every query to a tenant id read straight from an attacker-controlled request field satisfies the analysis completely and leaks everything. If that is out of scope, §1 and §79 must say so in the words used externally, because a reader will hear the stronger claim. **Presence is cheap to check and correctness is not** — that asymmetry is the analysis's shape, not an oversight in it, and it is the first thing an honest reviewer will find.

The remaining classes, roughly by how much they would cost to close:

1. **The privileged raw-SQL capability (§57).** A declared escape hatch is not a hole, but it is only sound if possessing it is rare, visible, and non-transitive. Can a library acquire it and re-export a helper that looks ordinary?
2. **Joins to unscoped tables.** A scoped table joined to a lookup table that carries no tenant column — does scope propagate across the join, or is it satisfied by the scoped side alone?
3. **Nesting.** Scope in the outer query and an unscoped subquery, aggregate, or `EXISTS` beneath it.
4. **Queries as values.** A query built in one function, stored in a struct or returned, and scoped by the caller. The analysis must follow it or refuse it.
5. **The result cache.** A correctly scoped query whose result is cached and served to a different tenant. The analysis covers queries; caches are not queries.
6. **Multi-step flows.** An id legitimately obtained under tenant A, used in a query correctly scoped to tenant B. Every individual query passes.
7. **The legitimately cross-tenant path.** Admin tooling and migrations must be able to do this. How is that marked, how visible is the marking, and can it be applied by someone who did not realise what it turns off?
8. **Non-query reads.** Stored procedures, triggers, a raw connection obtained through a capability, or any supplier surface (§98) that returns rows without passing through the query layer.
9. **Dynamic shape.** Table or column names computed at runtime.
10. **Where the tenant value comes from.** The analysis assumes the request context is trustworthy. Whatever establishes that context is inside the trusted base and belongs in the review.

**How to run it.** The reviewer's job is to produce a program that compiles and leaks, not to assess whether the design seems sound. One such program resolves OD-8 negatively, which is the outcome §0.11 wants found in month four rather than after publication. A review that produces no counterexample should say which of these classes it actually attempted.

### 56.2 What the analysis must check — proposed

Row 6 and row 8 of `docs/DEMO_TARGET_PROGRAM.md` are both unowned, and nothing states what the analysis checks. The attack list in §56.1 has nothing to attack until it does. This is a proposal, not a decision; the value of writing it now is that §56.1 was written first and can be run against it.

**1. Declaration.** An entity type declares which field carries its scope. The compiler records the pairing; nothing else in the program may assert it.

**2. Obligation.** Every query rooted at a scoped entity carries a scope obligation. A query whose obligations are not all discharged does not compile.

**3. Discharge is by *provenance*, not by syntax — this is the load-bearing rule.** An obligation is discharged only by a predicate whose value flows from a **scope-typed** binding, `Scope[Workspace]`, obtainable only from the request context and not constructible from user input. A `where workspace == <some string>` does not discharge anything, however well-formed it looks. This is what converts the presence claim §56.1 identifies as the weakest point into a provenance claim, and it is the difference between "a scope is present" and "the caller's scope is present". **If exactly one rule here survives review, it should be this one.** It is also the rule most likely to be quietly weakened during implementation, because syntactic matching is far easier and passes the same tests until someone attacks it.

**4. Joins introduce obligations; they do not satisfy them.** Each scoped entity in a query carries its own obligation. Discharging one never discharges another, and an unscoped lookup table joined in carries none — which is correct only if the scoped side cannot be widened through the join, and that is exactly what §56.1's class 2 exists to test.

**5. Nesting is not a boundary.** A subquery, aggregate, or `EXISTS` over a scoped entity carries its own obligation regardless of the enclosing query's.

**6. The cross-tenant path is explicit, capability-gated, and visible at the call site.** Admin tooling and migrations genuinely need it. It is a named marker requiring a capability, spelled at the site rather than configured, so that reading the code shows what it turns off.

**7. Rejection is at compile time, at the query, with the diagnostic in `docs/DEMO_TARGET_PROGRAM.md`.** Not a lint, not a runtime check, not a generated test — those are §79's evidence that the rule holds, not the rule.

**What this proposal does not cover, and knows it.** Caches (§56.1 class 5), non-query reads (class 8), and multi-step flows (class 6) are all outside the query analysis by construction. Naming them here rather than leaving them out is the point: the analysis is sound over queries, and **the claim made externally must be about queries** or it will be broader than the thing that was checked.

> **OD-8 lives here.** §0.15 names this section as where OD-8 is stated in full, and until 2026-08-20 it was not stated here at all — a reader could finish §56 without learning that the soundness of the analysis above is an open, *thesis-invalidating* question. **Is the scoping analysis sound?** One counterexample — one program that carries no tenant scope and compiles anyway — retires the only claim this document makes, which is why §0.11 requires an adversarial review before publication rather than after. Nothing in §56 is weakened by saying so; the claim is exactly as strong as the analysis, and the analysis has not yet been attacked. Status is owned by §0.15.

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

> **The first sentence holds; the second has no mechanism.** `import` resolves one source file at a time, so "a module is one source file" is true de facto. There is no `package`, `module`, or `manifest` keyword in the live lexer and no manifest or lockfile format in the repository — the only `.toml` files belong to the deprecated prototype and to `treefmt`. Package identity, the approved package graph, the capability graph, and §72's lockfile diff have no representation. `docs/ONE_WAY_LEDGER.md` E21.

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
>
> **Nothing here is implemented for applications; the discipline it argues for exists, aimed at the compiler.** Measured 2026-08-20 at `b47d0049`: 260 test programs of which 115 are named negative fixtures (102 `*reject*`), 409 `guard-` recipes, 82 parity/differential guards, and 66 CI workflows — roughly 44% of the corpus asserts programs must *not* compile. None of §75's categories or §79's generated checks exist, because they presuppose the platform. So the remaining work is aiming an existing, sustained practice at a new target, not establishing one. `docs/ONE_WAY_LEDGER.md` E22.

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

> **Half-mechanised, and the missing half is not blocked on the platform.** The *linear* half has a mechanism: `#[linear]` marks a type as a resource and is wired end to end (§28). The *opaque* half has none — there is no `Secret` type and nothing marks a type as unprintable, unformattable, or unloggable, so `std.Format` and `os.LogStr` accept whatever they are given.
>
> Worth separating from the platform sections around it: "this value has no string representation" is a property of the type system, not of the platform. `secret.use<"stripe">` needs effects; refusing to format does not. `docs/ONE_WAY_LEDGER.md` E26.

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

*Post-1.0 commercial service tier (§2), not the core guarantee. Assumes a certification function with real staffing. **Do not commit to supplier certification externally until OD-5 is resolved.***

> **Direction set 2026-08-20 — split the function, do not staff it whole.** An
> agent does the recurring mechanical work; the operator does the human and
> commercial work. That is the answer to "who does this, forever", and it changes
> the shape of the cost from a team to a person plus a process.
>
> **The dividing line, stated so it survives contact with a hard case: an agent
> can verify that a contract is well-formed and current. Only a person can decide
> that a supplier is trustworthy.** Conformance is checkable; trust is a
> judgement with liability attached, and nothing in §83–§86 makes it otherwise.
>
> | Agent — conformance | Operator — trust and commerce |
> | --- | --- |
> | Derive and maintain the capability contract from the supplier's API surface | Decide which suppliers are admitted at all |
> | Detect supplier API changes and flag contract breakage | Negotiate terms, SLAs, and liability |
> | Verify §84's reliability policy is *declared* — timeout, retry, idempotency, fallback | Decide whether a declared policy is *acceptable* |
> | Verify §85's data-minimisation declarations match what the contract actually sends | Approve a destination region, a retention period, a purpose |
> | Regenerate contracts on version bumps and report what moved | **Revoke a supplier, and tell the customers who depend on it** |
>
> **This is `docs/AGENT_TOPOLOGY.md` §6's rule one level out.** That section
> argues mechanical decisions belong in documents and product decisions belong to
> the operator, with no third category. Supplier certification looked like a third
> category — an ongoing staffed function that is neither — and it is not one: it
> splits cleanly along the same seam once *conformance* and *trust* are named as
> different questions.
>
> **A supplier-certification agent would be a legitimate fourth lane** under
> `AGENT_TOPOLOGY` Constraint C, because it has a genuinely disjoint domain — the
> supplier contract files — with no shared-semantic-zone dependency. Post-1.0, and
> noted here so the topology count is known to be extensible rather than fixed at
> three.
>
> **What this does not resolve.** How the tier is priced, and what the guarantee
> is worth to a buyer, remain open. Those are §2's commercial questions rather
> than §0.15's design ones, and the warning above still stands: **saying "we
> certify our suppliers" is cheap, and being it is a commitment** — an agent
> lowers the recurring cost, it does not remove the promise.

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

> **A gate exists; the governance does not; and the builtins bypass it.** Verified 2026-08-20 at `b47d0049`. `extern func` declarations parse (`compiler/parser.gst:1169-1199`) and calling one requires an explicit `unsafe` block (`compiler/typechecker.gst:4047`) — that much is real. No signed adapter, native-code capability, isolation, or separate process exists.
>
> The asymmetry matters more than the missing governance: the built-in `os.*` surface passes through no gate at all, so `os.System` spawns `/bin/sh` from a four-line program with no `unsafe` and no import (`tests/e2e_os_system.gst`). A *declared* FFI call is gated; *arbitrary shell execution* is not. `docs/ONE_WAY_LEDGER.md` E21, issue #108.

A separate process or sandbox is preferred over in-process execution.

## 94. Arbitrary networking

Arbitrary networking is forbidden by default.

> **True, vacuously.** There is no networking at all — no socket, `connect`, or `AF_INET` anywhere in `src/runtime/*.c`. Nothing enforces the rule; there is simply nothing to enforce it against, and it becomes testable only when a network capability exists.

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

> **Nothing enforces these boundaries yet, and one of them is inverted.** No escape-hatch machinery exists — no manifest, capability, signed adapter, isolation, or expiry (§97). The one real gate is that `extern` calls require `unsafe` (`compiler/typechecker.gst:4047`), which the built-in `os.*` surface bypasses entirely, so "arbitrary filesystem or process access" is currently the *ungated* path (`docs/ONE_WAY_LEDGER.md` E21, issue #108).
>
> This section is nonetheless the most reusable idea in the document: it is the only place that states guarantees weaken *by degree and by named boundary* rather than being binary. `docs/VISION_RECONCILIATION.md` §5 develops it into a proposed `gust guarantees` ledger, which is what would make "loss of guarantee" a thing a reviewer can read rather than a sentence in a specification.

---

# Part XIX — Versioning and Compatibility

> **Status: SPECULATIVE.** The Part already says post-1.0 and not a commitment.

*Post-1.0 (§0.14). Recorded so demo-stage decisions do not foreclose it. Not a commitment.*

## 99. Compatibility promise

After 1.0, Gust promises strong source compatibility within each language edition.

> **No edition concept exists.** `edition` and `version` are not keywords in the live lexer, `edition` appears in no compiler source file, and there is no manifest to pin one in (§70). Recorded because §103 calls compiler-assisted migrations "a core product feature", and every mechanism it describes — deprecation warnings, automated rewrites, removal at an edition boundary — depends on a boundary that has no representation. `docs/ONE_WAY_LEDGER.md` E25.

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

### 107.1 Gust Forge — a workspace for humans and remote coding agents

**Operator direction, 2026-08-21. Not demo scope.** When the Gust Forge
platform is built, it includes a hosted collaborative coding workspace in the
shape demonstrated by Paseo. A human opens Forge in a browser on their laptop,
works in the project there, and connects cloud coding agents including Claude
and Codex to work alongside them. The laptop is a client, not the machine that
holds the authoritative checkout or runs the agents.

**Deployment model.** Forge provisions a per-project remote workspace on a
managed VM, VPS or equivalent cloud runner. That workspace holds the checkout,
agent worktrees, build cache, compiler, sandboxes and durable task state. Forge
starts and supervises the Claude, Codex or later agent harnesses on those cloud
runners; their file operations, commands, builds and tests execute against the
remote workspace. The browser provides the editor, terminal, task view, agent
controls and streamed results. A user may close the laptop without terminating
the workspace or its authorized tasks.

The product requirement is the collaboration surface, not a copy of Paseo's
implementation or interface. Forge provides:

- one durable hosted project view shared through the web by the human and
  connected agents;
- remote workspace lifecycle: provision, suspend, resume, snapshot and destroy;
- a distinct identity, isolated worktree and sandbox for each agent;
- per-agent permissions and an audit trail for file changes, commands, external
  actions and handoffs;
- live state showing which agent owns which task, what is running, and what has
  reached a terminal state;
- durable conclusions and artifacts on disk, so a remote session can disappear
  or be replaced without taking the project's state with it;
- provider adapters rather than provider semantics in Gust: Claude, Codex and
  later agents connect through the same task, authority and artifact model.

Forge owns the harness and workspace lifecycle; model providers may still own
inference. Supporting Claude or Codex means Forge can launch the corresponding
agent harness in the project runner, authenticate it through a scoped provider
connection, stream its state to the browser, and recover or replace the session
without losing the project record. It does not mean either provider's task model
becomes part of Gust.

The authority boundary is the one in §114. Connecting an agent does not grant it
the application's capabilities, another agent's credentials, or permission to
approve its own authority widening. Repository publication, deployment and
other outward-facing actions remain explicit capabilities with human-visible
records.

**The browser is not in the warm inner loop.** Checkout, file operations,
compilation, execution, caches and traces stay together on the Forge runner, so
no laptop round trip sits between an agent command and its result. A provider-
hosted Claude or Codex inference call may still cross a public network boundary
and therefore does not satisfy §107's single-digit platform-overhead target; it
is the slower outer loop. §113's colocation remains the later optimisation for a
provider able to host inference and execution together, not a prerequisite for
Forge to support cloud agent harnesses.

`docs/AGENT_TOPOLOGY.md` §4 records the observed Paseo mechanics this requirement
draws from: long-lived agents with working directories, per-agent permissions,
schedules, agent discovery and messaging. That document is evidence for the
shape, not a dependency or an instruction to reproduce its current governance.

## 108. Execution traces

Every run emits a structured, machine-readable trace. The trace is a first-class artifact with a versioned schema, not a log format. It is one of the three things humans actually read (§0.12).

> **No run trace exists.** Verified 2026-08-20 at `b47d0049`. The only thing in the compiler named "trace" is `typechecker_log_trace` (`compiler/typechecker.gst:8618-8619`), whose body is empty — 40 call sites compiling to nothing. That is stubbed compiler debug logging, and it says nothing about a *program's* run regardless.
>
> Worth separating from the rest of Part XX: **this is the only one of §0.12's three human-read artifacts that could exist before the platform does.** The capability manifest needs effects; the lockfile diff needs packages. But a trace of allocation and context lifetimes at region granularity, and of typed error values with their propagation path, is expressible today — regions and errors both exist. Nothing schedules it. `docs/ONE_WAY_LEDGER.md` E25.

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

> **Half of this exists.** Verified 2026-08-20 at `b47d0049`. `CompilerError` (`compiler/errors.gst:10-15`) carries a `kind`, a `span`, and a `file_path`, so diagnostics are structured values with precise locations and do satisfy the design constraint below. What is absent is identity and machine-readability: there is no error-code or rule-id scheme anywhere, no JSON emission, and no candidate edits — the rule violated exists only as English prose inside `message`.
>
> The gap is already being worked around. `guard-stdlib-s1-str-equality-diagnostic` pins diagnostic identity by asserting the *sentence* is byte-identical in both compilers, which is a stable rule identifier implemented as English and cannot be reworded without breaking CI. `docs/ONE_WAY_LEDGER.md` E23.

The design constraint: a diagnostic must be sufficient for correction without re-reading the whole file. Diagnostics that require whole-program context to act on are defects.

## 110. Sandbox lifecycle

Agent execution runs in a pre-warmed sandbox with the application's capability set already resolved.

The sandbox boundary and the capability boundary are the same mechanism. Gust does not wrap an untrusted container around agent output and hope; the compiler has already established what the program can reach, and the runtime enforces exactly that set.

Sandboxes are disposable, content-addressed, and reproducible. Two runs of the same release with the same input produce the same trace, or the difference is itself recorded as a nondeterminism finding.

## 111. Reproducibility

Content-addressed builds, no install-time execution (§15), virtualized time and randomness (§76), and deterministic scheduling (§77) combine to make a run a clean observation.

> **One of those four holds; a stronger property is enforced elsewhere.** Verified 2026-08-20 at `b47d0049`. No install-time execution is real (no macros, build scripts, or compile-time execution). Content-addressed builds, virtualized time and randomness, and deterministic scheduling are all absent.
>
> What *is* enforced is byte-identical self-compilation: `make bootstrap` fails unless stage 2 and stage 3 are identical, and the converged output becomes the committed seed (`Makefile:199-202`). Object reproducibility has its own guard. That is a demanding determinism property checked on every bootstrap — it is about the compiler's output rather than a program's run. `docs/ONE_WAY_LEDGER.md` E24.

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

Not mutually exclusive.

### 117.1 Leading proposal for OD-6 — one attachment point, two authoring depths

**Operator proposal, 2026-08-20.** Recorded as the leading answer for OD-6. The candidates above are kept as the record of what was considered; this is the shape to prototype against during v0.1.

**(3) Contracts on capabilities — *where* a check attaches.** A function already declares `uses payments.charge`. The contract hangs off that same declaration: *the amount charged equals the amount on the order*, *never charge the same order twice*. This is the core because effect declarations are a small fixed set of points the compiler already knows about, so **intent lands on exactly the same boundary authority does.** There is nothing new to invent about placement.

**(1) Examples — *who* can author one.** *A £10 order charges £10.* Writable by someone who understands the business and not the codebase. That matters more than it looks: §116 requires human authorship, and **that requirement is worthless if only the system's own authors can satisfy it.** Examples are the surface that keeps a non-programmer inside the trust chain.

**(2) Properties — *how much* a check covers.** *A refund never exceeds the original charge.* One statement standing in for every case, checked by generated tests over §79's existing conformance machinery. Powerful and genuinely hard to write, which is why it is the depth option rather than the front door.

**So: one attachment point, two authoring depths.** A reviewer never picks between an example and a property for the same job — they are a case and its generalisation, not rival spellings. You write the example because it is what you can state; you write the property when you can state something stronger.

**What this proposal decides, and what it leaves open.** It settles placement, which was the part with a defensible answer: intent attaches where authority attaches. It does not settle the language a contract is written in, how a contract composes when one capability calls another, or what a violation costs at runtime versus at build time. Those are prototype questions, and the prototypes now have a fixed attachment point to be prototypes *of* — which is the practical gain from deciding this half early.

**Why that combination, and why it is not three ways to do one thing.** The three candidates answer different questions, which is what makes stacking them legitimate under §13 rather than a violation of it. (3) answers **where a check attaches** — effect declarations, a small fixed set of points the compiler already knows about, so intent lands on the same boundary authority does. (1) answers **who can author one** — an example is writable by someone who understands the business and not the codebase, which matters because §116 requires human authorship and that requirement is worthless if only the system's authors can satisfy it. (2) answers **how much a check covers** — properties generalise a case into a class, over §79's existing conformance machinery.

One attachment point, two authoring depths. A reviewer never chooses between them for the same job: an example and a property attached to the same contract are not rival spellings, they are a case and its generalisation. **If that stops being true — if the same intent can be stated equally well as either — the combination has become three ways to do one thing and should collapse to one.** Worth checking during the v0.1 prototypes, because it is the failure mode this document's own premise would predict.

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

**Partly true, and misleading as stated.** 16 — `Option` exists but `Result` is not a builtin and there is no `?` operator; the working convention is `guard … else` (E2). 26 — resource *opt-in* is explicit, but the move-versus-copy linearity that governs ordinary values is *inferred* structurally and unannotated, so adding a `str` field silently changes a struct's category (E13); the two mechanisms share a word and only one is opt-in. 27 — `defer` parses and scope-exit cleanup is validated, but only for `Resource[T]` and only in the self-hosted compiler, because `type_is_resource` keys on a `Generic` named `Resource` (E7 addendum).

**Violated.** §34's panic scoping, reached from rule 28's neighbourhood: a string bounds failure calls `exit(1)` and terminates the process rather than the request (E3, issue #91). And §32's overflow trapping, which rule 3's "containment, not correctness" does not cover: overflow is undefined behaviour on the default backend rather than a trap (E11, issue #103).

Rule 46 is the discipline that makes this section necessary. A rule stated in the present tense that nothing enforces is the document saying *prove* while meaning *intend*.
