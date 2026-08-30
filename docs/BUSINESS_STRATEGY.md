# Business strategy

## The position, in one paragraph

Sell a **deterministic control** to the party who **carries the risk** but does
not **write the code** — reached through the ten or so generators that now
produce most of it, before an incumbent closes the same gap from inside the stack
developers already use. The control is that the unscoped program does not
compile; the wedge is that claim; **the thing actually being bought is a compiler
that can answer structured questions about a whole deployed application**, which
is the part that cannot be reproduced in a quarter. No business model is chosen
yet, deliberately, and §0 says why.

> **Going into a meeting? Read `docs/MESSAGING.md` first.** It indexes this document, `docs/STRATEGY_REVIEW.md` §6 and `docs/VISION.md` §2 into the lines, the three questions you will be asked, and what can honestly be claimed today.

## 0. What this document is

**Not a business plan.** `docs/VISION.md` §0.10 withdrew three of those —
direct-to-team SaaS, platform licensing, first-party product margin — on the
grounds that each *"assumed a business chosen before the mechanism was proven."*
That discipline holds and this document does not break it.

**This is the decision procedure for choosing one**, plus the commitments that
hold whichever is chosen. It answers: what must be true before a business model
can be picked, what evidence picks it, who decides, and when.

**Where the commercial position is already stated, this points rather than
restates.** §2 holds market positioning, §0.8 the prospect count, §0.9 the
counting programme, §0.10 the numbers and odds, §0.11 the risks, §0.14 the
sequencing, Part XVI the certification service. **What follows is only what none
of them covers.**

### 0.1 Four independent gates

The month-four decision uses four gates and does not substitute evidence across
them:

| Gate | Required evidence | What does not satisfy it |
| --- | --- | --- |
| Technical | The stated compiler/runtime control survives its threat model and independent attack | A polished application demo |
| Generation | Secure functional completion within a preregistered repair, token, latency, and intervention budget | Compiler soundness alone |
| Commercial | A named buyer, incident owner, budget, and feasible adoption path | Benchmark superiority or prospect enthusiasm |
| Defensibility | Material advantage over the cheapest credible incumbent response | Time already spent building Gust |

A mechanism demo can eliminate a path or authorize the next evidence stage. It
cannot select the company. The integrated product, acquisition, licensing, and
research-artifact outcomes are chosen only from the combined gate record.

---

## 1. The contradiction to resolve first

**§0.10 and §2 describe different customers, and both cannot be right.**

> **§2:** *"**Not the end user.** Someone shipping an internal tool does not wake
> up wanting capability enforcement, and willingness-to-pay is near zero until
> after a breach."*

> **§0.10, the product path:** *"Self-serve, **$30–60 per user per month**,
> plausible path to $1–5M ARR."*

Self-serve at that price is a developer-tools motion sold to the individual
developer — precisely the buyer §2 says will not buy, at precisely the
willingness-to-pay §2 says is near zero. **One of the two is wrong, and which one
determines whether there is a product path at all.**

Three ways it resolves, and they are not equally likely:

1. **§2 is right and the product path is thinner than §0.10 models.** Then
   acquisition is not one of three outcomes, it is close to the only one, and the
   ~50% "small product, some customers, no exit" branch is optimistic.
2. **§0.10 is right about a different buyer than §2 modelled** — a platform
   engineering or security team, buying enforcement rather than convenience.
   That is a seat-based sale with a real budget line, and it is *not* the end
   user §2 dismisses. **This is the reading that makes both sentences true**, and
   it has never been written down as such.
3. **Both are right at different times.** No willingness-to-pay before the
   statistic exists (§0.9), some after. This is the most comfortable reading and
   the one to be most suspicious of, because it defers the test indefinitely.

**Recommendation: resolve this before month 4, not at it.** It is answerable by
conversation rather than by code, it costs nothing but time, and every other
commercial decision depends on it. **It is also the cheapest possible way to
discover that the product path is thinner than modelled** — which is the outcome
§0.10's own odds already lean toward.

Five named prospects are a minimum discovery sample, not proof of demand. For
each conversation record: who owned the last relevant incident; its direct and
indirect cost; which budget paid; which controls were considered or accepted;
who can authorize language/runtime adoption; procurement, migration, ecosystem,
support, and lock-in objections; and whether acquisition, licensing, internal
implementation, or ordinary guardrails are preferred. Name the target generator
or platform and its incentives; “roughly ten generators” remains a falsifiable
adoption hypothesis until this map exists.

