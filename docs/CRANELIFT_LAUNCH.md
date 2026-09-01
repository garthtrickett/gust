# Post-Cranelift technical launch and outreach

**Status:** planned after the complete Cranelift/C-retirement tail; not active.

This document defines Gust's coordinated external technical-credibility launch.
It creates no compiler work and authorizes no outreach. The launch begins only
after Phase 27 and every preceding checkpoint in `docs/ROADMAP_TAIL.md` are
closed with authoritative merged-main evidence. Earlier individualized research
and operator-approved contact is governed separately by
`docs/EVIDENCE_LED_OUTREACH.md`.

Intermediate milestones—including whole-program qualification, native
self-hosting qualification, and the default-backend flip—do not trigger this
coordinated public campaign. They may trigger a narrow evidence-led outreach
review and a small number of private, operator-approved technical messages under
the protocol above. Waiting for the complete tail still gives the public event
one clear, durable claim instead of a sequence of nearly-finished announcements.

## 1. Launch gate

Before outreach begins, verify from then-current authority rather than from a
dated handoff:

- every Phase 20–27 status row and intervening assurance checkpoint is closed;
- the final implementation is merged to `main`;
- the exact merged-main `Cranelift Historical Full` run is successful with its
  complete registry-derived job population;
- normal supported build, test, package, and release workflows do not invoke the
  generated-C backend or a host C compiler, except for explicitly documented
  optional foreign-runtime components;
- the native compiler build/run and bootstrap claims have exact artifact hashes
  and a reproducible transcript;
- no selected native route silently falls back to C;
- all material review conversations are resolved; and
- the Rust adapter and runtime boundary is described honestly.

If any item is missing, delay outreach or lower the claim. Do not reinterpret an
unfinished gate as a messaging problem.

## 2. Claim ladder

Use only the highest level whose evidence exists:

| Level | Claim | Minimum evidence |
| --- | --- | --- |
| 1 | A named Gust feature cohort works through Cranelift. | Registry rows, focused differentials, and no-fallback guards. |
| 2 | The complete declared production cohort compiles and behaves through Cranelift. | Whole-program corpus, selected registry closure, differential observables, and exact-main Historical Full. |
| 3 | The self-hosted Gust compiler builds and runs through the native path, and normal supported bootstrap no longer requires generated C or a host C compiler. | Phase 25 closure, reproducible build/run/bootstrap transcript, exact hashes, no C code-generation fallback, and documented optional foreign-runtime exceptions. |
| 4 | Gust is the first project in a precisely defined historical category. | Level 3 plus a narrow written definition and credible external confirmation that no known predecessor qualifies. |

The post-tail launch targets **Level 3**. Never infer Level 3 merely because the
compiler source is written in Gust, and never infer Level 4 from an ordinary web
search.

## 3. Public wording

The exact release text is written from closure evidence. A safe target shape is:

> Gust's self-hosted compiler now builds and runs through its Cranelift native
> backend, and Gust's normal supported bootstrap no longer falls back to
> generated C or requires a host C compiler. The compiler frontend and semantic
> authority are written in Gust; a narrow Rust adapter integrates Cranelift, and
> any retained optional foreign-runtime components are listed in the proof
> package.

The strategic bridge is:

> This is not primarily a speed milestone. The native route lets Gust carry its
> own memory and authority model to machine code instead of inheriting rules from
> C's abstract machine. It is evidence that Gust can build hard end-to-end
> controls—the same discipline intended for effects, tenant provenance,
> dependencies, vendor capabilities, deployment, and the governed application
> stack.

That paragraph presents the backend as technical credibility and foundation. It
does not claim that Cranelift proves the later application controls, agent
fluency, customer demand, adoption, or defensibility gates.

## 4. Wording prohibited without additional evidence

Do not say:

- “the first non-Rust project to use Cranelift”;
- “the first non-Wasm Cranelift compiler”;
- “Gust contains no Rust”;
- “the entire Gust language is supported” when the evidence names a narrower
  cohort;
- “fully self-hosted through Cranelift” unless the exact workflow and bootstrap
  stages in question are reproduced;
- “formally verified” for differential tests and conformance guards;
- “memory safe” without the unsafe, FFI, runtime, and unqualified-feature
  boundaries; or
- “production ready” without separately defined and satisfied production-use
  criteria.

Use “one of the first” only after private upstream review, and attach the exact
category. Use “first” only if knowledgeable Cranelift maintainers confirm that
category and permit any attributed quotation.

## 5. Permanent proof package

The release post points to a linkable package containing:

1. **Identity:** release tag, full 40-character SHA, supported targets, pinned
   environment, and principal artifact hashes.
2. **One-command reproduction:** clean-clone command, prerequisites, expected
   output and exit status, and the honest Rust/foreign-runtime boundary.
3. **No-fallback evidence:** explicit native selection, the guard preventing C
   fallback, and a negative unsupported-feature example that fails clearly.
4. **Semantic evidence:** declared cohort and registry, MIR-to-C/native
   observables, positive and negative behaviour, runtime/resource/ABI coverage,
   and zero unexplained selected-cohort divergences.
5. **Authoritative CI:** exact merged-main Historical Full run ID, event,
   conclusion, head SHA, job count, closure record, and resolved reviews.
6. **Native bootstrap evidence:** transcript showing the compiler built and run
   through the native route, bootstrap-stage explanation, and proof that normal
   supported bootstrap does not invoke generated C or a host C compiler.
