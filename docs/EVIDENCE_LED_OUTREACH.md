# Gust Evidence-Led Outreach Protocol

**Purpose:** Instructions for the vision/docs agent to identify, research, and
draft individualized outreach at the earliest credible Gust milestone.

**Adopted:** 2026-08-30.

**Authority boundary:** This protocol authorizes research and drafting only. It
never authorizes sending a message, publishing a claim, or contacting a third
party. The operator rewrites and approves every message and alone decides
whether, when, and how to send it.

**Operating principle:**

> Build the smallest new piece of evidence, identify the people who uniquely
> care about it, draft a specific message, have the operator rewrite it in their
> own voice, send it, and feed the response back into Gust's priorities.

Outreach is a continuous product-development lane. It is not publicity deferred
until Gust is finished, and it is not permission to announce claims before the
evidence exists. The coordinated public Cranelift launch remains separately
gated by Phase 25 and the complete tail in `docs/CRANELIFT_LAUNCH.md`.

## Manager mandate

The vision/docs agent must:

1. Detect when a completed Gust milestone creates a legitimate reason to
   contact a new or existing person.
2. Confirm the milestone's exact evidence and limitations before drafting
   anything.
3. Select recipients because the evidence is specifically relevant to their
   work, not because they are prominent.
4. Research each recipient from current, reliable sources.
5. Draft one concise, individualized message containing one modest request.
6. Present the draft and supporting facts to the operator for rewriting and
   approval.
7. Never send a message, publish a claim, or contact a third party autonomously.
8. Record the interaction and route useful feedback back into product, evidence,
   and outreach planning.

The agent optimizes for durable relationships and high-quality information, not
message volume, impressions, or superficial engagement.

## The governing loop

For every material milestone:

1. **Verify** — determine exactly what has been proved and link the authoritative
   evidence.
2. **Classify** — map the evidence to the audience for whom it changes
   something.
3. **Select** — choose a small number of recipients with a concrete reason to
   care now.
4. **Research** — verify their present role, recent relevant work, and
   appropriate contact context.
5. **Draft** — produce a short message using only supported facts and one
   request.
6. **Humanize** — give the operator the draft, rationale, and fact sheet so they
   can rewrite it in their own words.
7. **Send** — the operator alone decides whether, when, and how to send it.
8. **Record** — update the relationship ledger with what was sent and what
   happened.
9. **Learn** — convert replies, objections, silence, and introductions into
   explicit next actions or falsification evidence.
10. **Follow up** — contact the person again only when the cadence below permits
    or genuinely new evidence makes the message useful.

The trigger is the earliest **credible** moment, not the earliest imaginable
moment. A claim is credible when an independent technical reader can inspect
enough evidence to understand and challenge it.

## Milestone-to-audience routing

### 1. Working Cranelift integration

**Primary audience:** Cranelift and Bytecode Alliance maintainers, compiler
engineers, and code-generation specialists.

**What they may care about:**

- a substantial new Cranelift frontend;
- integration feedback outside the dominant WebAssembly use case;
- unusual AOT, object, linker, ABI, or runtime requirements; and
- errors, missing abstractions, or reusable improvements discovered by Gust.

**Permitted claim:** Only the exact registered cohort demonstrated through
Cranelift.

**Useful request:** Factual correction, technical reaction, precedent
identification, or direction to the right maintainer.

**Do not lead with:** The acquisition thesis, the entire governed-platform
ambition, or an unverified “first.”

### 2. No-fallback differential parity

**Primary audience:** Language implementers, runtime engineers,
compiler-correctness researchers, and memory-model specialists.

**What they may care about:**

- explicit rejection instead of silent fallback;
- MIR-to-C as an independent semantic oracle;
- differential observables and registry-owned coverage;
- resource, move, layout, ABI, and cross-feature semantics; and
- evidence about using Cranelift for a self-hosted language.

**Permitted claim:** The exact selected cohort has zero unexplained divergence
and cannot silently fall back, only after authoritative closure evidence passes.

**Useful request:** Critique of the evidence model, reproduction, review of a
specific semantic boundary, or introduction to a relevant researcher.

### 3. Agent benchmark

**Primary audience:** Model labs, coding-agent teams, evaluation researchers,
and developer-tool teams.

**What they may care about:**

- secure functional completion rather than compilation alone;
- whether locality and restricted surfaces improve agent reliability;
- comparisons with a hardened mainstream stack;
- stable diagnostics and machine-applicable repair; and
- falsifiable evidence that can show Gust losing as well as winning.

