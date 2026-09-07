# Opportunistic cleanup

**Status:** active register. Owner: Cranelift lane.

Work that is worth doing and is **not** a gate on anything. A row here may be
picked up whenever a patch is already in the neighbourhood, may be deferred
indefinitely, and blocks no launch, no phase closure, and no claim.

This register exists because Phase 27 was retired. Its four consolidation rows
were not equivalent to each other: two were safety and bootstrap properties that
the launch actually rests on, and two were deletions of paths made obsolete by
work that has already landed. Retiring the phase as a unit would have treated
them as one thing. They are adjudicated below one at a time.

## The rule for this document

**Nothing here is a launch obligation.** A row is admitted only after it has
been shown that no claim in `docs/CRANELIFT_LAUNCH.md` becomes false if the row
is never done. If that cannot be shown, the row belongs in the launch gate as a
stated obligation instead, and the burden is on the person moving it here.

## The four Phase 27 rows, adjudicated individually

### 27.3 — delete `open_directories` from `TypeEnvironment` — cleanup

*Directories become `Resource[ctx, Directory]`.*

**Not a launch obligation.** This removes an older second mechanism for a
capability that generalized resources already provide. No clause of the Level-3
claim ladder, the no-fallback guarantee, the bootstrap claim, or the safe stdlib
surface depends on which internal registry the typechecker uses to track open
directories; the observable behaviour of a Gust program is the same either way.

Re-derived rather than inherited: it owns no `docs/ONE_WAY_LEDGER.md` violation.
Row 34 (*Host access*, **VIOLATED**) sounds adjacent but is about ambient `os.*`
authority — `os.System` spawning `/bin/sh` with no import or declaration — and
its remediation column reads `unowned — closes with §0.7 Track A`, not this row.

Carrying two spellings of directory authority is a genuine cost. It is a
maintenance cost, not a correctness or credibility one.

### 27.4 — delete split LHS/RHS subscript codegen branches — cleanup

*Subscripts are read-only copies and mutation uses explicit references; keep
parser LHS validation robust.*

**Not a launch obligation**, and for a stronger reason than 27.3. The safety
property in this area — direct subscript writes require `unsafe` or an explicit
write API — is enforced **today**, by the `[UnsafeSubscriptWrite]` diagnostic
recorded in `docs/ONE_WAY_LEDGER.md` and by parser LHS validation. 27.4
explicitly preserves both. What it deletes is duplicate lowering sitting behind
an enforcement that already holds, so its absence removes no guarantee.

Its “keep parser LHS validation robust” clause is a **constraint on the cleanup,
not an obligation created by it**, and it travels with the row: whoever does this
work must not weaken that validation on the way past.

### 27.5 — audit the stdlib safety surface — **launch obligation**

*Raw-pointer work does not leak through `std.Vector`, `std.HashMap`, or
`std.String`.*

**Preserved, and now stated in `docs/CRANELIFT_LAUNCH.md` §1 as itself.** The
repository forbids adding raw-pointer workarounds inside a safe stdlib surface,
but that rule constrains *new* code; nothing asserts the property for code
already there. The audit is the only thing that does, and the launch advertises
exactly that surface. Left in a retired phase it would have been discharged by
the phase disappearing.

### 27.6 — sum-type consolidation and seed promotion — **split**

*Refactor `Statement` and `Expression` into true sum-type enums, migrate tag
tests to `match`, and promote the consolidated result as the next bootstrap
seed.*

This row was two obligations wearing one number, and they are separated here.

- **The enum refactor and `match` migration are cleanup.** They change the
  compiler's internal representation, not what any Gust program means and not
  what the launch claims. Admitted to this register.
- **The seed promotion is a launch obligation** and is now stated in
  `docs/CRANELIFT_LAUNCH.md` §1. Level 3 claims that *the self-hosted compiler*
  builds and bootstraps through the native path, and that is only checkable if
  the committed `gust_v4.c` is the seed generated from the merged
  `compiler/*.gst` sources rather than a stale ancestor of them.

**The restatement matters as much as the preservation.** Written as *“promote
the consolidated result”*, the seed obligation is hostage to a refactor that is
now explicitly optional — if the enums never happen, there is no “consolidated
result” to promote and the obligation quietly evaporates. Stated as a property
of the seed itself, it holds whether or not the refactor is ever done.

## What the launch gate demanded before and after

Read the middle column as the answer to *“if this is still required, what
requires it?”*

| Demanded before | Required now by | Verdict |
| --- | --- | --- |
| Phases 20–26 status rows closed (via the `20–27` census) | §1 item 1, re-keyed to `20–26` | unchanged |
| The intervening assurance checkpoint closed (via the census) | §1 item 1, same clause | unchanged |
| Phase 27 exit clause (a): 27.3 complete | nothing | **deliberately dropped** — see 27.3 above |
| Phase 27 exit clause (a): 27.4 complete | nothing | **deliberately dropped** — see 27.4 above |
| Phase 27 exit clause (a): 27.5 complete | §1, stated: the stdlib safety surface is audited | unchanged, and now named rather than inherited |
| Phase 27 exit clause (a): 27.6 enum refactor complete | nothing | **deliberately dropped** — see 27.6 above |
| Phase 27 exit clause (a): 27.6 seed promotion | §1, stated: promoted through the seed policy | unchanged, and no longer hostage to the refactor |
| Phase 27 exit clause (b): no ledger violation owned by Phase 27 | §1, stated: no `VIOLATED` row names the tail **or this document** | **raised** — see below |
| Phase 27 exit clause (c): bootstrap converges | Phase 26's own exit gate, still inside the re-keyed enumeration | unchanged |
| Phase 27 exit clause (d) = 27.6 seed promotion | as above | unchanged |
| The other seven §1 items | themselves, verbatim | unchanged |