**And resolve it with the right question, because the obvious one does not
work.** *"Would you buy this?"* returns a polite maybe from everyone and
distinguishes nothing. The question that separates the three readings is
retrospective and specific:

> **"What did your last data-exposure incident cost, who paid for it, and which
> budget did it come out of?"**

A buyer who can answer with a number and a budget line is reading 2 — the
enforcement buyer with an existing budget. A buyer who has not had one, or cannot
say who paid, is reading 1 or 3, and no amount of demo changes that. **The answer
also supplies §0.9's numerator from the demand side**, which is the same number
the counting programme is trying to produce from the supply side — and two
independent derivations of it are worth far more than one.

---

## 2. The competitor nobody has named

§2 names buyers. **No document names the alternative**, and the alternative is
not another language.

> **The competitor is a frontier model writing TypeScript on Next.js and
> Postgres, with row-level security and a linter.**

Not Rust, not Go, not a systems language. That comparison is a category error
that flatters Gust: nobody choosing between Gust and Rust is the buyer in §2's
table. The real question a platform asks is *"why not keep emitting what we
already emit, and add guardrails to it?"*

**What that alternative actually gets them**, stated fairly:

- **Row-level security is real enforcement**, in the database, today, with no new
  language. It is the strongest single argument against §56.
- Enormous corpus, so the model is already fluent — which is **OD-9 already
  answered in the competitor's favour.**
- Every library, every hire, every deployment target.

**Where it fails, and this is the whole commercial case:**

- **RLS enforces at the database, after the query is written.** It cannot reject
  the program; it rejects the *row*. A query that forgets scoping still ships,
  still runs, and is caught only if the policy is present, correct, and enabled
  on every table. **§56's claim is that the unscoped program does not compile** —
  a different guarantee at a different time, and the only one that survives a
  developer who forgot to add the policy.
- **A linter is advisory** and generated code is not read (§0.1), so a warning
  nobody reads is not a control.
- **The failure is silent and correlated.** One missing policy on one table leaks
  every tenant at once, and the class is precisely what §0.4 calls containment.

### 2.1 The objection that has to be answered first

**"If the lever is the generator, why not just fix the generator?"**

This is the strongest argument against Gust and it comes directly out of §2's own
thesis. If code production is centralising into ten generators, the cheapest move
available to any of them is not to adopt a new language — it is to train the model
to always write scoped queries, and ship that next month. **No compiler, no
migration, no ecosystem problem, and it improves every application they emit
rather than only the new ones.**

It has to be answered in one sentence, and the sentence is:

> **A model that reliably writes scoped queries is a probabilistic control. A
> compiler that rejects unscoped ones is a deterministic one — and the party in
> §2's table who carries the risk cannot buy a probability.**

Everything follows from that distinction. A platform that has trained the leak
rate down to one in ten thousand has improved its product and has not changed what
it must say to a customer after an incident, or to an auditor, or in a contract.
**"Our model rarely does that" and "that program does not compile" are different
kinds of statement**, and only the second one is a control anyone can be held to.

**Two things follow that are worth acting on.**

**Training and Gust are complements, not rivals**, and the pitch should say so.
The generator gets better *and* the output is checked; §0.7's Track B — model
fluency — is a bet on exactly the same training capability the objection
describes. **Anyone who frames this as "our compiler versus your model" has
picked a fight with their own buyer's core competence** and will lose it.

**But it means the honest sale is narrower than "generated code is unsafe."**
Most generated code does not need a deterministic control, and the model will
keep getting better at the rest. The sale is for the applications where a
probability is not an acceptable answer — multi-tenant data, payments,
regulated workloads. **That is a real market and it is not the whole market**,
and a pitch that claims the whole market invites exactly this objection from
someone who will then dismiss the narrow case along with the broad one.

**The honest concession:** the competitor is *good enough* for most applications,
and Gust's market is applications where it is not. That is a smaller market than
"web development" and it is the one §2 already describes. **Anyone selling this
must be able to make the RLS comparison unprompted and concede its strengths**,
because the first competent buyer will raise it, and a pitch that has not
metabolised it will not survive that meeting.