**Permitted claim:** Only preregistered results, including negative and
ambiguous findings. Do not generalize from a narrow task suite to all software
development.

**Useful request:** Evaluation critique, an independent rerun, model access for
controlled testing, or a conversation with the responsible evaluation team.

### 4. Governed vertical slice

**Primary audience:** AI app builders, application-security leaders, platform
architects, and security-sensitive product teams.

**What they may care about:**

- tenant scope that cannot be accidentally omitted within the stated boundary;
- business effects visible in code and manifests;
- a closed application surface;
- controlled dependencies and vendor boundaries; and
- publish-time evidence rather than post-deployment scanning alone.

**Permitted claim:** The specific vertical slice and its enforced boundaries. Do
not present one demonstration as a complete production platform.

**Useful request:** Review against their threat model, identification of a
representative workload, or exploration of a bounded design partnership.

### 5. Real provider adapter

**Primary audience:** Vendors, infrastructure providers, hosting platforms, and
integration and ecosystem leaders.

**What they may care about:**

- one Gust-owned capability contract implemented by multiple providers;
- removal of vendor SDK code from the application trust boundary;
- conformance, versioning, revocation, observability, and migration behavior;
- lower certification cost for the second provider than the first; and
- distribution or managed-hosting opportunities.

**Permitted claim:** The adapter's certified capabilities and conformance
results. Do not imply provider endorsement without written permission.

**Useful request:** Technical review, a second implementation, a sandbox
account, a conformance collaboration, or a distribution conversation.

### 6. Production pilot

**Primary audience:** Executives, strategic product leaders, investors,
potential acquirers, and additional lighthouse customers.

**What they may care about:**

- verified business outcomes;
- adoption and migration friction;
- incident reduction and auditability;
- agent-development speed and completion quality;
- platform consumption and enterprise access; and
- why adoption or acquisition may be faster and less risky than rebuilding.

**Permitted claim:** Measured pilot outcomes and explicitly authorized customer
facts. Never expose confidential metrics or imply a commercial relationship
beyond its documented status.

**Useful request:** Executive conversation, second pilot, partnership,
investment discussion, or introduction to the appropriate strategic owner.

## Milestone evidence gate

Before drafting outreach, produce this evidence card:

```markdown
Milestone:
Status: proposed | locally demonstrated | merged | independently reproduced | production proven
Exact claim supported:
Claims not supported:
Authoritative commit or release:
Evidence links:
Validation environment:
Known limitations:
Who would care and why now:
Disclosure level:
```

If the card cannot be completed, the milestone is not ready for external
outreach. The agent may propose the missing evidence but must not strengthen the
claim linguistically.

Compiler milestones must distinguish:

- a working route from a complete declared cohort;
- a complete declared cohort from universal language coverage;
- compiler source being written in Gust from the compiler building and running
  through Cranelift;
- a non-Rust language frontend from a completely Rust-free toolchain;
- differential evidence from formal verification; and
- no fallback in selected routes from support for every route.

## Progressive-disclosure policy

The default public strategy is **technical visibility with commercial
discretion**.

### Public by default

- reproducible technical achievements;
- supported-cohort boundaries;
- compiler and runtime architecture already present in public project
  documentation;
- honest limitations; and
- narrow reasons the work matters technically.

### Selectively private

- detailed governed-web-stack sequencing before the demonstration exists;
- buyer and partner maps;
- acquisition logic and valuation expectations;
- unannounced provider or design-partner discussions;
- competitive response analysis;
- confidential benchmark or pilot results; and
- detailed commercial moat strategy.

Disclose the larger ambition privately only when relevant to the recipient and
approved by the operator. Do not mislead a recipient who asks directly. State
what is built, what is planned, and what remains uncertain.

If information is already plainly visible in the public repository, do not
describe it internally as secret. Treat the strategy as limited-opacity unless
the public documentation changes through its proper ownership process.

## Recipient selection

Select a recipient only when all are true:

1. Their current work or authority intersects the milestone.
2. There is a recipient-specific reason the evidence matters now.
3. A reasonable request appropriate to the relationship is identifiable.
4. The claim has a durable evidence link.
5. Contact would not violate a prior request, confidentiality obligation, or
   reasonable boundary.

Prefer five carefully selected recipients over fifty generic contacts.

Prioritize recipients with direct validating knowledge, adoption or integration
authority, ownership of a relevant model/platform/runtime/provider surface, an
ability to introduce the correct owner, demonstrated interest in the exact
problem, or an existing authentic relationship with the operator. Prominence
alone is not relevance.

