# GitHub issue roadmap

**Status:** repository-wide routing index
**Last audited:** 2026-09-12
**Audited GitHub repository:** `garthtrickett/gust`
**Audited main:** `a341b69a10170f874a85253b219c61f272481413`

This file gives every open GitHub issue an owned place in Gust's Markdown
roadmap. It prevents an issue from being technically well reported but absent
from every work queue.

This is not a third implementation lane and does not activate work. `TASK.md`
and `TASK_STDLIB.md` remain authoritative for active patches. Before anyone
implements a row below, the owning lane must promote it into an explicitly
activated roadmap patch with the normal boundary and exit gate.

## Intake contract

Every new GitHub issue must be added to the open register as part of the filing
task. A complete row names:

- the issue and current disposition;
- the owning lane or decision authority;
- one destination milestone or roadmap section;
- ordering dependencies; and
- the evidence that permits closure.

An issue may be open and deferred, but it may not be open and placeless.
`Unscheduled` is acceptable only when the same row names the milestone that
must schedule it. A partial fix narrows the row rather than removing it.

When an issue closes, move it to the closed ledger with its PR or commit and
current-main evidence. The open table must equal the complete open issue set
returned by GitHub, not a hand-picked priority subset.

## Ordering

```text
Phase 22 closure
  -> assurance and evidence health (#110, #240)
  -> same-scope declaration diagnostic (#105)
  -> Phases 23-25 C deprecation and retirement
  -> compiler-owned CR-15 handoff to Stdlib S1
  -> post-tail language ergonomics (#133, #102)
  -> post-tail safety semantics (#108, #103)
  -> structured runtime (#101, then #91)
```

Independent rows may be reordered by an activated roadmap when their stated
dependencies still hold. The ordering above may not be used to enter CR-15,
change a VISION decision, or widen the active Phase 22 boundary.

## Open issue register

