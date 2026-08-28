# PRD: Gust Semantic Change Assurance

**Status:** Proposed; report-only pilot not yet authorized

**Last refined:** 2026-08-28

**Audience:** Gust operator, compiler/runtime contributors, agents, reviewers, and release owners

**Initial product area:** Compiler-semantic and shared-zone changes

**Purpose:** Add decision provenance, independent challenge, exact-revision evidence accounting, and counterexample-driven assurance around Gust's existing proof system without creating a second roadmap or another control plane.

> This document is a proposal, not an activated roadmap. It does not change
> `AGENTS.md`, the active `TASK.md`, repository rules, merge policy, decision
> status, or any current patch exit gate. In particular, it does not widen
> Phase 21.17 or Phase 21.18. Implementation begins only after the operator
> selects and activates a later pilot.

## 1. Decision summary

Gust should pilot a **Semantic Change Assurance** layer around its existing
compiler proof system.

Gust already has unusually deep deterministic evidence: positive and negative
fixtures, compiler-backed guards, MIR-to-C/Cranelift differentials, capability
registries, bootstrap fixed points, historical shards, exact patch exit gates,
and generated closure records. The missing layer is not more test volume. It is
one compact way to establish:

1. who authorized the intended semantics;
2. which assumptions and questions remain unresolved;
3. whether an independent reviewer challenged the premise shared by the
   roadmap, implementation, and tests;
4. whether plausible semantic and evidence-selection defects are detected;
5. whether unsupported, skipped, fallback, empty, stale, or malformed evidence
   is visible;
6. which exact revision each conclusion applies to; and
7. whether a result was merely observed or was actually required.

The proposal adapts two groups of ideas:

- from Aeva: append-only provenance, explicit human-versus-agent authority,
  clean-context adversarial review, sticky material findings, non-author
  adjudication, and protected evidence publication;
- from csift: empirical reconstruction, minimized corpus-derived regressions,
  curated mutation testing, shared classification, and explicit loss
  accounting.

These are design references, not dependencies. Gust's existing Level 1–3
evidence remains the deterministic engine and source of truth.

## 2. Fit with Gust's existing authority

The assurance layer must reference current authorities rather than duplicate
or supersede them.

| Subject | Existing authority | Assurance-layer rule |
| --- | --- | --- |
| Agent operations, lane ownership, publication, monitoring, merge, and phase closure | `AGENTS.md` | The envelope records applicable rules and evidence; it cannot change them. |
| Active Cranelift work and patch boundaries | `TASK.md` | The envelope references one activated patch. It is not a second work queue. |
| Active Stdlib work and patch boundaries | `TASK_STDLIB.md` | A future Stdlib envelope may reference a Stdlib patch, but cannot authorize shared-zone work. |
| Shared semantic ownership | `docs/SHARED_SEMANTIC_ZONE.md` | A triggered shared-zone change still uses the seven-point stop report and Cranelift ownership decision. |
| Operator decisions | `docs/VISION.md` §0.15 | This remains the only place an OD is opened, closed, or renumbered. An envelope stores references and provenance, never a second OD status. |
| Current implementation versus design | `docs/ONE_WAY_LEDGER.md` | The envelope may cite reproduced ledger evidence but may not promote an old ledger claim to current evidence. |
| Cranelift capability, parity, and closure populations | `scripts/cranelift_feature_registry.json`, its schema, `scripts/cranelift_registry.py`, and generated compiler documents | Reuse registry-derived inventories where they apply. Do not create a competing capability registry. |
| Accepted-program semantics | MIR-to-C, under `AGENTS.md` and the active roadmap | Independent review cannot waive the oracle or authorize a divergence. |
| Native no-fallback policy | `AGENTS.md` and active Cranelift authority | `fallback_used` is always explicit and cannot count as parity. |
| Bootstrap seed and fixed point | `AGENTS.md`, `README.md`, and `make bootstrap` | Seed changes retain their isolated-PR rule; stage identity is evidence, not a reviewer judgement. |
| Operational lane handoff | the last terminal record in `/home/gust/code/GUST_LANE_STATE.md` | Useful for resumption only. It is neither semantic authority nor qualification evidence. |

The proposal introduces no manager, permanent reviewer lane, or new semantic
writer. The author, reviewer, adjudicator, and publisher below are roles in an
assurance transaction; they are not new ownership domains. The Cranelift lane
remains the single compiler-semantic writer.

## 3. Current-state basis

This revision was checked against main
`9288b0310bbf8e52d68c87b9975e4c56fc3697a5` after Patch 21.16b merged.