### 2.2 Make the answer empirical

The single demo in `VISION.md` section 0.7 shows the mechanism and is allowed to
select a failure that makes the distinction visible. It is not evidence that
Gust beats the alternative above across realistic generated applications.

After that demo holds, run `docs/GENERATION_SECURITY_BENCHMARK.md`. The comparison
has three arms: conventional Next.js/Postgres, a **hardened**
Next.js/Postgres-or-Supabase stack with RLS and current security gates, and Gust.
Give each the same application requirements, frontier model, harness, tool and
repair budget, acceptance tests, and adversarial traffic. The primary endpoint
is secure functional completion; publish security findings, iterations, tokens,
latency, and human intervention separately.

The hardened arm is the commercial test. Beating a stack with no RLS or publish
gate answers an objection nobody competent will make. If the hardened arm
captures most of Gust's security advantage at materially lower generation cost,
the wedge is weak even if the compiler works exactly as designed. If Gust remains
materially safer but the model cannot finish applications within the
preregistered budget, OD-9 fails in the form the buyer cares about.

This benchmark does **not** resolve section 1's buyer contradiction. A security
result cannot reveal who owns a budget or what an incident cost. It also does not
establish that traces improve model training; that needs a separate controlled
learning experiment after traces exist. Keep technical evidence, customer
evidence, and training evidence separate so success in one cannot be used to
smuggle in the other two.

---

## 3. The commercial risk that is not in §0.11

§0.11 lists technical risks — model fluency, a soundness hole, distribution. **All
three are risks of Gust failing. None is the risk of Gust succeeding and not
mattering.**

> **An incumbent closes the gap.** If a platform with distribution — a model
> provider with a build surface, or a deployment platform — ships
> tenant-scoping-by-construction inside the stack developers already use, **the
> differentiator evaporates without Gust doing anything wrong.**

This is more likely than a soundness hole, because it needs no research: the idea
is publishable, the mechanism is not secret, and this repository's own documents
describe it in enough detail to implement. **Being right early and slow is the
characteristic way a good technical bet loses commercially.**

**It is also monitorable, which is the only thing that makes it actionable.** The
tells, in roughly the order they would appear: a deployment or backend platform
shipping *secure by default* multi-tenant templates; row-level security generated
and enforced by construction rather than configured; a model provider publishing
a containment or data-isolation benchmark; any of the ten generators advertising
tenant isolation as a product property rather than a customer responsibility.
**The last one is the loudest signal and the latest** — by the time it is
marketing copy, the engineering is done. **Watching for the first three is
somebody's standing job and currently nobody's.**

Three things reduce it, and only the third is durable:

- **Speed to the artifact.** §0.14's four months is already the answer, and it is
  the reason not to widen scope.
- **The counting programme (§0.9)** — being the named alternative *before* the
  moment arrives, which is a lead-time asset an incumbent cannot retroactively
  acquire.
- **The moat is the machine interface, not the enforcement.**
  `VISION_RECONCILIATION.md` §4 and `docs/STRATEGY_REVIEW.md` §1 both argue this,
  and it matters most here: **tenant scoping is copyable in a quarter; a compiler
  that answers structured questions about a whole deployed application is not.**
  If the strategy rests on §56 alone, this risk is close to fatal. If it rests on
  Ring 4, §56 is the wedge rather than the position.

**That reframing is the single most important line in this document.** §56 gets
the meeting. Ring 4 is what is being bought.

Do not assume the incumbent must copy the whole architecture. Track the cheapest
valuable subset—closed query APIs, generated RLS, tenant-provenance types,
restricted imports, deployment policy gates, repair diagnostics, and sandboxed
execution—and test whether that subset captures most of the liability reduction.
The “three years of calendar” thesis holds only if diligence shows that the
buyer needs the larger machine interface.

The open-core boundary needs the same precision. The public specification and
reference compiler must state which enforcement they include; the proprietary
deployment gate and runtime must state what additional guarantees they enforce.
A decisive scoping analysis cannot simultaneously be the public reference
compiler's defining guarantee and an opaque proprietary secret. Trust,
inspectability, and commercial leverage are explicit trade-offs, not assumptions.

