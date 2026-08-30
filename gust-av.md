# Adversarial Review of the Gust Vision

**Prepared:** 2026-08-30

**Scope:** non-technical strategy, product thesis, market positioning, language
design, runtime architecture, containment model, and execution plan

**Repository reviewed by the reviewer:** `/home/garth/files/code/gust`

**Repository reconciled by this response:** `/home/gust/code/gust`

**Review basis:** `docs/VISION.md`, `docs/BUSINESS_STRATEGY.md`,
`docs/GENERATION_SECURITY_BENCHMARK.md`, `docs/VISION_RECONCILIATION.md`,
`docs/ONE_WAY_LEDGER.md`, `docs/DEMO_TARGET_PROGRAM.md`,
`docs/SHARED_SEMANTIC_ZONE.md`, and related governance documents

**Method:** read-only adversarial document review. This is not a customer study,
market survey, penetration test, formal soundness proof, or independent
implementation audit.

> This file preserves the review supplied to the project and records the
> repository response. Each `VISION-RESPONSE:` states whether the finding was
> accepted, narrowed, already addressed, or not applied, and identifies the
> resulting documentation change. A response is not implementation evidence;
> `docs/ONE_WAY_LEDGER.md` remains authoritative for that.

## Executive conclusion

Gust contains a real and potentially valuable technical idea: make important
classes of authority and tenant-isolation failure structurally unrepresentable,
then give agents structured diagnostics and traces with which to repair their
output. The project also demonstrates unusually strong intellectual honesty. It
distinguishes containment from correctness, records open decisions, identifies
falsifiers, compares itself with a hardened baseline, and maintains a ledger
showing where the implementation contradicts the specification.

That honesty exposes the central problem: the current vision joins four
independent bets and sometimes treats success in one as evidence for all four.

| Bet | Evidence currently available |
| --- | --- |
| Cross-tenant failures in generated applications are prevalent and economically material | Asserted; the counting programme is proposed but unstaffed |
| Gust can prevent the relevant failure class end to end | A query-provenance design is proposed; important leak paths are explicitly excluded |
| Frontier models can generate Gust competitively | Open, thesis-invalidating OD-9 |
| A platform will adopt or acquire Gust, or users will pay for a Gust-built product | No customer evidence; buyer, product, and sales models conflict |

The correct near-term framing is therefore not “the demo selects the strategy.”
It is:

> The next phase is a bounded falsification programme testing technical
> enforceability, generation economics, buyer demand, and competitive
> defensibility separately.

The project should continue only with a narrower external claim, a more explicit
trusted-computing-base model, a fair test of the strongest existing-language
alternative, and commercial evidence gathered in parallel. It should not
proceed automatically from a successful compiler demo into the proposed
integrated SaaS product.

**VISION-RESPONSE:** Accepted. `docs/VISION.md` §§0.7, 0.8, and 0.14 and
`docs/BUSINESS_STRATEGY.md` §0.1 now define four independent gates: technical,
generation, commercial, and defensibility. A mechanism demo may eliminate a
path or authorize the next evidence stage; it no longer selects the company by
itself. The integrated product is explicitly a separate-company decision.

## What is strongest in the vision

1. **Containment is separated from correctness.** The vision refuses to claim
   that capability enforcement establishes intent.
2. **The project records disconfirming evidence.** `docs/ONE_WAY_LEDGER.md`
   tracks absent, partial, and violated rules.
3. **The proposed benchmark includes a hardened competitor.** Careless
   TypeScript is not the meaningful comparison.
4. **OD-8 is framed as an attack, not a design review.** The burden is a
   compiling program that leaks.
5. **The vision identifies many of its own failure modes.** Model fluency,
   distribution, migration, incumbent response, product distraction, and the
   absence of an intent layer are not hidden.

These mechanisms should survive even if the commercial thesis or language
architecture changes.