- Phase 21.17 and Phase 21.18 remain the active Cranelift work. They are not the
  pilot for this proposal.
- The repository currently has 108 workflow files, 105 with a
  `pull_request` trigger. Those counts are observations, not contracts, and
  must be remeasured before reuse.
- The active `Protect main` ruleset currently requires only
  `Codex / Trusted actor`, produced by a push to `codex/**`. PR Fast, Heavy
  Guards, and the many focused PR workflows are authoritative under project
  policy but are not individually required by the ruleset.
- Review-thread resolution is required and the required approving-review count
  is zero.
- The latest scheduled `Cranelift Historical Full` visible during this review
  was run `33081780794`, completed `failure` on
  `d4bd0e96bd0d2494c35832459560d6974c477161`. Phase 21 already requires a new
  successful Historical Full on its exact merged closure head. No assurance
  enforcement may be enabled from a red Level 3 baseline.

These facts matter because the original concept would otherwise overstate the
repository's present enforcement, use a stale workflow count, and blur
candidate-head PR evidence with post-merge Level 3 evidence.

## 4. Why this product is needed

Gust is well defended against errors its roadmaps and guards already understand.
It is less defended against **correlated error**: one autonomous author can
define the semantic intent, implement it, write its fixtures, update the
registry, update its closure guard, and conclude that the resulting evidence is
sufficient.

That creates failure modes even when CI is extensive:

- roadmap, implementation, registry, and tests encode the same mistaken premise;
- a source-structure guard proves that text exists without proving behaviour;
- an unsupported, skipped, empty, or fallback path disappears from an aggregate
  and therefore looks successful;
- a workflow exists but is stale, red, cancelled, or unrelated to the candidate;
- a PR wave is counted without filtering to its full 40-character head SHA and
  `event == "pull_request"`;
- a phase decision is scattered across VISION, TASK, coordination records,
  review prose, and agent history without a single usable provenance view;
- future maintainers cannot distinguish an operator decision from an agent
  assumption; or
- a candidate-controlled workflow or policy projection is able to validate
  itself.

The product must answer:

> For this exact Gust change, is the intended semantic behaviour already
> authorized, independently challenged, mechanically qualified by the expected
> current evidence, and protected by counterexamples that detect plausible
> mistakes?

## 5. Goals

### 5.1 Assurance goals

- Make intended semantics and their authority unambiguous.
- Detect mistakes shared by a roadmap, implementation, and test.
- Require independent challenge for high-risk semantic changes.
- Bind every conclusion to the exact source, policy, registry, fixture, runner,
  toolchain, and environment identities relevant to it.
- Prevent skipped, unsupported, stale, empty, malformed, or lossy evidence from
  appearing green.
- Turn meaningful failures into minimized, durable Gust witnesses.
- Prove that a small set of plausible high-risk mutations is caught by named
  tests.
- Make current Level 3 health a real phase-closure input, as `AGENTS.md` already
  requires.

### 5.2 Maintainability goals

- Start with one versioned assurance envelope and one report-only evaluator.
- Reuse current registries, `just`/Make commands, workflow runs, and generated
  evidence rather than reproducing them.
- Add no new long-lived lane and no management authority.
- Keep authority records human-readable; keep bulky run output in CI artifacts.
- Preserve autonomous patch execution when an activated roadmap already decides
  the work.
- Delete superseded projections only after reachability evidence proves they
  are unused.

## 6. Non-goals

- Replacing `TASK.md`, `TASK_STDLIB.md`, VISION, the shared semantic zone, the
  Cranelift registry, or Level 1–3 suites.
- Injecting this work into Phase 21.17 or 21.18.
- Opening, closing, or deciding an OD.
- Changing repository rules, secrets, permissions, or required checks through
  this document.
- Requiring model review for spelling, formatting, generated snapshots, or
  ordinary low-risk documentation.
- Re-running Historical Full on every commit.
- Treating MIR-to-C as infallible or allowing a reviewer to replace it.
- Formal verification or a claim of compiler correctness.
- Publishing private agent transcripts or requiring them to reproduce CI.
- Automatically turning reconstructed historical conversation into authority.
- Brute-force mutation of generated `gust_v4.c` or every generated artifact.
- Optimizing for numbers of findings, mutations, guards, workflows, or evidence
  files.

## 7. Product principles

### 7.1 Every semantic decision names its authority

A behaviour-changing decision is recorded as one of:

- explicitly decided by the operator and linked to VISION §0.15;
- delegated by the operator within stated bounds;
- inherited from a named canonical contract;
- temporarily assumed with an owner and resolution gate;
- open and blocking; or
- parked outside the patch.

