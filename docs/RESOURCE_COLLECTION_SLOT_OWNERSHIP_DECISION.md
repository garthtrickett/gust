# Resource collection slot ownership and observation — OD-23 proposal

**Status: OPEN proposal, registered 2026-10-22. No decision is inferred.**
[VISION §0.15](VISION.md#015-open-decisions) owns the status. Register this
question before future public admission of the resource-valued collection
cohort. The 2026-10-24 Phase 26.2 characterization and continuation are recorded
below; this record grants no resource admission or slot-ownership decision.

## Question and retained 2026-10-22 boundary

OD-20 C preserves permitted valid collection copies and their initialized
values while retaining existing resource, move and drop meaning. Existing
single-owner resource rules do not by themselves decide which slot
observations through a copied handle remain permitted after an element
transfers. In the reported component path, resource identity does not descend
through the collection's backing raw pointer to establish a shared
slot/acquisition identity.

The retained component-only witness copies a resource-valued Vector, performs
a borrowed `PopTransfer`, and observes the slot through the copied handle.
Typed component admission, canonical production and relocatable object emission
succeed. That does not prove the later observation is permitted-valid. No
resulting program was linked or run. The independent public CLI output reports
`deferred_p13_resource_runtime_semantics`, with expected failure stage
`before_driver_discovery`; it supplies no executable support claim.

The current repair preserves transfer zeroing and that public deferral.
Preserve existing qualified resource cohorts. This report is neither an
admitted-profile executable failure nor justification to broaden admission.
Allocator payload zeroing addresses initial storage contents; it does not
choose post-transfer ownership or observation validity.

**Proposal:** require an explicit generic resource-slot ownership/observation
contract and its qualification before opening this public cohort. Specify
which acquisitions and later observations remain valid, how slot identity
survives permitted handle copies, and who retains cleanup authority after
transfer. Then enforce that decided contract through the owning compiler path.
No global move-only collection rule, alias invalidation or removal of resource
zeroing is proposed. The current question authorizes none of those changes.

## Phase 26.2 characterization — 2026-10-24

The activated remainder of Phase 26 includes generalized linear-resource
enforcement. Its [canonical 26.2 C contract](PHASES_26_AND_27.md#phase-262--generalized-linear-resource-enforcement)
already requires `Index[T, ctx]` to inherit linearity when `T` is linear: no
duplication or implicit copy, with ownership transferred only by explicit move
or through its `drop_func`. It also forbids freeing or moving an allocator,
including `std.GenerationalSwap`, while a resource branded by it remains open.
OD-23 does not reopen those requirements. It records the still-unselected
slot-observation and cleanup contract needed to implement the collection cases
without silently changing OD-20 C's preservation of permitted valid copies.

On main `35ebca4c91dce0b14d7343e638c8ed91a09cd867`, the compiler owner mapped
the existing Phase 20 declaration/destructor/acquisition and generic cleanup
foundations, plus Phase 24 local resource transfer. These foundations are
implemented starting points, not newly completed Phase 26.2 exit gates.
The inventory reports that `Index` is still classified as non-linear and that
allocator invalidation does not reject an active branded resource owner.

Five corrected compile-only captures cover a live resource followed by
allocator Free, Move or GenerationalSwap, a closed-resource Free control, and
a copied Index. Each reaches the intentionally failing driver after frontend
admission. None produces an executable or executes a program. This establishes
the current frontend boundary; it does not demonstrate a runtime failure or
qualify native resource-slot behavior. The initial capture used an invalid
Arena constructor and is retained but excluded from this characterization.
The registrar independently checked the five source hashes, diagnostics,
exits and absence of execution from the retained corrected capture.

The compiler's selected first obligation is **allocator liveness**, using
resolved allocator identity and existing acquisition, transfer and validated
cleanup state. It covers Free, explicit allocator move and both invalidated or
rebranded sides of GenerationalSwap. This correction can proceed independently
of OD-23; it selects no Index-slot semantics, MIR meaning, runtime ABI or
ownership-observation transport. Deferred allocator execution ordering remains
a separately identified follow-on if it cannot fit that coherent correction.

### Current proposal and decision boundary

**Proposal only:** retain cleanup authority in one compiler-identified owning
slot and require an explicit checked transfer for owned extraction. A copied
observation would not acquire cleanup authority. This direction is unselected;
it is not permission to implement a new borrow or alias model.

The compiler's slot-state/action packet makes the remaining cases concrete.
Its state labels (uninitialized, owned, cleanup scheduled, transferred and
closed) describe the question; they are not new compiler states or MIR
instructions. Canonical 26.2 C forbids duplicating an owning Index, while
OD-20 C protects copies already proved valid. Neither requires treating every
historical resource copy as valid or invalid. The open boundary is which views
are non-owning, how their validity is proved and what they may observe after
ownership moves.

| Case | Contract still to specify |
| --- | --- |
| Create or copy an owning `Index[linear T, ctx]` | One owner is mandatory; choose the ownership carrier and distinguish owning uses from observation without reclassifying existing admitted cohorts by inference |
| Move an owner or copy an observation | Preserve one acquisition and cleanup authority; decide whether a non-owning observer survives the ownership transfer |
| Read an occupied slot | Prevent implicit copying of owned T; distinguish observation from checked owned extraction and specify observation scope |
| Read after extraction or removal | Reject the read, expose absence, or retain a qualified non-owning observation; never fabricate a valid zero resource |
| Insert into an uninitialized slot | Establish slot identity and transfer ownership once; specify whether observations can predate activation |
| Replace an occupied slot | Reject replacement, return the old owner, or destroy it under a qualified observation rule; silently leaking or double-destroying it is forbidden |
| Copy a collection handle or grow through one copy | Preserve shared slot/acquisition identity and valid backing across copies, distinct logical lengths, growth, nested carriage and calls |
| Destroy a copied handle or schedule cleanup | Assign exactly-once destructor authority and decide which observations remain valid until cleanup |
| Free or move the branded allocator | Include admitted resource-valued slots in the live-owner proof; direct owned-resource enforcement requires no OD-23 choice |

Three observation alternatives remain **UNSELECTED**:

1. **Owner-rooted:** observation validity ends when the original owner
   transfers, and subsequent use must be rejected. This cannot invalidate an
   observation already promised valid by another admitted contract.
2. **Slot-rooted:** observation is valid only while the same acquisition
   remains resident and live in that slot. Extraction and replacement must
   enforce the state boundary through every copied handle.
3. **Retained-value after extraction:** some non-owning reads of initialized
   old backing remain valid after ownership transfers. This requires proof
   that the destination owner's cleanup cannot invalidate those reads; the
   existing single-owner rule alone does not provide that proof.

The packet does not recommend or select an alternative, syntax, lifetime
model, storage family or API. Selecting an observation rule would still require
the owning lane to specify its carrier and per-operation enforcement. A design
requiring new lifetime algebra, MIR meaning or runtime ABI needs that additional
authority before implementation; this registration supplies none.

These questions refine an existing OD; they do not turn the canonical
no-duplication requirement into an optional design. Any proposed observation
transport must be reconciled with that requirement and OD-20 C before it is
treated as decided. Unannotated types and ordinary compiler collections retain
26.2 A's opt-in isolation boundary.

The current seven-point report binds: (1) single-owner linear payloads;
(2) the frontend acceptance limitation above; (3) this unselected generic
slot/transfer/cleanup proposal; (4) compiler typechecking, storage/alias/resource
tracking, canonical ownership evidence and applicable lowerers/guards;
(5) review of historical oracle meaning if slot ownership changes, without
recreating a retired route; (6) shared decided semantics consumed by Cranelift;
and (7) per-operation opt-in and native fixed-point regression coverage because
the compiler uses Index throughout. Docs records this boundary; it does not
supply the semantic implementation or select the proposal.

OD-23 must be resolved before admitting the affected resource-valued collection
operations. Independent allocator-liveness work, Phase 26.3 preparation and
separately routed Phase 26.5 compiler prerequisites can continue. The completed
26.1 FFI-R1–R6 first release is preserved; its bounded acceptance does not close
general resource-slot support or the remaining Phase 26 exit gates.

The current report is
`/home/gust/phase26-recovery/phase26-2-20261024/inventory-and-boundary-v1.json`,
SHA-256 `8425e35037e227a8767dc3ce2aea498db025fc32a629483eb1eced08188a5aa2`.
Its corrected capture is `source-inventory-v2.json` in the same directory,
SHA-256 `d2c68dbeb60371f8733856284cedc7f5b652af217da9501be58ef0e779a6f9bd`.
The independent registrar check is
`/home/gust/phase26-recovery/phase26-remainder-activation-20261024/vision-checked-phase26-2-source-characterization-v1.json`,
SHA-256 `33794e95418f9296d220348d287a1203567f208a69f72fd2f864ba131b45dd99`.
The slot-state/action packet is
`/home/gust/phase26-recovery/phase26-2-20261024/od23-slot-state-action-matrix-v1.md`,
SHA-256 `ff7b695fccaad49e1f793f807a292cad712fb5a94edadb73b0650df85171a1f3`.
These retained local records are characterization evidence, not a portable
executable qualification package or an operator decision.

## Retained 2026-10-22 seven-point ownership report

1. **Intended behavior.** Preserve permitted handle copies and initialized
   values/reference observations while resource transfers retain single-owner
   cleanup identity. Future admission needs an explicit meaning for observation
   after slot transfer.
2. **Existing limitation.** Typed component acceptance of the retained copied
   handle/borrowed transfer/slot-read path does not establish that its final
   observation is allowed. The canonical operation and object exist, but the
   public profile independently defers. No runtime failure is demonstrated.
3. **Smallest generic change to decide.** Define resource-slot ownership and
   observation across copied handles, then qualify generic acquisition/slot
   identity and cleanup enforcement. Existing single-owner rules and OD-20 C
   leave this decision open. Removing zeroing alone does not settle it.
4. **Files and layers.** Cranelift owns resource acquisition, alias and
   collection-slot tracking in `compiler/typechecker.gst`, canonical producer
   ownership evidence, worker validation/lowering and resource regressions.
   Docs/vision records the question. A Stdlib wrapper cannot supply a local
   workaround for the missing semantic contract.
5. **Retired oracle.** Preserve frozen historical evidence. Any future generic
   frontend enforcement must remain canonical; a backend-specific meaning is
   not authorized, and the retired route is not recreated.
6. **Cranelift.** The component can emit an object for the reported program;
   the public route still defers. The current repair retains resource transfer
   zeroing and does not extend resource admission. Future admission must first
   resolve this contract and qualify its decided behavior.
7. **Bootstrap.** Future frontend/producer tracking may require native
   emitted-object fixed-point qualification. This registration implements no
   new MIR instruction, runtime symbol, layout/ABI, resource or drop meaning.

## Retained 2026-10-22 evidence and limits

The Cranelift report is retained at
`/home/gust/phase26-recovery/r4-preflight-20261022/resource-slot-ownership-boundary-v1.json`,
SHA-256 `04200c19ec506523cef1afca9febb974fc90d0b514afffd99fd5fc276fcf2d9a`.
It records the seven points and a compile-only witness from the unpublished
`codex/phase26-1r4-collection-preflight` worktree, based on main
`6bca6cdde2a3966758fc3fb40e04fc3115e270ad`. This is not an exact published-head
qualification or a fresh reproduction by the registrar.

All witness digests below were rechecked at registration. The first three
files are beneath that worktree's
`build/r4-preflight/resource-authority-compile-only/`; the final two are beneath
`build/r4-preflight/`.

| Artifact | SHA-256 |
| --- | --- |
| `source.gst` | `7193b10db46f16eb02369016ac662b81eba31798fa794ccd3a161230da9ee9fc` |
| `source.canonical` | `675c5dd34a9d461ee4424a53c2d05ebea66c89f150420770388b3b46416024f9` |
| `source.o` | `7c4e599d8b5d875bd871b79c6ee6078f1cb988dc09ed846e8cfc2473e8ac345a` |
| `resource-public.stdout` | `9e295145576984fdac42341a209aa29ed31afcee2f802961a4f97bdc9f340165` |
| `resource-public.stderr` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

The registrar verified `source.o` as an ELF relocatable object (`ET_REL`) and
read the public deferral output. The report records no linked or executed
resource witness. Private retained artifacts are evidence inputs, not a
clean-machine public reproduction package. An independent Spec reviewer
agreed that this is a genuine contract question; that assessment is not a
decision or a runtime result.

Resolve the OD before the first future patch that opens this public resource
collection cohort. That patch needs the decided validity/cleanup rules,
positive and negative source cases, canonical/worker checks, resource and alias
regressions, bootstrap and exact-head owning CI. No full R1–R6 completion or
resource-cohort support follows from this registration.