7. **Readable explanation:** a small pipeline diagram, why the historical C
   oracle existed, what replaced it, and known limitations.

“Complete declared cohort” must be explained in ordinary language with explicit
inclusions and exclusions. It may not remain an undefined registry phrase in
public material.

## 6. Upstream factual review

Before any historical novelty wording:

1. Send a two-paragraph technical summary and proof link privately to a small
   number of Cranelift/Bytecode Alliance maintainers and compiler experts.
2. Ask whether the Cranelift description is accurate and whether they know a
   predecessor matching the exact proposed category.
3. Invite correction without asking them to endorse Gust's commercial thesis.
4. Record responses, revise the category, and ask permission before quoting or
   naming anyone.

Launch does not depend on endorsement. It does depend on accurate wording.

The primary public upstream route is the Bytecode Alliance Zulip
[`#cranelift` stream](https://bytecodealliance.zulipchat.com/#narrow/stream/217117-cranelift).
Ask there whether a short item at the public
[Cranelift project meeting](https://github.com/bytecodealliance/meetings/tree/main/cranelift)
would be useful; do not place an announcement in an issue tracker. If upstream
considers the integration broadly useful, ask the SIG-Community stream about
the appropriate amplification or article route.
Address the community rather than treating named maintainers as a cold-email
list, and offer minimized upstream defects or generally useful fixtures without
asking for endorsement.

## 7. Outreach sequence

Every recipient is researched, drafted, humanized, approved, recorded, and
followed up under `docs/EVIDENCE_LED_OUTREACH.md`. Nothing in these waves permits
autonomous contact or publication.

### Wave 0 — quiet technical review

Contact a small set of Cranelift maintainers, direct Cranelift integrators, and
trusted language implementers. The objective is factual correction and a proof
package that survives expert scrutiny.

### Wave 1 — technical launch

Publish to Cranelift, Wasmtime, compiler, runtime, systems-language, bootstrap,
and programming-language communities. Lead with the reproducible Level-3 claim,
not Gust's commercial thesis. Seek external reproduction, technical criticism,
qualified contributors, and durable search-visible evidence.

Use one canonical technical article and submit it selectively rather than
copying one announcement everywhere:

| Venue | Fit and condition |
| --- | --- |
| [Bytecode Alliance Zulip `#cranelift`](https://bytecodealliance.zulipchat.com/#narrow/stream/217117-cranelift) | First public upstream route; lead with integration lessons and evidence. |
| [Hacker News / Show HN](https://news.ycombinator.com/showhn.html) | Use only when readers can clone, build, and run an immutable release without an account or email gate. |
| `r/ProgrammingLanguages` | Emphasize language design, self-hosting, canonical MIR, and the oracle migration; recheck live promotion rules first. |
| `r/Compilers` | Emphasize lowering, ABI/layout, object/linking, differential evidence, and bootstrap; recheck live rules first. |
| [Lobsters](https://lobste.rs/about) | Use only through an established participating account and within its current self-promotion norms. |
| Rust communities | Use only when the material contains substantial Rust/Cranelift integration detail, not for a general Gust announcement. |

Start upstream, incorporate corrections, and space later submissions so the
operator can answer technical questions. Never solicit votes or imply Bytecode
Alliance endorsement.

### Wave 2 — strategic listening

Personally contact a short named list—initially five to ten—across model labs,
coding-agent teams, AI application builders, hosting/deployment platforms, and
software-supply-chain security. Connect the backend milestone to the governed
application thesis, then ask which guarantee matters, what adoption would
require, and why they would prefer an incremental existing-stack response.

This wave is discovery, not a pilot announcement. A compiler milestone does not
prove the web stack, tenant/effect system, agent economics, or buyer demand.

### Wave 3 — tailored follow-up

Each message contains one precise claim, one proof link, one sentence explaining
why that recipient should care, and one modest request for a technical reaction
or conversation. Do not send a generic mass message.

## 8. Outcomes and negative evidence

Record more than impressions or social reach:

- upstream factual acknowledgment or corrections;
- independent reproduction of the build;
- qualified reviewers or contributors;
- meetings with people who can influence adoption or distribution;
- invitations to present or publish;
- a concrete design-partner path arising later from the governed-stack evidence;
- and new information that changes roadmap priorities.

Also record falsifiers:

- mature predecessors eliminate the proposed novelty category;
- reproduction depends on undocumented local state;
- the public cohort is not considered substantial;
- no-fallback or runtime-semantic evidence is incomplete;
- technical audiences see no credible bridge to governed applications;
- strategic audiences prefer restricted TypeScript, generated RLS, sandboxing,
  or dependency scanning; or
- outreach produces curiosity but nobody with authority will explore the later
  product evidence.

These findings change claims, evidence priorities, or product sequencing. They
are not presumed to be marketing failures.

## 9. Relationship to strategy

The launch can establish technical and semantic credibility, a relationship
surface, and evidence of difficult execution. It cannot establish production
adoption, OD-9, switching willingness, supplier governance, product-market fit,
or acquisition demand.

After the event, the four gates in `docs/VISION.md` §0.8 remain independent.
Acquisition remains optional upside, not the sole definition of success.

## 10. Source freshness

Venue rules, meeting schedules, participants, and contact routes change. Recheck
the official Cranelift site, Wasmtime/Cranelift contributing guide, Bytecode
Alliance meeting repository, SIG-Community page, and the live rules of every
publication venue immediately before use. Dated research is planning input, not
permission to post.