**VISION-RESPONSE:** Accepted and preserved. No ledger evidence or OD status was
changed. The current repository has since resolved OD-8 as a **bounded positive**
for the predefined compiler-owned typed-query suite, with explicit exclusions;
that later evidence is reflected below where the review's OD-8 wording became
stale.

Severity is used narrowly in this review:

- **Critical** can invalidate the headline claim, security boundary, or
  business-selection logic.
- **High** materially changes scope, feasibility, adoption, or defensibility.
- **Medium** weakens clarity, evidence quality, or operational safety.

# Part I — Non-technical and commercial review

## NT-1 — Critical: the buyer contradiction is unresolved

The market-positioning section says the end user is not the buyer, willingness
to pay is near zero before a breach, and Gust must arrive as a mode inside a
generator's product. The proposed post-demo business is nevertheless a
self-serve integrated product priced at $30–60 per seat.

`docs/BUSINESS_STRATEGY.md` correctly states that these cannot both be true. The
contradiction determines whether a standalone product path exists. The most
plausible enforcement buyer is a platform engineering, security, risk, or
compliance function. That buyer may have budget, but commonly brings
procurement, diligence, contracts, and enterprise support. The hard “no
enterprise sales” constraint may exclude the natural buyer while the self-serve
product targets someone the vision says does not care.

**Required evidence:** conversations with named prospects establishing who
owned the last relevant incident, its cost, the budget that paid for it, what
control would have been accepted, and whether language/runtime adoption is
feasible.

**VISION-RESPONSE:** Accepted as unresolved, not “fixed” by prose.
`docs/BUSINESS_STRATEGY.md` §1 now defines a named-prospect discovery record:
incident ownership and cost, paying budget, accepted controls, adoption
authority, procurement/migration/ecosystem objections, and preferred response.
Five interviews are explicitly a minimum discovery sample, not proof. The
integrated product cannot pass the commercial gate on a compiler result.

## NT-2 — Critical: the demo cannot select the business strategy

A demo can eliminate strategies when the mechanism fails. It cannot establish
problem frequency, a budget owner, willingness to change generated language,
migration acceptance, preferred commercial form, or superiority to a hardened
baseline. The month-four decision should have technical, generation,
commercial, and defensibility gates. A successful mechanism demo should
authorize the next evidence stage, not automatically select a company.

**VISION-RESPONSE:** Accepted. The sentence “the demo selects the strategy” was
removed from `docs/VISION.md` §§0.8 and 0.16. Four gates now govern the month-four
decision in VISION and `docs/BUSINESS_STRATEGY.md` §0.1.

## NT-3 — High: the “ten generators” lever is a hypothesis presented as a fact

No prospect map, adoption analysis, incentive study, or conversation evidence
supports the number. Even if concentration is directionally right, switching
output languages brings ecosystem, debugging, migration, deployment, training,
support, and early-runtime risk. The thesis should name target generators,
their incentives and constraints, and evidence that would show switching is
unrealistic.

**VISION-RESPONSE:** Accepted with narrower wording. The strategic shorthand is
retained as a falsifiable adoption hypothesis, not a measured fact.
`docs/BUSINESS_STRATEGY.md` §1 now requires a named target map and adoption
constraints before the commercial gate can pass. No prospect count was invented.

## NT-4 — High: the integrated-product fallback is a second company

The proposed product combines feature flags, issues, support, communication,
identity, permissions, notifications, search, audit, and migration. It depends
on product taste, distribution, support, migration quality, and operational
reliability. It can succeed while Gust is irrelevant or fail while Gust is
valuable, and can consume the team while the language stalls.

A narrower reference application provides stronger evidence per unit of effort:
one production-shaped multi-tenant system with real users, adversarial tenant
tests, public capability evidence, and no attempt to compete across five mature
product categories.

**VISION-RESPONSE:** Accepted. `docs/VISION.md` §0.8 and
`docs/BUSINESS_STRATEGY.md` §3.1 now make the narrow reference application the
default production evidence. The integrated product remains a candidate, but it
requires its own demand, distribution, migration, taste, operations, and support
evidence.