### 3.1 The integrated product is a separate-company decision

An integrated issues/support/flags/communication product can succeed while Gust
is irrelevant or fail while Gust is valuable. It therefore does not follow
automatically from a green compiler demo. The default production evidence is a
narrow multi-tenant reference application with real users, adversarial tests,
and public capability evidence. Expanding to five mature product surfaces needs
separate evidence for buyer demand, distribution, migration, taste, operations,
and support.

---

## 4. What acquisition actually requires

§2 says the realistic outcome is acquisition and §0.10 prices it on strategic
necessity. **Neither works through what has to exist at the moment it happens.**
Written down because it is buildable, and because a demo optimised for a
technical audience and one optimised for an acquirer differ in specific ways.

**An acquirer is buying three things, in this order:**

1. **A liability removed.** Not a compiler. The question in the room is *how many
   incidents attributable to generated code does this prevent, and what is one
   worth.* §0.9's statistic is the numerator and **without it the conversation
   has no units.**
2. **Calendar.** Three years of compiler and semantics work they would otherwise
   start from zero, on a critical path they cannot parallelise. This is the part
   that is genuinely hard to reproduce and the part most under-sold by a demo
   that shows a working web app.
3. **A team that can finish it.** Two to four people who built it are the
   transfer mechanism; documents are not.

**What must exist, and what is optional.** The compiler-enforced rejection with
its diagnostic is required — that is the artifact. The statistic is required, and
has the longest lead time of anything in this document. **The full-stack loop is
optional and is a demo aid**, which was one of the arguments weighed when
`WEB_SLICE_0.md`'s first-demo question was resolved on 2026-08-21: Slice 0 is
more *legible*, and legibility is worth less to an acquirer than to a conference
audience.

**One dynamic worth planning for.** §0.10 prices acquisition on *"competitive
tension between bidders."* Tension requires bidders, plural, which argues for
talking to several prospects in parallel rather than one deeply — **and that
cuts directly against §5's plan to build a relationship with five of them.** The
tension is real: the same conversations that resolve §1's buyer question also
show your hand to the party most able to build it themselves (§3). There is no
clean resolution, only a choice of which risk to run. **The asymmetry that
decides it: the counting programme's statistic is worth more when several people
know about it, and the compiler is worth more when few do.** Talk openly about
the problem; demo the mechanism narrowly.

**What is worth more than it looks:** `docs/ONE_WAY_LEDGER.md`. A project that
scores its own claims against its own compiler and publishes where it falls short
is making a credibility claim no pitch deck can make. **In diligence, the ledger
is the asset** — it converts "we believe" into "we checked, and here is where we
were wrong."

---

## 5. Commercial sequencing

§0.14 sequences the technical work. Nothing sequences the commercial work, so the
two are silently assumed to be serial — build for four months, then talk. **They
are not serial, and one of them has a longer lead time than the build.**

| When | Commercial action | Why then |
| --- | --- | --- |
| **Now** | Start the counting programme (§0.9) | Longest lead time of anything here; independent of compiler progress; §0.10 already funds it as a separate person |
| **Now** | Resolve §1's buyer contradiction by talking to five of the fifteen prospects | Costs time, not money; every other decision depends on it; a *no* now is worth more than a *no* at month 4 |
| **Now** | Preregister the security-adjusted generation benchmark | Task format, threat model, budgets, metrics and audit method can be fixed before results exist without competing for Track A implementation capacity |
| **Month 1–2** | Write the RLS comparison as a document, and have someone hostile attack it | The first competent buyer raises it; §2 must survive it |
| **Month 3** | Second conversation with the same five, showing the rejection diagnostic | The diagnostic is the artifact; a promise at month 0 and a demo at month 3 is a credible arc |
| **At every credible material milestone** | Run the evidence-led outreach review in `docs/EVIDENCE_LED_OUTREACH.md` | Builds a small informed network while evidence accumulates; contact remains individualized, operator-rewritten, and never autonomous |
| **Month 4** | §0.14's four-gate decision point, **with commercial evidence alongside technical** | OD-8 contributes bounded technical evidence; OD-9 and the buyer/defensibility gates must resolve far enough to choose the next evidence stage |
| **After the demo holds** | Five-application harness pilot, then 30–50 applications and an independent audit | Turns one selected mechanism demonstration into evidence against the strongest TypeScript alternative; scale only after the pilot fixes the instrument |
| **After Phase 25 and the complete Cranelift tail close** | Execute `docs/CRANELIFT_LAUNCH.md` | Convert exact native/bootstrap evidence into technical credibility and a small strategic listening programme; no intermediate Phase 20–24 result triggers the coordinated outreach |