An agent-authored sentence, green test, or confident review is not operator
authorization.

Authority references, assumptions, findings, and adjudications are append-only
within an envelope revision history. A correction supersedes an earlier entry;
it does not rewrite who said or decided what. Git history alone is not the
human-readable provenance view.

### 7.2 Independent review challenges the premise

The reviewer receives a SHA-bound package and attempts to falsify the intended
behaviour. It does not inherit the author's hidden reasoning and does not merely
search for implementation mistakes.

### 7.3 Deterministic evidence remains primary

Model review is bounded advisory evidence. It cannot waive a failing invariant,
differential, fixed point, required current run, or shared-zone stop. Conversely,
green tests cannot resolve an open semantic decision.

### 7.4 Unknown and skipped are outcomes

Every expected item is accounted for as passed, failed, unsupported,
skipped-with-reason, not-applicable, not-executed, empty-selection,
fallback-used, malformed, stale, or unresolved. Absence is never silently
interpreted as success.

### 7.5 Counterexamples outrank prose

When a disagreement can be represented as a minimized Gust program and an
observable contract, that witness becomes durable evidence. Logs and review
prose may explain it but do not replace it.

### 7.6 Candidate evidence and closure evidence are different populations

A pull request is qualified by exact 40-character PR-head runs whose event is
`pull_request`. Historical Full normally runs on `main`; before merge it can
only establish the health of an eligible main baseline, not prove the candidate.
Phase closure requires a new successful Historical Full on the exact merged
closure head, as the active roadmap already states.

### 7.7 Complexity must pay rent

No new workflow, registry, check type, reviewer pass, or evidence projection is
added without a gap the common envelope cannot express. Assurance code is part
of the maintenance burden and must itself be testable and removable.

## 8. Initial trigger boundary

The pilot applies to an activated change that modifies one or more of:

- canonical MIR or MIR validation;
- type identity, compatibility, brands, inference, or compiler-owned derivation;
- resource, move, destructor, arena, provenance, or linearity semantics;
- ABI, layout, symbols, relocations, calling convention, target, object, linker,
  or runtime-boundary semantics;
- runtime behaviour shared with compiler assumptions;
- observable MIR-to-C/Cranelift equivalence;
- bootstrap seed behaviour or a fixed-point/reproducibility claim;
- a shared semantic-zone contract;
- capability/parity declarations for supported compiler behaviour;
- a fixture expectation that newly accepts or rejects source; or
- a closure rule, selector, registry, workflow, or evidence aggregator capable
  of changing whether semantic work appears qualified.

Ordinary prose, formatting, generated refreshes under unchanged authority, and
isolated Stdlib ergonomics remain outside the trigger. Authority documents and
qualification wiring are not ordinary prose: changing them may trigger even
when compiler source is untouched.

The evaluator may propose a risk class from changed surfaces. The declared
class cannot downgrade a mechanically detected R0/R1 surface without a recorded
non-author adjudication.

## 9. Risk classes

| Class | Typical change | Proposed assurance |
| --- | --- | --- |
| R0 — Critical | Unsoundness, corruption, resource safety, ABI breakage, bootstrap trust, or evidence bypass | Existing operator authority, all applicable deterministic evidence, independent review, non-author adjudication, and rollback plan |
| R1 — Semantic | Acceptance/rejection, MIR meaning, layout, backend parity, runtime contract, or target behaviour | Authority provenance, applicable Level 1–2 evidence, clean-context review, and current baseline accounting |
| R2 — Behavioural support | Diagnostic contract, capability status, constrained support, or non-semantic runtime behaviour | Envelope plus focused evidence; targeted review only when the trigger warrants it |
| R3 — Mechanical | Refactor under an invariant, generated projection, ordinary docs, or formatting | Existing CI; evaluator records `not_triggered` or R3 without a semantic review |

## 10. Assurance flow

```text
operator activation + existing roadmap patch
                    │
            assurance envelope
 authority refs · assumptions · risk · scope · expected inventory
                    │
       implementation + existing Gust tests
                    │
        exact-PR-head evidence inventory
 contracts · differentials · fixed points · budgets · artifacts
                    │
         clean-context adversarial review
                    │
       sticky findings + non-author adjudication
                    │
        report-only evaluator during pilot
                    │
       operator continuation/enforcement decision
                    │
      optional protected publisher after authorization
                    │
                 merge/close
                    │
  later regression or counterexample ──► minimized fixture + mutation
```

The active roadmap remains the work queue. The envelope is an assurance input
for one patch or PR, not a replacement roadmap.

## 11. Roles and separation of authority