## NT-5 — High: the acquisition thesis is exposed to rapid partial replication

The likely incumbent response is not to rebuild Gust. It is to reproduce the
valuable subset inside the existing stack: closed database/query APIs, generated
RLS, tenant-provenance types, restricted imports, deployment policy gates,
repair diagnostics, and sandboxed execution. “Three years of calendar” is
persuasive only if diligence shows the whole architecture is needed.

The proposed open-core boundary is also unstable if the language specification
and reference compiler are open while the defining scoping analysis is
proprietary. The vision should state which enforcement is public, which runs in
a proprietary deployment gate, and why users can trust it.

**VISION-RESPONSE:** Accepted as a risk, not as a proven 20/80 conclusion.
`docs/BUSINESS_STRATEGY.md` §3 now tracks the cheapest valuable incumbent subset
and requires the calendar thesis to survive it. It also requires an explicit
public-reference-compiler versus proprietary-gate guarantee boundary.
`docs/VISION.md` §0.8 now places the lead scoping analysis and conformance
fixtures in the open reference compiler while reserving operational hosting and
policy services as proprietary candidates. The
review's speculative conclusion that partial replication necessarily defeats
the moat was not adopted as fact.

## NT-6 — High: the counting programme lacks a credible research protocol

“Scan public AI-generated deployments and publish the leak rate” leaves the
identification method, denominator, selection bias, legal authorization,
confirmation standard, false-positive adjudication, disclosure delay, and
publication ethics unanswered. Without a preregistered protocol, the statistic
is easy to attack and can become vulnerability marketing.

**VISION-RESPONSE:** Accepted. `docs/VISION.md` §0.9 now requires a preregistered
sampling, consent/legal, testing, adjudication, disclosure, and audit protocol.
Public reachability is explicitly not permission to test. If a defensible
denominator cannot be obtained, the prevalence claim is abandoned.

## NT-7 — Medium: “nobody reads the code” is memorable but too absolute

Humans still read incident-relevant code, migrations, authority changes,
traces, and intent specifications. Gust moves review to different artifacts; it
does not eliminate it. The stronger formulation is that human review moves from
implementation detail to intent, authority, evidence, and exceptions, coupled
to a metric for review time, expertise, and misunderstanding.

**VISION-RESPONSE:** Accepted. `docs/VISION.md` §§0.1 and 0.12 and its
consolidated rule 1 now use the “not reliably read before shipping” formulation,
name what humans still review, and require measurement of reviewer burden and
comprehension.

## NT-8 — Medium: the probability and cost model is not evidence-backed

The 30/50/20 probabilities and low-single-digit-million demo cost have no shown
model, comparables, dependency-adjusted schedule, or customer evidence. They
should be labelled planning priors with assumptions that would change them.

**VISION-RESPONSE:** Accepted. `docs/VISION.md` §0.10 now labels the figures
planning priors rather than honest measured odds and requires staffing,
throughput, dependency, infrastructure, adoption, and buyer assumptions before
they are used for funding or strategy. The numbers were retained as estimates,
not presented as evidence.

# Part II — Technical and architectural review

## T-1 — Critical: the lead claim is broader than the proposed enforcement

The headline can be heard as application-wide tenant isolation while the actual
analysis concerns a compiler-recognized scoped entity and trusted query
provenance. Correctly scoped queries can still leak through caches, identifier
reuse, messages, jobs, storage, stored procedures, triggers, raw connections,
or suppliers. The defensible initial claim is:

> Gust rejects typed query operations whose required tenant provenance is not
> discharged by the trusted request scope.

An application-wide headline would require end-to-end tenant-labelled
information flow across all those boundaries.

**VISION-RESPONSE:** Accepted, and partly already addressed after the review's
source snapshot. Current OD-8 is a bounded positive with these exclusions.
`docs/VISION.md` §1 now uses the narrow typed-query claim, lists excluded paths,
and consolidated rule 5 carries the same boundary. `docs/DEMO_TARGET_PROGRAM.md`
also says explicitly what its negative case does not establish.

