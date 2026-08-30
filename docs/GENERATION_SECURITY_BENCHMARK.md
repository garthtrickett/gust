# Security-adjusted generation benchmark

Status: **adopted evidence programme; full execution waits on the containment
demo.**

This document turns `VISION.md` section 0.7's single side-by-side into a staged,
falsifiable benchmark. It does not replace the first demo, add a third demo
track, resolve OD-9 or the remaining evidence gates in advance, reopen OD-8's
bounded-positive verdict, or choose a business. The demo proves
that Gust can express and reject the selected failure. The benchmark asks
whether that advantage survives realistic application variety and the strongest
credible TypeScript alternative.

The recent-incident comparisons in `docs/DEMO_EXPLOIT_AUTOPSIES.md` are a
separate explanatory artifact. They ask whether a specific disclosed exploit
path maps to a shipped Gust guarantee; they are not benchmark observations,
prevalence evidence, or a substitute for the hardened comparison arm below.

## 1. The question

For the same realistic multi-tenant application specification and a fixed agent
budget, does Gust increase **secure functional completion** enough to justify its
lower model fluency and smaller ecosystem?

That question deliberately combines the two ways Gust can fail:

- a generated application can work but remain exploitable; or
- it can be structurally safer but too difficult for an agent to finish.

The result must publish both dimensions. A composite score may be reported only
after the underlying completion, security, cost, and intervention measurements;
it may not hide a loss on any of them.

## 2. What this can and cannot establish

The benchmark can test:

- the security advantage of compiler enforcement over generation-time and
  publish-time guardrails;
- OD-9 in the commercially relevant form: whether an agent can produce a secure,
  working Gust application within a competitive repair budget;
- whether diagnostics and hard rejection improve the agent's repair loop; and
- whether Gust wins only against an unprotected baseline or also against the
  stack a competent platform would actually deploy.

It cannot establish:

- willingness to pay or which budget owns the problem — those require the
  customer conversations in `BUSINESS_STRATEGY.md` section 1;
- that Gust traces improve model training — that requires a separate controlled
  learning experiment after real execution traces exist; or
- the prevalence of cross-tenant leaks in deployed AI applications — that is
  the independent counting programme in `VISION.md` section 0.9.

One experiment does not answer three companies' questions. This benchmark is
technical and product evidence. Customer evidence and training evidence remain
separate.

## 3. Evidence ladder

### Stage 0 — protocol now

Write and preregister the task format, threat model, acceptance tests, stopping
rule, model and tool budgets, scoring procedure, audit procedure, and minimum
effect worth pursuing. Freeze them before the main results are visible.

Stage 0 also includes a serious architecture spike of the strongest
existing-language alternative: a restricted TypeScript frontend with a closed
query IR, compiler-enforced imports, tenant provenance, declared effects, and a
confined runtime. The spike records exactly which guarantees it can and cannot
provide while retaining TypeScript's model fluency and ecosystem. It must not be
a paper dialect designed to lose. Its concrete failure modes form part of the
positive case for a new language; if it remains credible, it graduates into a
maintained fourth arm before the main run.

This design work may run alongside Track B only when it does not consume Track A
compiler capacity. It does not authorise building the absent database, effect,
or trace surfaces outside their owning roadmap.

### Stage 1 — staged demonstration

Build one recognisable multi-tenant issue tracker or support inbox. Use one
chosen cross-tenant failure to make the distinction legible: the conventional
program can ship the error while Gust rejects the unsafe construction.

Stage 1 has three separately reported exit gates:

1. **Mechanism:** the selected unsafe typed query is rejected.
2. **Containment:** ambient bypasses are closed, runtime capabilities are
   enforced, and native or adapter code is independently isolated.
3. **Production-shaped:** tenant establishment, schema acquisition and pinning,
   realistic Postgres behaviour, traces, deployment evidence, and an independent
   attack are present.

The first is a mechanism demonstration, not a prevalence estimate and not a
fair contest. Its TypeScript failure is selected deliberately. Say so, and do
not report Stage 1.1 as though Stage 1.2 or 1.3 also passed.

### Stage 2 — five-application harness pilot

After the Gust arm can express the demo honestly, run five application families
through every arm. Use the pilot to find ambiguous specifications, broken tests,
missing instrumentation, audit cost, and benchmark leakage. Do not use it for a
headline result.

Set the minimum material security improvement and maximum acceptable generation
cost after this pilot and before the main benchmark.

### Stage 3 — 30–50 applications

Use eight to ten application families with independent model runs, seeds, or
requirement variants. Thirty different prompts with no repetition measure prompt
selection as much as the systems; repeated trials are required to estimate model
variance.

The suite should contain both ordinary product work and adversarially chosen
security cases. Publish the split. An attack-enriched suite measures resistance
to known attacks, not their natural prevalence.

### Stage 4 — independent audit and publication

Give the deployable artifacts and the preregistered threat model to an auditor
who did not build either arm. Publish the task specifications, prompts, agent
transcripts, tool calls, source, compiler and scanner diagnostics, acceptance
results, exploits, audit method, version pins, and failures.