**Clause (b) came back stronger, and that is a change, not a hold.** It read
*“no remaining ledger violation owned by this phase”*. Scoped to a phase, it
disappears when the phase does — the check would have been discharged by
retirement rather than by evidence. It is restated over the whole C-retirement
tail **and over this document**, because a demoted row is precisely where a
future violation would attach without anyone noticing: the row still exists, it
still has a name, and nothing is gating on it any more.

That is a small rise in the bar. It is recorded as a rise so nobody has to
reconstruct later whether it was one.

**Three rows were deliberately dropped as launch obligations.** That is the
point of the exercise rather than a side effect: a launch gate that carries
obsolete-path deletions cannot be read as a statement about the product, and a
reader cannot tell which of its items are load-bearing. They remain worth doing;
they are recorded here rather than deleted.

---

## Duplicate helper bodies in the self-hosted compiler

**Added 2026-09-06 from an external review, verified independently. Cleanup, not a
launch obligation** — the same rule as everything else in this document.

| What | Count | Evidence |
| --- | --- | --- |
| `*_field_is_safe` | 13 definitions | `grep -h "^func .*_field_is_safe" compiler/*.gst \| wc -l` |
| `*_align_up` | 3 definitions | `grep -h "^func .*_align_up" compiler/*.gst \| wc -l` |

**Corrected 2026-09-07 at `00715c96`, by two lanes measuring independently. The
two counts above hold. The identity claim that stood beside them did not, and it
was the load-bearing half.**

This section read *"bodies byte-identical, so collapsing them is pure deletion
with no behaviour to preserve"*, and cited for `align_up`:
`grep -A6 "func .*_align_up" compiler/*.gst | grep -c "remainder := value - quotient"`
returning 3.

**That grep returns 3 whether or not the bodies agree.** All three share the
`remainder` line; they differ on the line *above* it, which the check never
looked at. Agreement with it was not weak evidence of byte-identity — it was
none, and it read as conclusive.

| Symbol | Definitions | Agree | Differ |
| --- | --- | --- | --- |
| the `field_is_safe` role | **15** | 12 | 3 |
| `*_align_up` | 3 | 2 | 1 |

**`align_up` is not collapsible, and this document should not have said it was.**

    // mir_array_slice.gst:262, mir_enum.gst:197
    if alignment <= 0 { return 0; }
    // mir_struct_layout.gst:146
    if alignment <= 0 { return 0 - 1; }

Everything below that line is identical in all three. Collapsing them changes
the value at `mir_struct_layout.gst:241`, where `field.offset` is assigned from
it with no prior guard on `field.alignment`. The validator paths reject a
non-positive alignment before they call it, so the divergence is unreachable
*there*; nobody has shown it unreachable in the constructor, and that proof is
the precondition for treating this as pure deletion. Three further encodings of
the same error case live in
`compiler/experiments/cranelift/src/main.rs:7286,9903,10994` as `Option<usize>`,
adjudicated by `scripts/phase14_{struct,enum,array_slice}_differential.sh` — so
a change here is gated on that differential, not on this document.
**Deferred, deliberately.**

**The `field_is_safe` population is 15, not 13.** The evidence grep is
name-scoped, and two helpers carry the same role under a spelling it cannot see:
`mir_aggregate_parameter_field_safe` and `mir_call_field_safe` are `_field_safe`,
not `_field_is_safe`. They are identical to each other and **not** to the other
twelve — they reject a third character:

    if std.str_find(value, ";") != 0 - 1 { return 0; }

A third exception, `mir_runtime_field_is_safe`, takes one parameter instead of
two and has no `allow_empty` at all. The fifteen fall into **three** behaviour
classes, not one. This is the failure CR-a recorded for the `_identity`
builders, in the same shape: the name was a proxy for the role, and it failed
silently.

**Safe to collapse: the twelve that agree.** Do it when a patch is already in one
of these files; do not open a patch for it. The other three are excluded by
behaviour, not by cost.

**`docs/VISION.md` still carries the uncorrected claim, and no patch can fix it
in place today.** The OD-17 row repeats *"3 byte-identical `align_up`"* as a
measurement. Correcting it was attempted here and reverted: `docs/VISION.md` is
one of twelve provider docs pinned by
`phase24_s1_8_authority_successor.provider_docs_consumer_successor` to **exactly
two accepted digests**, a pre- and a post-state. Any third digest is rejected by
construction, so an ordinary edit cannot land. Eleven of the twelve are frozen
this way; only `docs/STDLIB_FOUNDATIONS.md` is admitted at any bytes, via the
S1.8 living-surface collapse.

The successor's `status` is `ready_for_exact_provider_docs_rebase` and it names
`owning_docs_pull_request: 320`, which **merged on 2026-09-04**; its recorded
`owning_docs_exact_head_sha` is not an ancestor of `main`. The tree already sits
at the post-state, so **this is a record of a completed transition still enforced
as a constraint on the present** — the defect class Patch 24.3b owns. Advancing
the pair to make room for this correction would assert that PR #320's provider
docs rebase contains it, which is false; that bump was written and reverted, for
the same reason the `current_inventory` bump was in #353.

**Until that successor is retired or `docs/VISION.md` is registered as a living
surface, this document is the correction of record for OD-17's tally.**

**Two related findings are deliberately not here.** The 93 hand-rolled
`_identity` string builders carry a correctness consequence — there is no single
definition of the `:field=` serialization, so the sites can diverge and a
divergence is a silent MIR identity collision — and the 247 `*_empty_*`
constructors may be irreducible without generics over the table types. Neither is
a while-you-are-here edit, and both are governed by whether the one-way rule binds
the compiler's own implementation, registered as **OD-17**. They belong in a
scheduled patch once that resolves, not in this document.