## T-2 — Critical: the vision specifies two different database-isolation architectures

One schema per workspace and a shared schema with `workspace == scope` are not
interchangeable. Schema-per-workspace depends on connection acquisition,
search-path/schema selection, and pool reset. Shared-schema isolation depends on
predicate provenance, joins, nesting, and mutations. The demo must choose one;
supporting both later requires separate threat models, tests, and guarantees.

**VISION-RESPONSE:** Accepted. `docs/VISION.md` §9 and
`docs/DEMO_TARGET_PROGRAM.md` now choose schema-per-workspace for the first
production-shaped deployment and name its proof obligations. Shared-schema plus
RLS is a separate future mode. The typed-query mechanism remains independently
demonstrable, but is no longer described as the schema-selection mechanism.

## T-3 — Critical: database enforcement should be defense in depth

Compiler provenance and PostgreSQL RLS are different controls. A serious
shared-schema deployment should use both: provenance prevents ordinary mistakes
and improves repair; RLS contains compiler, lowering, raw-query, and application
defects that reach PostgreSQL. Schema-per-workspace supplies a different
downstream boundary. The benchmark should not reward Gust for omitting a
defense its production deployment should retain.

**VISION-RESPONSE:** Accepted with deployment-specific scope. RLS is mandatory
for the future shared-schema mode, not for every schema-per-workspace design.
`docs/VISION.md` §9 and `docs/GENERATION_SECURITY_BENCHMARK.md` §4 now require a
fair downstream database boundary in each mode.

## T-4 — Critical: declaration is being conflated with confinement

An effect checker establishes declarations for known source operations. It does
not prevent ambient builtins, native/FFI authority, compiler defects,
compromised adapters, runtime defects, or dynamic host handles. Containment
requires unforgeable runtime handles, linker/import discipline, an
operator-approved ceiling, invocation checks, isolation beneath compiler/native
defects, first-deployment policy, and auditable expiring escape hatches.

**VISION-RESPONSE:** Accepted. `docs/VISION.md` §§0.4 and 110 now separate source
declaration, operator authorization, unforgeable runtime enforcement, and
isolation, and name the trusted computing base. §114 adds first-deployment
policy. Existing ambient `os.*` violations remain ledger evidence; documentation
did not pretend they were fixed.

## T-5 — Critical: sandboxing and capability enforcement are separate boundaries

Capabilities constrain legitimate operations. Sandboxes contain memory
corruption, compiler bugs, malformed adapters, unexpected syscalls, denial of
service, and resource exhaustion. A language capability system cannot safely be
its own containment boundary when the compiler and runtime are attack surface.

**VISION-RESPONSE:** Accepted. The “same mechanism” statement was removed from
`docs/VISION.md` §110 and consolidated rule 43. The vision now requires
capability enforcement plus process, Wasm, VM, or equivalent isolation with
explicit CPU, memory, filesystem, network, and syscall limits.

## T-6 — High: business-level effects hide a second authority system

`payments.charge` improves reviewability but still needs low-level network,
secret, and data access. The architecture needs linked application-authority
and implementation-authority manifests. The runtime constrains both, and
certification cannot replace confinement.

**VISION-RESPONSE:** Accepted. `docs/VISION.md` §18 now defines the two linked
manifests, requires evidence mapping business operations to low-level authority,
and states that certification does not replace runtime enforcement.

## T-7 — High: the no-GC systems-language core is not justified by the product wedge

Branded arenas, ownership, linear resources, a native backend, and no GC are not
necessary to enforce tenant provenance or business capabilities. They increase
OD-9 and implementation risk. The vision needs a direct argument for why no-GC
ownership is load-bearing for the initial security product.

**Operator clarification supplied with the review:** “It is not, but I wanted
to build a general-purpose language.”