## Recipient research protocol

Before drafting, verify from current reliable sources:

- full name and preferred public form of address;
- current employer, team, and role;
- one recent piece of work directly connected to the milestone;
- whether they are actually the appropriate person;
- whether the operator has contacted them before;
- any stated contact preference; and
- claims or quotations that will appear in the draft.

Use primary sources wherever possible: personal sites, project repositories,
talks, papers, official biographies, company pages, and the recipient's own
public posts. Do not rely on model memory for current roles. Do not manufacture
familiarity from a superficial post or claim to have followed someone's work
unless that is true for the operator.

Return research separately from the message so the operator can distinguish
verified facts from suggested language.

## Message construction rules

Every first message contains only:

1. **Relevance:** why this particular person is being contacted.
2. **Evidence:** the precise thing Gust has now proved.
3. **Proof:** one primary link to the best reproducible evidence.
4. **Connection:** why the result may matter to their work.
5. **Request:** one small, easy-to-answer next step.

Default length:

- direct message: 60–120 words;
- cold email: 90–160 words;
- warm email: as short as the existing relationship permits; and
- technical maintainer note: longer only where a precise question requires
  context, with the question front-loaded.

Default tone is direct, technically specific, modest about novelty, confident
about demonstrated facts, candid about limitations, and person-to-person rather
than launch-copy voice.

Each draft has one request, such as factual characterization, precedent,
evaluation criticism, redirection to the correct owner, a short walkthrough, or
whether a workload is representative. Do not combine feedback, introductions, a
pilot, investment, and amplification in one message.

## Anti-synthetic writing rules

Avoid:

- generic praise;
- “game-changing,” “revolutionary,” or “industry-first”;
- invented personal connection;
- summaries of the recipient's biography;
- long explanations of Gust before relevance;
- excessive formatting or multiple links;
- fake urgency;
- asking for an NDA before relevance is established;
- acquisition language in ordinary technical outreach; and
- pretending a first-name insertion makes a draft personal.

Never write:

- “I've been following your work for years” unless the operator confirms it;
- “I know you're passionate about” based only on a job title;
- “This is the first” without historical verification;
- “fully self-hosted through Cranelift” unless directly proved;
- “production ready” based on compilation or a demonstration; or
- “formally verified” based on tests or differential parity.

The operator rewrites the message. The agent supplies strong raw material rather
than simulating the operator's personality.

## Required output for each proposed contact

```markdown
## Recipient

**Name and current role:**
**Why this person:**
**Milestone:**
**Disclosure level:** public technical | selective strategic | confidential relationship
**Verified recipient facts:**
- Fact — source

**Exact Gust claim:**
**Evidence link:**
**Known limitation relevant to them:**
**Recommended request:**

### Draft

Subject, if email:

Message text.

### Operator rewrite notes

- What must remain factually intact
- What should be changed into the operator's natural language
- Any relationship context the agent cannot safely infer

### Ledger action

- Proposed status
- Follow-up date or milestone
- Information to record after sending
```

Give one recommended draft. Add at most one materially different alternative
when channel or tone creates a genuine choice.

## Human rewrite gate

Before sending, the operator should:

1. Remove any phrase they would not naturally say.
2. Confirm every statement about the recipient from the research card.
3. Confirm every Gust claim from the evidence card.
4. Delete unnecessary background.
5. Ensure the request is singular and proportionate.
6. Add authentic relationship context the agent could not infer.
7. Decide whether the strategic disclosure level is appropriate.
8. Send personally or decide not to send.

Past approval of one message is never standing authority to contact another
person.

## Relationship ledger

Maintain one row per recipient relationship, not one disconnected row per
message.

Store the working ledger in an operator-approved private location. Do not commit
personal contact details, confidential replies, disclosure ceilings, or private
commercial information to the public repository. This document defines the
schema, not the storage location.

| Field | Meaning |
| --- | --- |
| Recipient | Name and stable identifier. |
| Organization and role | Verified current context with last-checked date. |
| Why relevant | The durable reason the relationship matters. |
| Relationship owner | Normally the operator. |
| Disclosure ceiling | Highest level currently approved for this person. |
| Milestone/evidence sent | Exact claim, link, and version. |
| Date and channel | When and how contact occurred. |
| Status | proposed, drafted, sent, replied, meeting, dormant, declined, or do-not-contact. |
| Response | Factual summary, not an optimistic interpretation. |
| Objections or questions | Language and concerns worth preserving. |
| Commitments made | Anything the operator promised to send or do. |
| Next useful milestone | New evidence that would justify contact. |
| Follow-up date | A date only when follow-up is actually warranted. |
| Introductions | Offered, requested, made, and outcome. |
| Product learning | What should influence Gust's roadmap or evidence. |
| Confidentiality | Facts that must not be disclosed elsewhere. |