- **Operator:** activates roadmaps and retains material semantic, scope, and
  repository-configuration authority.
- **Change author:** implements the patch, declares effects, and supplies the
  candidate evidence. The author may be an agent.
- **Independent reviewer:** examines a clean SHA-bound package without the
  author's private reasoning. This should be an ephemeral invocation, not a new
  persistent lane.
- **Adjudicator:** resolves material findings. For R0/R1 findings it cannot be
  solely the author; OD-sized outcomes remain the operator's.
- **Evaluator:** deterministically checks schema, identity, inventory, loss
  states, and finding continuity. In the pilot it is report-only.
- **Trusted publisher:** a possible later protected mechanism that can issue a
  required status without executing untrusted candidate code with privileged
  credentials.
- **Level 3 owner:** the existing Cranelift owner responsible for Historical Full
  health and phase-closure evidence.

One person may perform several roles. The distinctions are evidence boundaries,
not a proposal for six people or six agents.

## 12. The versioned assurance envelope

One envelope owns the identity model. Operational storage may split large
artifacts, but manifests, findings, adjudications, loss states, and attestations
must not evolve into incompatible per-phase schemas.

### 12.1 Identity

The envelope records:

- envelope schema and evaluator versions;
- repository, roadmap, patch, branch, PR, and full candidate SHA;
- base SHA and merge-base SHA;
- dirty-worktree state for local evidence;
- relevant workflow, registry, fixture, toolchain, target, runtime, linker, and
  environment identities;
- every external artifact's cryptographic digest; and
- whether each conclusion applies to local advisory work, PR head, a main
  baseline, or exact merged closure head.

### 12.2 Semantic intent and authority references

The envelope contains a concise human rendering of:

- intended user-visible and compiler-visible behaviour;
- explicit non-goals and patch boundary;
- affected semantic authorities and compatibility contracts;
- expected changes to acceptance, rejection, diagnostics, output, layout, ABI,
  runtime effects, artifacts, or fallback state;
- operator decisions by VISION §0.15 reference;
- delegated or inherited authority and its bounds;
- assumptions with owner and resolution gate;
- open and parked questions;
- affected backends, targets, fixtures, registries, bootstrap stages, and test
  levels; and
- required documentation, diagnostic, example, and capability projections, or
  an explicit reason none changes.

The envelope does not copy OD status. If its reference disagrees with VISION
§0.15, VISION wins and the envelope is stale.

### 12.3 Four-lens review before closure

R0/R1 envelopes answer four Gust-specific lenses:

1. **Semantic integrity:** What rule changes, what remains invariant, and what
   newly compiles or fails?
2. **Compatibility and users:** What happens to existing Gust programs,
   diagnostics, generated C, native artifacts, targets, and Stdlib consumers?
3. **Operations and release:** What changes in bootstrap, fallback, budgets,
   reproducibility, rollback, and current Historical Full health?
4. **Evidence and falsification:** Which counterexamples, differentials,
   mutations, and independent challenges could prove the rule wrong?

An unanswered question is explicitly `open`, `assumed`, or `parked`. A question
affecting intent, safety, authority, or irreversibility blocks qualification.

### 12.4 Expected and observed evidence inventory

The evaluator composes existing proof surfaces rather than rerunning or copying
them. The normalized view includes:

- exact commands, workflow run IDs, job identities, events, head SHAs, statuses,
  and conclusions;
- expected versus observed guard, fixture, differential, mutation, target,
  shard, artifact, and review inventories;
- Level 1 contract results;
- Level 2 focused parity and differential results;
- applicable bootstrap and native reproducibility results;
- current Level 3 baseline identity and health;
- post-merge exact-head Level 3 identity where phase closure requires it;
- unsupported, skipped, not-applicable, not-executed, empty, fallback,
  malformed, stale, and unresolved counts;
- registry and workflow reachability conclusions;
- stable artifact references and minimal failure excerpts; and
- digests for every consumed artifact.

Presence of a workflow, fixture, row, or old run does not prove success. A
mismatched SHA, wrong event, cancelled required run, missing expected shard,
empty population, or red required conclusion fails qualification.

### 12.5 Existing Gust evidence mapping

The pilot should map rather than rename current proof surfaces:

| Envelope concept | Current Gust source |
| --- | --- |
| Level 1 contracts and wiring | PR Fast Level 1 jobs and focused registry/closure guards |
| Level 2 behaviour | focused source, MIR, differential, composition, and parity workflows |
| Heavy or expensive candidate checks | Heavy Guards and patch-specific workflows |
| Capability and expected populations | Cranelift JSON registry, schema, Python evaluator, and generated compiler documents |
| Bootstrap fixed point | `make bootstrap` and seed-specific authority |
| Native Phase 21 fixed point | Patch 21.16's pinned binary-identity evidence |
| Level 3 history | `Cranelift Historical Full` on `main` |
| Design-versus-implementation evidence | `docs/ONE_WAY_LEDGER.md` reproductions |
| Semantic authority | VISION §0.15, active TASK patch, and shared-zone authority |

No new `Level 4` name is needed.

## 13. Independent adversarial review

R0/R1 changes receive a bounded clean-context review after deterministic
preflight is green enough to make the package meaningful.

The reviewer receives:

- candidate diff, full SHA, and base identity;
- the envelope's intent, authority references, risks, and non-goals;
- affected source and generated projections;
- normalized deterministic evidence;
- relevant minimized counterexamples and expected differences; and
- a versioned review prompt and output schema.

The reviewer does not receive the author's private chain of thought and is not
asked to rewrite the roadmap. It tries to find:

- contradictions between authority, intent, and implementation;
- tests that restate source structure instead of behaviour;
- missing boundary, composition, negative, or cross-backend cases;
- unjustified compatibility, fallback, or support claims;
- silent loss, skip, empty-selection, or inventory mismatch;
- bootstrap trust or candidate-identity gaps;
- evidence that is stale, candidate-controlled, unreachable, or from the wrong
  event; and
- hidden scope expansion.

Review is capped at two rounds unless the operator extends it. Round two checks
fixes and unresolved findings; it does not restart an unbounded search.

## 14. Finding ledger and adjudication

Each finding has a stable ID, severity, category, evidence location, affected
authority, falsifier, author response, reviewer response, adjudicator, and
status.

| Severity | Meaning |
| --- | --- |
| F0 | Unsoundness, corruption, trust-boundary failure, or evidence forgery/bypass |
| F1 | Material semantic defect, missing required proof, or incompatible behaviour |
| F2 | Bounded correctness or maintainability risk requiring an owner |
| F3 | Advisory improvement or clarity issue |

F0/F1 findings are sticky. They remain blocking until the same stable finding
is explicitly resolved or independently adjudicated. A later reviewer cannot
make one disappear by omitting it. F2/F3 findings may be accepted, rejected, or
deferred with an owner and rationale.

An adjudication that would change an OD's status is not local adjudication; it
returns to the operator and VISION §0.15.

## 15. Curated semantic mutation registry

The pilot maintains a small set of plausible mutations for critical semantic
and evidence paths. Candidate families include:

- invert type compatibility, move validity, provenance, or terminal validation;
- broaden acceptance by deleting a negative check;
- turn unsupported native behaviour into silent fallback;
- omit destructor, brand, resource, layout, ABI, or native-boundary validation;
- suppress a MIR-to-C/Cranelift difference;
- accept an empty fixture, shard, or target selection;
- accept a mismatched-SHA, wrong-event, stale, or cancelled run;
- omit a generated/self-hosted compiler stage;
- satisfy a structural source-string check while executable behaviour fails; or
- remove a required registry row from the executed inventory.

Every mutation names the invariant, fixture, differential, or evaluator rule
expected to kill it. Release authority comes from killing every applicable
critical mutation, not from an aggregate percentage.

The initial pilot target is **five** curated mutations: at least three semantic
mutations and two evidence-integrity mutations derived from actual Gust failure
classes. Expand only after those produce signal. Mutation execution uses an
isolated worktree or CI job and must respect shared `/tmp` guard-family
serialization. It never edits the checked-in bootstrap seed by hand.

## 16. Counterexample corpus

Material regressions, backend disagreements, bootstrap divergences, and useful
surviving mutations should produce a minimized durable witness when the failure
can be represented deterministically.

Each case records:

- stable identity and provenance class;
- original failure or discovery reference;
- smallest source and environment that reproduces it;
- expected semantic and observable behaviour;
- affected compiler stages, backends, targets, and registries;
- the defect or ambiguity protected against;
- authority/adjudication state; and
- supersession or retirement reason.

Large logs remain CI artifacts. The committed case is the smallest useful
witness. Automated reduction is desirable after a manual workflow proves its
value, but is not required for the pilot.

## 17. Loss and fallback taxonomy

One vocabulary applies across deterministic evidence and review:

- `passed`;
- `failed`;
- `unsupported`;
- `skipped_with_reason`;
- `not_applicable`;
- `not_executed`;
- `empty_selection`;
- `fallback_used`;
- `malformed_evidence`;
- `stale_evidence`; and
- `unresolved`.