**VISION-RESPONSE:** Accepted with that operator correction. No-GC is explicitly
**not** load-bearing for the initial typed-query wedge. It is retained because
Gust is intended to be a general-purpose systems language. `docs/VISION.md`
§0.16 no longer lists general-purpose systems language as a non-goal, and §10
records the independent rationale and requires OD-9 to measure its cost. The
review's implied option of removing the systems-language core was not adopted.

## T-8 — High: the strongest existing-language alternative is tested too late

A restricted TypeScript frontend with enforced imports, tenant provenance,
effects, and runtime capabilities attacks the need for a new language more
directly than ordinary RLS. It must not be a paper strawman. An early
architecture spike should identify exactly where it fails; if it does not fail
materially, the low-level language investment should be reconsidered.

**VISION-RESPONSE:** Accepted. `docs/VISION.md` §0.7 and
`docs/GENERATION_SECURITY_BENCHMARK.md` Stage 0 now require a serious restricted-
TypeScript architecture spike. It becomes a maintained fourth arm if credible;
exclusion requires a concrete reason.

## T-9 — High: the demo critical path is substantially larger than stated

Effects, call-graph checking, typed queries, and provenance are enough for a
mechanism demo, not honest end-to-end containment. Trusted tenant identity,
schema pinning, SQL execution, cleanup, native boundaries, runtime confinement,
diagnostics, traces, I/O, and usable stdlib surfaces belong to later claims.
The plan should distinguish mechanism, containment, and production-shaped demos.

**VISION-RESPONSE:** Accepted. Those three stages and their exit boundaries now
appear in `docs/VISION.md` §0.7, `docs/GENERATION_SECURITY_BENCHMARK.md` Stage 1,
and `docs/DEMO_TARGET_PROGRAM.md`. The additional requirements were not silently
inserted into the narrow mechanism patch sequence.

## T-10 — High: database introspection conflicts with reproducible builds

Live PostgreSQL introspection can make identical source observe different
schema state. The missing bridge is an explicit acquisition command producing a
canonical content-addressed schema snapshot, reviewed and pinned, compiled
offline, and checked against the deployment schema version.

**VISION-RESPONSE:** Accepted. `docs/VISION.md` §54 now defines exactly that
acquisition/snapshot/offline-compilation/deployment-check workflow.

## T-11 — High: one query-tree walk does not establish sound SQL semantics

One traversal avoids duplicated-analysis drift but does not prove SQL lowering
preserves the analysed semantics. A closed inspectable query IR needs a separate
lowering stage and differential tests covering PostgreSQL semantics, mutations,
parameters, and typed extensions.

**VISION-RESPONSE:** Accepted. `docs/VISION.md` §55.1 now distinguishes one
semantic analysis over a closed query IR from separately tested SQL lowering and
names the differential surface. The former “cannot disagree with itself” claim
was narrowed.

## T-12 — High: the effect system is under-specified where complexity concentrates

Exact effects on every function create pressure around closures, callbacks,
spawned tasks, adapters, dispatch, and parameterized restrictions. With limited
generic machinery, likely failure modes include effect-set explosion and
compiler special cases. OD-9 should compare exact annotation with inference for
private functions while keeping public/package/capability/deployment boundaries
explicit.

**VISION-RESPONSE:** Accepted as an evidence requirement, not a semantic verdict.
`docs/VISION.md` §17 now requires that comparison and states that documentation
does not itself authorize a language change. Existing open sub-questions remain
open rather than being decided here.

## T-13 — Medium: production determinism is overstated

Real applications observe mutable databases, APIs, time, randomness, retries,
scheduling, and network failure. “Same input” is meaningful only with a complete
external-world transcript. Reproducible builds, controlled deterministic tests,
record/replay, and production observability are separate properties.

**VISION-RESPONSE:** Accepted. `docs/VISION.md` §§110–112 now separate all four.
Only a nondeterministic controlled test is called contaminated; ordinary
production observations are labelled with captured inputs and limitations.

## T-14 — Medium: the initial authority grant has no diff to review

At first deployment there is no previous manifest. The platform needs
organization ceilings, risk-ranked effects, least-authority suggestions,
mandatory justification for privilege, and policies over the complete initial
grant. Declaration without a separate ceiling is not least privilege.