Retain a private holdout set if the benchmark will be rerun against later models.
Publishing every task turns the next run into a corpus-recall test.

## 4. The arms

Run at least three:

1. **Conventional baseline:** frontier agent targeting Next.js and Postgres,
   without Gust-specific enforcement.
2. **Hardened baseline:** frontier agent targeting Next.js, Postgres or
   Supabase, row-level security, dependency checks, database-policy analysis,
   application security review, and the publish gates a competent generator can
   deploy today.
3. **Gust:** the same frontier agent targeting the pinned Gust compiler and
   platform surface.

The hardened arm is load-bearing. Gust's commercial competitor is not careless
TypeScript; it is TypeScript plus a fluent model, RLS, scanners, repair loops,
and a controlled runtime. If Gust wins only against arm 1, the structural wedge
has not survived its strongest objection.

Database defense in depth is held fair across deployment models. A shared-schema
Gust arm retains PostgreSQL RLS as an independent boundary; a schema-per-workspace
Gust arm is tested for trusted connection acquisition, schema pinning, and pool
reset. The benchmark must not improve Gust's apparent result by withholding a
downstream database control that a production deployment should use.

The Stage 0 restricted-TypeScript spike becomes a fourth arm when it can be
implemented and maintained credibly. If it is excluded, publish the concrete
technical or resourcing reason; “new language is cleaner” is not sufficient.

## 5. Controls

Hold constant across arms:

- application requirements, acceptance tests, initial data, users, and attack
  traffic;
- model family and version, agent harness, tool availability, context budget,
  maximum turns, token budget, wall-clock limit, and human-intervention policy;
- what documentation the agent may read, with equivalent stack documentation
  available to every arm;
- completion and stopping rules; and
- infrastructure size and deployment conditions where the stacks permit a fair
  match.

Randomise arm order. Run enough independent trials to expose model variance.
Record every repair; do not silently hand-correct a failed application. Gust's
smaller corpus is not a nuisance to control away — it is OD-9 — but stack-specific
prompting, examples, and fine-tuning must be disclosed and charged to the arm.

## 6. Measurements

### Primary endpoint

**Secure functional completion rate under the fixed budget:** the application
passes its functional acceptance suite and the adversarial audit finds no
successful in-scope exploit.

### Required secondary measurements

- functional completion rate before security scoring;
- exploitable findings by class and severity;
- the stage at which each finding is prevented or detected: generation,
  compilation, publish gate, scanner, database policy, or runtime;
- false-positive and false-negative rejections for the fixed attack suite;
- agent turns, compilation or build attempts, tokens, wall-clock time, and human
  interventions;
- successful completion after each repair attempt;
- undeclared and excess authority once effects exist; and
- diagnostic precision: whether the agent repaired the cause without being told
  the answer.

Publish the measurements separately before any summary score. A system that
prevents every exploit by failing to build has zero secure functional
completions, not perfect security.

## 7. Security suite

Derive the tenant cases from `VISION.md` section 56.1 rather than inventing an
easy showcase. At minimum cover:

- a missing tenant predicate;
- tenant identity taken from attacker-controlled input;
- joins between scoped and unscoped tables;
- aliases, subqueries, helper functions, and mutations;
- raw-query and privileged escape paths;
- an identifier obtained under one tenant and reused under another;
- cache keys that omit tenant identity;
- background or delayed work carrying the wrong tenant; and
- a legitimate cross-tenant administration path that must be explicit and
  separately authorised.

Not every case is demo scope. The benchmark may not claim coverage for a feature
the Gust platform does not implement.

## 8. Decision rules

The main run must be allowed to hurt the thesis.

- If Gust does not materially improve secure functional completion over the
  hardened baseline, the tenant-scoping wedge is unsupported.
- If Gust improves security but requires an unacceptable increase in turns,
  tokens, latency, human repair, or outright task failure, OD-9 fails in the form
  an application builder cares about.
- If Gust's advantage disappears under the private holdout or independent audit,
  the public result does not generalise.
- If Gust produces a material security advantage within the preregistered
  generation budget, the result supports further platform and buyer testing. It
  does not itself prove demand.

No threshold may be chosen after the main results are known.

## 9. Execution gate at adoption

Verified against `main` `f9c1cf412f9705519fe78ac8fea174c7e75c3bc2`
on 2026-08-22:

- effects in function types are absent: the complete keyword dispatch at
  `compiler/lexer.gst:159-187` has no `uses`, and `FunctionSignature` at
  `compiler/typechecker.gst:639-650` carries FFI obligations but no effects;
- compiler-owned Postgres query derivation and tenant tracking are absent:
  exact case-insensitive searches for `postgres|tenant` over `compiler/`
  returned zero matches at that commit; and
- execution traces are absent: `typechecker_log_trace` at
  `compiler/typechecker.gst:9474-9475` has an empty body and is a compiler
  debugging stub, not a program trace.

The active Phase 20 roadmap qualifies brand, arena, resource, and whole-program
differential behaviour. It does not own the four Track A items above. Therefore
Stage 0 is actionable now, the counting programme is independently actionable,
and Stages 1–4 wait on the named demo prerequisites and their owning roadmap.