**The asymmetry to exploit:** the counting programme and the buyer conversations
are the only work in this document that **does not depend on the compiler working
at all.** They can run through the 30% branch and still have produced something —
a statistic and a market map — where four months of compiler work would have
produced nothing. **That is the cheapest available hedge and it is currently
unstaffed.**

The post-tail launch is deliberately later than the commercial discovery and
individualized evidence-led outreach above. Buyer interviews, technical
correction requests, and benchmark design gather evidence now; the coordinated
Cranelift announcement waits until one durable Level-3 claim is reproducible.
Technical attention from any milestone is not commercial-gate evidence unless a
named person with authority enters a concrete adoption or design-partner path.

---

## 6. What is sold, if anything is

Held deliberately open per §0.10, with what is known recorded so the eventual
choice is made on evidence.

**The language is not the product.** It is free, open, and its adoption is the
distribution mechanism. Nothing here contemplates selling a compiler.

**Three candidate revenue lines, ranked by how much evidence exists:**

1. **Certified suppliers (§2, Part XVI, OD-5).** Already positioned as a service
   layered on the guarantee, and OD-5's direction — an agent does conformance,
   the operator does trust — makes it staffable rather than a team forever.
   **Weakness: it prices the ecosystem, and the ecosystem is deliberately small.**
2. **Compliance evidence.** §108's structured traces are what an auditor asks for
   and what nobody can currently produce: exercised authority, denied authority,
   query predicates, per-request. **SOC 2 and HIPAA evidence generated by the
   compiler is an existing budget line, not a new one** — and this is the only
   candidate that sells to a buyer who is already writing cheques for exactly
   this and getting worse answers. Underweighted everywhere in this repository.
   **The mechanism, stated because the claim is easy to wave at:** an audit
   accepts *evidence*, and today the evidence for "this system enforces least
   privilege" is a policy document, a screenshot, and an attestation that someone
   reviewed it. §108's trace is a machine-generated record of authority actually
   exercised and actually denied, per request. **That is categorically better
   evidence for a question the buyer is already required to answer** — which is a
   far shorter sale than persuading someone they have a problem.
3. **Hosting where the capability check runs** (`STRATEGY_REVIEW.md` §6.1). The
   refusal-to-deploy is only enforceable somewhere, and *somewhere* is a product.
   **Weakness: it is a cloud business, which is the layer §2's underclass
   argument says not to be beneath — and building one is exactly the horizontal
   expansion that consumes decades.**

**Recommendation: none of these is chosen now, and (2) is the one to test first**,
because it is the only one where the buyer has a budget, a deadline, and a worse
alternative today.

---

## 7. What survives the 30% branch

§0.10 prices the downside as "four months spent finding out" and calls it bounded.
**Bounded is not the same as zero, and what remains is worth naming**, because it
changes how the four months should be spent.

If any remaining technical, generation, commercial, or defensibility gate
fails—including OD-9, or the bounded OD-8 result proving insufficient—three
things survive and none of them is the compiler:

- **The statistic (§0.9)**, if it was started. It is independent of the thesis
  and it is publishable whichever way it comes out. **A rigorous count of how
  often generated code leaks tenant data is a contribution regardless of whether
  Gust exists** — and it is the only workstream here with that property.
- **The ledger and the reconciliation.** A worked, checked account of what a
  containment-first language would have to do, with the places it failed recorded
  rather than hidden. That is a genuine artifact and it has a readership.
- **The people.** §4 says a team that can finish it is a third of what an acquirer
  buys; that team exists at month 4 whether or not the thesis held.

**What this implies for how the four months are spent:** the workstreams that
survive failure are the cheap ones, and they are currently the unstaffed ones.
**Staffing the counting programme is not only the longest-lead-time decision, it
is the only one that pays out on the 30% branch.**

## 8. Commercial non-goals