**VISION-RESPONSE:** Accepted. `docs/VISION.md` §114 now applies those controls to
the complete initial manifest and states that later diffs are an additional
surface, not the source of authorization.

## T-15 — Medium: one visible status contradiction weakens governance

Part XXI said both that the intent layer blocks v1.0 and that it blocks v0.5.
The milestone must be resolved in the central register and stated once.

**VISION-RESPONSE:** Accepted. The OD-6 register already says v1.0, so Part XXI
now consistently says it blocks v1.0, not the demo or v0.5. No OD status changed.

# Part III — Recommended reframing

## A narrower, stronger thesis

The review recommends three claims with distinct evidence burdens:

1. **Technical:** Gust makes selected authority and tenant-provenance violations
   compile-time errors and enforces the corresponding runtime capability boundary.
2. **Product:** for security-sensitive generated applications, deterministic
   rejection improves secure functional completion over a hardened conventional
   stack at acceptable cost.
3. **Commercial:** the party carrying risk values that improvement enough to
   adopt, fund, or acquire it despite migration and ecosystem costs.

**VISION-RESPONSE:** Accepted, with technical evidence split once more into the
mechanism and containment stages so compile-time rejection is not conflated with
runtime confinement. The three claims map to the four gates in VISION §0.8;
defensibility is separate from buyer demand.

## Required pre-demo architecture decisions

The review requests: an exact external guarantee and exclusions; a selected
tenancy model; a named trusted computing base; a declaration/authorization/
confinement relationship; linked business and implementation capabilities; a
pinned schema workflow; independent sandboxing; initial-manifest review; a
minimal honest runtime surface; and a counterexample suite.

**VISION-RESPONSE:** Applied across `docs/VISION.md` §§0.4, 9, 18, 54–56,
110–114 and `docs/DEMO_TARGET_PROGRAM.md`. Where these require implementation,
they remain requirements rather than being recorded as delivered. OD-8's current
bounded verdict and exclusions remain authoritative.

## Recommended evidence sequence

The review proposes commercial discovery, architecture falsification, a
mechanism kernel, containment, generation economics, and then business
selection.

**VISION-RESPONSE:** Accepted in substance. The sequence now appears as four
gates and three technical demo stages in VISION, the benchmark, and the business
strategy. The suggested “at least five” conversations are treated as discovery,
not a pass threshold. No external interview, count, or audit is claimed to have
happened because of this documentation update.

## Final assessment

Gust's most compelling insight is not that machines need a new systems language.
It is that software nobody reliably reads needs deterministic controls and
human-reviewable authority artifacts. That can support a new language, but does
not yet prove one is necessary. Continue, but make the next phase harder to
pass: a narrowly scoped, independently attacked containment kernel plus buyer
evidence is valuable; a selected TypeScript failure followed by an automatic
five-surface SaaS product is not sufficient evidence.

**VISION-RESPONSE:** Accepted as the evidentiary posture. The operator's separate
general-purpose-language goal is also preserved: Gust may be worth building as
a language even if the initial security wedge is not what necessitates its
systems core. The roadmap can continue, but neither language progress nor a
green selected demo is allowed to smuggle in a product or market conclusion.

## Review limitations

- No repository files were modified during the review itself.
- No customer interviews, pricing research, or prospect validation were available.
- No external prevalence claims were independently verified.
- Implementation status relied primarily on the repository's own evidence ledger.
- The review did not resolve OD-8; that required implementing the analysis and
  attempting concrete compiling exploits.

**VISION-RESPONSE:** Accepted for the review's original snapshot, with one dated
update: the current repository resolved OD-8 on 2026-08-25 as **bounded positive**
for the complete predefined in-scope suite. It remains neither a formal proof nor
evidence for caches, non-query reads, multi-step flows, raw SQL, or trusted-
context establishment. This response is also a documentation reconciliation,
not a customer study, penetration test, or implementation audit.
