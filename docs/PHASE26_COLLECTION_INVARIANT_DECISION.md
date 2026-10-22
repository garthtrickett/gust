# Collection invariants — OD-20 proposal

**Status: OPEN proposal, registered 2026-10-22.**
[VISION §0.15](VISION.md#015-open-decisions) owns the decision status.
This record brings the Cranelift handoff's private proposal into the public
register. It grants no implementation authority and resolves no existing OD.

## Decision requested

Establish a generic compiler-enforced collection validity invariant before
shipping the Phase 26.1 safe byte wrapper. The proposed direction is to reserve
backing, initialized-length, capacity and arena metadata mutation to validated
collection operations, require valid initialization before use, check indexing
against initialized elements, and check growth arithmetic before allocation.

The operator must select the source visibility and initialization rule and the
observable failure contract for invalid indexing and growth overflow. This
proposal does not select new syntax, a trap scope, a recoverable error API, a
new MIR operation, or a runtime ABI. A decision must state which of those
interfaces it authorizes the compiler owner to change.

Checking caller-controlled length and capacity alone cannot establish the
actual allocation extent. The design must cover construction, direct fields,
copies, references, aliases, aggregate carriage and calls. It must preserve
ordinary valid construction and brand lifetimes without recognizing a zlib
wrapper or one library type by name in a backend.

## Seven-point ownership report

1. **Intended behavior.** Safe callers can construct, copy, borrow, index and
   grow valid collections. They cannot fabricate backing or arena association,
   expose uninitialized elements, access outside initialized length, or wrap
   allocation sizes. The separately owned safe adapter wrapper returns bytes
   in its explicit output arena with classified errors.
2. **Existing limitation.** Retained compile-only observations accepted safe
   Vector length/capacity writes and use of a default record. None of those
   generated programs was executed. In the current native worker,
   `lower_index_place` computes an ordinary Vector element address without a
   length check. `lower_vector_method` doubles capacity and computes byte
   counts in I32 without an overflow check. The scoped collection intrinsic
   added by R2 has a separate admission proof and does not cover these ordinary
   operations.
3. **Smallest proposed semantic change.** Give registered collections a generic
   metadata and initialization authority invariant, checked initialized-element
   access, and checked growth. Decide source compatibility and observable
   failure behavior before choosing an implementation. A wrapper-local prefill
   bound does not repair the general safe-language limitation.
4. **Files and layers affected.** Cranelift owns generic frontend checking in
   `compiler/typechecker.gst`, canonical producer metadata if needed, native
   lowering in `compiler/experiments/cranelift/src/full_program.rs`, and owning
   guards/registry evidence. Docs/vision owns this proposal and OD registration.
   Stdlib owns the separate public wrapper after merged compiler support and
   activation of its lane.
5. **Effect on the retired backend.** It remains retired. Preserve frozen
   expected behavior and predecessor projections. Any change to canonical
   operation meaning needs explicit shared-zone authority.
6. **Effect on Cranelift.** Ordinary index/growth lowering needs qualification
   under the selected invariant. Preserve actual element layout, stride,
   brands and allocator ABI; R2's scoped proof cannot authorize every Vector.
7. **Effect on bootstrap.** Frontend or producer changes require the applicable
   native emitted-object fixed point and exact-head authoritative CI. The
   removed C seed is not recreated or hand-edited.

## Evidence and limits

The source audit was checked against merged main
`6bca6cdde2a3966758fc3fb40e04fc3115e270ad` on 2026-10-22. The matching
source hashes are:

| Source | SHA-256 |
| --- | --- |
| `compiler/typechecker.gst` | `ab588402efc7e0314bed2832255b3a31fc1c2fc1dec12ec83be11b072f09f303` |
| `compiler/experiments/cranelift/src/full_program.rs` | `39db63a2c674a141ffdafd03fa706b1bbb83885a08f45ac9aeb673be742f0dbc` |

The relevant sites are `env_register_std_templates`, `lower_index_place`,
and the Push branch of `lower_vector_method`. The registrar read those bodies;
this is a static audit, not a fresh compile or runtime reproduction.

Retained local evidence lives beneath
`/home/gust/phase26-recovery/boot970ebe4e/`:

| Artifact | SHA-256 |
| --- | --- |
| `r4-current-main-safety-boundary-v1.json` | `cfa1b7066a10a1fd96b4019f8dca480b914f5759aa1201813de54fd9992e8e5c` |
| `r4-collection-invariants-ownership-proposal-v1.json` | `cfc6affd950c8b23d5e5f738da3a7bb6dbe16f3ccea0a25624ae25c2f346258a` |
| `r2-r4-vector-metadata-compile-only-v3/output/result.json` | `e4098ccb3554d39f6a488c7648ca1b6a1f6c3c114ff06253fd9567f535c7ed08` |

These artifact digests were rechecked at registration. The result records four
successful compilations with `ACCEPTED_UNEXECUTED` observations. This establishes
the historical admission observation, not an executed out-of-bounds result or
a current-main compiler reproduction. The private artifacts are retained local
evidence, not a clean-machine public reproduction package.

## Required qualification after a decision

The compiler owner must qualify valid direct/reference Byte, Int and Bool
construction, copying, indexing and growth; exact metadata/default-invalid
diagnostics; alias, arena and brand regressions; initialized-length boundaries;
and growth/size overflow without huge allocations or executing invalid memory
accesses. Preserve unchanged predecessor projections and obtain the native
fixed point, exact-head owning CI, independent review and merged support before
the Stdlib wrapper handoff. A design is falsified if safe source can fabricate
the authority it checks, or if ordinary valid collection uses lose their
required behavior.

## Phase 26.1 handoff

[PR #603](https://github.com/garthtrickett/gust/pull/603) merged the R2 scoped
byte-copy capability as `c0aaf4f94e5f33daf8b65fa9235226b3bd685bb3`.
[PR #604](https://github.com/garthtrickett/gust/pull/604) merged pinned-zlib
qualification with a signed test profile as
`6bca6cdde2a3966758fc3fb40e04fc3115e270ad`. Those publications establish
capability increments; they do not close the full R1–R6 release gates.

OD-20 blocks the FFI-R4 safe-wrapper claim and is also relevant to Phase 26.5.
The pending public tagged-result representation is a separate question; this
proposal does not substitute a handle for a promised success Vector. Production
package/signing admission, the public wrapper, full regressions, release closure
and the separately successful final-main Historical Full still need evidence
under the [active roadmap](PHASES_26_AND_27.md#required-release-gates-and-patch-order).

At the 2026-10-22 00:37 UTC registrar check, Paseo listed only the new VISION
agent, the work board was empty, and GitHub had no open capability PR. Resuming
the compiler owner and selecting OD-20's semantics are distinct prerequisites;
the registrar supplies neither semantic authority nor another lane's activation.