§0.16 lists product non-goals. These are the commercial equivalents — each one a
move that looks like progress and spends the four months §0.14 is protecting.

- **Do not sell to individual developers before the statistic exists.** §2 is
  explicit that willingness-to-pay is near zero until after a breach, and a
  failed self-serve launch is evidence about the launch rather than about the
  thesis. It would also produce the worst possible datapoint: a real *no* from
  the wrong buyer.
- **Do not build a cloud.** `STRATEGY_REVIEW.md` §6.1 keeps hosting as a
  candidate revenue line, and building one is the horizontal expansion that
  consumes decades — the danger that review names first. Deploy *onto* platforms;
  do not become one.
- **Do not chase regulated buyers early.** §2 already places them as the natural
  second market: slower, larger, higher-friction, and **the slowest to stop
  reading code**, which makes them the worst possible early test of a thesis
  whose premise is that nobody reads it.
- **Do not widen the language to win a comparison.** Every feature added to
  answer *"but can it do X"* is a §13 violation bought with a meeting, and
  `docs/ROADMAP_TAIL.md`'s organising principle — make the safe path convenient
  rather than the type system more expressive — is the rule that says no.
- **Do not promise supplier certification externally before OD-5's commercial
  half is settled.** Part XVI already carries this warning. **Saying it is cheap;
  being it is a payroll line.**

## 9. What would falsify this document

- **§1 resolves toward reading 1** — no buyer at any price before a breach. Then
  the product path is not thin, it is absent, and everything reduces to
  acquisition. Not fatal; it changes what month 4 decides.
- **The RLS comparison in §2 does not survive a hostile reading.** If a competent
  engineer can show the gap is narrower than claimed, §56 is not a wedge and §3's
  Ring 4 argument has to carry the whole position immediately rather than
  eventually.
- **The hardened arm of the generation benchmark captures the same security
  outcome more cheaply.** If RLS, current publish gates, and model repair achieve
  comparable secure functional completion with materially less agent cost, the
  deterministic distinction exists but is not a sufficient adoption wedge.
- **Gust wins the audit and loses generation.** If secure applications require
  materially more turns, tokens, latency, human repair, or outright task failure
  than the preregistered limit, OD-9 has failed commercially even if the type
  system is sound.
- **An incumbent ships containment first.** §3's risk lands. The response is
  already known — Ring 4 — but the timeline compresses hard.
- **The counting programme produces a small number.** If generated code does not
  leak measurably more than hand-written code, §0.9's statistic argues against
  the thesis. **That is the most valuable possible outcome of the cheapest
  workstream, and it is the one nobody would choose to look for.**

---

## 10. What needs deciding, by whom

| Question | Whose | When |
| --- | --- | --- |
| §1's buyer contradiction | Operator, from prospect conversations | Before month 4 |
| Staff the counting programme (§0.9) | Operator | Now — longest lead time |
| Which revenue line to test | Operator, after §1 | Month 4 |
| OD-10 distribution | Operator; first candidate at `STRATEGY_REVIEW.md` §6 | Month 4 |
| ~~Whether the demo is containment or Slice 0~~ | **Decided 2026-08-21** — containment first; Slice 0 follows. Recorded at `WEB_SLICE_0.md` § "Resolved 2026-08-21" | — |
| OD-5 certification staffing | **Decided 2026-08-20** — split agent/operator | — |

**Nothing in this document is a decision.** Sections 1, 2, and 3 are findings;
5 through 9 are proposals; this table is the routing.

**The limitation, stated plainly.** This was written by the documentation lane
from the repository's own documents. **It has no customer conversations behind
it, no pricing evidence, and no contact with any of the fifteen prospects §0.8
counts.** Sections 1 and 5 are the ones most exposed by that: the buyer
contradiction is *identified* here and can only be *resolved* by someone talking
to buyers, and the sequencing assumes those conversations are available to have.
Where this document and someone with a customer call disagree, **the call wins**
— and the finding in §1 exists precisely so that call gets made before month 4
rather than at it.

---

**If only one thing in this document is acted on, it is this: staff the counting
programme now.** It has the longest lead time of anything here, it is independent
of whether the compiler works, it supplies the numerator every other conversation
needs, and it is the only workstream that produces something on the 30% branch.
It is also, today, unstaffed.
