# Resource collection slot ownership and observation — OD-23 proposal

**Status: OPEN proposal, registered 2026-10-22. No decision is inferred.**
[VISION §0.15](VISION.md#015-open-decisions) owns the status. Register this
question before future public admission of the resource-valued collection
cohort. The current authorized metadata/index/growth/copy repair and its
unblocked qualification continue; this record grants no resource admission.

## Question and current boundary

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

## Seven-point ownership report

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

## Evidence and limits

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