Every aggregate reports its expected inventory, observed inventory, and every
non-passing state. Only `passed` satisfies an item already classified as
required. `not_applicable` is valid only when the authoritative expected
inventory classifies the item as conditional before execution; it cannot be
applied afterwards to waive a failure. Unsupported or fallback behaviour may be
an honest product state, but it cannot masquerade as parity.

## 18. Historical decision recovery

For legacy work whose rationale is fragmented, a local tool may search Gust's
documents, commits, PRs, CI history, and available agent records for candidate
decisions and counterexamples.

Recovered material is evidence to review, not authority. The tool may propose:

- operator instructions and durable references;
- agent assumptions never ratified;
- contradictory roadmap statements;
- historical failure witnesses;
- scope changes; or
- review conclusions missing from canonical documents.

An authorized owner must promote useful material into VISION, the active
roadmap, the shared zone, the envelope, or the counterexample corpus as
appropriate. CI remains reproducible without private transcripts.

## 19. Evaluation and possible trusted publication

### 19.1 Pilot: report-only evaluator

The first release adds no required status. A deterministic evaluator validates
the envelope, exact identities, expected/observed inventories, loss states, and
sticky findings, then produces a concise report. Existing repository policy
continues to decide mergeability.

The report-only stage must itself fail loudly on malformed input, but its GitHub
conclusion is not represented as a required semantic-assurance gate during the
pilot.

### 19.2 Later enforcement requires separate operator authorization

Only after the pilot demonstrates signal may the operator authorize:

- a protected publisher architecture;
- a `Gust / Semantic Assurance` repository status;
- changes to workflow triggers or repository rules; and
- an audited emergency bypass.

That authorization cannot be inferred from this PRD.

A future publisher must run from base-controlled policy or an equivalently
protected external actor. It must not execute untrusted PR code while holding
signing or repository-write credentials. A safe design will likely separate:

1. unprivileged candidate execution that produces SHA-bound artifacts; and
2. protected evaluation that reads base-controlled schema/policy, verifies
   GitHub run identities and artifact digests, enforces finding continuity, and
   publishes the status without executing the candidate.

Using `pull_request_target` to execute or source candidate code is forbidden.
Candidate changes to reviewer prompts, schemas, evaluator policy, or workflow
selection cannot use their changed version to approve themselves.

This also applies to ordinary workflow success. A candidate can edit a
`pull_request` workflow to replace a real guard with `true`, so a protected
publisher cannot treat the green conclusion alone as truth. If a candidate
touches workflow definitions, expected-inventory policy, registry evaluation,
the assurance schema, or the evaluator itself, its qualification must use the
unchanged base-controlled versions or a separately authorized configuration
change. Candidate-produced artifact digests establish which bytes were
evaluated; they do not establish that the bytes contain an honest result.

For non-triggered R3 changes, a future protected evaluator may return a signed
`not_triggered` result containing the candidate SHA, changed-surface inventory,
and trigger-policy version. Branch names, labels, workflow edits, or a missing
manifest must never allow a semantic candidate to avoid classification.

## 20. Proposed qualification policy

During the report-only pilot, existing `AGENTS.md` and roadmap rules remain the
only merge and closure policy.

If enforcement is later authorized, an R0/R1 change should qualify only when:

1. its envelope is complete for the declared risk;
2. every decision reference resolves to current authority;
3. no blocking question or expired assumption remains;
4. every required PR result belongs to the exact candidate head and
   `pull_request` event;
5. expected and observed inventories agree;
6. applicable critical mutations are killed;
7. applicable deterministic conclusions are successful;
8. independent review is complete;
9. every F0/F1 finding is resolved or independently adjudicated; and
10. expected semantic differences are explicitly authorized.

Phase closure remains distinct: it additionally requires the latest applicable
Historical Full to succeed on the exact merged closure head and be cited by run
ID, head SHA, event, status, and conclusion. An immutable older closure artifact
cannot override current red evidence.

## 21. Minimum viable pilot

The pilot should occur **after Phase 21 closes**, on one future R1 patch that
crosses at least two existing proof surfaces—for example typechecker behaviour
plus backend parity or a runtime consequence. A documentation-only or
fixture-only change is not representative.

The pilot is complete when:

1. one real activated R1 patch is represented without duplicating its roadmap;
2. authority references distinguish operator decisions, delegated decisions,
   inherited contracts, assumptions, open questions, and parked scope;
3. the four-lens review changes or confirms the boundary before closure;
4. the evaluator consumes existing Level 1–3 metadata without duplicating the
   suites;
5. an intentionally empty, skipped, wrong-event, or mismatched-SHA population is
   detected;