Do not store sensitive personal information unnecessary to the relationship.

## Follow-up policy

- Send one concise follow-up after approximately 7–14 days when the first
  message contained a reasonable request and no response arrived.
- A second follow-up is justified only by genuinely new evidence, a warm
  introduction, an invitation to reconnect, or a relevant time-sensitive event.
- After two unanswered contacts, stop until a material new milestone creates
  independent value for the recipient.
- Never disguise a repeated request as a product update.
- If someone declines or asks not to be contacted, record it and stop.
- If someone provides useful criticism, acknowledge it and later show what
  changed; do not immediately argue them into agreement.

Silence is weak evidence. Repeated silence from a correctly selected audience is
stronger evidence that the message, milestone, or assumed relevance may be
wrong.

## Turning responses into product learning

Classify each substantive response as one or more of:

- claim correction;
- technical defect;
- missing evidence;
- unclear explanation;
- wrong recipient;
- low-priority problem;
- preference for an incremental incumbent solution;
- interest without authority;
- potential champion;
- pilot requirement;
- provider requirement;
- distribution opportunity; or
- commercial or acquisition signal.

For each response, record what was said, the inference being made, confidence in
that inference, the smallest action that tests it, and whether it changes
product priority, evidence priority, recipient selection, or message language.

Do not change the roadmap from one person's opinion without respecting Gust's
ownership and decision process. Do use recurring independent feedback as
evidence for an explicit product or strategy decision.

## Outreach success measures

Track quality and learning rather than raw sends:

- percentage of messages with a verified recipient-specific reason;
- technically substantive response rate;
- factual corrections received;
- external reproductions or reviews;
- introductions to better internal owners;
- conversations with people who possess adoption authority;
- design-partner and pilot paths;
- provider or distribution discussions;
- product decisions improved by outreach;
- promises completed on time; and
- relationships that deepen across successive evidence milestones.

Do not optimize for follower counts, generic praise, or reply rate divorced from
recipient quality.

## Cadence

Run an outreach review whenever:

- a roadmap phase closes with authoritative evidence;
- a reproducible technical artifact becomes public;
- a benchmark completes;
- a governed vertical slice becomes demonstrable;
- a provider passes conformance;
- a pilot begins, reaches a measurable result, or ends;
- a recipient's earlier question has now been answered; or
- a new person or organization becomes directly relevant.

Also run a lightweight weekly review of drafts awaiting operator rewrite,
commitments, unprocessed replies, due follow-ups, and contacts who should remain
untouched until later. Do not manufacture outreach because a review occurred.

Phase closure triggers a **review**, not automatic contact. Phase 20–26 may
justify narrow private technical drafts under this protocol, but they do not
trigger the coordinated public Cranelift campaign. That campaign begins only
after Phase 27 and the complete tail close.

## Compact standing instruction

> **Evidence-led outreach:** Treat outreach as a continuous product-development
> lane. At the earliest credible completion of a Gust milestone, verify the
> exact claim and limitations, map it to the audience that uniquely cares,
> select a small number of relevant recipients, verify each recipient's current
> role and work from primary sources, and draft one concise individualized
> message. Every message contains: why this person, what Gust has proved, one
> primary evidence link, why it matters to their work, and one modest request.
> Return recipient research, an evidence card, the draft, operator rewrite
> notes, and a ledger action. Never send or publish autonomously. The operator
> rewrites every message in their own voice and decides whether to send it. Use
> technical visibility with commercial discretion: disclose reproducible
> achievements publicly, but reveal unbuilt product sequencing, buyer maps,
> acquisition logic, and confidential relationships only selectively and with
> operator approval. Record responses, objections, commitments, and next
> relevant milestones in the relationship ledger, and route substantive
> learning back into product and evidence decisions. Prefer five precise
> contacts to fifty generic messages; never invent familiarity, praise, novelty,
> or unsupported Gust claims.

## Final principle

The goal is not to make Gust appear larger than it is. The goal is to let the
right people observe it becoming real, one defensible milestone at a time.

By six months, success should mean more than revealing a finished project to
strangers. It should mean showing the next stage to a network of technically and
commercially relevant people who have watched the evidence accumulate,
corrected weak assumptions, and already understand why Gust might matter.
