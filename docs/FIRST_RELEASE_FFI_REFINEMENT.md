# First-release FFI contract refinement record

**Date:** 2026-10-19. **Outcome:** scoped plan; every implementation gate OPEN.

The operator requested a useful first-release contract, repeated refinement,
and a corresponding Phase 26 roadmap update. The documents are
[FIRST_RELEASE_FFI_CONTRACT.md](FIRST_RELEASE_FFI_CONTRACT.md) and the
[canonical roadmap](PHASES_26_AND_27.md#first-release-scope-and-execution).
This record explains the decisions; it is not implementation or test evidence.

## Review loop

The coordinator audited merged main `df653a32` and official library contracts.
The existing Cranelift lane agent independently checked feasibility, challenged
successive drafts, and reviewed the contract against the roadmap, VISION and
lane ownership. No duplicate implementation agent or compiler job was started.

| Pass | Finding | Revision |
| --- | --- | --- |
| Source and library audit | Gust Int is 32-bit; current borrow lowering qualifies flat aggregates, and native linking uses a controlled test-host slot. General library support cannot be inferred from those tests. | Select one GNU/Linux zlib adapter with checked widths and explicit package/byte-span prerequisites. Keep SQLite as a named follow-up with real lifecycle gates. |
| Trust boundary | Transient arenas do not contain native corruption; application-native policy is stronger than unsafe syntax. | Classify the release-supplied adapter/library as VISION §93 platform TCB. Preserve default denial, approval and isolation requirements for application/third-party native code. |
| ABI challenge | A vague status/output API could require additional out-pointer semantics or misuse the existing zero-success status policy. | Publish exact C/Gust signatures. Return a nonnegative signed count or distinct negative error; decode it in the wrapper using ordinary scalar ABI. |
| Scope challenge | Demanding a new test in every origin/route cell would recreate the full generic E/F project as a hidden release dependency. | Require reachable-path witnesses plus all existing owning tests. Keep the original general map OPEN with its original gates; known safe-code soundness holes still block release. |
| Package challenge | Artifact hashes alone do not establish a trusted platform adapter. Broad package rejection could accidentally retire historical cohorts. | Require a trusted signing identity, complete artifact binding, withdrawal/replacement and offline snapshot policy. Keep the historical fixed-host authority separate and unchanged. |
| Storage and ownership challenge | “Generic marshalling” did not identify an allocation/lifetime seam. A safe public wrapper belongs to Stdlib. | Use a separate call-scoped region reusing transient-arena allocation/cleanup. Keep Vector storage away from native code. Require merged compiler support, then a separately owned Stdlib wrapper, then closure. |
| Policy consistency challenge | Copying behind existing direct borrow policies would silently change their meaning; compile-time producers cannot copy runtime data. | Preserve direct address passing. The producer records runtime operands and schedules; generated marshalling code allocates/copies/validates/cleans. Partial allocation failure skips native execution and releases prior temporaries. |
| Final cross-document challenge | A public Result primitive was assumed, zero-capacity success had no pinned observable, and the wrapper could assume the later collection audit. | Use an enum-expressible tagged result owned by Stdlib. Require empty decompression success 0 versus nonempty short-buffer -3 at capacity 0. Require a targeted audit of the wrapper's actual Vector/brand/arena paths within R4. |

## Adoption conditions

The scoped plan requires all six FFI-R gates, including actual library execution
and a safe wrapper. An unsafe-only prototype does not satisfy 26.1. Each gate
has an owner and an observable exit condition. The original broader obligations
remain visible, OPEN and named, with re-entry conditions. Existing checks,
frozen registry projections, query/certificate budgets and memory caps remain
unchanged. Phase 26.2–26.6 retain their own gates, especially final native bridge
promotion and a successful Historical Full on final merged main.

Implementation uncertainty remains explicit: package signing/link admission,
direct byte spans, typed marshalling source operations/runtime hooks, the
cross-lane wrapper and its targeted audit are not implemented by this decision.
A required new MIR meaning or runtime symbol still needs the shared-zone
ownership process before implementation. Dependency installation and repository
configuration changes retain their existing authorization rules.

## Documentation validation

The final read-only cross-document review found no blocking contradiction in
the three-document scope decision. It did not qualify any implementation.
Local checks passed:

- `git diff --cached --check`;
- `python3 scripts/phase21_roadmap.py check-review`;
- `python3 scripts/phase23_mir_to_c_deprecation_opening.py check-review`;
- local link/anchor and scope comparisons: all six phase statuses OPEN, original
  26.1 staging/evidence and 26.2–26.6 sections byte-identical, docs-only diff.

An initial attempt to append the scope pointer to `TASK.md` failed its frozen
activation-manifest check. That append was withdrawn; its existing canonical
roadmap pointer is sufficient. No registry, projection or assertion changed.
The historical text-manifest check then passed under tracked work
`1792451437634` (exit 0).

The owning pull request records authoritative CI results. These documentation
checks do not demonstrate that zlib or the proposed byte marshalling works.