6. five curated mutations cover both semantics and evidence integrity, and all
   applicable critical mutations are killed;
7. one historical or deliberately seeded defect becomes a minimized witness;
8. a clean-context reviewer produces a schema-valid SHA-bound report;
9. a simulated F1 remains blocking when a later review omits it;
10. non-author adjudication resolves or rejects that finding durably;
11. the evaluator rejects stale, malformed, incomplete, and forged evidence;
12. the relevant current Historical Full baseline is green before any
    enforcement experiment;
13. the operator can understand the result without reading raw CI logs or agent
    transcripts; and
14. no roadmap, registry, workflow, or repository rule has silently become a
    second authority.

## 22. Delivery plan

### Phase A — Authority and trigger inventory

- Select the future pilot patch after Phase 21 closure.
- Map the patch to current TASK, VISION, shared-zone, registry, fixture, and
  workflow authorities.
- Define one envelope schema and human rendering.
- Record the current Level 3 baseline and workflow/ruleset facts.

**Exit:** A cold reader can classify the pilot and name its expected evidence
without reading every workflow manually.

### Phase B — Deterministic report-only evaluator

- Parse the envelope and base-controlled trigger rules.
- Query exact full-SHA PR runs and filter to `event == "pull_request"`.
- Compare expected and observed inventories.
- Classify all loss states and fail an empty selection.
- Run in report-only mode on the pilot and one closed historical patch.

**Exit:** The evaluator distinguishes a qualified population from stale,
missing, cancelled, wrong-event, red, empty, or merely present evidence.

### Phase C — Independent review and finding continuity

- Add bounded clean-context review and the stable finding ledger.
- Add non-author adjudication and sticky F0/F1 behaviour.
- Test omitted-finding, mismatched-SHA, malformed, and candidate-policy-change
  cases.

**Exit:** A material finding cannot disappear between review rounds and model
output cannot waive deterministic failure.

### Phase D — Counterexamples and mutation defense

- Seed five historical, plausible mutations.
- Promote one material failure into a minimized fixture.
- Link every mutation to its killing evidence.
- Exercise historical recovery on one fragmented semantic change.

**Exit:** The system detects correlated defects in both semantics and evidence
selection, not only ordinary test failures.

### Phase E — Continuation decision

- Measure signal, false positives, latency, and maintenance cost.
- Decide whether to continue, simplify, or retire clean-context model review.
- Keep exact identity, inventory, and loss accounting if they prove useful
  independently.
- Only then design and separately authorize protected publication or repository
  enforcement.

**Exit:** The operator explicitly chooses the next state; the proposal does not
promote itself.

## 23. Success measures

Required integrity measures for a continued pilot:

- 100% of R0/R1 semantic decisions name current authority and source;
- zero qualified changes with an open blocking question or expired assumption;
- 100% of candidate conclusions use exact full-SHA, correct-event evidence;
- 100% of applicable critical mutations are killed;
- zero F0/F1 findings disappear without resolution or adjudication;
- zero unclassified required loss states;
- zero phase-closure claims with red exact-head or required Level 3 evidence;
- zero candidate-controlled paths capable of issuing the final protected
  success; and
- zero silent changes to lane, OD, merge, or repository-rule authority.

The pilot should baseline rather than preselect targets for review precision,
duplicate findings, added lead time, mutation cost, time to minimized witness,
Level 3 flake/staleness, and maintenance burden. Metrics cannot improve by
downgrading risk, deleting counterexamples, widening `not_applicable`, weakening
mutations, or suppressing findings.

After the pilot and again after five triggered changes, the operator reviews
what this layer uniquely found and whether that signal pays for its cost.

## 24. Security and operational requirements

- Trusted publication must never execute untrusted PR code with privileged
  credentials.
- Every report binds candidate SHA, base SHA, reviewer identity, evaluator
  version, evidence digests, and adjudications.
- Private transcripts remain optional local recovery inputs and never CI
  dependencies.
- Reviewer prompts and schemas are versioned; a candidate cannot self-approve
  with its modified version.
- Missing artifacts, schema drift, empty reports, skipped required work,
  publisher failure, and wrong-event runs fail closed once enforcement exists.
- A future status names its underlying required suites and exact conclusions.
- Historical Full retains an owner and phase-closure response obligation.
- A future emergency bypass is explicit, audited, operator-owned, and creates a
  mandatory follow-up qualification; it cannot erase that obligation.
- Generated reports live in CI artifact storage unless intentionally selected
  as compact source-controlled baselines.

## 25. Control-plane constraints

To avoid worsening Gust's existing workflow and registry sprawl:

- begin with one schema and one report-only evaluator;
- add no workflow per risk class, mutation, phase, or semantic surface;
- do not depend on branch names, labels, or candidate-owned filters to classify
  a semantic change;
- consume existing guards as inputs instead of copying their logic;
- prefer registry-derived expected inventories over hard-coded counts;
- keep structural source checks as wiring evidence, never primary semantic
  evidence;
- keep bulky generated reports outside the repository;
- cap independent review at two rounds by default;
- make R3 classification cheap;
- add no permanent reviewer, manager, or assurance lane; and
- consolidate duplicated YAML or policy only when touched and only after
  reachability proves the replacement complete.

The proposal does not set an arbitrary total-workflow target. The observed 108
workflow files are a reason to consolidate carefully, not authority to perform
a big-bang rewrite.

## 26. Key risks and mitigations

| Risk | Consequence | Mitigation |
| --- | --- | --- |
| Envelope duplicates the roadmap | Conflicting work queues | Reference one activated patch; store only assurance-specific provenance and evidence identity. |
| Envelope duplicates VISION decisions | OD status drifts | Store references only; VISION §0.15 always wins. |
| Model review becomes noisy | Findings are ignored | R0/R1 trigger, deterministic preflight, two-round cap, stable deduplication, and measured precision. |
| Same author context is called independent | Correlated premise survives | Clean context, distinct reviewer identity, falsification prompt, and non-author adjudication. |
| Candidate changes its own approval policy | Candidate approves itself | Base-controlled evaluator/prompt/schema and protected publication only after explicit authorization. |
| Mutation testing becomes vanity work | Cost without risk reduction | Five plausible historical mutations first; named killing evidence; no percentage gate. |
| Historical corpus preserves a bug | Defect becomes expected behaviour | Authority/adjudication accompanies every expected outcome; the incumbent is evidence, not truth. |
| Loss taxonomy becomes waiver language | Required work is relabelled away | Strict satisfaction rules, owner/rationale, inventory comparison, and risk-aware adjudication. |
| Red Historical Full blocks indefinitely | Delivery stalls or bypass normalizes | Existing named owner, diagnosis, exact closure rerun, and no enforcement until baseline is green. |
| Recovery overclaims certainty | Agent prose becomes authority | Recovered material is a candidate requiring explicit promotion. |
| Assurance increases sprawl | More files obscure truth | One envelope/evaluator, report-only pilot, no new lane, and continuation review before enforcement. |

## 27. Implementation questions, not decisions

These must be answered before a pilot implementation. None changes OD status
or authorizes repository configuration:

1. Which post-Phase-21 R1 patch is representative without being excessively
   large?
2. Which current registry projection should supply its expected inventory, and
   which assurance-only fields should stay outside the capability registry?
3. Where should compact envelopes and minimized counterexamples live?
4. What clean-context reviewer configuration provides useful separation from
   the author?
5. Which findings require the operator personally and which may use a delegated
   semantic owner?
6. Which exact-SHA results can be referenced safely without rerun?
7. Which five historical mutation families best represent Gust's real defects?
8. What base-controlled mechanism could eventually publish a protected result
   without executing candidate code?
9. If later authorized, what is the audited emergency path and follow-up
   deadline?
10. Which duplicated policy projection is safest to consolidate only after the
    evaluator proves equivalent reachability?

An answer that would open or close an OD is recorded through VISION §0.15. An
answer that would change repository rules requires separate explicit operator
authorization. Everything else is ordinary activated implementation work.

## 28. Final product test

The product succeeds when a future maintainer can inspect one semantic Gust
change and answer, from reproducible evidence:

- Who authorized the intended behaviour, and what was merely assumed?
- Which programs, backends, targets, runtime contracts, and bootstrap stages are
  affected?
- What newly compiles, fails, falls back, or becomes unsupported?
- Did every expected exact-candidate proof run under the correct event?
- Is the relevant main baseline healthy, and did exact merged-head Level 3 pass
  when closure required it?
- Was anything skipped, stale, empty, malformed, lossy, cancelled, or absent?
- Which plausible semantic and evidence mutations are caught?
- Which minimized counterexamples protect the decision?
- Did a clean-context reviewer challenge the premise?
- What happened to every material finding?
- Could candidate-controlled code forge or bypass the final result?
- Did the assurance layer preserve Gust's existing lane, OD, roadmap, oracle,
  bootstrap, and merge authorities?

If any required answer is unavailable, the assurance report says so. During the
pilot that is a report to the operator; only a later explicitly authorized
enforcement design may turn it into a required merge status.