| Issue | Disposition and owner | Roadmap destination | Ordering and closure evidence |
| --- | --- | --- | --- |
| [#133 — Define `str ==` and `!=` as content equality](https://github.com/garthtrickett/gust/issues/133) | **Half delivered; Cranelift owner.** The equality half landed: Cranelift Patch 24.2q (#377, merge `2b8417a7`, 2026-09-10) makes `==`/`!=` on `str` content equality on both retained compiler paths, with positive coverage in `tests/test_str_content_equality.gst` and the repurposed `tests/test_str_equality_*` fixtures, and `TASK_STDLIB.md` CR-1 is resolved. The row narrows to the issue's second clause, *without exposing `std.str_eq`*: the symbol remains public safe surface and the compiler still calls it 3,866 times (`docs/ONE_WAY_LEDGER.md` E5, row 13 `PARTIAL`). | Post-Phase 25 language-ergonomics roadmap unless separately activated earlier; the compiler-source idiom adoption may ride any patch already in the file. | Close when `std.str_eq` is no longer offered as safe surface (or an operator ruling keeps it and says why) and the compiler sources use the operator, with `make gust` and the bootstrap fixed point green. Do not reintroduce a retired C backend merely to preserve the issue's historical parity wording. |
| [#325 — Registry records `std_Mutex_Alloc`/`std_Channel_Alloc` as `returns_explicit_error`; both `exit(1)`](https://github.com/garthtrickett/gust/issues/325) | **Registry-truth defect; Cranelift owner.** Filed 2026-09-04 against `6e5aaa67`: `scripts/cranelift_feature_registry.json` records `failure_form: returns_explicit_error` for two runtime symbols whose source prints to stdout and calls `exit(1)` on pool exhaustion (`src/runtime/fiber.c`), while holding the pool lock. The registry row is wrong today regardless of when the behaviour changes. Same family as #91. | Registry correction: next Cranelift patch already in the registry, or a standalone row-only fix. Behaviour change: `docs/PHASE28_RUNTIME_PRODUCTION_SHAPE.md` Patch 28.4 (inactive). | Independent of every other row. Close the registry half when the two rows describe the measured behaviour, cited to `src/runtime/fiber.c` at the audited main; close the behaviour half only under Phase 28.4 with a contained-failure test on the supported backend. |
| [#102 — Safe enum variant construction / `Option`](https://github.com/garthtrickett/gust/issues/102) | **Deferred generic semantic change; Cranelift owner.** `TASK_STDLIB.md` CR-14 establishes that an `Option`-only helper is forbidden. | Post-Phase 25 language-ergonomics roadmap, after CR-15 handoff; before the OD-9 demo experiment. | Implement generic enum-variant construction for user enums and `Option`, with no representation-field spelling in ordinary source. Close on safe construction, match/destructuring, diagnostics, and bootstrap evidence. |
| [#108 — `os.System` and builtins bypass the unsafe gate](https://github.com/garthtrickett/gust/issues/108) | **Policy decision then implementation; operator decides privileged set, Cranelift owns compiler enforcement.** | Post-Phase 25 safety-semantics/effects roadmap. | First decide whether to gate only process execution or a broader host surface. Preserve wrap-before-enforce bootstrap sequencing. Close only when the selected builtins require the chosen explicit authority and ordinary compiler/bootstrap use remains qualified. |
| [#103 — Numeric model absent and overflow is not trapping](https://github.com/garthtrickett/gust/issues/103) | **Deferred language semantics; Cranelift owner.** The numeric tower and the core overflow rule must not be conflated. | Post-Phase 25 safety-semantics roadmap; split overflow from later numeric/time library surface when promoted. | Close the overflow portion only after the language has a defined, tested overflow contract across the supported backend and bootstrap. Keep wider fixed-width, decimal, money, and time work open or separately roadmapped until delivered. |
| [#101 — Detached concurrency and channel ownership](https://github.com/garthtrickett/gust/issues/101) | **Deferred runtime/compiler semantic change; Cranelift owner.** OD-1 has a direction and OD-11 selected removal of bare application-facing `std.Spawn`; `TASK_STDLIB.md` CR-8 records the handoff. | Post-Phase 25 structured-runtime roadmap, after CR-15 and before #91. | Deliver scoped spawn, linear task handles, join/cancel/transfer obligations, and the checked non-copy channel-send rule. Use a deprecation path; do not delete the shipped primitive opportunistically. |
| [#91 — String bounds failures terminate the process](https://github.com/garthtrickett/gust/issues/91) | **Blocked runtime-contract correction; Cranelift owner.** `TASK_STDLIB.md` CR-3 remains the coordination authority. | Post-Phase 25 structured-runtime roadmap after #101 establishes task/request containment. | Route bounds failure through the compiler-owned panic/containment path and audit sibling string helpers. Close when a failing task/request is contained without terminating unrelated work and both compiler/runtime paths agree. |

## Audit result

All seven GitHub issues open on 2026-09-12 (#325, #133, #108, #103, #102, #101,
#91) are represented above. #325 was filed on 2026-09-04 and had no row until
this audit, which is the intake defect this file exists to prevent; it is
registered now. Issues #110, #240, and #105 qualified for closure on their
audited current-main revisions; the remaining issues did not:

- #133's equality half is delivered by 24.2q; its `std.str_eq` clause is not;
- #102 remains an open CR-14 generic-construction gap;
- `std.Spawn` remains registered and detached for #101;
- `std_str_slice` and `std_str_byte_at` still call `exit(1)` for #91;
- `os.System` remains an ambient builtin while declared extern calls are gated
  for #108;
- #103 remains explicitly documented as unimplemented.

## Closed issue ledger

| Issue | Closure evidence | Roadmap item |
| --- | --- | --- |
| [#110 — Two MIR surface guards fail](https://github.com/garthtrickett/gust/issues/110) | PR #271 exact head `bf53fa38a079a8cb9c019872408603ed9c17a356` passed 115/115 `pull_request` workflows with zero unresolved review threads and merged as `3c437227ae75a7b90a14916bd8d23df6799d5f00`; both `just guard-mir-lower-tiny-function-surface` and the Patch 23.2 contract passed on that exact current main. | Phase 23 Patch 23.2; retained historical input for Semantic Change Assurance Phases A/B. |
| [#240 — Phase 20 resource-acquisition parity guard expects a pre-migration native deferral](https://github.com/garthtrickett/gust/issues/240) | PR #275 exact head `cf97e6e4c99762366fde05002beb475de9cbde6e` passed 116/116 `pull_request` workflows with zero unresolved review threads and merged as `a26103fd40dd8c3762efe05c593d5ad111e7a50a`; `make gust`, the Patch 23.3 contract, and retained `just guard-cranelift-phase20-resource-acquisition-parity` passed on that exact current main. | Phase 23 Patch 23.3; retained historical input for Semantic Change Assurance Phases A/B. |
| [#105 — Same-scope local redeclaration reaches the C compiler](https://github.com/garthtrickett/gust/issues/105) | PR #278 exact head `74b259d2c7573b4929f2ffa331a261085a16e894` passed 120/120 `pull_request` workflows with zero unresolved review threads and merged as `f6814323588eeb5321a7c0e20210aec802be568f`; `make gust`, `make phase10-native-package`, and `just guard-cranelift-phase23-same-scope-declaration-evidence` passed on that exact current main. | Phase 23 Patch 23.6; bootstrap seed reconvergence remains isolated in Patch 23.6a. |
